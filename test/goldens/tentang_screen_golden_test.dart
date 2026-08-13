import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/features/tentang/tentang_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  for (final weight in ['400', '500']) {
    final loader = FontLoader(kFontFamily)
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$weight.ttf'));
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  testWidgets('TentangScreen at 360x800', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: flowSenseTheme(),
      debugShowCheckedModeBanner: false,
      home: const TentangScreen(),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(TentangScreen),
      matchesGoldenFile('tentang_screen.png'),
    );
  });
}
