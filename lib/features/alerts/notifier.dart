import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/config/app_config.dart';
import '../../core/logging/logger.dart';
import '../../data/models/intersection.dart';
import '../../data/repository/traffic_repository.dart';
import '../../domain/alerts.dart';
import '../../domain/subscription.dart';
import '../../state/providers.dart';

/// How an alert reaches the user.
///
/// An interface, not a plugin call, for one reason: `flutter test` must never
/// touch a platform channel. [FakeAlertNotifier] stands in everywhere the real
/// one would, so the rule and its wiring are testable on a machine with no
/// notification service at all.
abstract class AlertNotifier {
  /// Idempotent — safe to call before every send.
  Future<void> initialize();

  Future<void> raise(AlertObservation observation);

  /// Takes down the notification raised for this camera, if any.
  Future<void> clear(AlertObservation observation);
}

/// Records what it was asked to do. The test double.
class FakeAlertNotifier implements AlertNotifier {
  final List<AlertObservation> raised = [];
  final List<AlertObservation> cleared = [];
  int initializeCalls = 0;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<void> raise(AlertObservation observation) async =>
      raised.add(observation);

  @override
  Future<void> clear(AlertObservation observation) async =>
      cleared.add(observation);
}

/// The real thing, over `flutter_local_notifications`.
class LocalAlertNotifier implements AlertNotifier {
  LocalAlertNotifier({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String channelId = 'flowsense.jam';
  static const String channelName = 'Peringatan kemacetan';
  static const String channelDescription =
      'Pemberitahuan saat satu simpang macet dalam beberapa pembaruan berturut-turut.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  /// Stable within a session, which is all [clear] needs — the id only has to
  /// match the one [raise] used while the app is running. It is deliberately
  /// not persisted anywhere.
  static int notificationIdFor(String cameraId) =>
      cameraId.hashCode & 0x7fffffff;

  @override
  Future<void> initialize() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _ready = true;
  }

  @override
  Future<void> raise(AlertObservation observation) async {
    await initialize();
    await _plugin.show(
      id: notificationIdFor(observation.cameraId),
      title: 'Macet di ${observation.name}',
      body: 'Kepadatan bertahan di simpang ini. Pertimbangkan jalur lain.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: observation.cameraId,
    );
  }

  @override
  Future<void> clear(AlertObservation observation) async {
    await initialize();
    await _plugin.cancel(id: notificationIdFor(observation.cameraId));
  }
}

/// Drives [AlertEngine] from repository states and routes its decisions to an
/// [AlertNotifier].
class JamAlertService {
  JamAlertService({
    required this.notifier,
    required this.config,
    this.subscriptions = const SubscriptionSettings(),
    this.clock = const SystemClock(),
    AlertEngine? engine,
  }) : engine = engine ?? AlertEngine();

  final AlertNotifier notifier;
  final AppConfig config;

  /// What the user actually asked to hear about. Consulted at **delivery**
  /// time, not before the rule runs: the debounce state has to keep tracking
  /// every intersection regardless, or unsubscribing and resubscribing would
  /// reset a jam's streak and fire late.
  final SubscriptionSettings subscriptions;

  final Clock clock;
  final AlertEngine engine;

  /// Feeds one repository state to the rule.
  ///
  /// Only a **fresh** [RepoData] counts as a poll. A cache replay or a
  /// [RepoError]'s `lastGood` is the same reading arriving a second time, and
  /// counting it again would fire the alert a poll early.
  Future<void> onState(
    RepoState state,
    List<Intersection> intersections,
  ) async {
    if (state is! RepoData || state.isFromCache) return;

    final now = clock.now();
    final events = engine.observe(
      observationsFor(
        snapshot: state.snapshot,
        intersections: intersections,
        now: now,
        staleAfter: config.staleAfter,
        laneCapacityDefault: config.laneCapacityDefault,
      ),
      now,
    );

    for (final event in events) {
      final observation = event.observation;

      // A `clear` is always delivered. It only ever takes a notification down,
      // and suppressing it — because the user just unsubscribed, or because
      // the quiet hours started — would strand a jam warning on screen after
      // the jam ended.
      final allowed = event.decision == AlertDecision.clear ||
          subscriptions.allows(
            cameraId: observation.cameraId,
            level: observation.level,
            isStale: observation.isStale,
            now: now,
          );

      FlowLog.event('jam alert', fields: {
        'camera_id': observation.cameraId,
        'decision': event.decision.name,
        'delivered': allowed,
      });
      if (!allowed) continue;

      switch (event.decision) {
        case AlertDecision.raise:
          await notifier.raise(observation);
        case AlertDecision.clear:
          await notifier.clear(observation);
        case AlertDecision.none:
          break; // observe() never emits these.
      }
    }
  }
}

final alertNotifierProvider =
    Provider<AlertNotifier>((ref) => LocalAlertNotifier());

/// Rebuilt when the settings change, but the [AlertEngine] it carries is
/// created fresh with it — which is correct: editing subscriptions is a rare,
/// deliberate act, and starting the debounce over is safer than carrying
/// streaks across a change in what the user asked for.
final jamAlertServiceProvider = Provider<JamAlertService>(
  (ref) => JamAlertService(
    notifier: ref.watch(alertNotifierProvider),
    config: ref.watch(appConfigProvider),
    subscriptions: ref.watch(subscriptionProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Subscribes the alert service to the snapshot stream for as long as [child]
/// is mounted. Renders nothing of its own — it is wiring, wrapped around the
/// flavor's home screen.
class JamAlertListener extends ConsumerWidget {
  const JamAlertListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<RepoState>>(snapshotProvider, (_, next) {
      final state = next.valueOrNull;
      final intersections = ref.read(intersectionsProvider).valueOrNull;
      if (state == null || intersections == null) return;
      unawaited(
        ref.read(jamAlertServiceProvider).onState(state, intersections),
      );
    });
    return child;
  }
}
