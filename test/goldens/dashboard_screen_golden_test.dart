import 'dart:io';

import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/data/alerts/alerts_api.dart';
import 'package:flowsense_mobile/data/api/fake_flowsense_api.dart';
import 'package:flowsense_mobile/data/auth/fake_auth_api.dart';
import 'package:flowsense_mobile/data/auth/token_store.dart';
import 'package:flowsense_mobile/domain/congestion.dart';
import 'package:flowsense_mobile/domain/operator_alert.dart';
import 'package:flowsense_mobile/features/operator/dashboard_screen.dart';
import 'package:flowsense_mobile/state/alert_providers.dart';
import 'package:flowsense_mobile/state/auth_providers.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fixtures re-stamp to this instant, so the golden is reproducible.
final _t0 = DateTime.utc(2026, 8, 4, 16, 42);

FakeFlowSenseApi _trafficApi() => FakeFlowSenseApi.fromStrings(
      intersectionsJson:
          File('test/fixtures/intersections.json').readAsStringSync(),
      recordsJsonl: File('test/fixtures/records.jsonl').readAsStringSync(),
      demoJson: File('test/fixtures/demo.json').readAsStringSync(),
      now: () => _t0,
    );

/// One jam waiting for someone, and one already seen — so the golden pins both
/// halves of the alerts section rather than only the easy one.
List<OperatorAlert> _alerts() => [
      OperatorAlert(
        id: '1',
        cameraId: '30',
        name: 'Simpang DPRD',
        level: CongestionLevel.macet,
        raisedAt: _t0.subtract(const Duration(minutes: 37)),
      ),
      OperatorAlert(
        id: '2',
        cameraId: '31',
        name: 'Simpang Tujuh',
        level: CongestionLevel.macet,
        raisedAt: _t0.subtract(const Duration(minutes: 90)),
        acknowledgedBy: 'Ismail',
        acknowledgedAt: _t0.subtract(const Duration(minutes: 62)),
      ),
    ];

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

  testWidgets('DashboardScreen at 360x800', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authApi = FakeAuthApi();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(_trafficApi()),
        appConfigProvider.overrideWithValue(const AppConfig()),
        clockProvider.overrideWithValue(FakeClock(_t0)),
        snapshotCacheProvider.overrideWithValue(null),
        authApiProvider.overrideWithValue(authApi),
        tokenStoreProvider.overrideWithValue(FakeTokenStore(authApi.token)),
        alertsApiProvider.overrideWithValue(
          FakeAlertsApi(seed: _alerts(), now: () => _t0),
        ),
      ],
      child: MaterialApp(
        theme: flowSenseTheme(),
        debugShowCheckedModeBanner: false,
        home: const DashboardScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DashboardScreen),
      matchesGoldenFile('dashboard_screen.png'),
    );
  });
}
