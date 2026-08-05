import 'dart:io';

import 'package:flowsense_mobile/core/api_exception.dart';
import 'package:flowsense_mobile/data/api/fake_flowsense_api.dart';
import 'package:flutter_test/flutter_test.dart';

final _fixedNow = DateTime.utc(2026, 8, 2, 12);

FakeFlowSenseApi _fake() => FakeFlowSenseApi.fromStrings(
      intersectionsJson:
          File('test/fixtures/intersections.json').readAsStringSync(),
      recordsJsonl: File('test/fixtures/records.jsonl').readAsStringSync(),
      demoJson: File('test/fixtures/demo.json').readAsStringSync(),
      now: () => _fixedNow,
    );

void main() {
  test('serves one record per camera from the fixtures', () async {
    final snap = await _fake().snapshot();
    expect(snap.records.map((r) => r.cameraId).toSet(),
        {'30', '31', '32', '33', '34'});
    expect(snap.forCamera('30')!.perLane['kota'], 9); // first fixture tick
  });

  test('the opening tick reproduces the mockups', () async {
    // What a demo lands on has to be the screen the layout doc was drawn
    // against, or the first thing anyone sees is already off-spec.
    final snap = await _fake().snapshot();
    expect(snap.forCamera('30')!.totalVehicles, 18); // Simpang DPRD, macet
    expect(snap.forCamera('31')!.totalVehicles, 11); // Simpang Tujuh, padat
    expect(snap.forCamera('32')!.totalVehicles, 5); //  Simpang Jati, lancar
    expect(snap.forCamera('33')!.totalVehicles, 4); //  Simpang Bae, lancar
  });

  test('four lanes per intersection, as the marker ring assumes', () async {
    final list = await _fake().intersections();
    for (final i in list) {
      expect(i.lanes, hasLength(4), reason: i.name);
    }
  });

  test('successive snapshots advance through the fixture series', () async {
    final api = _fake();
    final first = await api.snapshot();
    final second = await api.snapshot();

    expect(first.forCamera('30')!.totalVehicles, 18);
    expect(second.forCamera('30')!.totalVehicles, isNot(18));
  });

  test('the series wraps rather than running out', () async {
    final api = _fake();
    for (var i = 0; i < 14; i++) {
      await api.snapshot();
    }
    final wrapped = await api.snapshot();
    expect(wrapped.forCamera('30')!.totalVehicles, 18);
    expect(api.tick, 15);
  });

  test('records are re-stamped to now, so nothing reads as stale', () async {
    final snap = await _fake().snapshot();
    expect(snap.fetchedAt, _fixedNow);
    for (final r in snap.records.where((r) => r.cameraId != '34')) {
      expect(r.ts, _fixedNow);
    }
  });

  test('the staged camera is served stale, so Data basi is reachable',
      () async {
    // Without this the demo can never show a dead connector, which is the one
    // failure the layout spec is most insistent about rendering honestly.
    final snap = await _fake().snapshot();
    expect(
      snap.forCamera('34')!.ts,
      _fixedNow.subtract(const Duration(minutes: 4)),
    );
  });

  test('failNext makes the error path reachable, then recovers', () async {
    final api = _fake()..failNext = 2;

    await expectLater(api.snapshot(), throwsA(isA<ApiException>()));
    await expectLater(api.snapshot(), throwsA(isA<ApiException>()));
    expect((await api.snapshot()).records, isNotEmpty);
    expect(api.failNext, 0);
  });

  group('history', () {
    test('serves one point per minute across the requested window', () async {
      final points = await _fake().history(
        '30',
        from: _fixedNow.subtract(const Duration(hours: 1)),
        to: _fixedNow,
      );

      // 60 minutes, less the three staged gap minutes.
      expect(points, hasLength(57));
      expect(points.last.ts, _fixedNow);
      for (var i = 1; i < points.length; i++) {
        expect(points[i].ts.isAfter(points[i - 1].ts), isTrue,
            reason: 'oldest first');
      }
    });

    test('staged gap minutes are absent, not zeroed', () async {
      // A zero is a reading. An absent bucket is a silence. The chart draws
      // them differently and must be handed the difference.
      final points = await _fake().history(
        '30',
        from: _fixedNow.subtract(const Duration(hours: 1)),
        to: _fixedNow,
      );
      final stamps = points.map((p) => p.ts).toSet();

      for (final ago in [33, 34, 35]) {
        expect(stamps, isNot(contains(_fixedNow.subtract(Duration(minutes: ago)))));
      }
      expect(stamps, contains(_fixedNow.subtract(const Duration(minutes: 32))));
      expect(stamps, contains(_fixedNow.subtract(const Duration(minutes: 36))));
    });

    test('defaults to the last hour when no window is given', () async {
      final points = await _fake().history('30');
      expect(points, hasLength(57));
    });

    test('history for an unknown camera is empty, not an error', () async {
      expect(await _fake().history('nope'), isEmpty);
    });
  });

  test('intersections come back with their calibrated capacity', () async {
    final list = await _fake().intersections();
    expect(list, hasLength(5));
    expect(
        list.firstWhere((i) => i.id == '30').capacityFor('kota', fallback: 12),
        12);
    expect(
        list.firstWhere((i) => i.id == '30').capacityFor('sekoe', fallback: 99),
        6);
  });

  test('fromFixtures loads the same data out of the asset bundle', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final api = await FakeFlowSenseApi.fromFixtures(now: () => _fixedNow);
    final snap = await api.snapshot();
    expect(snap.records.map((r) => r.cameraId).toSet(),
        {'30', '31', '32', '33', '34'});
    // The staging file has to ride along in the bundle too, or the running app
    // silently loses the stale camera the tests rely on.
    expect(api.staging.stalledCameras, contains('34'));
  });
}
