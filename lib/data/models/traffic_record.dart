/// One record emitted by the FlowSense edge connector.
/// Field names mirror the `.jsonl` schema exactly; unknown keys are ignored.
class TrafficRecord {
  const TrafficRecord({
    required this.ts,
    required this.cameraId,
    required this.cameraName,
    required this.totalVehicles,
    required this.perLane,
    this.crossings,
  });

  factory TrafficRecord.fromJson(Map<String, dynamic> json) => TrafficRecord(
        ts: DateTime.fromMillisecondsSinceEpoch(
            ((json['ts'] as num?)?.toInt() ?? 0) * 1000,
            isUtc: true),
        cameraId: '${json['camera_id'] ?? ''}',
        cameraName: json['camera'] as String? ?? '',
        totalVehicles: (json['total_vehicles'] as num?)?.toInt() ?? 0,
        perLane: countsFromJson(json['per_lane']),
        crossings:
            json['crossings'] == null ? null : countsFromJson(json['crossings']),
      );

  /// Coerces a `{lane: count}` map, tolerating non-map and null values rather
  /// than throwing — a malformed field costs one lane, not the whole record.
  static Map<String, int> countsFromJson(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries) '${e.key}': (e.value as num?)?.toInt() ?? 0,
    };
  }

  final DateTime ts;
  final String cameraId;
  final String cameraName;
  final int totalVehicles;
  final Map<String, int> perLane;
  final Map<String, int>? crossings;

  Map<String, dynamic> toJson() => {
        'ts': ts.millisecondsSinceEpoch ~/ 1000,
        'camera_id': cameraId,
        'camera': cameraName,
        'total_vehicles': totalVehicles,
        'per_lane': perLane,
        if (crossings != null) 'crossings': crossings,
      };
}
