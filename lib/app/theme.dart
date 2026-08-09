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

/// The spacing scale. Six sizes and nothing between — the refinement spec
/// §4 asks for consistent rhythm, and picking a value not on this list is
/// how a layout starts drifting.
///
/// Migration is deliberate: existing widgets keep their hardcoded EdgeInsets
/// until each screen's redesign pass touches them. This class exists so new
/// code has somewhere to reach, not to force a repo-wide rename.
abstract final class FlowSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// The type scale, expanded in Fase 2 of the refinement pass to hit
/// spec §14 (body 14–16, page title 22–24, KPI 28–32).
///
/// Rules that survived: **nothing below 11**, one type family, only two
/// weights. Nothing new can be added without an entry here.
abstract final class FlowTextSize {
  /// The hero KPI, when a card wants the number to carry the screen.
  /// Spec §15 recommends 28–32; use this for the primary figure on
  /// operational cards (dashboard hero, alert count).
  static const double figureLarge = 32;

  /// The everyday big number — vehicle counts in the sheet, KPI on
  /// secondary cards.
  static const double figure = 28;

  /// The page's own title. Spec §14 recommends 22–24.
  static const double pageTitle = 24;

  /// A section heading inside a screen. Was 18 pre-fase-2 — the spec
  /// pulls it up.
  static const double screenTitle = 22;

  /// The title of a row in a list, or a card's own name. Left alone;
  /// spec's "card title 14–16" would deflate row density more than
  /// it would clarify.
  static const double rowTitle = 15;

  /// Prominent body — the paragraph a user is meant to actually read.
  /// Spec §14: "do not shrink body text excessively to fit more data."
  static const double bodyLarge = 16;

  /// Everyday body. Was 13 pre-fase-2 — the spec floor is 14.
  static const double body = 14;

  /// Metadata, timestamps, unit labels. The floor.
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
    required this.errorInk,
    required this.errorPill,
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
    errorInk: Color(0xFFB3261E),
    errorPill: PillColors(tint: Color(0xFFF6E5E4), ink: Color(0xFFB3261E)),
  );

  /// Dark operational palette, from refinement spec §12: deep navy background,
  /// elevated slate surfaces, high-contrast text, restrained accents. Not
  /// pure black — pure black on OLED reads as a hole, and every hairline has
  /// to fight for visibility. The card sits one step above the page so a
  /// stacked card reads as a card, and `roadLine` is bright enough to render
  /// on it.
  ///
  /// Text tokens are held to the same 4.5:1 floor as [light]. Measured against
  /// [page] (relative luminance 0.007): `textPrimary` ≈ 15.4:1, `textSecondary`
  /// ≈ 8.2:1, `textFaint` ≈ 5.8:1. `faintInk` stays below the floor on purpose
  /// — it is only for non-text glyphs (drag handles, inactive icons), matching
  /// the same carve-out light mode makes.
  ///
  /// Warga is not affected by this palette: `flavor.dart` pins it to
  /// `ThemeMode.light`. The refinement spec targets the operator console.
  static const dark = FlowSurfaces(
    page: Color(0xFF0E1420),
    card: Color(0xFF172033),
    map: Color(0xFF0A0F19),
    roadLine: Color(0xFF29334A),
    textPrimary: Color(0xFFE6EAF2),
    textSecondary: Color(0xFFA6B0C4),
    textFaint: Color(0xFF8791A6),
    faintInk: Color(0xFF6B7691),
    errorInk: Color(0xFFF3A19E),
    errorPill: PillColors(tint: Color(0xFF3A1F1E), ink: Color(0xFFF3A19E)),
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

  /// Failed sign-in, rejected input — a form telling the user something is
  /// wrong.
  ///
  /// **Not `macet`.** The congestion reds are reserved for congestion, and the
  /// operator console is exactly where that rule is most tempting to break
  /// because the screens are denser. It would also fail on its own terms:
  /// `#D64541` measures 4.09:1 as text on the page, below the 4.5:1 floor.
  /// This is 6.09:1 and visibly a different red.
  final Color errorInk;

  /// [errorInk] as a pill, for connector states that need attention.
  ///
  /// The reference images give connector health the congestion palette —
  /// green `Berjalan`, amber `Terputus`, red `Berhenti`. That cannot be taken
  /// literally: on the dashboard a health mark sits on the same row as a
  /// congestion pill, and a green dot beside a green `Lancar` would make green
  /// mean two different things at once. Health states carry their word plus
  /// this one non-congestion red; the word is what distinguishes them.
  final PillColors errorPill;

  /// Looks the extension up, falling back to the palette that matches the
  /// ambient brightness — a widget rendered outside `flowSenseTheme` still
  /// gets tokens whose contrast is roughly right for its background.
  static FlowSurfaces of(BuildContext context) {
    final extension = Theme.of(context).extension<FlowSurfaces>();
    if (extension != null) return extension;
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

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
    Color? errorInk,
    PillColors? errorPill,
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
        errorInk: errorInk ?? this.errorInk,
        errorPill: errorPill ?? this.errorPill,
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
      errorInk: Color.lerp(errorInk, other.errorInk, t)!,
      errorPill: t < 0.5 ? errorPill : other.errorPill,
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

/// The refinement-spec semantic slots that are **not** congestion
/// (spec §11): AI prediction, emergency, and information.
///
/// Kept in its own extension rather than folded into [FlowSurfaces] because
/// the rule these hues live under is different — [FlowSurfaces] is chrome and
/// text, [CongestionColors] means traffic and *only* traffic, and this
/// extension exists so alerts, AI recommendations, and non-traffic info can
/// have colour without borrowing the congestion palette. A widget that mixes
/// them gets three shades of red side-by-side and a viewer who cannot tell an
/// emergency vehicle from a jam.
///
/// - [prediction] — purple. AI forecast, projected queue, recommendation.
/// - [emergency]  — a red distinct from `macet`. Emergency vehicle, gridlock
///                  risk, intersection failure. Different hue on purpose so
///                  it cannot be read as "the road is red".
/// - [info]       — cyan. System status, hint, neutral notice.
@immutable
class FlowSemantics extends ThemeExtension<FlowSemantics> {
  const FlowSemantics({
    required this.prediction,
    required this.predictionPill,
    required this.emergency,
    required this.emergencyPill,
    required this.info,
    required this.infoPill,
  });

  /// All pill inks pass 4.5:1 on their tint; every base colour passes 4.5:1
  /// as text on [FlowSurfaces.light.page].
  static const light = FlowSemantics(
    prediction: Color(0xFF5A3FCC),
    predictionPill: PillColors(tint: Color(0xFFEBE7FA), ink: Color(0xFF4632A6)),
    emergency: Color(0xFFC1281F),
    emergencyPill: PillColors(tint: Color(0xFFFADEDA), ink: Color(0xFF8F1B14)),
    info: Color(0xFF1568B8),
    infoPill: PillColors(tint: Color(0xFFDFEDFA), ink: Color(0xFF0F4C87)),
  );

  /// Dark counterparts. Base colours are lighter for legibility on the dark
  /// page; pill tints are dark, pill inks light — the inverse of the light
  /// pill, same contrast budget.
  static const dark = FlowSemantics(
    prediction: Color(0xFFA28BF7),
    predictionPill: PillColors(tint: Color(0xFF241B4A), ink: Color(0xFFC4B3FF)),
    emergency: Color(0xFFFF6E68),
    emergencyPill: PillColors(tint: Color(0xFF4A1815), ink: Color(0xFFFFB1AC)),
    info: Color(0xFF5FB0F5),
    infoPill: PillColors(tint: Color(0xFF10304F), ink: Color(0xFFA5D2F8)),
  );

  final Color prediction;
  final PillColors predictionPill;

  /// Not `macet`. This is a different hue and reserved for events that mean
  /// *danger*, not congestion.
  final Color emergency;
  final PillColors emergencyPill;

  final Color info;
  final PillColors infoPill;

  static FlowSemantics of(BuildContext context) {
    final extension = Theme.of(context).extension<FlowSemantics>();
    if (extension != null) return extension;
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  @override
  FlowSemantics copyWith({
    Color? prediction,
    PillColors? predictionPill,
    Color? emergency,
    PillColors? emergencyPill,
    Color? info,
    PillColors? infoPill,
  }) =>
      FlowSemantics(
        prediction: prediction ?? this.prediction,
        predictionPill: predictionPill ?? this.predictionPill,
        emergency: emergency ?? this.emergency,
        emergencyPill: emergencyPill ?? this.emergencyPill,
        info: info ?? this.info,
        infoPill: infoPill ?? this.infoPill,
      );

  @override
  FlowSemantics lerp(ThemeExtension<FlowSemantics>? other, double t) {
    if (other is! FlowSemantics) return this;
    return FlowSemantics(
      prediction: Color.lerp(prediction, other.prediction, t)!,
      predictionPill: t < 0.5 ? predictionPill : other.predictionPill,
      emergency: Color.lerp(emergency, other.emergency, t)!,
      emergencyPill: t < 0.5 ? emergencyPill : other.emergencyPill,
      info: Color.lerp(info, other.info, t)!,
      infoPill: t < 0.5 ? infoPill : other.infoPill,
    );
  }
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
    // 32 — the hero KPI. Reserved for the biggest number on the screen.
    displayLarge: style(FlowTextSize.figureLarge, _medium, primary),
    displayMedium: style(FlowTextSize.figureLarge, _medium, primary),
    // 28 — the everyday big number (sheet counts, secondary KPI).
    displaySmall: style(FlowTextSize.figure, _medium, primary),
    headlineLarge: style(FlowTextSize.figure, _medium, primary),
    headlineMedium: style(FlowTextSize.figure, _medium, primary),
    // 22 — a section heading inside a screen. Migrate to this instead of
    // hand-rolling a 22-px style; `titleMedium` stays a row title.
    headlineSmall: style(FlowTextSize.screenTitle, _medium, primary),
    // 24 — the page's own title (app bar, sheet header).
    titleLarge: style(FlowTextSize.pageTitle, _medium, primary),
    // 15 — row / card titles. Kept at rowTitle rather than promoted to the
    // spec's section-title size: many list rows across the app use this slot,
    // and inflating it would collapse density before the redesign pass gets
    // to reconsider each layout. Screens that want a section header should
    // reach for `headlineSmall`.
    titleMedium: style(FlowTextSize.rowTitle, _medium, primary),
    titleSmall: style(FlowTextSize.rowTitle, _medium, primary),
    // 16 — prominent body (paragraphs the user actually reads).
    bodyLarge: style(FlowTextSize.bodyLarge, _regular, primary),
    // 14 — everyday body. Was 13 pre-fase-2 — spec floor is 14.
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
  final surfaces = isDark ? FlowSurfaces.dark : FlowSurfaces.light;
  final congestion = isDark ? CongestionColors.dark : CongestionColors.light;
  final semantics = isDark ? FlowSemantics.dark : FlowSemantics.light;

  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: brightness,
  ).copyWith(
    surface: surfaces.page,
    onSurface: surfaces.textPrimary,
    onSurfaceVariant: surfaces.textSecondary,
    outlineVariant: surfaces.roadLine,
  );

  final text = _textTheme(surfaces);

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: kFontFamily,
    textTheme: text,
    scaffoldBackgroundColor: surfaces.page,
    extensions: [congestion, surfaces, semantics],
  );

  // Flat and clean: no gradients, no shadows, no glass. Hairline borders only.
  // Applied identically to both brightnesses — the tokens carry the light/dark
  // difference, the widget theming does not need to branch.
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
        // Ink, not the seeded blue. The primary action reads as weight rather
        // than hue, which keeps colour on these screens meaning congestion and
        // nothing else — and `textPrimary` is already in the token table, so
        // this introduces no new value.
        backgroundColor: surfaces.textPrimary,
        foregroundColor: surfaces.card,
        disabledBackgroundColor: surfaces.roadLine,
        disabledForegroundColor: surfaces.textFaint,
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
