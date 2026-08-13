import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// The heading above a block of content.
///
/// Three near-identical versions of this existed — `_SectionHeader`,
/// `_Section` and `_SectionLabel` — with three different type roles and three
/// different paddings for the same job.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.mono = false,
    this.padding = EdgeInsets.zero,
  });

  final String title;

  /// A qualifier on the right: `urut terparah dulu`, a count, a live
  /// indicator. Wraps beneath the title when the two together do not fit.
  final Widget? trailing;

  /// Sets the title in the console's monospace capitals.
  ///
  /// **Operator only.** The citizen app never passes true: monospace capitals
  /// are the control room's voice, and a public app used partly by elderly
  /// riders should not address them in it.
  final bool mono;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);

    final label = Text(
      mono ? FlowTypography.monoLabel(title) : title,
      style: mono
          ? type.labelMono
          : type.sectionTitle.copyWith(color: colors.textSecondary),
    );

    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        // The uppercased string is decoration. A screen reader handed
        // `PERSIMPANGAN AKTIF` may spell it out letter by letter.
        label: title,
        excludeSemantics: true,
        child: trailing == null
            ? label
            // Wrap rather than Row: at textScale 1.3 in a 320 px column the
            // title and its qualifier stop fitting side by side, and a Row
            // answers that by overflowing. This drops the qualifier to the
            // next line instead.
            : Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: FlowSpace.sm,
                runSpacing: FlowSpace.xs,
                children: [label, trailing!],
              ),
      ),
    );
  }
}
