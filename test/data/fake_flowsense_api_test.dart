import 'dart:io';

import 'package:flowsense_mobile/core/api_exception.dart';
import 'package:flowsense_mobile/data/api/fake_flowsense_api.dart';
import 'package:flutter_test/flutter_test.dart';

final _fixedNow = DateTime.utc(2026, 8, 2, 12);

FakeFlowSenseApi _fake() => FakeFlowSenseApi.fromStrings(
      intersectionsJson:
          File('test/fixtures/intersections.json').readAsStringSync(),
      recordsJsonl: File('test/fixtures/records.jsonl').readAsStringSync(),
      now: () => _fixedNow,
    );

void main() {
  test('serves one record per camera from the fixtures', () async {
    final snap = await _fake().snapshot();
    expect(snap.records.map((r) => r.cameraId).toSet(), {'30', '31', '32'});
    expect(snap.forCamera('30')!.perLane['kota'], 2); // first fixture tick
  });

  test('successive snapshots advance through the fixture series', () async {
    final api = _fake();
    final first = await api.snapshot();
    final second = await api.snapshot();
    final third = await api.snapshot();

    expect(first.forCamera('30')!.totalVehicles, 4);
    expect(second.forCamera('30')!.totalVehicles, 9);
    expect(third.forCamera('30')!.totalVehicles, 13);
  });

  test('the series wraps rather than running out', () async {
    final api = _fake();
    for (var i = 0; i < 3; i++) {
      await api.snapshot();
    }
    final wrapped = await api.snapshot();
    expect(wrapped.forCamera('30')!.totalVehicles, 4);
    expect(api.tick, 4);
  });

  test('records are re-stamped to now, so nothing reads as stale', () async {
    final snap = await _fake().snapshot();
    expect(snap.fetchedAt, _fixedNow);
    for (final r in snap.records) {
      expect(r.ts, _fixedNow);
    }
  });

  test('failNext makes the error path reachable, then recovers', () async {
    final api = _fake()..failNext = 2;

    await expectLater(api.snapshot(), throwsA(isA<ApiException>()));
    await expectLater(api.snapshot(), throwsA(isA<ApiException>()));
    expect((await api.snapshot()).records, isNotEmpty);
    expect(api.failNext, 0);
  });

  test('history returns the camera series oldest-first, one point per minute',
      () async {
    final points = await _fake().history('30');
    expect(points, hasLength(3));
    expect(points.map((p) => p.totalVehicles), [4, 9, 13]);
    expect(points.last.ts, _fixedNow);
    expect(points.first.ts, _fixedNow.subtract(const Duration(minutes: 2)));
  });

  test('history for an unknown camera is empty, not an error', () async {
    expect(await _fake().history('nope'), isEmpty);
  });

  test('intersections come back with their calibrated capacity', () async {
    final list = await _fake().intersections();
    expect(list, hasLength(3));
    expect(
        list.firstWhere((i) => i.id == '32').capacityFor('pasar', fallback: 12),
        9);
  });

  test('fromFixtures loads the same data out of the asset bundle', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final api = await FakeFlowSenseApi.fromFixtures(now: () => _fixedNow);
    final snap = await api.snapshot();
    expect(snap.records.map((r) => r.cameraId).toSet(), {'30', '31', '32'});
  });
}
