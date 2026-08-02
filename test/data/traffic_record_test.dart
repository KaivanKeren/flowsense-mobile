import 'dart:convert';
import 'dart:io';

import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/data/models/traffic_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a connector line', () {
    final r = TrafficRecord.fromJson(jsonDecode(
      '{"ts":1755000000,"camera_id":30,"camera":"Simpang DPRD Arah Kota",'
      '"total_vehicles":4,"per_lane":{"kota":2,"ploso":2}}',
    ) as Map<String, dynamic>);

    expect(r.cameraId, '30'); // int id normalised to String
    expect(r.ts.toUtc().year, 2025);
    expect(r.totalVehicles, 4);
    expect(r.perLane['kota'], 2);
    expect(r.crossings, isNull);
  });

  test('reads optional crossings', () {
    final r = TrafficRecord.fromJson(jsonDecode(
      '{"ts":1,"camera_id":"30","camera":"x","total_vehicles":2,'
      '"per_lane":{"kota":1},"crossings":{"kota":12}}',
    ) as Map<String, dynamic>);
    expect(r.crossings!['kota'], 12);
  });

  test('ignores unknown keys instead of throwing', () {
    final r = TrafficRecord.fromJson(jsonDecode(
      '{"ts":1,"camera_id":30,"camera":"x","total_vehicles":0,"per_lane":{},'
      '"future_field":{"anything":true}}',
    ) as Map<String, dynamic>);
    expect(r.totalVehicles, 0);
  });

  test('missing per_lane degrades to empty, not an exception', () {
    final r = TrafficRecord.fromJson(
        jsonDecode('{"ts":1,"camera_id":30,"camera":"x","total_vehicles":3}')
            as Map<String, dynamic>);
    expect(r.perLane, isEmpty);
    expect(r.totalVehicles, 3);
  });

  test('every fixture line parses', () {
    final lines = File('test/fixtures/records.jsonl')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty);
    final records = lines
        .map((l) =>
            TrafficRecord.fromJson(jsonDecode(l) as Map<String, dynamic>))
        .toList();

    expect(records, hasLength(9));
    expect(records.map((r) => r.cameraId).toSet(), {'30', '31', '32'});
    expect(records.any((r) => r.crossings != null), isTrue);
    expect(records.any((r) => r.crossings == null), isTrue);
  });

  test('Intersection parses, with capacity falling back per lane', () {
    final list = jsonDecode(File('test/fixtures/intersections.json')
        .readAsStringSync()) as List<Object?>;
    final i = Intersection.fromJson(list.first! as Map<String, dynamic>);

    expect(i.id, '30');
    expect(i.name, 'Simpang DPRD');
    expect(i.lat, closeTo(-6.8047, 1e-6));
    expect(i.lon, closeTo(110.8405, 1e-6));
    expect(i.lanes, ['kota', 'ploso']);
    expect(i.capacityFor('kota', fallback: 12), 14);
    expect(i.capacityFor('tidak-ada', fallback: 12), 12);
  });

  test('snapshot looks a record up by camera id', () {
    final r = TrafficRecord.fromJson(
        jsonDecode('{"ts":1,"camera_id":30,"camera":"x","total_vehicles":3}')
            as Map<String, dynamic>);
    final snap = TrafficSnapshot(
        fetchedAt: DateTime.utc(2025, 8, 12), records: [r]);

    expect(snap.forCamera('30'), same(r));
    expect(snap.forCamera('99'), isNull);
  });

  test('snapshot parses the /v1/snapshot envelope', () {
    final snap = TrafficSnapshot.fromJson(jsonDecode(
      '{"ts":1755000004,"items":['
      '{"ts":1755000004,"camera_id":30,"camera":"a","total_vehicles":1,"per_lane":{}},'
      '{"ts":1755000003,"camera_id":31,"camera":"b","total_vehicles":2,"per_lane":{}}'
      ']}',
    ) as Map<String, dynamic>);

    expect(snap.records, hasLength(2));
    expect(snap.fetchedAt.toUtc().year, 2025);
    expect(snap.forCamera('31')!.totalVehicles, 2);
  });
}
