import 'package:flutter/material.dart';

import '../domain/congestion.dart';

/// The four semantic colours, and nothing else.
///
/// These hues are reserved: they are driven entirely by [CongestionLevel] and
/// are never used decoratively, so colour on the map always means one thing.
/// App chrome comes from the seeded [ColorScheme] instead.
@immutable
class CongestionColors extends ThemeExtension<CongestionColors> {
  const CongestionColors({
    required this.lancar,
    required this.padat,
    required this.macet,
    required this.unknown,
  });

  static const light = CongestionColors(
    lancar: Color(0xFF2E7D32),
    padat: Color(0xFFF9A825),
    macet: Color(0xFFC62828),
    unknown: Color(0xFF9E9E9E),
  );

  static const dark = CongestionColors(
    lancar: Color(0xFF66BB6A),
    padat: Color(0xFFFFCA28),
    macet: Color(0xFFEF5350),
    unknown: Color(0xFF757575),
  );

  final Color lancar;
  final Color padat;
  final Color macet;
  final Color unknown;

  Color forLevel(CongestionLevel level) => switch (level) {
        CongestionLevel.lancar => lancar,
        CongestionLevel.padat => padat,
        CongestionLevel.macet => macet,
        CongestionLevel.unknown => unknown,
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
  }) =>
      CongestionColors(
        lancar: lancar ?? this.lancar,
        padat: padat ?? this.padat,
        macet: macet ?? this.macet,
        unknown: unknown ?? this.unknown,
      );

  @override
  CongestionColors lerp(ThemeExtension<CongestionColors>? other, double t) {
    if (other is! CongestionColors) return this;
    return CongestionColors(
      lancar: Color.lerp(lancar, other.lancar, t)!,
      padat: Color.lerp(padat, other.padat, t)!,
      macet: Color.lerp(macet, other.macet, t)!,
      unknown: Color.lerp(unknown, other.unknown, t)!,
    );
  }
}

/// Copy is plain Indonesian, sentence case, no exclamation marks.
extension CongestionLabel on CongestionLevel {
  String get label => switch (this) {
        CongestionLevel.lancar => 'Lancar',
        CongestionLevel.padat => 'Padat',
        CongestionLevel.macet => 'Macet',
        CongestionLevel.unknown => 'Tidak ada data',
      };
}

/// Seeded blue for chrome, deliberately far from the three congestion hues.
const _seed = Color(0xFF1565C0);

ThemeData flowSenseTheme({Brightness brightness = Brightness.light}) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    extensions: [
      brightness == Brightness.dark
          ? CongestionColors.dark
          : CongestionColors.light,
    ],
  );
}
