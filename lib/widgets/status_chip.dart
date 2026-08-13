import 'package:flutter/material.dart';

import '../domain/congestion.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// What a chip is reporting. Named for the meaning, not the colour.
enum StatusTone {
  /// Traffic moving, a connector running, a check that passed.
  normal,

  /// Building up, or something that will need attention soon.
  warning,

  /// Jammed, or stopped.
  critical,

  /// An emergency override is in force. A separate tone from [critical]
  /// because a jam is a road condition and an override is a human decision.
  emergency,

  /// No reading. **Never rendered as [normal]** — absence of data is not a
  /// clear road, and that is the most dangerous mistake this app could make.
  unknown,

  /// Not a status at all: a filter value, a mode, a count. Neutral ink, no
  /// claim about how things are going.
  neutral,
}

/// `Lancar` / `Padat` / `Macet` / `Data basi`, and the console's system states,
/// as one chip.
///
/// **The status is never carried by colour alone.** Every chip shows its word,
/// and unless the caller turns it off, an icon beside it. Red and green are the
/// two hues this app leans on hardest, red-green colour blindness is precisely
/// the relevant case for a traffic app, and — as
/// `test/theme/contrast_test.dart` records — no palette can separate a red from
/// a grey at matched contrast. The word is the signal; the tint reinforces it.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.tone,
    this.showIcon = true,
    this.semanticsPrefix,
  });

  /// A congestion level, with staleness outranking it.
  ///
  /// A stale reading takes the [StatusTone.unknown] grey whatever the level
  /// said. Dimming the real hue instead would leave a washed-out red still
  /// reading as red.
  factory StatusChip.congestion({
    Key? key,
    required CongestionLevel level,
    required bool isStale,
    bool showIcon = true,
    String? semanticsPrefix = 'Status simpang',
  }) =>
      StatusChip(
        key: key,
        label: statusLabel(level, isStale: isStale),
        tone: isStale ? StatusTone.unknown : toneForLevel(level),
        showIcon: showIcon,
        semanticsPrefix: semanticsPrefix,
      );

  /// The word. Always shown — this is the chip's primary signal.
  final String label;

  final StatusTone tone;

  /// Drops the glyph for a row too narrow to hold it. The word stays, so the
  /// chip is still readable without colour.
  final bool showIcon;

  /// Turns `Macet` into `Status simpang: macet` for a screen reader. Null
  /// leaves the bare label, for chips whose surrounding `Semantics` already
  /// says what it is.
  final String? semanticsPrefix;

  static StatusTone toneForLevel(CongestionLevel level) => switch (level) {
        CongestionLevel.lancar => StatusTone.normal,
        CongestionLevel.padat => StatusTone.warning,
        CongestionLevel.macet => StatusTone.critical,
        CongestionLevel.unknown => StatusTone.unknown,
      };

  /// The glyph for [tone].
  ///
  /// Chosen so the four shapes differ in silhouette, not only in fill — a
  /// circle, a triangle, an octagon-ish exclamation and a question mark stay
  /// distinct at 16 px and in greyscale.
  static IconData iconFor(StatusTone tone) => switch (tone) {
        StatusTone.normal => Icons.check_circle_outline,
        StatusTone.warning => Icons.warning_amber_rounded,
        StatusTone.critical => Icons.error_outline,
        StatusTone.emergency => Icons.campaign_outlined,
        StatusTone.unknown => Icons.help_outline,
        StatusTone.neutral => Icons.remove,
      };

  static PillColors _pillFor(AppColors colors, StatusTone tone) =>
      switch (tone) {
        StatusTone.normal => colors.pillNormal,
        StatusTone.warning => colors.pillWarning,
        StatusTone.critical => colors.pillCritical,
        StatusTone.emergency => colors.pillEmergency,
        StatusTone.unknown => colors.pillUnknown,
        StatusTone.neutral => colors.pillUnknown,
      };

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final type = FlowTypography.of(context);
    final pill = _pillFor(colors, tone);

    return Semantics(
      label: semanticsPrefix == null
          ? label
          : '$semanticsPrefix: ${label.toLowerCase()}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: pill.tint,
          borderRadius: BorderRadius.circular(FlowRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FlowSpace.sm,
            vertical: FlowSpace.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showIcon && tone != StatusTone.neutral) ...[
                Icon(iconFor(tone), size: FlowIconSize.sm, color: pill.ink),
                const SizedBox(width: FlowSpace.xs),
              ],
              // Flexible, so a long label inside a narrow row ellipsizes
              // rather than pushing the chip past its parent. `softWrap:
              // false` keeps it on one line: a two-line chip is what "Data
              // basi" looked like before, split across a 40 px box.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: type.caption.copyWith(
                    color: pill.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small filled dot in the status colour, for rows a full chip would crowd.
///
/// **Never used alone.** Every call site pairs it with a name and a `Semantics`
/// label that spells the status out — the dot is a locator, not the message.
class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    required this.tone,
    this.size = FlowSpace.sm,
  });

  StatusDot.congestion({
    super.key,
    required CongestionLevel level,
    required bool isStale,
    this.size = FlowSpace.sm,
  }) : tone = isStale
            ? StatusTone.unknown
            : StatusChip.toneForLevel(level);

  final StatusTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = switch (tone) {
      StatusTone.normal => colors.statusNormal,
      StatusTone.warning => colors.statusWarning,
      StatusTone.critical => colors.statusCritical,
      StatusTone.emergency => colors.statusEmergency,
      StatusTone.unknown => colors.statusUnknown,
      StatusTone.neutral => colors.textMuted,
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
