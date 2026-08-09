import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'relative_time.dart';

/// A tiny "data as of X ago" chip with a coloured dot for status.
///
/// Spec §21: data freshness is a first-class UI concern in operational tools.
/// The reader shouldn't have to trust that what's on screen is current —
/// there should be a visible timestamp with a status glyph. This is that.
///
/// The stamp does **not** duplicate [StaleBanner]: the banner explains that a
/// fetch failed and the screen is behind; this stamp only reports how old the
/// current data is, whatever the reason. They can coexist — a stale banner
/// above a card whose stamp still shows the last poll's age.
enum FreshnessLevel {
  /// Poll came back on time.
  fresh,

  /// Older than the freshness window but not offline. The screen may still
  /// be useful for context.
  stale,

  /// No connection, or the connector reports it hasn't seen the source in
  /// long enough to be trusted.
  offline,
}

class FreshnessStamp extends StatelessWidget {
  const FreshnessStamp({
    super.key,
    required this.age,
    this.level = FreshnessLevel.fresh,
    this.prefix = 'Diperbarui',
  });

  /// How long ago the data on screen was captured. Formatted through
  /// [relativeIndonesian], so a negative age reads as `baru saja`.
  final Duration age;

  final FreshnessLevel level;

  /// The word before the age. Defaults to `Diperbarui`; a caller can pass
  /// `Terakhir dilihat` when the meaning is different.
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final surfaces = FlowSurfaces.of(context);
    final text = Theme.of(context).textTheme;
    final dotColor = _dotColor(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$prefix ${relativeIndonesian(age)}',
          style: text.bodySmall?.copyWith(color: surfaces.textSecondary),
        ),
      ],
    );
  }

  Color _dotColor(BuildContext context) {
    final congestion = CongestionColors.of(context);
    final surfaces = FlowSurfaces.of(context);
    return switch (level) {
      FreshnessLevel.fresh => congestion.lancar,
      FreshnessLevel.stale => congestion.padat,
      // Not `macet`: an offline feed is not a jam. The neutral error ink
      // reads as "something is wrong" without borrowing the congestion red.
      FreshnessLevel.offline => surfaces.errorInk,
    };
  }
}
