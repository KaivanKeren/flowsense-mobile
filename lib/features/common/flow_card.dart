import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Three flavours of card, matching the spec §9 hierarchy so the eye lands on
/// the right thing without reading the copy.
///
/// - [FlowCard.critical]    — an emergency, gridlock, intersection failure.
///                            2 px `semantics.emergency` border, extra padding.
/// - [FlowCard.operational] — the everyday card: traffic condition, queue,
///                            AI prediction. Hairline `roadLine` border,
///                            same shape the `CardTheme` uses.
/// - [FlowCard.supporting]  — historical stats, secondary metadata. No border,
///                            sits on the page surface so it reads as
///                            subordinate to the operational cards around it.
///
/// Not `Card`: Material's [Card] carries an elevation/tint story the app
/// deliberately doesn't use (flat, no shadow, no glass — see `flowSenseTheme`).
/// This widget is a thin surface + border wrapper that guarantees the three
/// levels never drift.
class FlowCard extends StatelessWidget {
  const FlowCard.critical({
    super.key,
    this.title,
    this.leading,
    this.trailing,
    this.onTap,
    required this.child,
  }) : _level = _Level.critical;

  const FlowCard.operational({
    super.key,
    this.title,
    this.leading,
    this.trailing,
    this.onTap,
    required this.child,
  }) : _level = _Level.operational;

  const FlowCard.supporting({
    super.key,
    this.title,
    this.leading,
    this.trailing,
    this.onTap,
    required this.child,
  }) : _level = _Level.supporting;

  final _Level _level;
  final String? title;

  /// Usually an icon. Rendered left of the title.
  final Widget? leading;

  /// Usually a status pill or timestamp. Rendered right of the title.
  final Widget? trailing;

  final VoidCallback? onTap;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final semantics = FlowSemantics.of(context);
    final text = Theme.of(context).textTheme;

    final (border, background, padding) = switch (_level) {
      _Level.critical => (
          Border.all(color: semantics.emergency, width: 2),
          surfaces.card,
          const EdgeInsets.all(16),
        ),
      _Level.operational => (
          Border.all(color: surfaces.roadLine),
          surfaces.card,
          const EdgeInsets.all(12),
        ),
      _Level.supporting => (
          const Border.fromBorderSide(BorderSide.none),
          surfaces.page,
          const EdgeInsets.all(12),
        ),
    };

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null || leading != null || trailing != null) ...[
          Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 10),
              ],
              if (title != null)
                Expanded(child: Text(title!, style: text.titleMedium)),
              if (trailing != null) ...[
                if (title == null) const Spacer(),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 10),
        ],
        child,
      ],
    );

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: border,
        borderRadius: BorderRadius.circular(FlowRadius.card),
      ),
      child: Padding(padding: padding, child: body),
    );

    if (onTap == null) return decorated;

    // The tap ring rides above the border, so the border stays visible while
    // the ink runs — same shape, so nothing bleeds outside the card.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FlowRadius.card),
        child: decorated,
      ),
    );
  }
}

enum _Level { critical, operational, supporting }
