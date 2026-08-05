import 'dart:convert';
import 'dart:io';

import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/data/api/fake_flowsense_api.dart';
import 'package:flowsense_mobile/data/api/flowsense_api.dart';
import 'package:flowsense_mobile/data/cache/snapshot_cache.dart';
import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/data/models/traffic_snapshot.dart';
import 'package:flowsense_mobile/data/repository/traffic_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _config = AppConfig(
  apiBase: 'https://flowsense.test',
  apiKey: 'k',
  pollInterval: Duration(seconds: 5),
  staleAfter: Duration(seconds: 30),
);

final _t0 = DateTime.utc(2026, 8, 2, 12);

/// The fake stamps records with its own `now`, which the tests point at [_t0]
/// while moving the repository's clock independently — that is how a record
/// ages into staleness without any real time passing.
FakeFlowSenseApi _api({DateTime Function()? recordTime}) =>
    FakeFlowSenseApi.fromStrings(
      intersectionsJson:
          File('test/fixtures/intersections.json').readAsStringSync(),
      recordsJsonl: File('test/fixtures/records.jsonl').readAsStringSync(),
      now: recordTime ?? () => _t0,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the first poll emits loading, then data', () async {
    final clock = FakeClock(_t0);
    final repo = TrafficRepository(
        api: _api(), config: _config, clock: clock, cache: null);
    final states = <RepoState>[];

    repo.watch().listen(states.add);
    await pumpEventQueue();

    expect(states, hasLength(2));
    expect(states.first, isA<RepoLoading>());
    final data = states.last as RepoData;
    expect(data.snapshot.records, hasLength(5));
    expect(data.isStale, isFalse);
    expect(data.isFromCache, isFalse);

    repo.dispose();
  });

  test('a failing poll emits RepoError carrying the last good snapshot',
      () async {
    final clock = FakeClock(_t0);
    final api = _api();
    final repo = TrafficRepository(
        api: api, config: _config, clock: clock, cache: null);
    final states = <RepoState>[];

    repo.watch().listen(states.add);
    await pumpEventQueue();

    api.failNext = 1;
    clock.tick();
    await pumpEventQueue();

    final error = states.last as RepoError;
    expect(error.message, isNotEmpty);
    expect(error.lastGood, isNotNull,
        reason: 'a transient failure must not blank the screen');
    expect(error.lastGood!.records, hasLength(5));

    repo.dispose();
  });

  test('recovery re-emits fresh data', () async {
    final clock = FakeClock(_t0);
    final api = _api();
    final repo = TrafficRepository(
        api: api, config: _config, clock: clock, cache: null);
    final states = <RepoState>[];

    repo.watch().listen(states.add);
    await pumpEventQueue();

    api.failNext = 1;
    clock.tick();
    await pumpEventQueue();
    expect(states.last, isA<RepoError>());

    clock.tick();
    await pumpEventQueue();

    final data = states.last as RepoData;
    expect(data.isFromCache, isFalse);
    expect(data.snapshot.records, hasLength(5));

    repo.dispose();
  });

  test('a record older than staleAfter sets isStale', () async {
    final clock = FakeClock(_t0);
    // Records are stamped at _t0; the clock is 60s ahead of them.
    clock.advance(const Duration(seconds: 60));
    final repo = TrafficRepository(
        api: _api(), config: _config, clock: clock, cache: null);
    final states = <RepoState>[];

    repo.watch().listen(states.add);
    await pumpEventQueue();

    expect((states.last as RepoData).isStale, isTrue);

    repo.dispose();
  });

  test('one lagging camera among fresh ones is not a stale feed', () async {
    final clock = FakeClock(_t0);
    final repo = TrafficRepository(
      api: _StubApi([
        TrafficSnapshot(fetchedAt: _t0, records: [
          _record('30', _t0),
          _record('31', _t0.subtract(const Duration(minutes: 5))),
        ]),
      ]),
      config: _config,
      clock: clock,
      cache: null,
    );
    final states = <RepoState>[];

    repo.watch().listen(states.add);
    await pumpEventQueue();

    expect((states.last as RepoData).isStale, isFalse,
        reason: 'the banner is for a feed-wide outage; dead cameras grey out '
            'per marker instead');

    repo.dispose();
  });

  test('a cold start with a populated cache shows it before the network',
      () async {
    final cached = TrafficSnapshot(fetchedAt: _t0, records: [_record('30', _t0)]);
    SharedPreferences.setMockInitialValues({
      'flowsense.snapshot.v1': jsonEncode(cached.toJson()),
    });

    final clock = FakeClock(_t0);
    final api = _api()..failNext = 1; // network is down on this cold start
    final repo = TrafficRepository(
      api: api,
      config: _config,
      clock: clock,
      cache: const SnapshotCache(),
    );
    final states = <RepoState>[];

    repo.watch().listen(states.add);
    await pumpEventQueue();

    expect(states.first, isA<RepoLoading>());
    final fromCache = states[1] as RepoData;
    expect(fromCache.isFromCache, isTrue);
    expect(fromCache.snapshot.records.single.cameraId, '30');
    // ...and the failed poll that follows still has something to fall back on.
    expect((states.last as RepoError).lastGood, isNotNull);

    repo.dispose();
  });

  test('a good poll is written to the cache', () async {
    final clock = FakeClock(_t0);
    const cache = SnapshotCache();
    final repo = TrafficRepository(
        api: _api(), config: _config, clock: clock, cache: cache);

    repo.watch().listen((_) {});
    await pumpEventQueue();

    final persisted = await cache.read();
    expect(persisted, isNotNull);
    expect(persisted!.records, hasLength(5));

    repo.dispose();
  });

  test('corrupt cache data is ignored, not fatal', () async {
    SharedPreferences.setMockInitialValues(
        {'flowsense.snapshot.v1': 'not json at all'});

    final clock = FakeClock(_t0);
    final repo = TrafficRepository(
      api: _api(),
      config: _config,
      clock: clock,
      cache: const SnapshotCache(),
    );
    final states = <RepoState>[];

    repo.watch().listen(states.add);
    await pumpEventQueue();

    expect(states, hasLength(2)); // loading, then live data — no cache emit
    expect(states.last, isA<RepoData>());

    repo.dispose();
  });

  test('dispose cancels the ticker and stops polling', () async {
    final clock = FakeClock(_t0);
    final api = _api();
    final repo = TrafficRepository(
        api: api, config: _config, clock: clock, cache: null);

    repo.watch().listen((_) {});
    await pumpEventQueue();
    expect(api.tick, 1);
    expect(clock.hasListeners, isTrue);

    repo.dispose();
    clock.tick();
    await pumpEventQueue();

    expect(api.tick, 1, reason: 'no API call may outlive the repository');
    expect(clock.hasListeners, isFalse);
  });
}

TrafficRecord _record(String cameraId, DateTime ts) => TrafficRecord(
      ts: ts,
      cameraId: cameraId,
      cameraName: 'Simpang $cameraId',
      totalVehicles: 4,
      perLane: const {'kota': 2, 'ploso': 2},
    );

/// Serves fixed snapshots, cycling — used where the fixture fake's re-stamping
/// gets in the way of controlling per-record timestamps.
class _StubApi implements FlowSenseApi {
  _StubApi(this._snapshots);

  final List<TrafficSnapshot> _snapshots;
  int _i = 0;

  @override
  Future<TrafficSnapshot> snapshot() async =>
      _snapshots[_i++ % _snapshots.length];

  @override
  Future<List<Intersection>> intersections() async => const [];

  @override
  Future<List<TrafficRecord>> history(
    String id, {
    DateTime? from,
    DateTime? to,
    String bucket = '1m',
  }) async =>
      const [];

  @override
  void close() {}
}
