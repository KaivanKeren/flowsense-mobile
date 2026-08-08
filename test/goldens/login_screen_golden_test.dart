import 'dart:io';

import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/data/api/fake_flowsense_api.dart';
import 'package:flowsense_mobile/data/auth/fake_auth_api.dart';
import 'package:flowsense_mobile/data/auth/token_store.dart';
import 'package:flowsense_mobile/features/operator/login_screen.dart';
import 'package:flowsense_mobile/state/auth_providers.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the rendered screen, not just its behaviour.
///
/// The reference PNGs in `assets/design/` preserve nothing on their own — they
/// are not compared to anything. This is what keeps the layout from drifting
/// once somebody else edits the file.
final _t0 = DateTime.utc(2026, 8, 2, 12);

FakeFlowSenseApi _trafficApi() => FakeFlowSenseApi.fromStrings(
      intersectionsJson:
          File('test/fixtures/intersections.json').readAsStringSync(),
      recordsJsonl: File('test/fixtures/records.jsonl').readAsStringSync(),
      demoJson: File('test/fixtures/demo.json').readAsStringSync(),
      now: () => _t0,
    );

Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  FakeAuthApi? authApi,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      // The operator flavor runs on fixtures end to end, login included.
      apiProvider.overrideWithValue(_trafficApi()),
      authApiProvider.overrideWithValue(authApi ?? FakeAuthApi()),
      tokenStoreProvider.overrideWithValue(FakeTokenStore()),
      appConfigProvider.overrideWithValue(const AppConfig()),
      clockProvider.overrideWithValue(FakeClock(_t0)),
      snapshotCacheProvider.overrideWithValue(null),
    ],
    child: MaterialApp(
      theme: flowSenseTheme(),
      debugShowCheckedModeBanner: false,
      home: child,
    ),
  ));
  await tester.pumpAndSettle();
}

/// Loads the real typeface into the test binary.
///
/// Without this, `flutter test` substitutes Ahem and every glyph renders as a
/// filled box — the golden would still catch layout drift, but a person could
/// not hold it next to `assets/design/operator-01-login.png` and judge whether
/// they match, which is most of the point.
Future<void> _loadFonts() async {
  for (final weight in ['400', '500']) {
    final loader = FontLoader(kFontFamily)
      ..addFont(
        rootBundle.load('assets/fonts/PlusJakartaSans-$weight.ttf'),
      );
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  testWidgets('LoginScreen at 360x800', (tester) async {
    await _pump(tester, child: const LoginScreen());

    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('login_screen.png'),
    );
  });

  testWidgets('LoginScreen with the error line at 360x800', (tester) async {
    await _pump(tester, child: const LoginScreen());

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('field-password')),
        matching: find.byType(EditableText),
      ),
      'salah',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LoginScreen),
      matchesGoldenFile('login_screen_error.png'),
    );
  });
}
