import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models/intersection.dart';
import '../../data/models/traffic_record.dart';
import '../../domain/congestion.dart';
import '../common/stale_banner.dart';

/// Detail for one intersection: its level, how old the reading is, and the
/// per-lane breakdown that produced it.
class IntersectionSheet extends StatelessWidget {
  const IntersectionSheet({
    super.key,
    required this.intersection,
    required this.record,
    required this.level,
    required this.isStale,
    required this.now,
    this.laneCapacityDefault = 12,
  });

  final Intersection intersection;
  final TrafficRecord? record;
  final CongestionLevel level;
  final bool isStale;
  final DateTime now;
  final int laneCapacityDefault;

  @override
  Widget build(BuildContext context) {
    final colors = CongestionColors.of(context);
    final text = Theme.of(context).textTheme;
    final reading = record;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(intersection.name, style: text.titleLarge),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isStale ? colors.unknown : colors.forLevel(level),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(level.label, style: text.titleMedium),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              reading == null
                  ? 'Belum ada data untuk simpang ini'
                  : 'Data terakhir ${relativeIndonesian(now.difference(reading.ts))}',
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (reading == null || reading.perLane.isEmpty)
              Text('Tidak ada rincian lajur.', style: text.bodyMedium)
            else
              ..._laneRows(context, reading, colors),
          ],
        ),
      ),
    );
  }

  List<Widget> _laneRows(
    BuildContext context,
    TrafficRecord reading,
    CongestionColors colors,
  ) {
    final ordered = <String>[
      ...intersection.lanes.where(reading.perLane.containsKey),
      ...reading.perLane.keys.where((k) => !intersection.lanes.contains(k)),
    ];

    return [
      for (final lane in ordered)
        _LaneRow(
          lane: lane,
          count: reading.perLane[lane]!,
          capacity: intersection.capacityFor(lane, fallback: laneCapacityDefault),
          isStale: isStale,
        ),
    ];
  }
}

class _LaneRow extends StatelessWidget {
  const _LaneRow({
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
    final level = levelForLane(count, capacity);
    final color = isStale ? colors.unknown : colors.forLevel(level);
    final ratio = capacity <= 0 ? 0.0 : (count / capacity).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(lane, style: Theme.of(context).textTheme.bodyMedium),
              ),
              Text(
                '$count/$capacity',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
