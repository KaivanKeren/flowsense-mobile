import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/api_exception.dart';
import '../models/intersection.dart';
import '../models/traffic_record.dart';
import '../models/traffic_snapshot.dart';
import 'flowsense_api.dart';

/// Demo-only staging that does not belong to the API contract.
///
/// A real backend serves whatever the connectors actually sent. The fake has
/// to *manufacture* the interesting failures, because a demo that only ever
/// shows the happy path proves nothing — and the layout spec's hardest
/// requirements (`Data basi`, the un-interpolated gap in the history chart)
/// are precisely the ones you cannot see when everything is working.
class DemoStaging {
  const DemoStaging({
    this.stalledCameras = const {},
    this.stalledBy = const Duration(minutes: 4),
    this.historyGapAgoMinutes = const {},
  });

  factory DemoStaging.fromJson(Map<String, dynamic> json) => DemoStaging(
        stalledCameras: {
          for (final e in (json['stalledCameras'] as List? ?? const [])) '$e',
        },
        stalledBy: Duration(
          seconds: (json['stalledBySeconds'] as num?)?.toInt() ?? 240,
        ),
        historyGapAgoMinutes: {
          for (final e in (json['historyGapAgoMinutes'] as List? ?? const []))
            (e as num).toInt(),
        },
      );

  /// Cameras whose records are served [stalledBy] old, so the stale path is
  /// reachable without unplugging anything.
  final Set<String> stalledCameras;
  final Duration stalledBy;

  /// Minutes-ago positions omitted from [FlowSenseApi.history], so the chart's
  /// "Data hilang" rendering is reachable too.
  final Set<int> historyGapAgoMinutes;
}

/// A [FlowSenseApi] backed by connector fixtures instead of a backend.
///
/// Two jobs. It keeps the whole app buildable and demoable before the HTTP
/// service exists, and it makes the error paths reachable on demand — set
/// [failNext] and the UI's error state shows up without unplugging anything.
///
/// Records are re-stamped to the current time as they are served. Fixture
/// timestamps are months old; replaying them verbatim would render every
/// marker stale and grey, which is the opposite of what a demo needs — except
/// for the cameras [DemoStaging] deliberately holds back.
class FakeFlowSenseApi implements FlowSenseApi {
  FakeFlowSenseApi({
    required List<Intersection> intersections,
    required List<TrafficRecord> records,
    DateTime Function()? now,
    this.staging = const DemoStaging(),
  })  : _intersections = List.unmodifiable(intersections),
        _byCamera = _group(records),
        _now = now ?? DateTime.now;

  /// Parses the fixture payloads directly. Used by tests, which read them off
  /// disk, and by [fromFixtures], which reads them out of the asset bundle.
  factory FakeFlowSenseApi.fromStrings({
    required String intersectionsJson,
    required String recordsJsonl,
    String? demoJson,
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
      staging: demoJson == null
          ? const DemoStaging()
          : DemoStaging.fromJson(jsonDecode(demoJson) as Map<String, dynamic>),
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
    final demoJson = await rootBundle.loadString('test/fixtures/demo.json');
    return FakeFlowSenseApi.fromStrings(
      intersectionsJson: intersectionsJson,
      recordsJsonl: recordsJsonl,
      demoJson: demoJson,
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
  final DemoStaging staging;

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
      final ts = staging.stalledCameras.contains(entry.key)
          ? at.subtract(staging.stalledBy)
          : at;
      records.add(_restamp(series[_tick % series.length], ts));
    }
    _tick++;
    return TrafficSnapshot(fetchedAt: at, records: records);
  }

  /// One point per minute across the requested window, oldest first — the
  /// shape a real time-bucketed endpoint returns, so the chart is exercised
  /// against 60 points rather than however many fixture lines happen to exist.
  ///
  /// Minutes listed in [DemoStaging.historyGapAgoMinutes] are **omitted**, not
  /// zeroed. A gap has to arrive as an absent bucket, because that is the one
  /// case the chart must refuse to interpolate over.
  @override
  Future<List<TrafficRecord>> history(
    String id, {
    DateTime? from,
    DateTime? to,
    String bucket = '1m',
  }) async {
    _maybeFail();
    final series = _byCamera[id] ?? const <TrafficRecord>[];
    if (series.isEmpty) return const [];

    final end = to ?? _now();
    final start = from ?? end.subtract(const Duration(hours: 1));
    final minutes = end.difference(start).inMinutes;
    if (minutes <= 0) return const [];

    return [
      for (var ago = minutes - 1; ago >= 0; ago--)
        if (!staging.historyGapAgoMinutes.contains(ago))
          _restamp(
            series[(minutes - ago) % series.length],
            end.subtract(Duration(minutes: ago)),
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
