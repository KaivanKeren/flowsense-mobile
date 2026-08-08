import 'dart:io';

import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/data/api/fake_flowsense_api.dart';
import 'package:flowsense_mobile/data/auth/fake_auth_api.dart';
import 'package:flowsense_mobile/data/auth/token_store.dart';
import 'package:flowsense_mobile/data/calibration/calibration_api.dart';
import 'package:flowsense_mobile/domain/calibration.dart';
import 'package:flowsense_mobile/features/operator/kalibrasi_screen.dart';
import 'package:flowsense_mobile/state/auth_providers.dart';
import 'package:flowsense_mobile/state/calibration_providers.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 8, 2, 9, 14);

FakeFlowSenseApi _trafficApi() => FakeFlowSenseApi.fromStrings(
      intersectionsJson:
          File('test/fixtures/intersections.json').readAsStringSync(),
      recordsJsonl: File('test/fixtures/records.jsonl').readAsStringSync(),
      demoJson: File('test/fixtures/demo.json').readAsStringSync(),
      now: () => _t0,
    );

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

  testWidgets('KalibrasiScreen at 360x800', (tester) async {
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
        calibrationApiProvider.overrideWithValue(
          FakeCalibrationApi(
            now: () => _t0,
            // Already calibrated once, so the golden pins the "who and when"
            // line as well as the empty case.
            seed: {
              '30': CapacityCalibration(
                cameraId: '30',
                capacity: const {
                  'kota': 12,
                  'ploso': 10,
                  'demak': 8,
                  'sekoe': 6,
                },
                updatedBy: 'Ismail',
                updatedAt: _t0,
              ),
            },
          ),
        ),
      ],
      child: MaterialApp(
        theme: flowSenseTheme(),
        debugShowCheckedModeBanner: false,
        home: const KalibrasiScreen(cameraId: '30'),
      ),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(KalibrasiScreen),
      matchesGoldenFile('kalibrasi_screen.png'),
    );
  });
}
