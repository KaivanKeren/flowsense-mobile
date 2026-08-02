import 'traffic_record.dart';

/// The latest record for every intersection, as served by `GET /v1/snapshot`.
class TrafficSnapshot {
  const TrafficSnapshot({required this.fetchedAt, required this.records});

  factory TrafficSnapshot.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    return TrafficSnapshot(
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(
          ((json['ts'] as num?)?.toInt() ?? 0) * 1000,
          isUtc: true),
      records: [
        if (items is List)
          for (final e in items)
            if (e is Map<String, dynamic>) TrafficRecord.fromJson(e),
      ],
    );
  }

  /// An explicitly empty snapshot — distinct from "not loaded yet", which the
  /// repository models as `RepoLoading`.
  const TrafficSnapshot.empty(this.fetchedAt) : records = const [];

  final DateTime fetchedAt;
  final List<TrafficRecord> records;

  bool get isEmpty => records.isEmpty;

  TrafficRecord? forCamera(String id) {
    for (final r in records) {
      if (r.cameraId == id) return r;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'ts': fetchedAt.millisecondsSinceEpoch ~/ 1000,
        'items': [for (final r in records) r.toJson()],
      };
}
