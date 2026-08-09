import 'dart:math' as math;

import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/domain/congestion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const surfaces = FlowSurfaces.light;
  const congestion = CongestionColors.light;

  group('tokens match the layout spec', () {
    test('the surface and congestion palette is exactly the token table', () {
      expect(surfaces.page, const Color(0xFFF7F7F5));
      expect(surfaces.card, const Color(0xFFFFFFFF));
      expect(surfaces.map, const Color(0xFFEEF0ED));
      expect(surfaces.roadLine, const Color(0xFFE3E5E2));
      expect(surfaces.textPrimary, const Color(0xFF1A1D1C));
      expect(surfaces.textSecondary, const Color(0xFF6B706E));
      expect(congestion.lancar, const Color(0xFF1F9D62));
      expect(congestion.padat, const Color(0xFFE0A32E));
      expect(congestion.macet, const Color(0xFFD64541));
      expect(congestion.unknown, const Color(0xFF9AA0A0));
    });

    test('#9AA0A0 survives as the non-text faint ink', () {
      // The spec's `Teks samar` value is kept exactly — for icons, handles and
      // the unknown fill, where the contrast rule does not apply.
      expect(surfaces.faintInk, const Color(0xFF9AA0A0));
    });

    test('radii are 8 / 12 / 16 and there is no fourth value', () {
      expect(FlowRadius.control, 8);
      expect(FlowRadius.card, 12);
      expect(FlowRadius.sheet, 16);
    });

    test('the type scale is the permitted sizes, nothing below 11', () {
      // Fase 2 of the refinement pass grew the scale from five to seven to hit
      // spec §14 (body 14–16, page title 22–24, KPI 28–32). The "nothing
      // below 11" rule and the exhaustive-slot check are what has to hold.
      const sizes = [
        FlowTextSize.figureLarge,
        FlowTextSize.figure,
        FlowTextSize.pageTitle,
        FlowTextSize.screenTitle,
        FlowTextSize.rowTitle,
        FlowTextSize.bodyLarge,
        FlowTextSize.body,
        FlowTextSize.caption,
      ];
      expect(sizes, [32.0, 28.0, 24.0, 22.0, 15.0, 16.0, 14.0, 11.0]);

      final text = flowSenseTheme().textTheme;
      for (final style in [
        text.displayLarge,
        text.displaySmall,
        text.headlineSmall,
        text.titleLarge,
        text.titleMedium,
        text.bodyLarge,
        text.bodyMedium,
        text.bodySmall,
        text.labelSmall,
      ]) {
        expect(sizes, contains(style!.fontSize),
            reason: 'every slot uses a permitted size');
        expect(style.fontSize, greaterThanOrEqualTo(11.0));
      }
    });

    test('only two font weights are used, and the family is bundled', () {
      final text = flowSenseTheme().textTheme;
      for (final style in [
        text.displaySmall,
        text.titleLarge,
        text.titleMedium,
        text.bodyMedium,
        text.bodySmall,
      ]) {
        expect(style!.fontFamily, kFontFamily);
        expect(
          style.fontWeight,
          anyOf(FontWeight.w400, FontWeight.w500),
          reason: 'the spec allows 400 and 500 only',
        );
      }
    });

    test('line heights are ratios, so textScaler is free to do its job', () {
      final text = flowSenseTheme().textTheme;
      expect(text.bodyMedium!.height, isNotNull);
      expect(text.bodyMedium!.height, lessThan(3));
    });
  });

  group('contrast', () {
    test('body and secondary text clear 4.5:1 on both backgrounds', () {
      for (final bg in [surfaces.page, surfaces.card]) {
        expect(contrast(surfaces.textPrimary, bg),
            greaterThanOrEqualTo(4.5));
        expect(contrast(surfaces.textSecondary, bg),
            greaterThanOrEqualTo(4.5));
        expect(contrast(surfaces.textFaint, bg), greaterThanOrEqualTo(4.5));
      }
    });

    test('every status pill clears 4.5:1 — ink against its own tint', () {
      // The spec singles this out as where the rule leaks most often, so it is
      // pinned for all four levels rather than eyeballed.
      for (final level in CongestionLevel.values) {
        final pill = congestion.pillFor(level);
        expect(
          contrast(pill.ink, pill.tint),
          greaterThanOrEqualTo(4.5),
          reason: '${level.name} pill',
        );
      }
    });

    test('the raw level colours would have failed as pill text', () {
      // Why the inks are darkened rather than reused: this is the mistake the
      // pill colours exist to prevent, and it stays pinned so nobody "simplifies"
      // pillFor back to forLevel.
      final macetPill = congestion.macetPill;
      expect(contrast(congestion.macet, macetPill.tint), lessThan(4.5));
    });
  });

  group('copy', () {
    test('labels are Indonesian, sentence case, no exclamation or emoji', () {
      for (final level in CongestionLevel.values) {
        final label = level.label;
        expect(label, isNot(contains('!')));
        expect(label, matches(RegExp(r'^[A-Z][a-z]')));
      }
      expect(CongestionLevel.lancar.label, 'Lancar');
      expect(CongestionLevel.padat.label, 'Padat');
      expect(CongestionLevel.macet.label, 'Macet');
    });

    test('a stale reading reads as Data basi whatever the level said', () {
      // Staleness outranks the level: a four-minute-old macet is a silence,
      // not a jam.
      expect(statusLabel(CongestionLevel.macet, isStale: true), 'Data basi');
      expect(statusLabel(CongestionLevel.lancar, isStale: true), 'Data basi');
      expect(statusLabel(CongestionLevel.macet, isStale: false), 'Macet');
    });

    test('never-arrived data is distinct from a feed that stopped', () {
      expect(statusLabel(CongestionLevel.unknown, isStale: false),
          'Tidak ada data');
      expect(statusLabel(CongestionLevel.unknown, isStale: true), 'Data basi');
    });
  });

  group('flat, per the spec: no shadows, no gradients, no glass', () {
    test('surfaces carry no elevation', () {
      final theme = flowSenseTheme();
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
      expect(theme.cardTheme.elevation, 0);
      expect(theme.bottomSheetTheme.elevation, 0);
    });

    test('dividers are one hairline weight', () {
      final theme = flowSenseTheme();
      expect(theme.dividerTheme.thickness, 1);
      expect(theme.dividerTheme.color, surfaces.roadLine);
    });

    test('controls meet the 44 px touch floor', () {
      final theme = flowSenseTheme();
      final size = theme.filledButtonTheme.style!.minimumSize!
          .resolve(<WidgetState>{});
      expect(size!.height, greaterThanOrEqualTo(44));
    });
  });

  testWidgets('the extensions resolve through Theme.of', (tester) async {
    late CongestionColors resolved;
    late FlowSurfaces resolvedSurfaces;

    await tester.pumpWidget(MaterialApp(
      theme: flowSenseTheme(),
      home: Builder(builder: (context) {
        resolved = CongestionColors.of(context);
        resolvedSurfaces = FlowSurfaces.of(context);
        return const SizedBox();
      }),
    ));

    expect(resolved.macet, congestion.macet);
    expect(resolvedSurfaces.page, surfaces.page);
  });

  testWidgets('a widget outside the theme still gets sane colours',
      (tester) async {
    late CongestionColors resolved;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        resolved = CongestionColors.of(context);
        return const SizedBox();
      }),
    ));
    expect(resolved.macet, CongestionColors.light.macet);
  });
}
