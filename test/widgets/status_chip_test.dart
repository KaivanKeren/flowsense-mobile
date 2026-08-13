import 'package:flowsense_mobile/domain/congestion.dart';
import 'package:flowsense_mobile/theme/app_theme.dart';
import 'package:flowsense_mobile/theme/colors.dart';
import 'package:flowsense_mobile/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: flowSenseTheme(brightness: brightness),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('status is never carried by colour alone', () {
    testWidgets('every level renders its word', (tester) async {
      for (final level in CongestionLevel.values) {
        await tester.pumpWidget(_wrap(
          StatusChip.congestion(level: level, isStale: false),
        ));
        expect(
          find.text(statusLabel(level, isStale: false)),
          findsOneWidget,
          reason: '${level.name} must say what it is',
        );
      }
    });

    testWidgets('every tone renders a distinct glyph', (tester) async {
      // The tint is reinforcement. If two tones shared an icon, a greyscale
      // screen would show two identical chips — and as
      // `test/theme/contrast_test.dart` records, red and grey are not
      // separable by lightness at matched contrast.
      final icons = <IconData>{};
      for (final tone in StatusTone.values) {
        if (tone == StatusTone.neutral) continue;
        icons.add(StatusChip.iconFor(tone));
      }
      expect(icons, hasLength(StatusTone.values.length - 1));
    });

    testWidgets('the word survives with the icon turned off', (tester) async {
      await tester.pumpWidget(_wrap(
        const StatusChip(label: 'Macet', tone: StatusTone.critical,
            showIcon: false),
      ));
      expect(find.text('Macet'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });
  });

  group('semantics', () {
    testWidgets('a congestion chip announces what the status is about',
        (tester) async {
      await tester.pumpWidget(_wrap(
        StatusChip.congestion(
          level: CongestionLevel.macet,
          isStale: false,
        ),
      ));

      // The brief asks for exactly this: "Status simpang: macet", not a
      // colour and not a bare word.
      expect(
        find.bySemanticsLabel('Status simpang: macet'),
        findsOneWidget,
      );
    });

    testWidgets('the prefix can be dropped when the parent already says it',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const StatusChip(
          label: 'Berjalan',
          tone: StatusTone.normal,
          semanticsPrefix: null,
        ),
      ));
      expect(find.bySemanticsLabel('Berjalan'), findsOneWidget);
    });
  });

  group('staleness outranks the level', () {
    test('a stale macet is unknown, not critical', () {
      // A four-minute-old jam is a silence, not a jam. Rendering it in a
      // washed-out red would leave it still reading as red.
      final chip = StatusChip.congestion(
        level: CongestionLevel.macet,
        isStale: true,
      );
      expect(chip.tone, StatusTone.unknown);
      expect(chip.label, 'Data basi');
    });

    test('unknown is never mapped to normal', () {
      // Absence of data is not a clear road. This is the single most
      // dangerous mistake this app could make, so it is pinned.
      expect(
        StatusChip.toneForLevel(CongestionLevel.unknown),
        isNot(StatusTone.normal),
      );
    });
  });

  testWidgets('a long label ellipsizes instead of overflowing', (tester) async {
    await tester.pumpWidget(_wrap(
      SizedBox(
        width: 60,
        child: Row(
          children: const [
            Flexible(
              child: StatusChip(
                label: 'Belum pernah menerima data sama sekali',
                tone: StatusTone.unknown,
              ),
            ),
          ],
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
  });

  testWidgets('the chip reads in both themes', (tester) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(_wrap(
        const StatusChip(label: 'Padat', tone: StatusTone.warning),
        brightness: brightness,
      ));
      expect(find.text('Padat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
