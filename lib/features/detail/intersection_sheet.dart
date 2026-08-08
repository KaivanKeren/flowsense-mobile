import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models/intersection.dart';
import '../../data/models/traffic_record.dart';
import '../../domain/congestion.dart';
import '../../domain/geo.dart';
import '../../domain/history.dart';
import '../../domain/lane_label.dart';
import '../common/relative_time.dart';
import '../common/status_pill.dart';
import 'history_chart.dart';

/// Everything known about one intersection, revealed in three stages as the
/// sheet is dragged up.
///
/// The order is the argument. The compact stage answers the only question a
/// rider actually has — how bad is it, and how old is that. Lanes and history
/// come next, for someone deciding whether to wait. The camera comes **last**,
/// deliberately: it is the most eye-catching element and the least actionable,
/// since nobody reads congestion off a low-resolution video faster than off one
/// coloured bar.
class IntersectionSheet extends StatefulWidget {
  const IntersectionSheet({
    super.key,
    required this.intersection,
    required this.record,
    required this.level,
    required this.isStale,
    required this.now,
    this.history = const [],
    this.nearby = const [],
    this.laneCapacityDefault = 12,
    this.scrollController,
    this.onRetry,
    this.onSelectNearby,
  });

  final Intersection intersection;
  final TrafficRecord? record;
  final CongestionLevel level;
  final bool isStale;
  final DateTime now;

  /// Time-bucketed points from `GET /v1/intersections/{id}/history`. Server
  /// side aggregation — the phone never pulls raw records for an hour.
  final List<TrafficRecord> history;

  /// Other intersections, with the reading each one currently has.
  final List<NearbyIntersection> nearby;

  final int laneCapacityDefault;

  /// Supplied by `DraggableScrollableSheet` so dragging the sheet and scrolling
  /// its content are the same gesture.
  final ScrollController? scrollController;

  final VoidCallback? onRetry;
  final ValueChanged<Intersection>? onSelectNearby;

  @override
  State<IntersectionSheet> createState() => _IntersectionSheetState();
}

/// One entry in the `Simpang terdekat` row.
class NearbyIntersection {
  const NearbyIntersection({
    required this.intersection,
    required this.level,
    required this.isStale,
  });

  final Intersection intersection;
  final CongestionLevel level;
  final bool isStale;
}

class _IntersectionSheetState extends State<IntersectionSheet> {
  String? _lane;

  @override
  void didUpdateWidget(IntersectionSheet old) {
    super.didUpdateWidget(old);
    // Switching intersections must not carry a lane selection across to one
    // that has no such approach.
    if (old.intersection.id != widget.intersection.id) _lane = null;
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final reading = widget.record;

    final buckets = bucketHistory(
      records: widget.history,
      intersection: widget.intersection,
      end: widget.now,
      lane: _lane,
      laneCapacityDefault: widget.laneCapacityDefault,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DragHandle(color: surfaces.faintInk),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              // --- Stage one: compact -------------------------------------
              _Header(
                name: widget.intersection.name,
                level: widget.level,
                isStale: widget.isStale,
              ),
              const SizedBox(height: 6),
              _Summary(
                record: reading,
                now: widget.now,
                isStale: widget.isStale,
              ),
              if (reading != null && reading.perLane.isNotEmpty) ...[
                const SizedBox(height: 2),
                _WorstLaneLine(
                  intersection: widget.intersection,
                  record: reading,
                  laneCapacityDefault: widget.laneCapacityDefault,
                ),
              ],
              if (widget.isStale && widget.onRetry != null) ...[
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: widget.onRetry,
                  child: const Text('Coba lagi'),
                ),
              ],

              // --- Stage two: lanes and history ---------------------------
              const SizedBox(height: 18),
              Divider(color: surfaces.roadLine, height: 1),
              const SizedBox(height: 16),
              _Lanes(
                intersection: widget.intersection,
                record: reading,
                isStale: widget.isStale,
                laneCapacityDefault: widget.laneCapacityDefault,
              ),
              const SizedBox(height: 20),
              HistoryChart(
                buckets: buckets,
                lanes: widget.intersection.lanes,
                selectedLane: _lane,
                onLaneChanged: (lane) => setState(() => _lane = lane),
              ),

              // --- Stage three: camera, then neighbours -------------------
              const SizedBox(height: 22),
              const _CameraPanel(),
              if (widget.nearby.isNotEmpty) ...[
                const SizedBox(height: 22),
                _Nearby(
                  origin: widget.intersection,
                  items: widget.nearby,
                  onSelect: widget.onSelectNearby,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Center(
          child: Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.level,
    required this.isStale,
  });

  final String name;
  final CongestionLevel level;
  final bool isStale;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(name, style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(width: 12),
          StatusPill(level: level, isStale: isStale),
        ],
      );
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.record,
    required this.now,
    required this.isStale,
  });

  final TrafficRecord? record;
  final DateTime now;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reading = record;

    if (reading == null) {
      return Text('Belum ada data untuk simpang ini', style: text.bodyMedium);
    }

    final age = relativeIndonesian(now.difference(reading.ts));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${reading.totalVehicles} kendaraan · $age',
          style: text.bodyMedium,
        ),
        if (isStale)
          Text('Perangkat tidak mengirim data', style: text.bodySmall),
      ],
    );
  }
}

/// `Arah kota paling padat` — names the approach that set the intersection's
/// level, so the single colour on the map is accounted for.
class _WorstLaneLine extends StatelessWidget {
  const _WorstLaneLine({
    required this.intersection,
    required this.record,
    required this.laneCapacityDefault,
  });

  final Intersection intersection;
  final TrafficRecord record;
  final int laneCapacityDefault;

  @override
  Widget build(BuildContext context) {
    String? worstLane;
    var worstRatio = -1.0;

    for (final lane in intersection.orderedLanes(record.perLane.keys)) {
      final capacity =
          intersection.capacityFor(lane, fallback: laneCapacityDefault);
      if (capacity <= 0) continue;
      final ratio = record.perLane[lane]! / capacity;
      if (ratio > worstRatio) {
        worstRatio = ratio;
        worstLane = lane;
      }
    }

    if (worstLane == null) return const SizedBox.shrink();
    return Text(
      '${laneLabel(worstLane)} paling padat',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _Lanes extends StatelessWidget {
  const _Lanes({
    required this.intersection,
    required this.record,
    required this.isStale,
    required this.laneCapacityDefault,
  });

  final Intersection intersection;
  final TrafficRecord? record;
  final bool isStale;
  final int laneCapacityDefault;

  @override
  Widget build(BuildContext context) {
    final reading = record;

    // An empty per_lane is rendered as "no data", never as a clear road. This
    // is the most dangerous mistake this app could make.
    if (reading == null || reading.perLane.isEmpty) {
      return Text(
        'Tidak ada rincian lajur.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Column(
      children: [
        for (final lane in intersection.orderedLanes(reading.perLane.keys))
          _LaneRow(
            // Keyed so a test can assert lane *order* without tripping over
            // the chart legend and the direction chips, which legitimately
            // repeat the same words further down the sheet.
            key: ValueKey('lane-$lane'),
            lane: lane,
            count: reading.perLane[lane]!,
            capacity:
                intersection.capacityFor(lane, fallback: laneCapacityDefault),
            isStale: isStale,
          ),
      ],
    );
  }
}

class _LaneRow extends StatelessWidget {
  const _LaneRow({
    super.key,
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
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;

    final level = levelForLane(count, capacity);
    final color =
        colors.forLevel(isStale ? CongestionLevel.unknown : level);
    final ratio = capacity <= 0 ? 0.0 : (count / capacity).clamp(0.0, 1.0);

    return Semantics(
      label: '${laneLabel(lane)}, $count kendaraan, '
          '${statusLabel(level, isStale: isStale).toLowerCase()}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                laneLabel(lane),
                style: text.bodyMedium?.copyWith(
                  color: surfaces.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(color: surfaces.roadLine),
                      ),
                      // `heightFactor: 1` is load bearing: without it the
                      // child gets loose vertical constraints and the
                      // `ColoredBox` collapses to zero height, leaving an
                      // empty track while every text assertion still passes.
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: ratio,
                            heightFactor: 1,
                            child: ColoredBox(color: color),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 24,
              child: Text(
                '$count',
                textAlign: TextAlign.right,
                style: text.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The camera, last on the page.
///
/// There is no image endpoint in `docs/api-contract.md`, so the panel renders
/// its unavailable state rather than pretending. The caption stays either way:
/// it tells a rider how often the view would refresh, which is what makes the
/// panel worth waiting for or not.
class _CameraPanel extends StatelessWidget {
  const _CameraPanel();

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surfaces.map,
              borderRadius: BorderRadius.circular(FlowRadius.card),
              border: Border.all(color: surfaces.roadLine),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off_outlined,
                      size: 24, color: surfaces.faintInk),
                  const SizedBox(height: 8),
                  Text('Kamera tidak tersedia', style: text.bodySmall),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Diperbarui tiap 20 detik',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: surfaces.textFaint),
        ),
      ],
    );
  }
}

/// A single horizontally scrolling row, not a grid — it is a shortcut, not a
/// second index of the whole city.
class _Nearby extends StatelessWidget {
  const _Nearby({
    required this.origin,
    required this.items,
    required this.onSelect,
  });

  final Intersection origin;
  final List<NearbyIntersection> items;
  final ValueChanged<Intersection>? onSelect;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;

    final sorted = [...items]..sort((a, b) => distanceKm(
              origin.lat,
              origin.lon,
              a.intersection.lat,
              a.intersection.lon,
            ).compareTo(distanceKm(
              origin.lat,
              origin.lon,
              b.intersection.lat,
              b.intersection.lon,
            )));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Simpang terdekat', style: text.titleMedium),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in sorted.take(6))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Semantics(
                    button: onSelect != null,
                    label: '${item.intersection.name}, '
                        '${statusLabel(item.level, isStale: item.isStale).toLowerCase()}',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: onSelect == null
                          ? null
                          : () => onSelect!(item.intersection),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: surfaces.card,
                          borderRadius:
                              BorderRadius.circular(FlowRadius.control),
                          border: Border.all(color: surfaces.roadLine),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StatusDot(
                              level: item.level,
                              isStale: item.isStale,
                            ),
                            const SizedBox(width: 8),
                            Text(item.intersection.name,
                                style: text.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
