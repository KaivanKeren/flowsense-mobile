/// The single source of every colour in the app.
///
/// `flowsense-warga-layout.md` states the rule this file exists to enforce:
/// **never write a hex value in a widget.** Everything below is looked up
/// through a [ThemeExtension], so the palette can be checked in one place —
/// and so `git grep` over `lib/features/` finds no colour literals at all.
library;

import 'package:flutter/material.dart';

import '../domain/congestion.dart';

/// Radii, from the layout spec: 8 for controls, 12 for cards, 16 for the top
/// corners of the sheet. There is no fourth value.
abstract final class FlowRadius {
  static const double control = 8;
  static const double card = 12;
  static const double sheet = 16;
}

/// The type scale. Five sizes, and **nothing below 11**.
abstract final class FlowTextSize {
  /// The one big number — vehicle counts in the sheet.
  static const double figure = 28;
  static const double screenTitle = 18;
  static const double rowTitle = 15;
  static const double body = 13;
  static const double caption = 11;
}

/// Surfaces, text inks, and hairlines — everything that is not a congestion
/// colour.
///
/// Kept out of [ColorScheme] because two of these have no honest Material slot:
/// a map backdrop and a hairline are not "surfaceContainerHighest", and naming
/// them properly is what keeps widgets from reaching for an approximation.
@immutable
class FlowSurfaces extends ThemeExtension<FlowSurfaces> {
  const FlowSurfaces({
    required this.page,
    required this.card,
    required this.map,
    required this.roadLine,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.faintInk,
  });

  /// The layout spec's token table, verbatim except for [textFaint].
  ///
  /// The spec lists `Teks samar #9AA0A0`, but that measures 2.48:1 against the
  /// page — and the same document requires **4.5:1 for text**. Both rules are
  /// binding and they disagree, so the tie goes to the one whose failure is
  /// visible to a person: contrast wins, and faint *text* is darkened to the
  /// lightest grey that clears 4.5:1 (4.55 on page, 4.88 on card).
  ///
  /// `#9AA0A0` survives untouched as [faintInk] for everything that is **not**
  /// text — the drag handle, inactive tab icons, the unknown marker fill —
  /// where the ratio rule does not apply and the spec's intent is exact.
  static const light = FlowSurfaces(
    page: Color(0xFFF7F7F5),
    card: Color(0xFFFFFFFF),
    map: Color(0xFFEEF0ED),
    roadLine: Color(0xFFE3E5E2),
    textPrimary: Color(0xFF1A1D1C),
    textSecondary: Color(0xFF6B706E),
    textFaint: Color(0xFF6D7272),
    faintInk: Color(0xFF9AA0A0),
  );

  /// Page background.
  final Color page;

  /// Card and sheet surfaces.
  final Color card;

  /// The map backdrop, and the capsule behind the active navigation tab.
  final Color map;

  /// Hairline dividers and borders. One weight, never a shadow.
  final Color roadLine;

  final Color textPrimary;
  final Color textSecondary;

  /// Faint *text*. See the note on [light] for why this is not `#9AA0A0`.
  final Color textFaint;

  /// `#9AA0A0` for non-text use only: icons, handles, hairline accents.
  final Color faintInk;

  static FlowSurfaces of(BuildContext context) =>
      Theme.of(context).extension<FlowSurfaces>() ?? light;

  @override
  FlowSurfaces copyWith({
    Color? page,
    Color? card,
    Color? map,
    Color? roadLine,
    Color? textPrimary,
    Color? textSecondary,
    Color? textFaint,
    Color? faintInk,
  }) =>
      FlowSurfaces(
        page: page ?? this.page,
        card: card ?? this.card,
        map: map ?? this.map,
        roadLine: roadLine ?? this.roadLine,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textFaint: textFaint ?? this.textFaint,
        faintInk: faintInk ?? this.faintInk,
      );

  @override
  FlowSurfaces lerp(ThemeExtension<FlowSurfaces>? other, double t) {
    if (other is! FlowSurfaces) return this;
    return FlowSurfaces(
      page: Color.lerp(page, other.page, t)!,
      card: Color.lerp(card, other.card, t)!,
      map: Color.lerp(map, other.map, t)!,
      roadLine: Color.lerp(roadLine, other.roadLine, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      faintInk: Color.lerp(faintInk, other.faintInk, t)!,
    );
  }
}

/// A status pill's two colours: a pale tint, and an ink dark enough to read on
/// it.
///
/// The layout spec calls this out by name — *"coloured text on a pale tint is
/// where this rule leaks most often"* — so the inks here are not the level
/// colours. Each is the level colour darkened until it measures at least 4.5:1
/// against its own tint. Raw `#D64541` on its tint is 3.4:1; the shipped ink is
/// 4.52:1.
@immutable
class PillColors {
  const PillColors({required this.tint, required this.ink});

  final Color tint;
  final Color ink;
}

/// The four semantic colours, and nothing else.
///
/// These hues are reserved: they are driven entirely by [CongestionLevel] and
/// are never used for buttons, links, accents, or decorative icons, so colour
/// in this app always means exactly one thing.
@immutable
class CongestionColors extends ThemeExtension<CongestionColors> {
  const CongestionColors({
    required this.lancar,
    required this.padat,
    required this.macet,
    required this.unknown,
    required this.lancarPill,
    required this.padatPill,
    required this.macetPill,
    required this.unknownPill,
  });

  static const light = CongestionColors(
    lancar: Color(0xFF1F9D62),
    padat: Color(0xFFE0A32E),
    macet: Color(0xFFD64541),
    unknown: Color(0xFF9AA0A0),
    lancarPill: PillColors(tint: Color(0xFFE0F1E9), ink: Color(0xFF1B7A4E)),
    padatPill: PillColors(tint: Color(0xFFFBF2E2), ink: Color(0xFF8D6923)),
    macetPill: PillColors(tint: Color(0xFFF9E5E4), ink: Color(0xFFBA3E3A)),
    unknownPill: PillColors(tint: Color(0xFFF1F2F2), ink: Color(0xFF6A6F6E)),
  );

  /// Operator-only. The citizen app is light-only by decision — the layout
  /// spec lists dark mode under "deliberately not built", on the grounds that
  /// it scores nothing and doubles the contrast checking.
  static const dark = CongestionColors(
    lancar: Color(0xFF4FBF88),
    padat: Color(0xFFE9BC63),
    macet: Color(0xFFE8706C),
    unknown: Color(0xFF8B9190),
    lancarPill: PillColors(tint: Color(0xFF17352A), ink: Color(0xFF7FD8AC)),
    padatPill: PillColors(tint: Color(0xFF352C17), ink: Color(0xFFEFCE8C)),
    macetPill: PillColors(tint: Color(0xFF3A1F1E), ink: Color(0xFFF3A19E)),
    unknownPill: PillColors(tint: Color(0xFF2A2D2C), ink: Color(0xFFB3B8B7)),
  );

  final Color lancar;
  final Color padat;
  final Color macet;
  final Color unknown;

  final PillColors lancarPill;
  final PillColors padatPill;
  final PillColors macetPill;
  final PillColors unknownPill;

  Color forLevel(CongestionLevel level) => switch (level) {
        CongestionLevel.lancar => lancar,
        CongestionLevel.padat => padat,
        CongestionLevel.macet => macet,
        CongestionLevel.unknown => unknown,
      };

  PillColors pillFor(CongestionLevel level) => switch (level) {
        CongestionLevel.lancar => lancarPill,
        CongestionLevel.padat => padatPill,
        CongestionLevel.macet => macetPill,
        CongestionLevel.unknown => unknownPill,
      };

  /// Looks the extension up, falling back to [light] so a widget rendered
  /// outside `flowSenseTheme` still gets sane colours instead of throwing.
  static CongestionColors of(BuildContext context) =>
      Theme.of(context).extension<CongestionColors>() ?? light;

  @override
  CongestionColors copyWith({
    Color? lancar,
    Color? padat,
    Color? macet,
    Color? unknown,
    PillColors? lancarPill,
    PillColors? padatPill,
    PillColors? macetPill,
    PillColors? unknownPill,
  }) =>
      CongestionColors(
        lancar: lancar ?? this.lancar,
        padat: padat ?? this.padat,
        macet: macet ?? this.macet,
        unknown: unknown ?? this.unknown,
        lancarPill: lancarPill ?? this.lancarPill,
        padatPill: padatPill ?? this.padatPill,
        macetPill: macetPill ?? this.macetPill,
        unknownPill: unknownPill ?? this.unknownPill,
      );

  @override
  CongestionColors lerp(ThemeExtension<CongestionColors>? other, double t) {
    if (other is! CongestionColors) return this;
    return CongestionColors(
      lancar: Color.lerp(lancar, other.lancar, t)!,
      padat: Color.lerp(padat, other.padat, t)!,
      macet: Color.lerp(macet, other.macet, t)!,
      unknown: Color.lerp(unknown, other.unknown, t)!,
      lancarPill: t < 0.5 ? lancarPill : other.lancarPill,
      padatPill: t < 0.5 ? padatPill : other.padatPill,
      macetPill: t < 0.5 ? macetPill : other.macetPill,
      unknownPill: t < 0.5 ? unknownPill : other.unknownPill,
    );
  }
}

/// Copy is plain Indonesian, sentence case, no exclamation marks, no emoji.
extension CongestionLabel on CongestionLevel {
  String get label => switch (this) {
        CongestionLevel.lancar => 'Lancar',
        CongestionLevel.padat => 'Padat',
        CongestionLevel.macet => 'Macet',
        CongestionLevel.unknown => 'Tidak ada data',
      };
}

/// What the status pill says.
///
/// Staleness outranks the level, and deliberately so: a `macet` reading from
/// four minutes ago is not a jam, it is a silence. `Data basi` says the feed
/// stopped; `Tidak ada data` says none ever arrived. Conflating the two would
/// hide a dead connector behind a colour.
String statusLabel(CongestionLevel level, {required bool isStale}) =>
    isStale ? 'Data basi' : level.label;

/// The font, bundled in `assets/fonts/`. Two weights exist and no more.
const String kFontFamily = 'Plus Jakarta Sans';

const FontWeight _regular = FontWeight.w400;
const FontWeight _medium = FontWeight.w500;

/// Every text slot, stated explicitly.
///
/// Material's defaults reach down to 11 and below and pull in weights the spec
/// does not allow, so nothing is inherited — each slot is pinned to one of the
/// five permitted sizes. Heights are ratios, never fixed pixel line boxes, so
/// `MediaQuery.textScaler` can do its job.
TextTheme _textTheme(FlowSurfaces surfaces) {
  TextStyle style(double size, FontWeight weight, Color color) => TextStyle(
        fontFamily: kFontFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.35,
      );

  final primary = surfaces.textPrimary;
  final secondary = surfaces.textSecondary;

  return TextTheme(
    // 28 — the one big number.
    displayLarge: style(FlowTextSize.figure, _medium, primary),
    displayMedium: style(FlowTextSize.figure, _medium, primary),
    displaySmall: style(FlowTextSize.figure, _medium, primary),
    headlineLarge: style(FlowTextSize.figure, _medium, primary),
    headlineMedium: style(FlowTextSize.figure, _medium, primary),
    // 18 — screen titles.
    headlineSmall: style(FlowTextSize.screenTitle, _medium, primary),
    titleLarge: style(FlowTextSize.screenTitle, _medium, primary),
    // 15 — row titles.
    titleMedium: style(FlowTextSize.rowTitle, _medium, primary),
    titleSmall: style(FlowTextSize.rowTitle, _medium, primary),
    // 13 — body.
    bodyLarge: style(FlowTextSize.body, _regular, primary),
    bodyMedium: style(FlowTextSize.body, _regular, primary),
    labelLarge: style(FlowTextSize.body, _medium, primary),
    labelMedium: style(FlowTextSize.body, _regular, secondary),
    // 11 — captions. The floor.
    bodySmall: style(FlowTextSize.caption, _regular, secondary),
    labelSmall: style(FlowTextSize.caption, _regular, secondary),
  );
}

/// Seeded blue for chrome, deliberately far from the three congestion hues —
/// so a button can never be mistaken for a traffic state.
const _seed = Color(0xFF1565C0);

ThemeData flowSenseTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final surfaces = FlowSurfaces.light;
  final congestion = isDark ? CongestionColors.dark : CongestionColors.light;

  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
  ).copyWith(
    surface: isDark ? null : surfaces.page,
    onSurface: isDark ? null : surfaces.textPrimary,
    onSurfaceVariant: isDark ? null : surfaces.textSecondary,
    outlineVariant: isDark ? null : surfaces.roadLine,
  );

  final text = isDark
      ? ThemeData(brightness: Brightness.dark).textTheme
      : _textTheme(surfaces);

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: isDark ? null : kFontFamily,
    textTheme: text,
    scaffoldBackgroundColor: isDark ? null : surfaces.page,
    extensions: [congestion, surfaces],
  );

  if (isDark) return base;

  // Flat and clean: no gradients, no shadows, no glass. Hairline borders only.
  return base.copyWith(
    dividerTheme: DividerThemeData(
      color: surfaces.roadLine,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surfaces.page,
      surfaceTintColor: Colors.transparent,
      foregroundColor: surfaces.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: surfaces.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FlowRadius.card),
        side: BorderSide(color: surfaces.roadLine),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surfaces.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(FlowRadius.sheet),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlowRadius.control),
        ),
        minimumSize: const Size(0, 44), // the 44 px touch floor
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        elevation: 0,
        textStyle: text.labelLarge,
        foregroundColor: surfaces.textPrimary,
        side: BorderSide(color: surfaces.roadLine),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlowRadius.control),
        ),
        minimumSize: const Size(0, 44),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: text.labelLarge,
        minimumSize: const Size(0, 44),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStatePropertyAll(surfaces.roadLine),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: text.titleMedium,
      subtitleTextStyle: text.bodySmall,
      iconColor: surfaces.textSecondary,
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
