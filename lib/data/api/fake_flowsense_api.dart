import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/api_exception.dart';
import '../models/intersection.dart';
import '../models/traffic_record.dart';
import '../models/traffic_snapshot.dart';
import 'flowsense_api.dart';

/// A [FlowSenseApi] backed by connector fixtures instead of a backend.
///
/// Two jobs. It keeps the whole app buildable and demoable before the HTTP
/// service exists, and it makes the error paths reachable on demand — set
/// [failNext] and the UI's error state shows up without unplugging anything.
///
/// Records are re-stamped to the current time as they are served. Fixture
/// timestamps are months old; replaying them verbatim would render every
/// marker stale and grey, which is the opposite of what a demo needs.
class FakeFlowSenseApi implements FlowSenseApi {
  FakeFlowSenseApi({
    required List<Intersection> intersections,
    required List<TrafficRecord> records,
    DateTime Function()? now,
  })  : _intersections = List.unmodifiable(intersections),
        _byCamera = _group(records),
        _now = now ?? DateTime.now;

  /// Parses the fixture payloads directly. Used by tests, which read them off
  /// disk, and by [fromFixtures], which reads them out of the asset bundle.
  factory FakeFlowSenseApi.fromStrings({
    required String intersectionsJson,
    required String recordsJsonl,
    DateTime Function()? now,
  }) {
    final rawIntersections = jsonDecode(intersectionsJson);
    return FakeFlowSenseApi(
      intersections: [
        if (rawIntersections is List)
          for (final e in rawIntersections)
            if (e is Map<String, dynamic>) Intersection.fromJson(e),
      ],
      records: [
        for (final line in const LineSplitter().convert(recordsJsonl))
          if (line.trim().isNotEmpty)
            TrafficRecord.fromJson(
                jsonDecode(line) as Map<String, dynamic>),
      ],
      now: now,
    );
  }

  /// Loads `test/fixtures/` from the asset bundle — works both in the running
  /// app and under `flutter test`.
  static Future<FakeFlowSenseApi> fromFixtures({DateTime Function()? now}) async {
    final intersectionsJson =
        await rootBundle.loadString('test/fixtures/intersections.json');
    final recordsJsonl =
        await rootBundle.loadString('test/fixtures/records.jsonl');
    return FakeFlowSenseApi.fromStrings(
      intersectionsJson: intersectionsJson,
      recordsJsonl: recordsJsonl,
      now: now,
    );
  }

  static Map<String, List<TrafficRecord>> _group(List<TrafficRecord> records) {
    final grouped = <String, List<TrafficRecord>>{};
    for (final r in records) {
      grouped.putIfAbsent(r.cameraId, () => []).add(r);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.ts.compareTo(b.ts));
    }
    return grouped;
  }

  final List<Intersection> _intersections;
  final Map<String, List<TrafficRecord>> _byCamera;
  final DateTime Function() _now;

  /// Number of upcoming calls that will throw. Decrements per failed call, so
  /// `failNext = 2` reproduces "two failures then recovery".
  int failNext = 0;

  /// How many times [snapshot] has been served — the synthetic clock that
  /// advances the fixtures.
  int get tick => _tick;
  int _tick = 0;

  void _maybeFail() {
    if (failNext <= 0) return;
    failNext--;
    throw const ApiException('Fake sedang disetel untuk gagal',
        statusCode: 503);
  }

  @override
  Future<List<Intersection>> intersections() async {
    _maybeFail();
    return _intersections;
  }

  @override
  Future<TrafficSnapshot> snapshot() async {
    _maybeFail();
    final at = _now();
    final records = <TrafficRecord>[];
    for (final entry in _byCamera.entries) {
      final series = entry.value;
      records.add(_restamp(series[_tick % series.length], at));
    }
    _tick++;
    return TrafficSnapshot(fetchedAt: at, records: records);
  }

  @override
  Future<List<TrafficRecord>> history(
    String id, {
    DateTime? from,
    DateTime? to,
    String bucket = '1m',
  }) async {
    _maybeFail();
    final series = _byCamera[id] ?? const <TrafficRecord>[];
    final end = to ?? _now();
    // One point per minute, ending at `end`, oldest first.
    return [
      for (var i = 0; i < series.length; i++)
        _restamp(
          series[i],
          end.subtract(Duration(minutes: series.length - 1 - i)),
        ),
    ];
  }

  @override
  void close() {}

  static TrafficRecord _restamp(TrafficRecord r, DateTime ts) => TrafficRecord(
        ts: ts,
        cameraId: r.cameraId,
        cameraName: r.cameraName,
        totalVehicles: r.totalVehicles,
        perLane: r.perLane,
        crossings: r.crossings,
      );
}
