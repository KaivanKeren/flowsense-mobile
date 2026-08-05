import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models/intersection.dart';
import '../../data/models/traffic_record.dart';
import '../../domain/congestion.dart';

/// The signature element of the citizen map.
///
/// Anatomy, from the layout spec:
///
/// * A core circle carrying `total_vehicles` as a number, 38–46 px across,
///   scaled against the busiest intersection **currently on screen** rather
///   than an absolute ceiling — so the map re-ranks itself as traffic moves.
/// * An outer ring cut into equal arcs, one per lane, each arc coloured by
///   that lane's own level, with a small gap between them.
/// * The core's fill follows the **worst lane, not the total**. Deliberate: one
///   blocked approach has to read red even when the total count is small, and
///   an intersection where everything is mildly busy must not.
/// * No data at all: an empty white core, a grey outline, `?` in place of the
///   number, and four grey arcs.
class IntersectionMarker extends StatelessWidget {
  const IntersectionMarker({
    super.key,
    required this.intersection,
    required this.record,
    required this.level,
    required this.isStale,
    this.laneCapacityDefault = 12,
    this.busiestVehicles = 0,
    this.isSelected = false,
    this.isDimmed = false,
    this.onTap,
  });

  final Intersection intersection;

  /// Null when the snapshot has no record for this camera at all.
  final TrafficRecord? record;
  final CongestionLevel level;
  final bool isStale;
  final int laneCapacityDefault;

  /// `total_vehicles` of the busiest intersection currently displayed. The
  /// scale is relative to what is on screen, per the spec.
  final int busiestVehicles;

  final bool isSelected;

  /// True when some *other* marker is selected. The spec dims the rest to 0.55
  /// so the chosen one reads first.
  final bool isDimmed;

  final VoidCallback? onTap;

  static const double minDiameter = 38;
  static const double maxDiameter = 46;

  /// Opacity of the markers that are not the selected one.
  static const double dimmedOpacity = 0.55;

  /// The number of arcs drawn when a marker has no lane data — the spec's
  /// "four grey arcs".
  static const int placeholderArcs = 4;

  /// Diameter for [totalVehicles], scaled against [busiest].
  ///
  /// Guards the degenerate cases rather than dividing blindly: an empty map, or
  /// one where every intersection reads zero, gives every marker the floor size
  /// instead of a NaN radius.
  static double diameterFor(int totalVehicles, {required int busiest}) {
    if (busiest <= 0) return minDiameter;
    final t = (totalVehicles.clamp(0, busiest)) / busiest;
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

  bool get hasData => record != null && record!.perLane.isNotEmpty;

  double get diameter => diameterFor(
        record?.totalVehicles ?? 0,
        busiest: busiestVehicles,
      );

  /// What a screen reader announces. The spec's example is
  /// `"Simpang DPRD, macet, 18 kendaraan"` — the status is spoken, never left
  /// to the fill colour.
  String get semanticsLabel {
    final status = statusLabel(level, isStale: isStale).toLowerCase();
    if (record == null) return '${intersection.name}, $status';
    return '${intersection.name}, $status, '
        '${record!.totalVehicles} kendaraan';
  }

  @override
  Widget build(BuildContext context) {
    final colors = CongestionColors.of(context);
    final surfaces = FlowSurfaces.of(context);
    final size = diameter;

    final marker = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MarkerPainter(
          fill: hasData
              ? colorFor(colors, level, isStale: isStale)
              : surfaces.card,
          outline: surfaces.card,
          emptyOutline: surfaces.faintInk,
          hasData: hasData,
          isSelected: isSelected,
          arcs: _arcs(colors, surfaces),
        ),
        child: Center(
          child: Text(
            hasData ? '${record!.totalVehicles}' : '?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  // On a filled core the number sits on a saturated hue, so it
                  // is white; on the empty core it sits on white, so it is ink.
                  color: hasData ? surfaces.card : surfaces.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );

    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      // The count is already in the label. Without this the inner Text adds a
      // second node and a screen reader reads "18" twice.
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: isDimmed
            ? Opacity(opacity: dimmedOpacity, child: marker)
            : marker,
      ),
    );
  }

  /// One arc per lane, **equal in size**, in the intersection's declared lane
  /// order so the ring does not reshuffle between polls.
  ///
  /// Equal arcs are the point: the ring answers "which approach is blocked",
  /// and weighting each arc by its own count would shrink exactly the arc a
  /// rider most needs to see when one lane empties while another jams.
  List<Color> _arcs(CongestionColors colors, FlowSurfaces surfaces) {
    final perLane = record?.perLane ?? const <String, int>{};
    if (perLane.isEmpty) {
      return List.filled(placeholderArcs, colors.unknown);
    }

    return [
      for (final lane in intersection.orderedLanes(perLane.keys))
        colorFor(
          colors,
          levelForLane(
            perLane[lane]!,
            intersection.capacityFor(lane, fallback: laneCapacityDefault),
          ),
          isStale: isStale,
        ),
    ];
  }
}

class _MarkerPainter extends CustomPainter {
  const _MarkerPainter({
    required this.fill,
    required this.outline,
    required this.emptyOutline,
    required this.hasData,
    required this.isSelected,
    required this.arcs,
  });

  final Color fill;
  final Color outline;
  final Color emptyOutline;
  final bool hasData;
  final bool isSelected;
  final List<Color> arcs;

  static const double _ringWidth = 3.5;
  static const double _gap = 2;
  static const double _arcGapRadians = 0.14;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final coreRadius = radius - _ringWidth - _gap;

    // A white disc under the core keeps the marker legible over busy tiles.
    canvas.drawCircle(
      center,
      coreRadius + 1.5,
      Paint()..color = outline,
    );
    canvas.drawCircle(center, coreRadius, Paint()..color = fill);

    // The no-data core is an outline, not a fill — an absent reading should
    // look absent rather than like a quiet road.
    if (!hasData) {
      canvas.drawCircle(
        center,
        coreRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = emptyOutline,
      );
    }

    if (isSelected) {
      canvas.drawCircle(
        center,
        coreRadius + 2.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = fill,
      );
    }

    if (arcs.isEmpty) return;

    final ringRect = Rect.fromCircle(
      center: center,
      radius: radius - _ringWidth / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ringWidth
      ..strokeCap = StrokeCap.butt;

    final sweep = (math.pi * 2) / arcs.length;
    var start = -math.pi / 2; // 12 o'clock
    for (final color in arcs) {
      canvas.drawArc(
        ringRect,
        start + _arcGapRadians / 2,
        sweep - _arcGapRadians,
        false,
        paint..color = color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_MarkerPainter old) =>
      old.fill != fill ||
      old.outline != outline ||
      old.hasData != hasData ||
      old.isSelected != isSelected ||
      !listEquals(old.arcs, arcs);
}
