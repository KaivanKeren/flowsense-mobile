import 'package:flutter/material.dart';

import '../features/common/relative_time.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// A dot and a sentence: `Diperbarui 8 detik lalu`.
///
/// The dot takes the accent while the feed is current and the muted ink once
/// it is behind — but the **words** are what say so, because a dot that
/// changes colour is a status carried by colour alone.
///
/// Laid out to survive a narrow box. The previous version sat in a fixed-width
/// container and broke `Diperbarui 8 dtk lalu` across two lines inside it; this
/// one stays on one line and ellipsizes, and abbreviates nothing.
class LiveIndicator extends StatelessWidget {
  const LiveIndicator({
    super.key,
    required this.age,
    this.isStale = false,
    this.prefix = 'Diperbarui',
  });

  /// How long ago the freshest record arrived.
  final Duration age;

  /// True once the feed is behind by more than the configured window.
  final bool isStale;

  /// The verb. `Diperbarui` for a live feed; a caller showing cached data
  /// passes `Data tersimpan`.
  final String prefix;

  String get text => '$prefix ${relativeIndonesian(age)}';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);

    return Semantics(
      label: text,
      // The age changes on every poll, and a live region would make a screen
      // reader interrupt itself every few seconds to say so.
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: FlowSpace.sm,
            height: FlowSpace.sm,
            decoration: BoxDecoration(
              color: isStale ? colors.textMuted : colors.accentPrimary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: FlowSpace.sm),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: type.caption,
            ),
          ),
        ],
      ),
    );
  }
}
