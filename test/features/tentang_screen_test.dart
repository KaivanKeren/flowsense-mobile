import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/core/app_version.dart';
import 'package:flowsense_mobile/features/tentang/tentang_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: flowSenseTheme(),
    home: const TentangScreen(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('names both data sources', (tester) async {
    await _pump(tester);

    // An examiner will ask where the data comes from; having the screen beats
    // answering out loud.
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);
    expect(find.textContaining('ODbL'), findsOneWidget);
    expect(
      find.textContaining('portal CCTV Pemerintah Kabupaten Kudus'),
      findsOneWidget,
    );
  });

  testWidgets('explains how the status is computed, without jargon',
      (tester) async {
    await _pump(tester);

    expect(find.text('Cara status dihitung'), findsOneWidget);
    expect(find.textContaining('lajur yang paling padat'), findsOneWidget);
  });

  testWidgets('admits the numbers can be wrong', (tester) async {
    await _pump(tester);

    // The section that actually matters: an automatic count that can be wrong
    // should say so, where the person relying on it can read it.
    await tester.scrollUntilVisible(find.text('Batasan'), 200);
    expect(find.textContaining('estimasi otomatis dan dapat meleset'),
        findsOneWidget);
    expect(find.textContaining('malam hari'), findsOneWidget);
    expect(
      find.textContaining('tidak pernah ditandai lancar'),
      findsOneWidget,
      reason: 'absence of data is never free flow, and the screen says so',
    );
  });

  testWidgets('shows the app version', (tester) async {
    await _pump(tester);

    await tester.scrollUntilVisible(
      find.text('FlowSense versi $kAppVersion'),
      200,
    );
    expect(find.text('FlowSense versi $kAppVersion'), findsOneWidget);
  });
}
