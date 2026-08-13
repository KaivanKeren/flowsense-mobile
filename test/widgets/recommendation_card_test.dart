import 'package:flowsense_mobile/theme/app_theme.dart';
import 'package:flowsense_mobile/widgets/recommendation_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: flowSenseTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

/// The card under test. [onAction] is supplied by default because a card
/// without one renders no buttons at all — no dead controls — and a test that
/// forgot it would pass every "no forbidden verb" assertion trivially.
RecommendationCard _build({
  ValueChanged<RecommendationAction>? onAction = _ignore,
  double confidence = 0.72,
}) =>
    RecommendationCard(
      title: 'Perpanjang fase utara 8 detik',
      confidence: confidence,
      reason: 'Antrean utara naik tiga siklus berturut-turut sementara arah '
          'selatan kosong.',
      expectedImpact:
          'Perkiraan antrean utara turun sekitar 20 persen dalam dua siklus.',
      actions: RecommendationAction.values,
      onAction: onAction,
    );

void _ignore(RecommendationAction _) {}

void main() {
  group('the console stays read-only', () {
    test('the action vocabulary is a closed set', () {
      // The reason this is an enum: a free String label invites `Terapkan`,
      // `Kirim ke lampu` or `Ubah durasi`, three buttons that would promise a
      // capability the system does not have. Adding a case is a deliberate act
      // a reviewer will see; this test is what makes it visible.
      expect(
        RecommendationAction.values.map((a) => a.label),
        ['Tinjau', 'Konfirmasi', 'Catat'],
      );
    });

    testWidgets('no rendered button suggests changing a traffic light',
        (tester) async {
      await tester.pumpWidget(_wrap(_build()));

      for (final forbidden in const [
        'Terapkan',
        'Kirim',
        'Ubah durasi',
        'Aktifkan',
        'Jalankan',
        'Setel',
      ]) {
        expect(
          find.textContaining(forbidden),
          findsNothing,
          reason: '"$forbidden" implies control this console does not have',
        );
      }
    });

    testWidgets('every card carries the read-only note', (tester) async {
      // Part of the component, not a caption a screen can forget to add.
      await tester.pumpWidget(_wrap(_build()));
      expect(find.text(RecommendationCard.readOnlyNote), findsOneWidget);
    });
  });

  group('confidence is legible three ways', () {
    testWidgets('a word, a percentage, and a bar', (tester) async {
      await tester.pumpWidget(_wrap(_build()));

      expect(find.text('Kepercayaan tinggi'), findsOneWidget);
      expect(find.text('72%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    test('a boundary lands on the lower band', () {
      // Same rule as the congestion thresholds: a model that is exactly 60%
      // sure is not `tinggi`.
      expect(ConfidenceBand.of(0.4), ConfidenceBand.rendah);
      expect(ConfidenceBand.of(0.41), ConfidenceBand.sedang);
      expect(ConfidenceBand.of(0.6), ConfidenceBand.sedang);
      expect(ConfidenceBand.of(0.61), ConfidenceBand.tinggi);
    });

    test('an out-of-range confidence is clamped, not rendered raw', () {
      expect(_build(confidence: 1.8).band, ConfidenceBand.tinggi);
      expect(_build(confidence: -0.5).band, ConfidenceBand.rendah);
    });
  });

  testWidgets('the reasoning is on the card, not behind a tap',
      (tester) async {
    // The reason and the expected effect are why a person is in this loop. A
    // card showing only a conclusion would be asking for assent rather than
    // review.
    await tester.pumpWidget(_wrap(_build()));
    expect(find.textContaining('Antrean utara naik'), findsOneWidget);
    expect(find.textContaining('turun sekitar 20 persen'), findsOneWidget);
  });

  testWidgets('actions report which one was pressed', (tester) async {
    final pressed = <RecommendationAction>[];
    await tester.pumpWidget(_wrap(_build(onAction: pressed.add)));

    await tester.tap(find.text('Konfirmasi'));
    expect(pressed, [RecommendationAction.konfirmasi]);
  });

  testWidgets('three buttons survive a narrow card at textScale 1.3',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: flowSenseTheme(),
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: Scaffold(
          body: SingleChildScrollView(child: _build()),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    for (final action in RecommendationAction.values) {
      expect(find.text(action.label), findsOneWidget);
    }
  });
}
