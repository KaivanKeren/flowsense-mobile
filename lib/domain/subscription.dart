import 'congestion.dart';

/// How bad it has to get before someone is interrupted.
enum AlertThreshold {
  macetSaja('Beri tahu saat macet'),
  padatDanMacet('Beri tahu saat padat dan macet');

  const AlertThreshold(this.label);

  final String label;

  /// Whether [level] is worth a notification under this threshold.
  ///
  /// `unknown` is never worth one under either: a connector that stopped
  /// reporting is not a traffic jam.
  bool covers(CongestionLevel level) => switch (this) {
        AlertThreshold.macetSaja => level == CongestionLevel.macet,
        AlertThreshold.padatDanMacet =>
          level == CongestionLevel.macet || level == CongestionLevel.padat,
      };
}

/// A window of the day during which notifications are allowed, in local time.
///
/// Minutes since midnight rather than `TimeOfDay`, so this file stays free of
/// `package:flutter` and the rule can be unit-tested without a widget binding.
class TimeRange {
  const TimeRange({required this.startMinute, required this.endMinute});

  const TimeRange.hours(int startHour, int endHour)
      : startMinute = startHour * 60,
        endMinute = endHour * 60;

  factory TimeRange.fromJson(Map<String, dynamic> json) => TimeRange(
        startMinute: (json['start'] as num?)?.toInt() ?? 0,
        endMinute: (json['end'] as num?)?.toInt() ?? 0,
      );

  final int startMinute;
  final int endMinute;

  /// True when [minuteOfDay] falls inside this window.
  ///
  /// A range whose end is before its start wraps past midnight — 22:00–06:00
  /// is one window, not an empty one.
  bool contains(int minuteOfDay) {
    if (startMinute == endMinute) return false;
    if (startMinute < endMinute) {
      return minuteOfDay >= startMinute && minuteOfDay < endMinute;
    }
    return minuteOfDay >= startMinute || minuteOfDay < endMinute;
  }

  Map<String, dynamic> toJson() => {'start': startMinute, 'end': endMinute};

  String get label => '${_hhmm(startMinute)} – ${_hhmm(endMinute)}';

  static String _hhmm(int minuteOfDay) {
    final h = (minuteOfDay ~/ 60) % 24;
    final m = minuteOfDay % 60;
    // Indonesian convention writes the time separator as a full stop.
    return '${h.toString().padLeft(2, '0')}.${m.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      other is TimeRange &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute;

  @override
  int get hashCode => Object.hash(startMinute, endMinute);
}

/// What the user asked to be told about, stored on the device and never sent
/// anywhere.
class SubscriptionSettings {
  const SubscriptionSettings({
    this.cameraIds = const {},
    this.threshold = AlertThreshold.macetSaja,
    this.activeHours = defaultActiveHours,
  });

  factory SubscriptionSettings.fromJson(Map<String, dynamic> json) =>
      SubscriptionSettings(
        cameraIds: {
          for (final e in (json['cameraIds'] as List? ?? const [])) '$e',
        },
        threshold: AlertThreshold.values.firstWhere(
          (t) => t.name == json['threshold'],
          orElse: () => AlertThreshold.macetSaja,
        ),
        activeHours: [
          for (final e in (json['activeHours'] as List? ?? const []))
            if (e is Map<String, dynamic>) TimeRange.fromJson(e),
        ],
      );

  /// The commute peaks. **Do not remove this default.** Telling somebody that
  /// Simpang DPRD is jammed at two in the morning is the fastest way to get
  /// the app uninstalled.
  static const defaultActiveHours = [
    TimeRange.hours(6, 9),
    TimeRange.hours(15, 19),
  ];

  /// Intersections being watched. Empty means no notifications at all — the
  /// app never opts anyone in on their behalf.
  final Set<String> cameraIds;

  final AlertThreshold threshold;

  /// Windows during which a notification may be delivered. An empty list means
  /// the user switched every window off, which is a valid way to say "never".
  final List<TimeRange> activeHours;

  bool isSubscribed(String cameraId) => cameraIds.contains(cameraId);

  /// Whether the clock currently allows an interruption.
  bool isWithinActiveHours(DateTime now) {
    final minuteOfDay = now.hour * 60 + now.minute;
    return activeHours.any((range) => range.contains(minuteOfDay));
  }

  /// The single question the alert pipeline asks: may this intersection, at
  /// this level, wake this person up right now?
  bool allows({
    required String cameraId,
    required CongestionLevel level,
    required bool isStale,
    required DateTime now,
  }) {
    if (isStale) return false;
    if (!isSubscribed(cameraId)) return false;
    if (!threshold.covers(level)) return false;
    return isWithinActiveHours(now);
  }

  SubscriptionSettings copyWith({
    Set<String>? cameraIds,
    AlertThreshold? threshold,
    List<TimeRange>? activeHours,
  }) =>
      SubscriptionSettings(
        cameraIds: cameraIds ?? this.cameraIds,
        threshold: threshold ?? this.threshold,
        activeHours: activeHours ?? this.activeHours,
      );

  SubscriptionSettings toggle(String cameraId) => copyWith(
        cameraIds: cameraIds.contains(cameraId)
            ? ({...cameraIds}..remove(cameraId))
            : {...cameraIds, cameraId},
      );

  Map<String, dynamic> toJson() => {
        'cameraIds': cameraIds.toList()..sort(),
        'threshold': threshold.name,
        'activeHours': [for (final r in activeHours) r.toJson()],
      };
}
