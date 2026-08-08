import 'congestion.dart';

/// A jam that was raised for an operator's attention, and what happened to it.
///
/// Acknowledgement is one of exactly two things the operator console may write
/// — the other is lane capacity. There is no actuator behind any of this, so
/// acknowledging changes nothing about the road; it records that a person saw
/// it. That record is the point.
class OperatorAlert {
  const OperatorAlert({
    required this.id,
    required this.cameraId,
    required this.name,
    required this.level,
    required this.raisedAt,
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.note,
  });

  factory OperatorAlert.fromJson(Map<String, dynamic> json) => OperatorAlert(
        id: '${json['id'] ?? ''}',
        cameraId: '${json['camera_id'] ?? ''}',
        name: json['name'] as String? ?? '',
        level: CongestionLevel.values.firstWhere(
          (l) => l.name == json['level'],
          orElse: () => CongestionLevel.macet,
        ),
        raisedAt: _epochSeconds(json['raised_at']),
        acknowledgedBy: json['acknowledged_by'] as String?,
        acknowledgedAt: json['acknowledged_at'] == null
            ? null
            : _epochSeconds(json['acknowledged_at']),
        note: json['note'] as String?,
      );

  static DateTime _epochSeconds(Object? raw) =>
      DateTime.fromMillisecondsSinceEpoch(
        ((raw as num?)?.toInt() ?? 0) * 1000,
        isUtc: true,
      );

  final String id;
  final String cameraId;
  final String name;
  final CongestionLevel level;
  final DateTime raisedAt;

  /// Who acknowledged it. Null while it still needs attention.
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;

  /// What the operator wrote down, if anything — `Ada perbaikan jalan`.
  /// Free text, and the only part of an alert a person authors.
  final String? note;

  bool get isAcknowledged => acknowledgedBy != null;

  /// How long the jam has been running, as of [now].
  Duration age(DateTime now) {
    final elapsed = now.difference(raisedAt);
    // Clock skew between the phone and the server must not produce a negative
    // duration on screen.
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  OperatorAlert acknowledge({
    required String by,
    required DateTime at,
  }) =>
      OperatorAlert(
        id: id,
        cameraId: cameraId,
        name: name,
        level: level,
        raisedAt: raisedAt,
        acknowledgedBy: by,
        acknowledgedAt: at,
        note: note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'camera_id': cameraId,
        'name': name,
        'level': level.name,
        'raised_at': raisedAt.millisecondsSinceEpoch ~/ 1000,
        if (acknowledgedBy != null) 'acknowledged_by': acknowledgedBy,
        if (acknowledgedAt != null)
          'acknowledged_at': acknowledgedAt!.millisecondsSinceEpoch ~/ 1000,
        if (note != null) 'note': note,
      };
}

/// `37 menit`, `2 jam 5 menit`, `baru saja`.
///
/// Reads as a duration rather than a clock time, because "how long has this
/// been going" is the question an operator is actually asking.
String durationIndonesian(Duration d) {
  if (d.inMinutes < 1) return 'baru saja';
  if (d.inMinutes < 60) return '${d.inMinutes} menit';
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  if (minutes == 0) return '$hours jam';
  return '$hours jam $minutes menit';
}

/// `16:05`, local time.
String clockTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

/// Unacknowledged first and newest-first within that, then the acknowledged
/// ones — the dashboard shows what needs a person above what already had one.
///
/// Acknowledged alerts are never dropped. Their history is the accountability
/// the console exists to provide.
List<OperatorAlert> sortAlerts(List<OperatorAlert> alerts) {
  final sorted = [...alerts];
  sorted.sort((a, b) {
    if (a.isAcknowledged != b.isAcknowledged) {
      return a.isAcknowledged ? 1 : -1;
    }
    return b.raisedAt.compareTo(a.raisedAt);
  });
  return sorted;
}
