import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/domain/congestion.dart';
import 'package:flutter_test/flutter_test.dart';

const _simpang = Intersection(
  id: '30',
  name: 'Simpang DPRD',
  lat: -6.8047,
  lon: 110.8405,
  lanes: ['kota', 'ploso'],
  capacity: {'kota': 10, 'ploso': 10},
);

TrafficRecord _record(Map<String, int> perLane, {DateTime? ts}) => TrafficRecord(
      ts: ts ?? DateTime.utc(2025, 8, 12, 10),
      cameraId: '30',
      cameraName: 'Simpang DPRD Arah Kota',
      totalVehicles: perLane.values.fold(0, (a, b) => a + b),
      perLane: perLane,
    );

void main() {
  test('lane thresholds', () {
    expect(levelForLane(3, 12), CongestionLevel.lancar); // 0.25
    expect(levelForLane(6, 12), CongestionLevel.padat); // 0.50
    expect(levelForLane(10, 12), CongestionLevel.macet); // 0.83
  });

  test('boundaries are inclusive at the upper level', () {
    expect(levelForLane(4, 10), CongestionLevel.padat); // exactly 0.4
    expect(levelForLane(75, 100), CongestionLevel.macet); // exactly 0.75
  });

  test('zero capacity is unknown, never a divide-by-zero', () {
    expect(levelForLane(5, 0), CongestionLevel.unknown);
    expect(levelForLane(5, -1), CongestionLevel.unknown);
  });

  test('worst lane decides the intersection', () {
    final r = _record({'kota': 1, 'ploso': 9}); // lancar + macet
    expect(levelForIntersection(r, _simpang), CongestionLevel.macet);
  });

  test('empty per_lane is unknown, not lancar', () {
    // Absence of data is not free flow. Showing green because the connector
    // went down is the worst failure this app can have.
    expect(levelForIntersection(_record({}), _simpang), CongestionLevel.unknown);
  });

  test('a lane with no calibrated capacity uses the fallback', () {
    final r = _record({'lajur-baru': 9});
    expect(levelForIntersection(r, _simpang, laneCapacityDefault: 10),
        CongestionLevel.macet);
  });

  test('unknown lanes do not mask a worse known lane', () {
    final r = _record({'kota': 9, 'lajur-baru': 0});
    expect(levelForIntersection(r, _simpang, laneCapacityDefault: 0),
        CongestionLevel.macet);
  });

  test('stale records are detected', () {
    final now = DateTime.utc(2025, 8, 12, 10, 1); // 60s after the record
    final r = _record({'kota': 1});
    expect(isStale(r, now, const Duration(seconds: 30)), isTrue);
    expect(isStale(r, now, const Duration(minutes: 5)), isFalse);
  });

  test('a record timestamped in the future is not stale', () {
    final now = DateTime.utc(2025, 8, 12, 9, 59);
    expect(isStale(_record({'kota': 1}), now, const Duration(seconds: 30)),
        isFalse);
  });
}
