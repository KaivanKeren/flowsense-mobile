import 'congestion.dart';
import 'operator_alert.dart';

/// How far back the alert history reaches.
enum AlertWindow {
  hari1('24 jam terakhir', Duration(days: 1)),
  hari7('7 hari terakhir', Duration(days: 7)),
  hari30('30 hari terakhir', Duration(days: 30));

  const AlertWindow(this.label, this.span);

  final String label;
  final Duration span;
}

/// Whether an alert has been seen by a person.
enum AlertAckFilter {
  semua('Semua status'),
  belumDiakui('Belum diakui'),
  diakui('Diakui');

  const AlertAckFilter(this.label);

  final String label;
}

/// The three chips above the list: time, intersection, status.
///
/// Pure and separate from the widget so the combinations are testable without
/// pumping anything — filters are where an off-by-one quietly hides the row
/// somebody was looking for.
class AlertFilter {
  const AlertFilter({
    this.window = AlertWindow.hari7,
    this.cameraId,
    this.ack = AlertAckFilter.semua,
  });

  final AlertWindow window;

  /// Null means every intersection.
  final String? cameraId;

  final AlertAckFilter ack;

  String get cameraLabel => cameraId == null ? 'Semua simpang' : 'Simpang';

  AlertFilter copyWith({
    AlertWindow? window,
    String? cameraId,
    bool clearCamera = false,
    AlertAckFilter? ack,
  }) =>
      AlertFilter(
        window: window ?? this.window,
        cameraId: clearCamera ? null : (cameraId ?? this.cameraId),
        ack: ack ?? this.ack,
      );

  bool matches(OperatorAlert alert, DateTime now) {
    if (now.difference(alert.raisedAt) > window.span) return false;
    if (cameraId != null && alert.cameraId != cameraId) return false;
    return switch (ack) {
      AlertAckFilter.semua => true,
      AlertAckFilter.belumDiakui => !alert.isAcknowledged,
      AlertAckFilter.diakui => alert.isAcknowledged,
    };
  }
}

/// The history list: filtered, then newest first.
///
/// Unlike the dashboard, acknowledged alerts are **not** pushed to the bottom
/// here. This screen is a record, and a record reads in the order things
/// happened.
List<OperatorAlert> applyAlertFilter(
  List<OperatorAlert> alerts,
  AlertFilter filter,
  DateTime now,
) {
  final matched =
      alerts.where((a) => filter.matches(a, now)).toList()
        ..sort((a, b) => b.raisedAt.compareTo(a.raisedAt));
  return matched;
}

/// `2 Agu 16:05` — short month, because these rows are scanned rather than
/// read.
String shortDateTime(DateTime t) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return '${t.day} ${months[t.month - 1]} '
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

/// `Macet 37 menit · Ismail · Ada perbaikan jalan`
///
/// The duration is how long the jam ran, not how long ago it was — an operator
/// reviewing history is judging severity, not recency.
String alertSummaryLine(OperatorAlert alert, DateTime now) => [
      '${alert.level.label} ${durationIndonesian(alert.age(now))}',
      if (alert.acknowledgedBy != null) alert.acknowledgedBy!,
      if (alert.note != null && alert.note!.trim().isNotEmpty) alert.note!,
    ].join(' · ');
