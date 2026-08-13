/// Type, by the role it plays rather than the size it happens to be.
///
/// A widget asks for `sectionTitle`, never for "15 px medium". That is what
/// lets the whole scale move at once, and what stops the next screen from
/// inventing a sixth size because 15 felt slightly too large that afternoon.
library;

import 'package:flutter/material.dart';

import 'colors.dart';
import 'tokens.dart';

/// The six text roles, resolved against the active palette.
@immutable
class FlowTypography extends ThemeExtension<FlowTypography> {
  const FlowTypography({
    required this.metricLarge,
    required this.metricUnit,
    required this.sectionTitle,
    required this.labelMono,
    required this.body,
    required this.caption,
  });

  /// Builds the roles for [colors].
  factory FlowTypography.of_(AppColors colors) {
    TextStyle base(double size, FontWeight weight, Color color) => TextStyle(
          fontFamily: kFontFamily,
          fontSize: size,
          fontWeight: weight,
          color: color,
          // A ratio, never a fixed pixel line box — otherwise
          // `MediaQuery.textScaler` grows the glyphs inside a box that does not
          // grow with them, and the descenders clip.
          height: 1.35,
        );

    return FlowTypography(
      metricLarge: base(
        FlowTextSize.figure,
        FontWeight.w500,
        colors.textPrimary,
      ).copyWith(
        // Tabular figures so a counter ticking 9 → 10 does not shift the
        // digits beside it. A console full of numbers that jitter on every
        // poll reads as unstable even when the data is fine.
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.1,
      ),
      metricUnit: base(
        FlowTextSize.body,
        FontWeight.w400,
        colors.textSecondary,
      ),
      sectionTitle: base(
        FlowTextSize.rowTitle,
        FontWeight.w500,
        colors.textPrimary,
      ),
      labelMono: TextStyle(
        fontFamilyFallback: kMonoFontFamilyFallback,
        fontSize: FlowTextSize.caption,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
        height: 1.3,
        // Wide tracking is what makes an all-caps monospace label read as a
        // category rather than as shouting.
        letterSpacing: 1.1,
      ),
      body: base(FlowTextSize.body, FontWeight.w400, colors.textPrimary),
      caption: base(
        FlowTextSize.caption,
        FontWeight.w400,
        colors.textSecondary,
      ),
    );
  }

  /// The one big number on a metric card. Tabular figures, tight leading.
  final TextStyle metricLarge;

  /// The unit or qualifier beside [metricLarge] — `kendaraan`, `dtk`, `%`.
  final TextStyle metricUnit;

  /// A section heading inside a screen.
  final TextStyle sectionTitle;

  /// The console's category label: monospace, wide tracking, and **always set
  /// in capitals by the caller** — see [monoLabel].
  ///
  /// This is the operator console's visual signature and it does not belong on
  /// the citizen side. A public app aimed partly at older riders should not
  /// address them in the typography of a control room.
  final TextStyle labelMono;

  final TextStyle body;
  final TextStyle caption;

  static FlowTypography of(BuildContext context) =>
      Theme.of(context).extension<FlowTypography>() ??
      FlowTypography.of_(AppColors.light);

  /// Uppercases [text] for [labelMono].
  ///
  /// A function rather than `TextStyle` trickery: Flutter has no
  /// `text-transform`, and uppercasing at the call site keeps the *accessible*
  /// string lowercase — a screen reader that meets `PERSIMPANGAN AKTIF` may
  /// spell it out letter by letter, so the `Semantics` label must stay
  /// sentence case.
  static String monoLabel(String text) => text.toUpperCase();

  @override
  FlowTypography copyWith({
    TextStyle? metricLarge,
    TextStyle? metricUnit,
    TextStyle? sectionTitle,
    TextStyle? labelMono,
    TextStyle? body,
    TextStyle? caption,
  }) =>
      FlowTypography(
        metricLarge: metricLarge ?? this.metricLarge,
        metricUnit: metricUnit ?? this.metricUnit,
        sectionTitle: sectionTitle ?? this.sectionTitle,
        labelMono: labelMono ?? this.labelMono,
        body: body ?? this.body,
        caption: caption ?? this.caption,
      );

  @override
  FlowTypography lerp(ThemeExtension<FlowTypography>? other, double t) {
    if (other is! FlowTypography) return this;
    return FlowTypography(
      metricLarge: TextStyle.lerp(metricLarge, other.metricLarge, t)!,
      metricUnit: TextStyle.lerp(metricUnit, other.metricUnit, t)!,
      sectionTitle: TextStyle.lerp(sectionTitle, other.sectionTitle, t)!,
      labelMono: TextStyle.lerp(labelMono, other.labelMono, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
    );
  }
}

/// Every Material text slot, stated explicitly.
///
/// Nothing is inherited: Material's defaults reach below 11 and pull in weights
/// the scale does not allow, so each slot is pinned to one of the five
/// permitted sizes.
TextTheme flowTextTheme(AppColors colors) {
  TextStyle style(double size, FontWeight weight, Color color) => TextStyle(
        fontFamily: kFontFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.35,
      );

  const regular = FontWeight.w400;
  const medium = FontWeight.w500;

  final primary = colors.textPrimary;
  final secondary = colors.textSecondary;

  return TextTheme(
    // 28 — the one big number.
    displayLarge: style(FlowTextSize.figure, medium, primary),
    displayMedium: style(FlowTextSize.figure, medium, primary),
    displaySmall: style(FlowTextSize.figure, medium, primary),
    headlineLarge: style(FlowTextSize.figure, medium, primary),
    headlineMedium: style(FlowTextSize.figure, medium, primary),
    // 18 — screen titles.
    headlineSmall: style(FlowTextSize.screenTitle, medium, primary),
    titleLarge: style(FlowTextSize.screenTitle, medium, primary),
    // 15 — row titles.
    titleMedium: style(FlowTextSize.rowTitle, medium, primary),
    titleSmall: style(FlowTextSize.rowTitle, medium, primary),
    // 13 — body.
    bodyLarge: style(FlowTextSize.body, regular, primary),
    bodyMedium: style(FlowTextSize.body, regular, primary),
    labelLarge: style(FlowTextSize.body, medium, primary),
    labelMedium: style(FlowTextSize.body, regular, secondary),
    // 11 — captions. The floor.
    bodySmall: style(FlowTextSize.caption, regular, secondary),
    labelSmall: style(FlowTextSize.caption, regular, secondary),
  );
}
