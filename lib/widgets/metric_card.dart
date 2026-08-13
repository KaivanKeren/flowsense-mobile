import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'app_card.dart';

/// Which way a number moved, and whether that is good news.
///
/// Direction and meaning are separate on purpose: a rising queue is bad, a
/// rising average speed is good, and a component that assumed "up is green"
/// would be wrong half the time on this screen.
enum MetricTrend {
  up(Icons.trending_up),
  down(Icons.trending_down),
  flat(Icons.trending_flat);

  const MetricTrend(this.icon);

  final IconData icon;
}

/// One number, with the label that says what it counts.
///
/// The console's signature element: a monospace category label in capitals, a
/// large figure beneath it, and an optional unit, trend and icon. The figure is
/// the point — everything else is there so the figure can be read without
/// asking what it is.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.trend,
    this.trendLabel,
    this.icon,
    this.onTap,
    this.semanticsValue,
  });

  /// The category. Rendered in monospace capitals; kept sentence case for the
  /// screen reader.
  final String label;

  /// The figure. A string rather than a number so the caller owns the
  /// formatting — thousands separators, `—` for absent, `<1` for a rounded
  /// zero.
  final String value;

  /// `kendaraan`, `dtk`, `%`. Sits on the figure's baseline.
  final String? unit;

  final MetricTrend? trend;

  /// What the trend is against: `vs 1 jam lalu`. Ignored without [trend].
  final String? trendLabel;

  final IconData? icon;

  final VoidCallback? onTap;

  /// What a screen reader hears instead of the assembled label and value. Use
  /// it when the visible text is abbreviated — `18` and `KEND/MNT` read badly
  /// as `18 kend slash mnt`.
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(FlowSpace.md),
      semanticsLabel: semanticsValue ??
          [
            label,
            value,
            ?unit,
            if (trend != null && trendLabel != null) trendLabel,
          ].join(', '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: FlowIconSize.sm, color: colors.textMuted),
                const SizedBox(width: FlowSpace.xs),
              ],
              Expanded(
                child: Text(
                  FlowTypography.monoLabel(label),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: type.labelMono,
                ),
              ),
            ],
          ),
          const SizedBox(height: FlowSpace.sm),
          // Baseline-aligned so a two-character unit sits under the figure's
          // feet rather than its middle.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // A five-digit figure at textScale 1.3 in a 150 px cell does not
              // fit at 28 px. Shrinking it is the right failure: the number
              // stays whole and readable, where an ellipsis would turn 12345
              // into a lie.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: type.metricLarge),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: FlowSpace.xs),
                Flexible(
                  child: Text(
                    unit!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.metricUnit,
                  ),
                ),
              ],
            ],
          ),
          if (trend != null) ...[
            const SizedBox(height: FlowSpace.xs),
            Row(
              children: [
                Icon(
                  trend!.icon,
                  size: FlowIconSize.sm,
                  // Neutral ink, never a status hue. A rising queue and a
                  // rising speed point the same way and mean opposite things,
                  // so the arrow states the direction and the words carry the
                  // judgement.
                  color: colors.textMuted,
                ),
                if (trendLabel != null) ...[
                  const SizedBox(width: FlowSpace.xs),
                  Expanded(
                    child: Text(
                      trendLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.caption,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Metric cards in a grid that wraps.
///
/// Two columns, not a horizontal strip. A strip puts content off the right
/// edge, and the previous console shipped exactly that failure — a row of
/// cards cut in half at the screen edge with nothing to say more existed. A
/// grid has no hidden state: every card is on screen, and a fifth one moves
/// down rather than out.
class MetricGrid extends StatelessWidget {
  const MetricGrid({
    super.key,
    required this.children,
    this.columns = 2,
  });

  final List<Widget> children;

  final int columns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          // Below this the two columns leave no room for a figure, so the grid
          // becomes one column rather than squeezing both.
          final columnCount = constraints.maxWidth < 280 ? 1 : columns;
          final gaps = FlowSpace.md * (columnCount - 1);
          final cellWidth = (constraints.maxWidth - gaps) / columnCount;

          return Wrap(
            spacing: FlowSpace.md,
            runSpacing: FlowSpace.md,
            children: [
              for (final child in children)
                SizedBox(width: cellWidth, child: child),
            ],
          );
        },
      );
}
