import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import '../core/config/app_config.dart';
import '../data/api/flowsense_api.dart';
import '../data/cache/snapshot_cache.dart';
import '../data/location/location_source.dart';
import '../data/models/intersection.dart';
import '../data/models/traffic_record.dart';
import '../data/prefs/subscription_store.dart';
import '../data/repository/traffic_repository.dart';
import '../domain/subscription.dart';

/// Runtime config. Overridden in tests; read from `--dart-define` in the app.
final appConfigProvider = Provider<AppConfig>(
  (ref) => const AppConfig.fromEnvironment(),
);

/// True when the app is running on bundled fixtures because no backend was
/// configured. Derived from the same condition `buildApi` uses, so the badge in
/// the app bar cannot disagree with what is actually serving the data.
final isDemoProvider =
    Provider<bool>((ref) => !ref.watch(appConfigProvider).isConfigured);

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final snapshotCacheProvider =
    Provider<SnapshotCache?>((ref) => const SnapshotCache());

/// **Always overridden at the root** — by `buildApi` in the entry points, and
/// by a fake in tests. Throwing here means a missing override is a loud
/// startup failure rather than a silent fallback to the network.
final apiProvider = Provider<FlowSenseApi>((ref) {
  throw UnimplementedError(
    'apiProvider must be overridden in ProviderScope (see lib/main_*.dart)',
  );
});

final repositoryProvider = Provider<TrafficRepository>((ref) {
  final repository = TrafficRepository(
    api: ref.watch(apiProvider),
    config: ref.watch(appConfigProvider),
    clock: ref.watch(clockProvider),
    cache: ref.watch(snapshotCacheProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

/// The one stream every screen watches. Widgets never learn whether the data
/// came from HTTP, the cache, or a fixture.
final snapshotProvider = StreamProvider<RepoState>(
  (ref) => ref.watch(repositoryProvider).watch(),
);

/// Static-ish geometry: fetched once, not polled.
final intersectionsProvider = FutureProvider<List<Intersection>>(
  (ref) => ref.watch(apiProvider).intersections(),
);

/// Camera id of the intersection whose detail sheet is open, or null.
final selectedIntersectionProvider = StateProvider<String?>((ref) => null);

/// How far back the operator history chart looks.
const kHistoryWindow = Duration(hours: 1);

/// History for one intersection, backed by `FlowSenseApi.history`. Keyed by
/// camera id so the operator dashboard can chart whichever one is selected.
///
/// The window is requested explicitly rather than left to the server's default:
/// the chart's x-axis is drawn against [kHistoryWindow], so the two must agree.
final historyProvider = FutureProvider.family<List<TrafficRecord>, String>(
  (ref, cameraId) {
    final now = ref.watch(clockProvider).now();
    return ref.watch(apiProvider).history(
          cameraId,
          from: now.subtract(kHistoryWindow),
          to: now,
        );
  },
);

/// How far back the operator detail chart looks, and at what resolution.
///
/// 96 buckets of 15 minutes. The layout spec rules out 5-minute buckets by
/// name: 288 points across 360 px is a blur, not a chart.
const kOperatorHistoryWindow = Duration(hours: 24);
const kOperatorHistoryBucket = Duration(minutes: 15);
const kOperatorHistoryBuckets = 96;

/// A day of history for one intersection, aggregated **server side**.
///
/// The bucket is requested explicitly rather than left to the server's
/// default, because the chart's x-axis is drawn against it — the two have to
/// agree or the bars land in the wrong places.
final operatorHistoryProvider =
    FutureProvider.family<List<TrafficRecord>, String>(
  (ref, cameraId) {
    final now = ref.watch(clockProvider).now();
    return ref.watch(apiProvider).history(
          cameraId,
          from: now.subtract(kOperatorHistoryWindow),
          to: now,
          bucket: '15m',
        );
  },
);

/// Overridden with a fake in tests, so no widget test touches a platform
/// channel.
final locationSourceProvider =
    Provider<LocationSource>((ref) => const GeolocatorLocationSource());

/// The device's position, or null when permission was refused, the service is
/// off, or no fix arrived.
///
/// Read once rather than streamed: the list shows distance to fixed junctions,
/// which does not need to update as a rider moves — and a live position stream
/// would cost battery for a number rendered to one decimal place.
final deviceLocationProvider = FutureProvider<DeviceLocation?>(
  (ref) => ref.watch(locationSourceProvider).current(),
);

final subscriptionStoreProvider =
    Provider<SubscriptionStore>((ref) => const SubscriptionStore());

/// What the user asked to be notified about. Device-local; never sent anywhere.
final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionSettings>(
  SubscriptionNotifier.new,
);

class SubscriptionNotifier extends Notifier<SubscriptionSettings> {
  @override
  SubscriptionSettings build() {
    // Defaults render immediately and the stored value replaces them when it
    // arrives, so the settings screen never opens on a spinner.
    unawaited(_restore());
    return const SubscriptionSettings();
  }

  Future<void> _restore() async {
    final stored = await ref.read(subscriptionStoreProvider).load();
    state = stored;
  }

  Future<void> _persist(SubscriptionSettings next) async {
    state = next;
    await ref.read(subscriptionStoreProvider).save(next);
  }

  Future<void> toggle(String cameraId) => _persist(state.toggle(cameraId));

  Future<void> setThreshold(AlertThreshold threshold) =>
      _persist(state.copyWith(threshold: threshold));

  Future<void> setActiveHours(List<TimeRange> hours) =>
      _persist(state.copyWith(activeHours: hours));
}
