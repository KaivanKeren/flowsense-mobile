import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models/intersection.dart';
import '../../data/models/traffic_record.dart';
import '../../domain/congestion.dart';

/// The signature element of the citizen map: a filled circle sized by
/// `total_vehicles`, with the lane split rendered as a thin ring around it.
///
/// Readable at a glance from a phone mounted on a handlebar — size carries
/// volume, fill carries the worst lane, and the ring shows which approach is
/// carrying it.
class IntersectionMarker extends StatelessWidget {
  const IntersectionMarker({
    super.key,
    required this.intersection,
    required this.record,
    required this.level,
    required this.isStale,
    this.laneCapacityDefault = 12,
    this.onTap,
  });

  final Intersection intersection;

  /// Null when the snapshot has no record for this camera at all.
  final TrafficRecord? record;
  final CongestionLevel level;
  final bool isStale;
  final int laneCapacityDefault;
  final VoidCallback? onTap;

  static const double minDiameter = 30;
  static const double maxDiameter = 54;

  /// Volume at which a marker reaches [maxDiameter]. Above this the circle
  /// stops growing rather than swallowing its neighbours.
  static const int busyVehicles = 24;

  static double diameterFor(int totalVehicles) {
    final t = (totalVehicles.clamp(0, busyVehicles)) / busyVehicles;
    return minDiameter + (maxDiameter - minDiameter) * t;
  }

  /// Stale markers render in the unknown grey rather than a dimmed hue: a
  /// washed-out red still reads as red, and a colour on this screen must mean
  /// exactly one thing.
  static Color colorFor(
    CongestionColors colors,
    CongestionLevel level, {
    required bool isStale,
  }) =>
      isStale ? colors.unknown : colors.forLevel(level);

  double get diameter => diameterFor(record?.totalVehicles ?? 0);

  @override
  Widget build(BuildContext context) {
    final colors = CongestionColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: onTap != null,
      label: '${intersection.name}, ${level.label}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: CustomPaint(
            painter: _MarkerPainter(
              fill: colorFor(colors, level, isStale: isStale),
              outline: scheme.surface,
              lanes: _laneSlices(colors),
            ),
          ),
        ),
      ),
    );
  }

  /// One ring slice per lane, in the intersection's declared lane order so the
  /// ring does not reshuffle between polls. Lanes that appear mid-session are
  /// appended rather than dropped.
  List<_LaneSlice> _laneSlices(CongestionColors colors) {
    final perLane = record?.perLane ?? const <String, int>{};
    if (perLane.isEmpty) return const [];

    return [
      for (final lane in intersection.orderedLanes(perLane.keys))
        _LaneSlice(
          weight: perLane[lane]!.toDouble(),
          color: colorFor(
            colors,
            levelForLane(
              perLane[lane]!,
              intersection.capacityFor(lane, fallback: laneCapacityDefault),
            ),
            isStale: isStale,
          ),
        ),
    ];
  }
}

class _LaneSlice {
  const _LaneSlice({required this.weight, required this.color});

  final double weight;
  final Color color;
}

class _MarkerPainter extends CustomPainter {
  const _MarkerPainter({
    required this.fill,
    required this.outline,
    required this.lanes,
  });

  final Color fill;
  final Color outline;
  final List<_LaneSlice> lanes;

  static const double _ringWidth = 4;
  static const double _gap = 2;
  static const double _sliceGapRadians = 0.06;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final coreRadius = radius - _ringWidth - _gap;

    // Outline first, so the marker stays legible over busy map tiles.
    canvas.drawCircle(
      center,
      coreRadius + 1.5,
      Paint()..color = outline.withValues(alpha: 0.9),
    );
    canvas.drawCircle(center, coreRadius, Paint()..color = fill);

    final total = lanes.fold<double>(0, (sum, l) => sum + l.weight);
    if (lanes.isEmpty || total <= 0) return;

    final ringRect = Rect.fromCircle(
      center: center,
      radius: radius - _ringWidth / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ringWidth
      ..strokeCap = StrokeCap.round;

    var start = -math.pi / 2; // 12 o'clock
    for (final lane in lanes) {
      final sweep = (math.pi * 2) * (lane.weight / total);
      if (sweep <= _sliceGapRadians) {
        start += sweep;
        continue;
      }
      canvas.drawArc(
        ringRect,
        start + _sliceGapRadians / 2,
        sweep - _sliceGapRadians,
        false,
        paint..color = lane.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_MarkerPainter old) =>
      old.fill != fill || old.outline != outline || old.lanes != lanes;
}
