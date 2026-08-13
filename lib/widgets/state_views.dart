/// The four things a screen can be doing besides showing data: loading it,
/// having none, having failed, and showing data it no longer trusts.
///
/// **There is no bare spinner in this app.** A spinner says "wait" without
/// saying what for, and on a phone at a junction that is worse than saying
/// nothing. Every state below carries a sentence, and every failure carries a
/// way on.
library;

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'status_chip.dart';

/// A sentence and a button. The shape the empty and error states share.
class MessageState extends StatelessWidget {
  const MessageState({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  /// Nothing has arrived, and nothing is wrong.
  const MessageState.empty({
    super.key,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
  }) : icon = Icons.inbox_outlined;

  /// Something failed. [onAction] is the way out, and it is never a dead end.
  const MessageState.error({
    super.key,
    required this.message,
    this.title,
    required String this.actionLabel,
    required VoidCallback this.onAction,
  }) : icon = Icons.cloud_off_outlined;

  /// A short heading. Omitted when [message] is already one sentence.
  final String? title;

  final String message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);

    return Center(
      child: SingleChildScrollView(
        // Scrollable, because at textScale 1.3 in a landscape window this
        // block is taller than the space a `Center` gives it, and a centred
        // overflow clips from both ends at once.
        padding: const EdgeInsets.all(FlowSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: FlowIconSize.xl, color: colors.textMuted),
              const SizedBox(height: FlowSpace.md),
            ],
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: type.sectionTitle,
              ),
              const SizedBox(height: FlowSpace.sm),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: type.body.copyWith(color: colors.textSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: FlowSpace.xl),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Grey blocks in the shape of the content that is coming.
///
/// A skeleton rather than a spinner because it says *what* is loading, and
/// because the page does not jump when the data lands. Static, not shimmering:
/// an animation that never stops is an animation that runs behind every widget
/// test in the suite, and the honesty is in the shape, not the movement.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.rows = 4,
    this.hasLeading = false,
    this.padding = const EdgeInsets.all(FlowSpace.lg),
  });

  final int rows;

  /// Draws a square block on the left of each row, for lists whose real rows
  /// carry an icon or a marker.
  final bool hasLeading;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Memuat data',
        excludeSemantics: true,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rows; i++) ...[
                if (i > 0) const SizedBox(height: FlowSpace.lg),
                _SkeletonRow(hasLeading: hasLeading),
              ],
            ],
          ),
        ),
      );
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.hasLeading});

  final bool hasLeading;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasLeading) ...[
            const SkeletonBlock(width: FlowSpace.xxl, height: FlowSpace.xxl),
            const SizedBox(width: FlowSpace.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Widths as fractions, so the placeholder keeps its proportions
                // at every screen size instead of being sized for a 360 px one.
                const FractionallySizedBox(
                  widthFactor: 0.55,
                  child: SkeletonBlock(height: FlowSpace.md),
                ),
                const SizedBox(height: FlowSpace.sm),
                const FractionallySizedBox(
                  widthFactor: 0.8,
                  child: SkeletonBlock(height: FlowSpace.sm),
                ),
              ],
            ),
          ),
        ],
      );
}

/// One grey block. The unit a skeleton is built from.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({super.key, this.width, required this.height});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.of(context).dataTrack,
          borderRadius: BorderRadius.circular(FlowRadius.sm),
        ),
      );
}

/// Says, without alarm, that what is on screen is not current.
///
/// A strip rather than a takeover: a failed poll must never empty the screen.
/// The last good data keeps rendering underneath, and this only ever adds a
/// line above it saying how old that data is.
class StaleNotice extends StatelessWidget {
  const StaleNotice({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Coba lagi',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);

    return Semantics(
      label: message,
      excludeSemantics: true,
      child: Material(
        color: colors.surfaceElevated,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FlowSpace.lg,
            vertical: FlowSpace.sm,
          ),
          child: Row(
            children: [
              Icon(
                StatusChip.iconFor(StatusTone.unknown),
                size: FlowIconSize.sm,
                color: colors.textMuted,
              ),
              const SizedBox(width: FlowSpace.sm),
              Expanded(
                child: Text(
                  message,
                  style: type.caption.copyWith(color: colors.textSecondary),
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(width: FlowSpace.sm),
                TextButton(onPressed: onRetry, child: Text(retryLabel)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
