import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/congestion.dart';

/// `Lancar` / `Padat` / `Macet` / `Data basi`, as a pill.
///
/// The status is **always** written out, never carried by colour alone. Red and
/// green are the two hues this app leans on hardest and red-green colour
/// blindness is precisely the relevant case for a traffic app, so the word is
/// the primary signal and the tint is reinforcement.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.level,
    required this.isStale,
  });

  final CongestionLevel level;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    // A stale reading is shown in the unknown grey whatever the level said.
    // Dimming the real hue instead would leave a washed-out red still reading
    // as red, and a colour here must mean exactly one thing.
    final pill = CongestionColors.of(context)
        .pillFor(isStale ? CongestionLevel.unknown : level);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: pill.tint,
        borderRadius: BorderRadius.circular(FlowRadius.control),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          statusLabel(level, isStale: isStale),
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: pill.ink, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// A small filled dot in the level's colour, for the places a full pill would
/// crowd the row — the "Simpang terdekat" cards, mainly.
///
/// Never used alone: every call site pairs it with the intersection's name and
/// a `Semantics` label that spells the status out.
class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    required this.level,
    required this.isStale,
    this.size = 8,
  });

  final CongestionLevel level;
  final bool isStale;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = CongestionColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.forLevel(isStale ? CongestionLevel.unknown : level),
        shape: BoxShape.circle,
      ),
    );
  }
}
