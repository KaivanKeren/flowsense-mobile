/// The single source of every colour in the app, in both themes.
///
/// **Never write a hex value in a widget.** Everything below is looked up
/// through a [ThemeExtension], so the palette can be checked in one place — and
/// so `git grep` over `lib/features/` and `lib/widgets/` finds no colour
/// literals at all. `test/app/palette_discipline_test.dart` enforces that on
/// every commit.
///
/// Tokens are named for their **role**, never their hue. `accentPrimary`, not
/// `cyan`; `statusCritical`, not `red`. That is what makes a light theme
/// possible: the dark console's cyan is `#3FD8CE`, the light theme's is the
/// teal `#0B6E70`, and no widget has to know they differ.
library;

import 'package:flutter/material.dart';

import '../domain/congestion.dart';

// ---------------------------------------------------------------------------
// The raw values. Declared once each, referenced by every token below.
// ---------------------------------------------------------------------------

// -- Dark: the operations console. Near-black canvas, cyan accent. -----------

const Color _dCanvas = Color(0xFF0A0E0D);
const Color _dCard = Color(0xFF141918);
const Color _dElevated = Color(0xFF1E2423);
const Color _dBorderSubtle = Color(0xFF2C3432);
const Color _dBorderStrong = Color(0xFF414A48);

const Color _dTextPrimary = Color(0xFFF1F5F4);
const Color _dTextSecondary = Color(0xFFA9B2B0);
const Color _dTextMuted = Color(0xFF8B9391);

const Color _dAccent = Color(0xFF3FD8CE);
const Color _dOnAccent = Color(0xFF04211F);

const Color _dStatusNormal = Color(0xFF4FBF88);
const Color _dStatusWarning = Color(0xFFE9BC63);
const Color _dStatusCritical = Color(0xFFE8706C);
const Color _dStatusEmergency = Color(0xFFFF5F5A);
const Color _dStatusUnknown = Color(0xFF8B9190);

const Color _dDataInk = Color(0xFFC7D0CE);
const Color _dDataTrack = Color(0xFF232A29);

// -- Light: calmer, and not the dark theme inverted. -------------------------
//
// A neon cyan moved onto white measures 1.4:1 and disappears. Every accent and
// status hue below is the dark theme's role darkened until it clears its own
// floor — 4.5:1 for text, 3:1 for a graphic mark. `theme_contrast_test.dart`
// checks each one rather than trusting this comment.

const Color _lCanvas = Color(0xFFF7F7F5);
const Color _lCard = Color(0xFFFFFFFF);
const Color _lElevated = Color(0xFFEEF0ED);
const Color _lBorderSubtle = Color(0xFFE3E5E2);
const Color _lBorderStrong = Color(0xFFC4C9C6);

const Color _lTextPrimary = Color(0xFF1A1D1C);

/// Was `#6B706E`. That cleared 4.5:1 on the page and the card but measured
/// 4.40:1 on `surfaceElevated`, and a token that fails on one of its own
/// surfaces is a trap for whoever uses it there next.
const Color _lTextSecondary = Color(0xFF666B69);

/// Was `#6D7272`, and failed on `surfaceElevated` for the same reason.
const Color _lTextMuted = Color(0xFF676C6C);

const Color _lAccent = Color(0xFF0B6E70);
const Color _lOnAccent = Color(0xFFFFFFFF);

const Color _lStatusNormal = Color(0xFF1F9D62);

/// Was `#E0A32E`. Amber on white is the classic contrast failure: that value
/// measures 2.07:1 against the page, so a `padat` bar was a graphic element
/// nobody with low vision could locate. Darkened until it clears 3:1 (3.35).
const Color _lStatusWarning = Color(0xFFB57C0A);

const Color _lStatusCritical = Color(0xFFD64541);
const Color _lStatusEmergency = Color(0xFFB3261E);

/// Was `#9AA0A0`, which measured 2.48:1 — the "no data" marker was the hardest
/// mark on the map to see, which is exactly backwards.
const Color _lStatusUnknown = Color(0xFF828888);

const Color _lDataInk = Color(0xFF3A403E);
const Color _lDataTrack = Color(0xFFE3E5E2);

// ---------------------------------------------------------------------------

/// A status surface's two colours: a pale tint, and an ink dark enough to read
/// on it.
///
/// Coloured text on a pale tint is where the contrast rule leaks most often, so
/// the inks here are **not** the status colours. Each is that hue pushed until
/// it measures at least 4.5:1 against its own tint. Raw `#D64541` on its tint is
/// 3.4:1; the shipped ink is 4.52:1.
@immutable
class PillColors {
  const PillColors({required this.tint, required this.ink});

  final Color tint;
  final Color ink;

  static PillColors lerp(PillColors a, PillColors b, double t) => PillColors(
        tint: Color.lerp(a.tint, b.tint, t)!,
        ink: Color.lerp(a.ink, b.ink, t)!,
      );
}

/// The semantic token table. One object, two variants, every colour the app is
/// allowed to draw.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.surfaceCanvas,
    required this.surfaceCard,
    required this.surfaceElevated,
    required this.borderSubtle,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accentPrimary,
    required this.textOnAccent,
    required this.statusNormal,
    required this.statusWarning,
    required this.statusCritical,
    required this.statusEmergency,
    required this.statusUnknown,
    required this.pillNormal,
    required this.pillWarning,
    required this.pillCritical,
    required this.pillEmergency,
    required this.pillUnknown,
    required this.pillAccent,
    required this.dataInk,
    required this.dataTrack,
  });

  /// The console: near-black canvas, cards a step lighter, cyan accent.
  static const dark = AppColors(
    brightness: Brightness.dark,
    surfaceCanvas: _dCanvas,
    surfaceCard: _dCard,
    surfaceElevated: _dElevated,
    borderSubtle: _dBorderSubtle,
    borderStrong: _dBorderStrong,
    textPrimary: _dTextPrimary,
    textSecondary: _dTextSecondary,
    textMuted: _dTextMuted,
    accentPrimary: _dAccent,
    textOnAccent: _dOnAccent,
    statusNormal: _dStatusNormal,
    statusWarning: _dStatusWarning,
    statusCritical: _dStatusCritical,
    statusEmergency: _dStatusEmergency,
    statusUnknown: _dStatusUnknown,
    pillNormal: PillColors(tint: Color(0xFF17352A), ink: Color(0xFF7FD8AC)),
    pillWarning: PillColors(tint: Color(0xFF352C17), ink: Color(0xFFEFCE8C)),
    pillCritical: PillColors(tint: Color(0xFF3A1F1E), ink: Color(0xFFF3A19E)),
    pillEmergency: PillColors(tint: Color(0xFF3D1A1C), ink: Color(0xFFFF9C99)),
    pillUnknown: PillColors(tint: Color(0xFF2A2D2C), ink: Color(0xFFB3B8B7)),
    pillAccent: PillColors(tint: Color(0xFF0F2C2B), ink: Color(0xFF5FE3D9)),
    dataInk: _dDataInk,
    dataTrack: _dDataTrack,
  );

  /// The public app, and the console for anyone who prefers a light screen.
  static const light = AppColors(
    brightness: Brightness.light,
    surfaceCanvas: _lCanvas,
    surfaceCard: _lCard,
    surfaceElevated: _lElevated,
    borderSubtle: _lBorderSubtle,
    borderStrong: _lBorderStrong,
    textPrimary: _lTextPrimary,
    textSecondary: _lTextSecondary,
    textMuted: _lTextMuted,
    accentPrimary: _lAccent,
    textOnAccent: _lOnAccent,
    statusNormal: _lStatusNormal,
    statusWarning: _lStatusWarning,
    statusCritical: _lStatusCritical,
    statusEmergency: _lStatusEmergency,
    statusUnknown: _lStatusUnknown,
    pillNormal: PillColors(tint: Color(0xFFE0F1E9), ink: Color(0xFF1B7A4E)),
    pillWarning: PillColors(tint: Color(0xFFFBF2E2), ink: Color(0xFF8D6923)),
    pillCritical: PillColors(tint: Color(0xFFF9E5E4), ink: Color(0xFFBA3E3A)),
    pillEmergency: PillColors(tint: Color(0xFFF6E5E4), ink: Color(0xFFB3261E)),
    pillUnknown: PillColors(tint: Color(0xFFF1F2F2), ink: Color(0xFF6A6F6E)),
    pillAccent: PillColors(tint: Color(0xFFDEEFEF), ink: Color(0xFF0B6E70)),
    dataInk: _lDataInk,
    dataTrack: _lDataTrack,
  );

  /// Which variant this is. Lets a widget branch on the theme without asking
  /// `Theme.of(context)` a second question.
  final Brightness brightness;

  /// The page behind everything.
  final Color surfaceCanvas;

  /// Cards and panels: one step off the canvas, never a shadow.
  final Color surfaceCard;

  /// A surface that sits above a card — the active tab capsule, a banner strip,
  /// the map backdrop.
  final Color surfaceElevated;

  /// Hairline dividers and card borders. One weight.
  final Color borderSubtle;

  /// A border that has to be seen: focus rings, the selected chip.
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;

  /// The least important text on the page. Still clears 4.5:1 on all three
  /// surfaces — "muted" is a rank, not a licence to be unreadable.
  final Color textMuted;

  /// The one non-status accent. Interactive affordances and the live
  /// indicator, never a traffic state.
  final Color accentPrimary;

  /// Text and icons drawn *on* [accentPrimary].
  final Color textOnAccent;

  /// `lancar` — traffic moving.
  final Color statusNormal;

  /// `padat` — building up.
  final Color statusWarning;

  /// `macet` — jammed.
  final Color statusCritical;

  /// An emergency override is in force. A different red from
  /// [statusCritical] on purpose: a jam is a road condition, an override is a
  /// human decision, and they must not read as the same event. Neither is ever
  /// carried by colour alone.
  final Color statusEmergency;

  /// No reading at all. Never [statusNormal] — absence of data is not a clear
  /// road, and that is the most dangerous mistake this app could make.
  final Color statusUnknown;

  final PillColors pillNormal;
  final PillColors pillWarning;
  final PillColors pillCritical;
  final PillColors pillEmergency;
  final PillColors pillUnknown;
  final PillColors pillAccent;

  /// The ink for numeric data marks that carry no status: a volume trend, the
  /// filled part of a neutral bar, a sparkline.
  final Color dataInk;

  /// The unfilled part of a bar or gauge.
  final Color dataTrack;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  /// The colour for [level], as a graphic mark.
  Color forLevel(CongestionLevel level) => switch (level) {
        CongestionLevel.lancar => statusNormal,
        CongestionLevel.padat => statusWarning,
        CongestionLevel.macet => statusCritical,
        CongestionLevel.unknown => statusUnknown,
      };

  /// The tint/ink pair for [level], as a chip.
  PillColors pillFor(CongestionLevel level) => switch (level) {
        CongestionLevel.lancar => pillNormal,
        CongestionLevel.padat => pillWarning,
        CongestionLevel.macet => pillCritical,
        CongestionLevel.unknown => pillUnknown,
      };

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? surfaceCanvas,
    Color? surfaceCard,
    Color? surfaceElevated,
    Color? borderSubtle,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accentPrimary,
    Color? textOnAccent,
    Color? statusNormal,
    Color? statusWarning,
    Color? statusCritical,
    Color? statusEmergency,
    Color? statusUnknown,
    PillColors? pillNormal,
    PillColors? pillWarning,
    PillColors? pillCritical,
    PillColors? pillEmergency,
    PillColors? pillUnknown,
    PillColors? pillAccent,
    Color? dataInk,
    Color? dataTrack,
  }) =>
      AppColors(
        brightness: brightness ?? this.brightness,
        surfaceCanvas: surfaceCanvas ?? this.surfaceCanvas,
        surfaceCard: surfaceCard ?? this.surfaceCard,
        surfaceElevated: surfaceElevated ?? this.surfaceElevated,
        borderSubtle: borderSubtle ?? this.borderSubtle,
        borderStrong: borderStrong ?? this.borderStrong,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        accentPrimary: accentPrimary ?? this.accentPrimary,
        textOnAccent: textOnAccent ?? this.textOnAccent,
        statusNormal: statusNormal ?? this.statusNormal,
        statusWarning: statusWarning ?? this.statusWarning,
        statusCritical: statusCritical ?? this.statusCritical,
        statusEmergency: statusEmergency ?? this.statusEmergency,
        statusUnknown: statusUnknown ?? this.statusUnknown,
        pillNormal: pillNormal ?? this.pillNormal,
        pillWarning: pillWarning ?? this.pillWarning,
        pillCritical: pillCritical ?? this.pillCritical,
        pillEmergency: pillEmergency ?? this.pillEmergency,
        pillUnknown: pillUnknown ?? this.pillUnknown,
        pillAccent: pillAccent ?? this.pillAccent,
        dataInk: dataInk ?? this.dataInk,
        dataTrack: dataTrack ?? this.dataTrack,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      surfaceCanvas: Color.lerp(surfaceCanvas, other.surfaceCanvas, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      textOnAccent: Color.lerp(textOnAccent, other.textOnAccent, t)!,
      statusNormal: Color.lerp(statusNormal, other.statusNormal, t)!,
      statusWarning: Color.lerp(statusWarning, other.statusWarning, t)!,
      statusCritical: Color.lerp(statusCritical, other.statusCritical, t)!,
      statusEmergency: Color.lerp(statusEmergency, other.statusEmergency, t)!,
      statusUnknown: Color.lerp(statusUnknown, other.statusUnknown, t)!,
      pillNormal: PillColors.lerp(pillNormal, other.pillNormal, t),
      pillWarning: PillColors.lerp(pillWarning, other.pillWarning, t),
      pillCritical: PillColors.lerp(pillCritical, other.pillCritical, t),
      pillEmergency: PillColors.lerp(pillEmergency, other.pillEmergency, t),
      pillUnknown: PillColors.lerp(pillUnknown, other.pillUnknown, t),
      pillAccent: PillColors.lerp(pillAccent, other.pillAccent, t),
      dataInk: Color.lerp(dataInk, other.dataInk, t)!,
      dataTrack: Color.lerp(dataTrack, other.dataTrack, t)!,
    );
  }
}

// ---------------------------------------------------------------------------
// The pre-refactor extensions, now views onto the token table above.
//
// They survive because roughly sixty widgets and four hundred tests name them.
// They hold **no colours of their own** — every field below points at one of
// the raw values, so there is still exactly one place a hue is decided.
// ---------------------------------------------------------------------------

/// Surfaces, text inks, and hairlines.
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

  static const light = FlowSurfaces(
    page: _lCanvas,
    card: _lCard,
    map: _lElevated,
    roadLine: _lBorderSubtle,
    textPrimary: _lTextPrimary,
    textSecondary: _lTextSecondary,
    textFaint: _lTextMuted,
    faintInk: _lStatusUnknown,
    errorInk: _lStatusEmergency,
    errorPill: PillColors(tint: Color(0xFFF6E5E4), ink: _lStatusEmergency),
  );

  /// The console variant.
  ///
  /// This did not exist before, and its absence was a real defect rather than
  /// a gap: `flowSenseTheme(brightness: dark)` installed the *light* surfaces
  /// under a dark `ColorScheme`, so an operator whose phone was in dark mode
  /// got `#1A1D1C` text on a near-black background.
  static const dark = FlowSurfaces(
    page: _dCanvas,
    card: _dCard,
    map: _dElevated,
    roadLine: _dBorderSubtle,
    textPrimary: _dTextPrimary,
    textSecondary: _dTextSecondary,
    textFaint: _dTextMuted,
    faintInk: _dStatusUnknown,
    errorInk: _dStatusEmergency,
    errorPill: PillColors(tint: Color(0xFF3D1A1C), ink: Color(0xFFFF9C99)),
  );

  /// Page background. [AppColors.surfaceCanvas].
  final Color page;

  /// Card and sheet surfaces. [AppColors.surfaceCard].
  final Color card;

  /// The map backdrop and the active tab capsule. [AppColors.surfaceElevated].
  final Color map;

  /// Hairline dividers and borders. [AppColors.borderSubtle].
  final Color roadLine;

  final Color textPrimary;
  final Color textSecondary;

  /// [AppColors.textMuted].
  final Color textFaint;

  /// Non-text greys: icons, handles, the unknown marker fill.
  /// [AppColors.statusUnknown].
  final Color faintInk;

  /// Failed sign-in, rejected input — a form saying something is wrong.
  ///
  /// **Not `macet`.** The congestion reds are reserved for congestion, and the
  /// console is exactly where that rule is most tempting to break because the
  /// screens are denser. [AppColors.statusEmergency].
  final Color errorInk;

  /// [errorInk] as a pill, for connector states needing attention.
  final PillColors errorPill;

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
      errorPill: PillColors.lerp(errorPill, other.errorPill, t),
    );
  }
}

/// The four congestion colours, and nothing else.
///
/// These hues are reserved: they are driven entirely by [CongestionLevel] and
/// are never used for buttons, links, or decorative icons — so colour in this
/// app always means exactly one thing.
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
    lancar: _lStatusNormal,
    padat: _lStatusWarning,
    macet: _lStatusCritical,
    unknown: _lStatusUnknown,
    lancarPill: PillColors(tint: Color(0xFFE0F1E9), ink: Color(0xFF1B7A4E)),
    padatPill: PillColors(tint: Color(0xFFFBF2E2), ink: Color(0xFF8D6923)),
    macetPill: PillColors(tint: Color(0xFFF9E5E4), ink: Color(0xFFBA3E3A)),
    unknownPill: PillColors(tint: Color(0xFFF1F2F2), ink: Color(0xFF6A6F6E)),
  );

  static const dark = CongestionColors(
    lancar: _dStatusNormal,
    padat: _dStatusWarning,
    macet: _dStatusCritical,
    unknown: _dStatusUnknown,
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

  /// Falls back to [light] so a widget rendered outside `flowSenseTheme` still
  /// gets sane colours instead of throwing.
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
      lancarPill: PillColors.lerp(lancarPill, other.lancarPill, t),
      padatPill: PillColors.lerp(padatPill, other.padatPill, t),
      macetPill: PillColors.lerp(macetPill, other.macetPill, t),
      unknownPill: PillColors.lerp(unknownPill, other.unknownPill, t),
    );
  }
}

/// What the status chip says.
///
/// Staleness outranks the level, deliberately: a `macet` reading from four
/// minutes ago is not a jam, it is a silence. `Data basi` says the feed
/// stopped; `Tidak ada data` says none ever arrived. Conflating the two would
/// hide a dead connector behind a colour.
String statusLabel(CongestionLevel level, {required bool isStale}) =>
    isStale ? 'Data basi' : level.label;
