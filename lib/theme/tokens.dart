/// Every non-colour measurement in the app: space, radius, icon size, and the
/// touch floor.
///
/// The rule these exist to enforce is the same one `colors.dart` enforces for
/// hue — **never write a bare number in a widget.** A padding of 14 is not
/// wrong on its own; it is wrong because the card beside it uses 12 and nobody
/// can say which was the decision and which was the typo.
library;

/// The spacing scale. Multiples of four, six steps, and no seventh.
///
/// Anything that is not one of these is a bug. The previous code base drifted
/// to 2, 5, 6, 10, 14, 18, 20 and 22 across roughly forty call sites, which is
/// how two cards that were meant to match ended up two pixels apart.
abstract final class FlowSpace {
  /// Between a label and the thing it labels.
  static const double xs = 4;

  /// Between related lines inside one block.
  static const double sm = 8;

  /// Between a row's columns.
  static const double md = 12;

  /// The standard screen gutter, and a card's inner padding.
  static const double lg = 16;

  /// Between sections of a screen.
  static const double xl = 24;

  /// Above the first section and below the last.
  static const double xxl = 32;
}

/// Corner radii. Three values: controls, cards, sheets.
abstract final class FlowRadius {
  /// Controls, chips, pills, inputs.
  static const double sm = 8;

  /// Cards and panels.
  static const double md = 12;

  /// The top corners of a bottom sheet.
  static const double lg = 16;

  /// Older name for [sm]. Kept so the pre-refactor call sites keep compiling.
  static const double control = sm;

  /// Older name for [md].
  static const double card = md;

  /// Older name for [lg].
  static const double sheet = lg;
}

/// Icon sizes. Four, matched to the type scale rather than chosen per widget.
abstract final class FlowIconSize {
  /// Inline with caption text — a status glyph inside a chip.
  static const double sm = 16;

  /// The default: list rows, tab bars, buttons.
  static const double md = 20;

  /// A section's leading icon.
  static const double lg = 24;

  /// The single illustrative icon on an empty or error state.
  static const double xl = 32;
}

/// The type scale. Five sizes, and **nothing below 11**.
abstract final class FlowTextSize {
  /// The one big number — a metric card's figure.
  static const double figure = 28;

  /// Screen titles.
  static const double screenTitle = 18;

  /// Row titles and section headers.
  static const double rowTitle = 15;

  static const double body = 13;

  /// The floor. Captions and monospace category labels.
  static const double caption = 11;
}

/// The minimum size of anything a finger has to hit.
///
/// 48, not 44. The old value came from Apple's guidance; Material and WCAG
/// 2.5.5 both say 48dp, and this app is Android-first and used by people who
/// are older than its designers.
abstract final class FlowTouch {
  static const double minTarget = 48;
}

/// The body font, bundled in `assets/fonts/`. Two weights exist and no more.
const String kFontFamily = 'Plus Jakarta Sans';

/// The monospace family for category labels.
///
/// **Not bundled**, deliberately: a second font file costs more in APK size
/// than the console gains, and every platform ships a serviceable monospace.
/// This is a fallback chain rather than one name, because the family that
/// exists differs per platform — and if none resolves, the label degrades to
/// the body font with its letter spacing intact, which is legible rather than
/// broken.
const List<String> kMonoFontFamilyFallback = <String>[
  'RobotoMono',
  'Roboto Mono',
  'SF Mono',
  'Menlo',
  'Consolas',
  'monospace',
];
