import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'status_chip.dart';

/// The strip that says something is in force right now.
///
/// Its loudest use is the emergency override, which is why it takes a
/// [StatusTone] rather than being red by construction: the same shape carries
/// a stale feed and a lost connector, and three separate banner widgets is how
/// they drifted apart before.
///
/// Never colour alone. The tone chooses a tint and a glyph; the [title] is what
/// actually says what happened.
class AlertBanner extends StatelessWidget {
  const AlertBanner({
    super.key,
    required this.title,
    this.detail,
    this.tone = StatusTone.warning,
    this.actionLabel,
    this.onAction,
    this.isLive = false,
  });

  /// An emergency override, in the one tone reserved for it.
  const AlertBanner.emergency({
    super.key,
    required this.title,
    this.detail,
    this.actionLabel,
    this.onAction,
  })  : tone = StatusTone.emergency,
        // An override appearing while somebody is reading the screen is worth
        // interrupting a screen reader for. A stale-data notice is not.
        isLive = true;

  final String title;

  /// The second line: when it started, who set it, what it affects.
  final String? detail;

  final StatusTone tone;

  /// Wording stays in the console's read-only register — `Tinjau`, `Coba
  /// lagi`, `Catat`. Never `Terapkan`.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Announces the banner when it appears.
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);
    final pill = switch (tone) {
      StatusTone.normal => colors.pillNormal,
      StatusTone.warning => colors.pillWarning,
      StatusTone.critical => colors.pillCritical,
      StatusTone.emergency => colors.pillEmergency,
      StatusTone.unknown => colors.pillUnknown,
      StatusTone.neutral => colors.pillUnknown,
    };

    return Semantics(
      liveRegion: isLive,
      label: [title, ?detail].join('. '),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: pill.tint,
          borderRadius: BorderRadius.circular(FlowRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(FlowSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                StatusChip.iconFor(tone),
                size: FlowIconSize.md,
                color: pill.ink,
              ),
              const SizedBox(width: FlowSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: type.sectionTitle.copyWith(color: pill.ink),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: FlowSpace.xs),
                      Text(
                        detail!,
                        style: type.caption.copyWith(color: pill.ink),
                      ),
                    ],
                    // The action sits under the text rather than beside it.
                    // Beside it is what pushed `Coba lagi` off the right edge
                    // at textScale 1.3; under it, the button keeps its full
                    // 48 dp whatever the message length.
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: FlowSpace.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: onAction,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: pill.ink,
                            side: BorderSide(color: pill.ink),
                          ),
                          child: Text(actionLabel!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
