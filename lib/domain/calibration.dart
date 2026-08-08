/// A lane's calibrated capacity, and who last vouched for it.
///
/// Capacity is the number the whole classification rests on: every level in
/// this app is `count / capacity`. A wrong capacity does not look like a bug,
/// it looks like traffic — which is why the console records who set it.
class CapacityCalibration {
  const CapacityCalibration({
    required this.cameraId,
    required this.capacity,
    this.updatedBy,
    this.updatedAt,
  });

  factory CapacityCalibration.fromJson(Map<String, dynamic> json) =>
      CapacityCalibration(
        cameraId: '${json['camera_id'] ?? ''}',
        capacity: {
          for (final e
              in (json['capacity'] as Map<String, dynamic>? ?? const {}).entries)
            e.key: (e.value as num?)?.toInt() ?? 0,
        },
        updatedBy: json['updated_by'] as String?,
        updatedAt: json['updated_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                ((json['updated_at'] as num).toInt()) * 1000,
                isUtc: true,
              ),
      );

  final String cameraId;
  final Map<String, int> capacity;
  final String? updatedBy;
  final DateTime? updatedAt;

  bool get hasBeenCalibrated => updatedBy != null && updatedAt != null;

  Map<String, dynamic> toJson() => {
        'camera_id': cameraId,
        'capacity': capacity,
        if (updatedBy != null) 'updated_by': updatedBy,
        if (updatedAt != null)
          'updated_at': updatedAt!.millisecondsSinceEpoch ~/ 1000,
      };
}

const _months = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// `2 Agustus 2026 09.14` — Indonesian month, full-stop time separator.
String indonesianDateTime(DateTime t) =>
    '${t.day} ${_months[t.month - 1]} ${t.year} '
    '${t.hour.toString().padLeft(2, '0')}.'
    '${t.minute.toString().padLeft(2, '0')}';

/// `Terakhir diubah Ismail, 2 Agustus 2026 09.14.`
///
/// Null when nobody has calibrated this intersection yet — which is worth
/// saying plainly rather than papering over with a default date.
String? lastChangedLine(CapacityCalibration calibration) {
  if (!calibration.hasBeenCalibrated) return null;
  return 'Terakhir diubah ${calibration.updatedBy}, '
      '${indonesianDateTime(calibration.updatedAt!)}.';
}

/// Whether [edited] differs from [original], so `Simpan` can be offered only
/// when there is something to save.
bool hasCapacityChanges(
  Map<String, int> original,
  Map<String, int> edited,
) {
  if (original.length != edited.length) return true;
  for (final entry in edited.entries) {
    if (original[entry.key] != entry.value) return true;
  }
  return false;
}

/// Capacity has to be a positive whole number.
///
/// Zero is rejected rather than accepted-and-handled: `levelForLane` treats a
/// non-positive capacity as *uncalibrated* and returns `unknown`, so saving a
/// zero would silently blank the lane instead of classifying it.
String? capacityError(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 'Kapasitas harus diisi';
  final value = int.tryParse(trimmed);
  if (value == null) return 'Kapasitas harus berupa angka';
  if (value <= 0) return 'Kapasitas harus lebih dari 0';
  if (value > 999) return 'Kapasitas terlalu besar';
  return null;
}
