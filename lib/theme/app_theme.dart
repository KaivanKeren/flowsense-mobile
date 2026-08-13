/// Assembles the token table into a [ThemeData].
library;

import 'package:flutter/material.dart';

import 'colors.dart';
import 'tokens.dart';
import 'typography.dart';

/// Seeded blue for the parts of Material that insist on a primary, kept far
/// from the three congestion hues so a stock control can never be mistaken for
/// a traffic state. Nothing in this app draws it on purpose.
const Color _seed = Color(0xFF1565C0);

/// The app's theme for [brightness].
///
/// Flat throughout: no gradients, no shadows, no glass. Separation comes from
/// one hairline weight and one step of surface lightness, which is what makes
/// the console read as an instrument rather than a marketing page.
ThemeData flowSenseTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final colors = isDark ? AppColors.dark : AppColors.light;
  final surfaces = isDark ? FlowSurfaces.dark : FlowSurfaces.light;
  final congestion = isDark ? CongestionColors.dark : CongestionColors.light;
  final type = FlowTypography.of_(colors);
  final text = flowTextTheme(colors);

  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
  ).copyWith(
    surface: colors.surfaceCanvas,
    onSurface: colors.textPrimary,
    surfaceContainer: colors.surfaceCard,
    surfaceContainerHighest: colors.surfaceElevated,
    onSurfaceVariant: colors.textSecondary,
    outline: colors.borderStrong,
    outlineVariant: colors.borderSubtle,
    // The scheme's own error red would be a fifth red on a screen that already
    // rations four.
    error: colors.statusEmergency,
    onError: colors.textOnAccent,
    // `secondaryContainer` is what the demo badge sits on.
    secondaryContainer: colors.pillAccent.tint,
    onSecondaryContainer: colors.pillAccent.ink,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: kFontFamily,
    textTheme: text,
    scaffoldBackgroundColor: colors.surfaceCanvas,
    extensions: [colors, type, congestion, surfaces],
  );

  return base.copyWith(
    dividerTheme: DividerThemeData(
      color: colors.borderSubtle,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surfaceCanvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: colors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: colors.surfaceCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FlowRadius.md),
        side: BorderSide(color: colors.borderSubtle),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surfaceCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(FlowRadius.lg),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceCard,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        // Ink, not the seeded blue. The primary action reads as weight rather
        // than hue, which keeps colour on these screens meaning congestion and
        // nothing else.
        backgroundColor: colors.textPrimary,
        foregroundColor: colors.surfaceCanvas,
        disabledBackgroundColor: colors.borderSubtle,
        disabledForegroundColor: colors.textMuted,
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlowRadius.sm),
        ),
        minimumSize: const Size(0, FlowTouch.minTarget),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        elevation: 0,
        textStyle: text.labelLarge,
        foregroundColor: colors.textPrimary,
        side: BorderSide(color: colors.borderStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlowRadius.sm),
        ),
        minimumSize: const Size(0, FlowTouch.minTarget),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: text.labelLarge,
        foregroundColor: colors.accentPrimary,
        minimumSize: const Size(0, FlowTouch.minTarget),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: colors.textSecondary,
        minimumSize: const Size(FlowTouch.minTarget, FlowTouch.minTarget),
      ),
    ),
    iconTheme: IconThemeData(color: colors.textSecondary, size: FlowIconSize.md),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStatePropertyAll(colors.borderStrong),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: text.titleMedium,
      subtitleTextStyle: text.bodySmall,
      iconColor: colors.textSecondary,
      minTileHeight: FlowTouch.minTarget,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.accentPrimary,
      linearTrackColor: colors.dataTrack,
      circularTrackColor: colors.dataTrack,
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
