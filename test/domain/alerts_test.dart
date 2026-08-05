import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/data/models/traffic_snapshot.dart';
import 'package:flowsense_mobile/data/repository/traffic_repository.dart';
import 'package:flowsense_mobile/domain/alerts.dart';
import 'package:flowsense_mobile/domain/congestion.dart';
import 'package:flowsense_mobile/domain/subscription.dart';
import 'package:flowsense_mobile/features/alerts/notifier.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 8, 2, 12);
const _poll = Duration(seconds: 5);

/// Everything subscribed, every hour active — so the debounce tests measure the
/// rule rather than the delivery gate.
const _allowAll = SubscriptionSettings(
  cameraIds: {'30', '31'},
  activeHours: [TimeRange(startMinute: 0, endMinute: 24 * 60 - 1)],
);

AlertObservation _obs(
  CongestionLevel level, {
  bool isStale = false,
  String cameraId = '30',
}) =>
    AlertObservation(
      cameraId: cameraId,
      name: 'Simpang $cameraId',
      level: level,
      isStale: isStale,
    );

/// Replays a poll sequence through the rule and returns one decision per poll,
/// so a test reads as the story it is asserting.
List<AlertDecision> _replay(
  List<AlertObservation> polls, {
  AlertRule rule = const AlertRule(),
  Duration since = _poll,
}) {
  var state = AlertState.initial;
  return [
    for (final poll in polls)
      () {
        final outcome = rule.evaluate(state, poll, since: since);
        state = outcome.state;
        return outcome.decision;
      }(),
  ];
}

// --- Fixtures for the service tests ---------------------------------------

const _intersections = [
  Intersection(
    id: '30',
    name: 'Simpang DPRD',
    lat: -6.8047,
    lon: 110.8405,
    lanes: ['kota', 'ploso'],
    capacity: {'kota': 10, 'ploso': 10},
  ),
  Intersection(
    id: '31',
    name: 'Simpang Tanjung',
    lat: -6.8112,
    lon: 110.8348,
    lanes: ['utara', 'selatan'],
    capacity: {'utara': 10, 'selatan': 10},
  ),
];

TrafficRecord _record(String id, Map<String, int> perLane, DateTime ts) =>
    TrafficRecord(
      ts: ts,
      cameraId: id,
      cameraName: 'Simpang $id',
      totalVehicles: perLane.values.fold(0, (a, b) => a + b),
      perLane: perLane,
    );

/// Both cameras at the same level, timestamped now — so nothing is stale.
RepoData _fresh(DateTime at, {required int kota, required int utara}) =>
    RepoData(
      snapshot: TrafficSnapshot(fetchedAt: at, records: [
        _record('30', {'kota': kota, 'ploso': 1}, at),
        _record('31', {'utara': utara, 'selatan': 1}, at),
      ]),
      isStale: false,
      isFromCache: false,
    );

void main() {
  group('AlertRule', () {
    test('a single macet poll does not fire', () {
      expect(
        _replay([_obs(CongestionLevel.macet)]),
        [AlertDecision.none],
      );
    });

    test('three consecutive macet polls fire, exactly once', () {
      expect(
        _replay(List.filled(5, _obs(CongestionLevel.macet))),
        [
          AlertDecision.none,
          AlertDecision.none,
          AlertDecision.raise,
          // An alert already up does not re-fire on every later poll — that is
          // how a useful notification becomes spam people mute.
          AlertDecision.none,
          AlertDecision.none,
        ],
      );
    });

    test('an already-raised alert does not re-fire after a padat dip', () {
      expect(
        _replay([
          _obs(CongestionLevel.macet),
          _obs(CongestionLevel.macet),
          _obs(CongestionLevel.macet), // raise
          _obs(CongestionLevel.padat),
          _obs(CongestionLevel.macet),
          _obs(CongestionLevel.macet),
          _obs(CongestionLevel.macet),
        ]).where((d) => d == AlertDecision.raise).length,
        1,
      );
    });

    test('flapping lancar/macet never reaches the threshold', () {
      expect(
        _replay([
          _obs(CongestionLevel.macet),
          _obs(CongestionLevel.lancar),
          _obs(CongestionLevel.macet),
          _obs(CongestionLevel.lancar),
          _obs(CongestionLevel.macet),
          _obs(CongestionLevel.lancar),
        ]),
        everyElement(AlertDecision.none),
      );
    });

    test('stale data never fires — a dead connector is not a traffic jam', () {
      expect(
        _replay(List.filled(10, _obs(CongestionLevel.macet, isStale: true))),
        everyElement(AlertDecision.none),
      );
    });

    test('unknown never fires either', () {
      expect(
        _replay(List.filled(10, _obs(CongestionLevel.unknown))),
        everyElement(AlertDecision.none),
      );
    });

    test('a sustained return to lancar clears a raised alert', () {
      expect(
        _replay([
          _obs(CongestionLevel.macet),
          _obs(CongestionLevel.macet),
          _obs(CongestionLevel.macet), // raise
          _obs(CongestionLevel.lancar),
          _obs(CongestionLevel.lancar),
          _obs(CongestionLevel.lancar), // clear
        ]).last,
        AlertDecision.clear,
      );
    });

    test('one lancar poll does not clear — the return has to be sustained', () {
      expect(
        _replay([
          _obs(CongestionLevel.macet),
          _obs(CongestionLevel.macet),
          _obs(CongestionLevel.macet), // raise
          _obs(CongestionLevel.lancar),
          _obs(CongestionLevel.macet),
        ]),
        isNot(contains(AlertDecision.clear)),
      );
    });

    test('stale data does not clear an alert that is already up', () {
      expect(
        _replay([
          _obs(CongestionLevel.macet),
          _obs(CongestionLevel.macet),
          _obs(CongestionLevel.macet), // raise
          _obs(CongestionLevel.lancar, isStale: true),
          _obs(CongestionLevel.lancar, isStale: true),
          _obs(CongestionLevel.lancar, isStale: true),
        ]),
        isNot(contains(AlertDecision.clear)),
      );
    });

    test('a gap longer than maxGap breaks the streak', () {
      // Three macet readings an hour apart are three readings, not a jam.
      expect(
        _replay(
          List.filled(3, _obs(CongestionLevel.macet)),
          since: const Duration(hours: 1),
        ),
        everyElement(AlertDecision.none),
      );
    });

    test('a gap does not cancel an alert that is already raised', () {
      const rule = AlertRule();
      var state = const AlertState(isRaised: true);

      // Backgrounded for an hour, then one lancar poll: the streak restarted,
      // so this is the first of three, not the third.
      final afterGap = rule.evaluate(
        state,
        _obs(CongestionLevel.lancar),
        since: const Duration(hours: 1),
      );
      expect(afterGap.decision, AlertDecision.none);
      expect(afterGap.state.isRaised, isTrue);

      state = afterGap.state;
      for (var i = 0; i < 2; i++) {
        state = rule.evaluate(state, _obs(CongestionLevel.lancar), since: _poll)
            .state;
      }
      expect(state.isRaised, isFalse, reason: 'the third lancar poll clears it');
    });

    test('the thresholds are configurable', () {
      expect(
        _replay(
          List.filled(2, _obs(CongestionLevel.macet)),
          rule: const AlertRule(raiseAfter: 2),
        ),
        [AlertDecision.none, AlertDecision.raise],
      );
    });
  });

  group('AlertEngine', () {
    test('tracks each intersection separately', () {
      final engine = AlertEngine();
      var at = _t0;
      var events = <AlertEvent>[];

      for (var i = 0; i < 3; i++) {
        at = at.add(_poll);
        events = engine.observe([
          _obs(CongestionLevel.macet, cameraId: '30'),
          _obs(CongestionLevel.lancar, cameraId: '31'),
        ], at);
      }

      expect(events, hasLength(1));
      expect(events.single.decision, AlertDecision.raise);
      expect(events.single.observation.cameraId, '30');
      expect(engine.stateFor('31').isRaised, isFalse);
    });

    test('emits nothing on a quiet poll', () {
      expect(
        AlertEngine().observe([_obs(CongestionLevel.lancar)], _t0),
        isEmpty,
      );
    });
  });

  group('observationsFor', () {
    test('marks an intersection missing from the snapshot as stale', () {
      final observations = observationsFor(
        snapshot: TrafficSnapshot(fetchedAt: _t0, records: [
          _record('30', {'kota': 9, 'ploso': 1}, _t0),
        ]),
        intersections: _intersections,
        now: _t0,
        staleAfter: const Duration(seconds: 30),
        laneCapacityDefault: 10,
      );

      expect(observations.map((o) => o.cameraId), ['30', '31']);
      expect(observations.first.level, CongestionLevel.macet);
      expect(observations.first.isStale, isFalse);
      expect(observations.last.level, CongestionLevel.unknown);
      expect(observations.last.isStale, isTrue);
    });

    test('marks an old record stale without changing its level', () {
      final observations = observationsFor(
        snapshot: TrafficSnapshot(fetchedAt: _t0, records: [
          _record('30', {'kota': 9, 'ploso': 1},
              _t0.subtract(const Duration(minutes: 5))),
        ]),
        intersections: [_intersections.first],
        now: _t0,
        staleAfter: const Duration(seconds: 30),
        laneCapacityDefault: 10,
      );

      expect(observations.single.level, CongestionLevel.macet);
      expect(observations.single.isStale, isTrue);
    });
  });

  group('JamAlertService', () {
    late FakeAlertNotifier notifier;
    late FakeClock clock;
    late JamAlertService service;

    setUp(() {
      notifier = FakeAlertNotifier();
      clock = FakeClock(_t0);
      service = JamAlertService(
        notifier: notifier,
        config: const AppConfig(laneCapacityDefault: 10),
        // These tests are about the debounce rule, so delivery is opened all
        // the way up: both cameras subscribed, every hour active. The gating
        // itself is exercised separately below.
        subscriptions: _allowAll,
        clock: clock,
      );
    });

    Future<void> poll(RepoData Function(DateTime at) build) async {
      clock.advance(const Duration(seconds: 5));
      await service.onState(build(clock.now()), _intersections);
    }

    test('three sustained macet polls reach the notifier once', () async {
      for (var i = 0; i < 4; i++) {
        await poll((at) => _fresh(at, kota: 9, utara: 1));
      }

      expect(notifier.raised, hasLength(1));
      expect(notifier.raised.single.cameraId, '30');
      expect(notifier.raised.single.name, 'Simpang DPRD');
      expect(notifier.cleared, isEmpty);
    });

    test('a sustained recovery reaches the notifier as a clear', () async {
      for (var i = 0; i < 3; i++) {
        await poll((at) => _fresh(at, kota: 9, utara: 1));
      }
      for (var i = 0; i < 3; i++) {
        await poll((at) => _fresh(at, kota: 1, utara: 1));
      }

      expect(notifier.raised, hasLength(1));
      expect(notifier.cleared.single.cameraId, '30');
    });

    test('a cache replay is not a poll', () async {
      for (var i = 0; i < 2; i++) {
        await poll((at) => _fresh(at, kota: 9, utara: 1));
      }

      // The same reading arriving off disk must not count as the third poll.
      clock.advance(const Duration(seconds: 5));
      final replayed = _fresh(clock.now(), kota: 9, utara: 1);
      await service.onState(
        RepoData(
          snapshot: replayed.snapshot,
          isStale: false,
          isFromCache: true,
        ),
        _intersections,
      );

      expect(notifier.raised, isEmpty);
    });

    test('a failed poll is not a poll', () async {
      for (var i = 0; i < 2; i++) {
        await poll((at) => _fresh(at, kota: 9, utara: 1));
      }

      final lastGood = _fresh(clock.now(), kota: 9, utara: 1).snapshot;
      await service.onState(
        RepoError(message: 'jaringan bermasalah', lastGood: lastGood),
        _intersections,
      );
      await service.onState(
        RepoError(message: 'jaringan bermasalah', lastGood: lastGood),
        _intersections,
      );

      expect(notifier.raised, isEmpty);
    });

    test('loading never notifies', () async {
      await service.onState(const RepoLoading(), _intersections);
      expect(notifier.raised, isEmpty);
      expect(notifier.cleared, isEmpty);
    });
  });

  group('delivery gate', () {
    late FakeAlertNotifier notifier;
    late FakeClock clock;

    JamAlertService serviceWith(SubscriptionSettings subscriptions) =>
        JamAlertService(
          notifier: notifier,
          config: const AppConfig(laneCapacityDefault: 10),
          subscriptions: subscriptions,
          clock: clock,
        );

    setUp(() {
      notifier = FakeAlertNotifier();
      clock = FakeClock(_t0);
    });

    Future<void> jam(JamAlertService service, {int polls = 4}) async {
      for (var i = 0; i < polls; i++) {
        clock.advance(_poll);
        await service.onState(
          _fresh(clock.now(), kota: 9, utara: 1),
          _intersections,
        );
      }
    }

    test('nothing is delivered when nothing is subscribed', () async {
      // The default. The app never opts anyone in on their behalf.
      await jam(serviceWith(const SubscriptionSettings()));
      expect(notifier.raised, isEmpty);
    });

    test('an unsubscribed intersection stays silent while a jam runs',
        () async {
      await jam(serviceWith(SubscriptionSettings(
        cameraIds: const {'31'}, // not the one that jams
        activeHours: _allowAll.activeHours,
      )));
      expect(notifier.raised, isEmpty);
    });

    test('outside the active hours, a real jam is not delivered', () async {
      // _t0 is 12:00 — squarely between the two commute windows.
      await jam(serviceWith(const SubscriptionSettings(
        cameraIds: {'30'},
        activeHours: SubscriptionSettings.defaultActiveHours,
      )));
      expect(notifier.raised, isEmpty,
          reason: 'the default quiet hours must actually be quiet');
    });

    test('inside an active window the same jam is delivered', () async {
      // Same settings, a clock inside the morning peak.
      clock = FakeClock(DateTime.utc(2026, 8, 2, 7));
      await jam(serviceWith(const SubscriptionSettings(
        cameraIds: {'30'},
        activeHours: SubscriptionSettings.defaultActiveHours,
      )));
      expect(notifier.raised, hasLength(1));
    });

    test('the macet-only threshold ignores a padat intersection', () async {
      final service = serviceWith(SubscriptionSettings(
        cameraIds: const {'30'},
        activeHours: _allowAll.activeHours,
      ));
      for (var i = 0; i < 4; i++) {
        clock.advance(_poll);
        // 5/10 is padat, never macet, so the rule never raises anyway — the
        // point is that it stays silent under both mechanisms.
        await service.onState(
          _fresh(clock.now(), kota: 5, utara: 1),
          _intersections,
        );
      }
      expect(notifier.raised, isEmpty);
    });

    test('a clear is delivered even after the window closes', () async {
      // Raise inside the morning peak...
      clock = FakeClock(DateTime.utc(2026, 8, 2, 8, 50));
      final service = serviceWith(const SubscriptionSettings(
        cameraIds: {'30'},
        activeHours: SubscriptionSettings.defaultActiveHours,
      ));
      await jam(service, polls: 3);
      expect(notifier.raised, hasLength(1));

      // ...and recover after 09:00, when raises are no longer allowed.
      clock.advance(const Duration(minutes: 20));
      for (var i = 0; i < 3; i++) {
        clock.advance(_poll);
        await service.onState(
          _fresh(clock.now(), kota: 1, utara: 1),
          _intersections,
        );
      }

      // Suppressing this would strand a jam warning on screen after the jam
      // ended — worse than the notification it was trying to avoid.
      expect(notifier.cleared, hasLength(1));
    });
  });
}
