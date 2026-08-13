import 'dart:math' as math;

import 'package:flowsense_mobile/theme/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.1 relative luminance.
double luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

String hex(Color c) => '#'
    '${(c.r * 255).round().toRadixString(16).padLeft(2, '0')}'
    '${(c.g * 255).round().toRadixString(16).padLeft(2, '0')}'
    '${(c.b * 255).round().toRadixString(16).padLeft(2, '0')}'
    .toUpperCase();

/// WCAG 1.4.3 — normal-size text.
const double kTextFloor = 4.5;

/// WCAG 1.4.11 — a graphical object needed to understand the content. A
/// congestion bar and a status dot are exactly that; a hairline divider is
/// decoration and is excluded below.
const double kGraphicFloor = 3.0;

void main() {
  const themes = <String, AppColors>{
    'dark': AppColors.dark,
    'light': AppColors.light,
  };

  /// The three surfaces a token may legitimately be drawn on.
  Map<String, Color> surfacesOf(AppColors c) => {
        'surfaceCanvas': c.surfaceCanvas,
        'surfaceCard': c.surfaceCard,
        'surfaceElevated': c.surfaceElevated,
      };

  Map<String, Color> textsOf(AppColors c) => {
        'textPrimary': c.textPrimary,
        'textSecondary': c.textSecondary,
        'textMuted': c.textMuted,
        'accentPrimary': c.accentPrimary,
        'dataInk': c.dataInk,
      };

  Map<String, Color> graphicsOf(AppColors c) => {
        'statusNormal': c.statusNormal,
        'statusWarning': c.statusWarning,
        'statusCritical': c.statusCritical,
        'statusEmergency': c.statusEmergency,
        'statusUnknown': c.statusUnknown,
        'dataInk': c.dataInk,
      };

  Map<String, PillColors> pillsOf(AppColors c) => {
        'pillNormal': c.pillNormal,
        'pillWarning': c.pillWarning,
        'pillCritical': c.pillCritical,
        'pillEmergency': c.pillEmergency,
        'pillUnknown': c.pillUnknown,
        'pillAccent': c.pillAccent,
      };

  for (final entry in themes.entries) {
    final name = entry.key;
    final colors = entry.value;

    group('$name theme', () {
      test('every text token clears 4.5:1 on every surface token', () {
        // The whole cross product, not a sample. A token that reads on the
        // canvas and fails on the card is a trap for whoever puts it there
        // next, and "we only use it on the page" is a convention nothing
        // enforces.
        final failures = <String>[];

        for (final text in textsOf(colors).entries) {
          for (final surface in surfacesOf(colors).entries) {
            final ratio = contrast(text.value, surface.value);
            if (ratio < kTextFloor) {
              failures.add(
                '${text.key} ${hex(text.value)} on '
                '${surface.key} ${hex(surface.value)} = '
                '${ratio.toStringAsFixed(2)}',
              );
            }
          }
        }

        expect(failures, isEmpty,
            reason: 'text owes 4.5:1 against whatever it sits on');
      });

      test('every status colour clears 3:1 as a graphic mark', () {
        // A bar, a dot, a marker fill. Not text, so 3:1 rather than 4.5 —
        // but a mark nobody can locate is a mark that is not there.
        //
        // `surfaceElevated` is excluded: nothing draws a status mark on the
        // banner strip or the tab capsule, and requiring it would darken the
        // amber past the point where it still reads as amber.
        final failures = <String>[];

        for (final graphic in graphicsOf(colors).entries) {
          for (final surface in [colors.surfaceCanvas, colors.surfaceCard]) {
            final ratio = contrast(graphic.value, surface);
            if (ratio < kGraphicFloor) {
              failures.add(
                '${graphic.key} ${hex(graphic.value)} on ${hex(surface)} = '
                '${ratio.toStringAsFixed(2)}',
              );
            }
          }
        }

        expect(failures, isEmpty,
            reason: 'a status mark has to be findable');
      });

      test('every chip ink clears 4.5:1 against its own tint', () {
        // Coloured text on a pale tint is where this rule leaks most often,
        // so all six pairs are pinned rather than eyeballed.
        for (final pill in pillsOf(colors).entries) {
          expect(
            contrast(pill.value.ink, pill.value.tint),
            greaterThanOrEqualTo(kTextFloor),
            reason: '${pill.key}: ink ${hex(pill.value.ink)} on tint '
                '${hex(pill.value.tint)}',
          );
        }
      });

      test('text on the accent clears 4.5:1', () {
        expect(
          contrast(colors.textOnAccent, colors.accentPrimary),
          greaterThanOrEqualTo(kTextFloor),
        );
      });

      test('the surfaces are distinguishable from one another', () {
        // Not a WCAG floor — a judgement. Three surfaces that measure the same
        // are one surface with extra names, and the card would vanish into the
        // page.
        expect(contrast(colors.surfaceCard, colors.surfaceCanvas),
            greaterThan(1.05));
        expect(contrast(colors.surfaceElevated, colors.surfaceCard),
            greaterThan(1.05));
      });

      test('the hairline is visible against the surfaces it separates', () {
        // Decoration, so no 3:1 obligation — but an invisible border is a
        // border that is not doing its job.
        expect(contrast(colors.borderSubtle, colors.surfaceCanvas),
            greaterThan(1.1));
        expect(contrast(colors.borderStrong, colors.surfaceCard),
            greaterThan(1.4));
      });
    });
  }

  group('the two themes stay distinguishable', () {
    test('the four status colours are four distinct values', () {
      for (final colors in themes.values) {
        final marks = {
          colors.statusNormal,
          colors.statusWarning,
          colors.statusCritical,
          colors.statusUnknown,
        };
        expect(marks, hasLength(4));
      }
    });

    test('two statuses are NOT separable by lightness alone', () {
      // This failure is pinned deliberately, because it is the argument for
      // the rule the widgets follow.
      //
      // `statusCritical` and `statusUnknown` both have to clear 3:1 against
      // the same page, which forces them to similar lightness — in the light
      // theme they measure 1.06:1 against each other. They differ in hue, and
      // to most people that is plenty. To someone with protanopia, a
      // desaturated red beside a grey is a coin toss, and red-green colour
      // blindness is precisely the relevant case for a traffic app.
      //
      // No palette fixes this: any pair of hues at matched contrast collapses
      // under greyscale. So the fix is not in the colours, it is in the
      // widgets — **every status carries a word or an icon**, and
      // `test/widgets/status_chip_test.dart` enforces that. If this
      // expectation ever starts failing, the redundancy rule has not become
      // unnecessary; someone has merely made one status lighter.
      const light = AppColors.light;
      expect(
        contrast(light.statusCritical, light.statusUnknown),
        lessThan(1.5),
        reason: 'colour alone cannot carry status — see StatusChip',
      );
    });

    test('emergency is a different red from critical', () {
      // Both are red because both are bad. They are told apart by their words
      // and icons; this only checks they are not literally the same value,
      // which would make the distinction a lie.
      for (final colors in themes.values) {
        expect(colors.statusEmergency, isNot(colors.statusCritical));
      }
    });

    test('the dark theme is genuinely dark and the light one light', () {
      expect(luminance(AppColors.dark.surfaceCanvas), lessThan(0.05));
      expect(luminance(AppColors.light.surfaceCanvas), greaterThan(0.8));
    });

    test('the light accent is not the dark accent', () {
      // The rule this test exists for: a neon cyan moved onto white measures
      // about 1.4:1 and disappears. The light theme darkens it instead of
      // reusing it.
      expect(AppColors.light.accentPrimary,
          isNot(AppColors.dark.accentPrimary));
      expect(
        contrast(AppColors.dark.accentPrimary, AppColors.light.surfaceCanvas),
        lessThan(kTextFloor),
        reason: 'this is why the light theme needs its own accent',
      );
    });
  });
}
