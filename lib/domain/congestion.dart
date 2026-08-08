import '../data/models/intersection.dart';
import '../data/models/traffic_record.dart';

/// How congested an approach is. Names are the Indonesian terms the UI shows.
enum CongestionLevel {
  lancar,
  padat,
  macet,
  unknown;

  /// Higher is worse. `unknown` sorts below everything so a dead camera never
  /// tops a worst-first list, but it is never rendered as free flow either.
  int get severity => switch (this) {
        CongestionLevel.unknown => 0,
        CongestionLevel.lancar => 1,
        CongestionLevel.padat => 2,
        CongestionLevel.macet => 3,
      };

  bool get isKnown => this != CongestionLevel.unknown;
}

/// Occupancy thresholds. `< 0.4` lancar, `< 0.75` padat, else macet — so a
/// boundary ratio lands on the *worse* level.
const double kPadatRatio = 0.4;
const double kMacetRatio = 0.75;

/// Classifies one lane. A non-positive [capacity] is uncalibrated data, not an
/// empty road, so it yields `unknown` rather than dividing by zero.
CongestionLevel levelForLane(int count, int capacity) {
  if (capacity <= 0) return CongestionLevel.unknown;
  final ratio = count / capacity;
  if (ratio < kPadatRatio) return CongestionLevel.lancar;
  if (ratio < kMacetRatio) return CongestionLevel.padat;
  return CongestionLevel.macet;
}

/// Classifies a whole intersection: the **worst** lane wins, because one
/// blocked approach is what a rider needs to know.
///
/// Lanes that classify as `unknown` are skipped rather than dominating — but
/// if *every* lane is unknown (or `per_lane` is empty) the result is `unknown`.
/// Absence of data is never reported as free flow.
CongestionLevel levelForIntersection(
  TrafficRecord record,
  Intersection intersection, {
  int laneCapacityDefault = 12,
}) {
  var worst = CongestionLevel.unknown;
  for (final entry in record.perLane.entries) {
    final level = levelForLane(
      entry.value,
      intersection.capacityFor(entry.key, fallback: laneCapacityDefault),
    );
    if (level.isKnown && level.severity > worst.severity) worst = level;
  }
  return worst;
}

/// True when [record] is older than [staleAfter] relative to [now].
///
/// A record timestamped in the future is not stale — clock skew between the
/// edge device and the phone should not paint the map grey.
bool isStale(TrafficRecord record, DateTime now, Duration staleAfter) =>
    now.difference(record.ts) > staleAfter;

/// Copy is plain Indonesian, sentence case, no exclamation marks, no emoji.
///
/// Lives in `domain/` rather than the theme: it is text, not styling, and the
/// alert history needs it without dragging `package:flutter` into a pure
/// filter.
extension CongestionLabel on CongestionLevel {
  String get label => switch (this) {
        CongestionLevel.lancar => 'Lancar',
        CongestionLevel.padat => 'Padat',
        CongestionLevel.macet => 'Macet',
        CongestionLevel.unknown => 'Tidak ada data',
      };
}
