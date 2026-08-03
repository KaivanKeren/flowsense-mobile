import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models/intersection.dart';
import '../../data/models/traffic_record.dart';
import '../../domain/congestion.dart';

/// The per-lane breakdown, as one dense row per lane: name, occupancy bar,
/// count against capacity.
///
/// Denser than the citizen sheet on purpose. An operator is scanning a list of
/// intersections at a desk, not reading one at arm's length on a motorbike, so
/// each lane gets a single line and the whole intersection stays glanceable in
/// a list.
class LaneBars extends StatelessWidget {
  const LaneBars({
    super.key,
    required this.intersection,
    required this.record,
    required this.isStale,
    this.laneCapacityDefault = 12,
  });

  final Intersection intersection;

  /// Null when the snapshot carries no record for this camera.
  final TrafficRecord? record;
  final bool isStale;
  final int laneCapacityDefault;

  @override
  Widget build(BuildContext context) {
    final perLane = record?.perLane ?? const <String, int>{};
    if (perLane.isEmpty) {
      return Text(
        'Tidak ada rincian lajur.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A lane the backend never declared still renders — it appeared
        // mid-session, which the connector is allowed to do.
        for (final lane in intersection.orderedLanes(perLane.keys))
          _LaneBar(
            lane: lane,
            count: perLane[lane]!,
            capacity: intersection.capacityFor(
              lane,
              fallback: laneCapacityDefault,
            ),
            isStale: isStale,
          ),
      ],
    );
  }
}

class _LaneBar extends StatelessWidget {
  const _LaneBar({
    required this.lane,
    required this.count,
    required this.capacity,
    required this.isStale,
  });

  final String lane;
  final int count;
  final int capacity;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final colors = CongestionColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final level = levelForLane(count, capacity);
    final color = isStale ? colors.unknown : colors.forLevel(level);
    final ratio = capacity <= 0 ? 0.0 : (count / capacity).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              lane,
              style: text.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(
              '$count/$capacity',
              style: text.bodySmall,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
