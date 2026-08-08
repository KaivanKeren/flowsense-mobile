import '../data/models/intersection.dart';
import '../data/models/traffic_record.dart';
import 'congestion.dart';

/// One minute of the history chart.
///
/// [count] is `null` for a minute nothing arrived for. That is **not** the same
/// as zero vehicles, and the distinction is the whole reason this type exists:
/// zero is a reading, absence is a silence, and a chart that smooths over the
/// difference is lying about a connector outage.
class HistoryBucket {
  const HistoryBucket({
    required this.minute,
    required this.count,
    required this.level,
  });

  /// Start of the minute this bucket covers.
  final DateTime minute;

  /// Vehicles counted, or null when no record arrived for this minute.
  final int? count;

  /// `unknown` whenever [count] is null — absence is never free flow.
  final CongestionLevel level;

  bool get hasData => count != null;
}

/// The lane the chart is currently showing, or null for every approach.
typedef LaneFilter = String?;

/// Buckets [records] into [count] slots of [bucketSize], ending at [end].
///
/// Missing slots are emitted with a null count rather than dropped, so the
/// chart receives a fixed-length series and never has to guess where a gap
/// was. **Nothing is interpolated.**
///
/// The defaults are the citizen app's hour of one-minute slots. The operator
/// console asks for 96 fifteen-minute slots — a full day. Aggregating to a
/// coarser bucket is exactly why this takes a size rather than assuming
/// minutes: 288 five-minute points on a 360 px screen is a blur, and the
/// layout spec rules it out by name.
///
/// When [lane] is given, the height and the level are computed for that
/// approach alone, against that approach's own calibrated capacity.
List<HistoryBucket> bucketHistory({
  required List<TrafficRecord> records,
  required Intersection intersection,
  required DateTime end,
  int count = 60,
  Duration bucketSize = const Duration(minutes: 1),
  LaneFilter lane,
  int laneCapacityDefault = 12,
}) {
  final lastSlot = _floorTo(end, bucketSize);

  // Latest record wins when a slot carries more than one — the chart shows the
  // most recent state of that slot, matching the map.
  final bySlot = <DateTime, TrafficRecord>{};
  for (final record in records) {
    final key = _floorTo(record.ts, bucketSize);
    final existing = bySlot[key];
    if (existing == null || record.ts.isAfter(existing.ts)) {
      bySlot[key] = record;
    }
  }

  return [
    for (var ago = count - 1; ago >= 0; ago--)
      () {
        final minute = lastSlot.subtract(bucketSize * ago);
        final record = bySlot[minute];
        if (record == null) {
          return HistoryBucket(
            minute: minute,
            count: null,
            level: CongestionLevel.unknown,
          );
        }
        if (lane == null) {
          return HistoryBucket(
            minute: minute,
            count: record.totalVehicles,
            level: levelForIntersection(
              record,
              intersection,
              laneCapacityDefault: laneCapacityDefault,
            ),
          );
        }
        final count = record.perLane[lane];
        if (count == null) {
          // The lane exists on the intersection but not in this record. That
          // is missing data for this series, not a lane that fell silent.
          return HistoryBucket(
            minute: minute,
            count: null,
            level: CongestionLevel.unknown,
          );
        }
        return HistoryBucket(
          minute: minute,
          count: count,
          level: levelForLane(
            count,
            intersection.capacityFor(lane, fallback: laneCapacityDefault),
          ),
        );
      }(),
  ];
}

/// Snaps [t] down to the start of the [size] slot containing it.
///
/// Anchored to the epoch rather than to `end`, so the slot boundaries of a
/// 15-minute chart land on :00, :15, :30 and :45 whatever time the request was
/// made — two operators looking at the same jam see the same bars.
DateTime _floorTo(DateTime t, Duration size) {
  final ms = size.inMilliseconds;
  if (ms <= 0) return t;
  return DateTime.fromMillisecondsSinceEpoch(
    t.millisecondsSinceEpoch - t.millisecondsSinceEpoch % ms,
    isUtc: t.isUtc,
  );
}

/// `16:05`, in the phone's local reading of the timestamp.
String hourMinute(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// The readout sentences under the chart — **at most three**, and only the ones
/// that are true right now.
///
/// Kept as pure text rather than widgets so the wording is unit-testable and
/// the chart cannot quietly grow a fourth line.
List<String> historySummary(List<HistoryBucket> buckets) {
  final lines = <String>[];
  final withData = buckets.where((b) => b.hasData).toList();
  if (withData.isEmpty) return lines;

  final sustained = _sustainedCongestion(buckets);
  if (sustained != null) lines.add(sustained);

  final peak = withData.reduce((a, b) => b.count! >= a.count! ? b : a);
  if (peak.count! > 0) {
    lines.add('Tertinggi ${peak.count} kendaraan pukul '
        '${hourMinute(peak.minute)}');
  }

  final gap = _longestGap(buckets);
  if (gap != null) lines.add(gap);

  return lines;
}

/// "Padat sejak 16:05, belum ada tanda reda" — but only while it is still
/// going. A jam that has already eased is history, not a warning.
String? _sustainedCongestion(List<HistoryBucket> buckets) {
  final lastKnown = buckets.lastIndexWhere((b) => b.hasData);
  if (lastKnown < 0) return null;

  final current = buckets[lastKnown].level;
  if (current != CongestionLevel.padat && current != CongestionLevel.macet) {
    return null;
  }

  // Walk back while the road stayed at least busy. Gaps do not break the run —
  // they say nothing either way — but they cannot start it.
  var start = lastKnown;
  for (var i = lastKnown - 1; i >= 0; i--) {
    final bucket = buckets[i];
    if (!bucket.hasData) continue;
    if (bucket.level == CongestionLevel.padat ||
        bucket.level == CongestionLevel.macet) {
      start = i;
    } else {
      break;
    }
  }

  // A single minute is a blip, not a trend worth a sentence.
  if (start == lastKnown) return null;

  final label = current == CongestionLevel.macet ? 'Macet' : 'Padat';
  return '$label sejak ${hourMinute(buckets[start].minute)}, '
      'belum ada tanda reda';
}

/// "Data tidak masuk 3 menit pukul 16:02", describing the longest silence.
String? _longestGap(List<HistoryBucket> buckets) {
  var bestStart = -1;
  var bestLength = 0;
  var runStart = -1;
  var runLength = 0;

  void close() {
    if (runLength > bestLength) {
      bestLength = runLength;
      bestStart = runStart;
    }
    runStart = -1;
    runLength = 0;
  }

  for (var i = 0; i < buckets.length; i++) {
    if (buckets[i].hasData) {
      close();
    } else {
      if (runStart < 0) runStart = i;
      runLength++;
    }
  }
  close();

  if (bestStart < 0) return null;
  return 'Data tidak masuk $bestLength menit pukul '
      '${hourMinute(buckets[bestStart].minute)}';
}

/// The three x-axis labels: window start, midpoint, and `sekarang`.
///
/// There is no y-axis at all — the chart answers "when was it bad", and a
/// vehicle-count scale would invite reading precision the detector does not
/// have.
List<String> historyAxisLabels(List<HistoryBucket> buckets) {
  if (buckets.isEmpty) return const [];
  return [
    hourMinute(buckets.first.minute),
    hourMinute(buckets[buckets.length ~/ 2].minute),
    'sekarang',
  ];
}
