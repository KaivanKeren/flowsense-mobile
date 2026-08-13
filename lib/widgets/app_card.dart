import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/tokens.dart';

/// A panel: one step off the canvas, one hairline border, radius 12.
///
/// This shape was written out six times across the console and the citizen
/// sheet, and the copies had already drifted — three different inner paddings
/// and two different radii for what was meant to be the same object.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(FlowSpace.lg),
    this.onTap,
    this.tone = AppCardTone.plain,
    this.semanticsLabel,
  });

  final Widget child;

  /// Inner padding. Override only for a card whose child draws its own edges —
  /// a list of rows with full-bleed dividers, say.
  final EdgeInsetsGeometry padding;

  /// Makes the whole card a target. Supply [semanticsLabel] with it, or the
  /// screen reader announces the card's contents as one unlabelled button.
  final VoidCallback? onTap;

  final AppCardTone tone;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final (background, border) = switch (tone) {
      AppCardTone.plain => (colors.surfaceCard, colors.borderSubtle),
      AppCardTone.raised => (colors.surfaceElevated, colors.borderSubtle),
      AppCardTone.selected => (colors.surfaceCard, colors.borderStrong),
    };

    final content = Padding(padding: padding, child: child);
    final radius = BorderRadius.circular(FlowRadius.md);

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        border: Border.all(color: border),
      ),
      child: onTap == null
          ? content
          // Material above the decoration rather than under it, so the ripple
          // is clipped to the same radius the border draws.
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: content,
              ),
            ),
    );

    if (semanticsLabel == null) return card;
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      excludeSemantics: true,
      child: card,
    );
  }
}

enum AppCardTone {
  /// The default. A card on the page.
  plain,

  /// A card on top of another card, or a strip that needs to separate itself
  /// from the content it annotates.
  raised,

  /// Currently chosen. Carries a stronger border, never a colour fill — a
  /// filled selection would spend a hue the palette reserves for status.
  selected,
}
