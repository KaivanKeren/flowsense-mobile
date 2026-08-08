/// What a connector is doing, from the console's point of view.
///
/// The whole reason the Kesehatan screen exists: without it an operator cannot
/// tell "the road is genuinely quiet" from "the connector died". Those look
/// identical on a traffic map and they call for opposite responses.
enum ConnectorStatus {
  /// Producing records at roughly the expected cadence.
  berjalan('Berjalan'),

  /// Still running, but records have stopped arriving on time.
  terputus('Terputus'),

  /// Not running at all.
  berhenti('Berhenti');

  const ConnectorStatus(this.label);

  final String label;

  /// Higher is worse. Drives the worst-first ordering.
  int get severity => switch (this) {
        ConnectorStatus.berjalan => 0,
        ConnectorStatus.terputus => 1,
        ConnectorStatus.berhenti => 2,
      };

  bool get needsAttention => this != ConnectorStatus.berjalan;
}

/// One connector's vitals.
class ConnectorHealth {
  const ConnectorHealth({
    required this.cameraId,
    required this.intersectionName,
    required this.status,
    required this.lastRecordAt,
    required this.gap,
    required this.failuresPerHour,
  });

  factory ConnectorHealth.fromJson(Map<String, dynamic> json) =>
      ConnectorHealth(
        cameraId: '${json['camera_id'] ?? ''}',
        intersectionName: json['name'] as String? ?? '',
        status: ConnectorStatus.values.firstWhere(
          (s) => s.name == json['status'],
          // An unrecognised status is not assumed healthy. A console that
          // guesses "probably fine" about a state it does not understand is
          // the exact failure this screen exists to prevent.
          orElse: () => ConnectorStatus.terputus,
        ),
        lastRecordAt: json['last_record_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                ((json['last_record_at'] as num).toInt()) * 1000,
                isUtc: true,
              ),
        gap: json['gap_seconds'] == null
            ? null
            : Duration(
                milliseconds:
                    ((json['gap_seconds'] as num).toDouble() * 1000).round(),
              ),
        failuresPerHour: (json['failures_per_hour'] as num?)?.toInt() ?? 0,
      );

  final String cameraId;
  final String intersectionName;
  final ConnectorStatus status;

  /// Null when nothing has ever arrived from this camera.
  final DateTime? lastRecordAt;

  /// Average interval between the last records, or null when the connector is
  /// stopped — a cadence for something that is not running would be fiction.
  final Duration? gap;

  final int failuresPerHour;

  /// `Kamera 30 — Simpang DPRD`
  String get title => 'Kamera $cameraId — $intersectionName';
}

/// `16:42:07` — to the second, deliberately.
///
/// Everywhere else in the app time is relative (`7 detik lalu`), because that
/// is what a rider needs. Here it is absolute and exact, because an operator
/// is comparing this against the connector's own log.
String clockSeconds(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}:'
    '${t.second.toString().padLeft(2, '0')}';

/// `2,0 detik` — one decimal, Indonesian comma.
String gapIndonesian(Duration gap) {
  final seconds = gap.inMilliseconds / 1000;
  return '${seconds.toStringAsFixed(1).replaceAll('.', ',')} detik';
}

/// The second line of a row: what arrived, how often, and how much is failing.
///
/// Parts that cannot honestly be stated are omitted rather than zero-filled —
/// a stopped connector has no cadence, and printing `0,0 detik` would read as
/// "instantaneous" rather than "not applicable".
String healthDetail(ConnectorHealth health) => [
      if (health.lastRecordAt != null)
        'record terakhir ${clockSeconds(health.lastRecordAt!)}'
      else
        'belum ada record',
      if (health.gap != null) 'jeda ${gapIndonesian(health.gap!)}',
      '${health.failuresPerHour} gagal/jam',
    ].join(' · ');

/// Worst first, then noisiest, then by name — so the connector that needs
/// looking at is on the first screen without scrolling, and the order holds
/// still between refreshes.
List<ConnectorHealth> sortByHealth(List<ConnectorHealth> items) {
  final sorted = [...items];
  sorted.sort((a, b) {
    final byStatus = b.status.severity.compareTo(a.status.severity);
    if (byStatus != 0) return byStatus;
    final byFailures = b.failuresPerHour.compareTo(a.failuresPerHour);
    if (byFailures != 0) return byFailures;
    return a.cameraId.compareTo(b.cameraId);
  });
  return sorted;
}
