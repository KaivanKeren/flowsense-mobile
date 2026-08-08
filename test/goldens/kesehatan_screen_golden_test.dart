import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/data/health/health_api.dart';
import 'package:flowsense_mobile/domain/connector_health.dart';
import 'package:flowsense_mobile/features/operator/kesehatan_screen.dart';
import 'package:flowsense_mobile/state/health_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 8, 4, 16, 42, 7);

/// The five connectors behind the bundled fixtures, one per intersection —
/// including the camera `demo.json` deliberately holds back, so the unhealthy
/// half of this screen is reachable with no backend.
List<ConnectorHealth> _fleet() => [
      ConnectorHealth(
        cameraId: '30',
        intersectionName: 'Simpang DPRD',
        status: ConnectorStatus.berjalan,
        lastRecordAt: _t0,
        gap: const Duration(seconds: 2),
        failuresPerHour: 0,
      ),
      ConnectorHealth(
        cameraId: '31',
        intersectionName: 'Simpang Tujuh',
        status: ConnectorStatus.berjalan,
        lastRecordAt: _t0.subtract(const Duration(seconds: 2)),
        gap: const Duration(milliseconds: 2100),
        failuresPerHour: 2,
      ),
      ConnectorHealth(
        cameraId: '32',
        intersectionName: 'Simpang Jati',
        status: ConnectorStatus.berjalan,
        lastRecordAt: _t0.subtract(const Duration(seconds: 1)),
        gap: const Duration(seconds: 2),
        failuresPerHour: 0,
      ),
      ConnectorHealth(
        cameraId: '33',
        intersectionName: 'Simpang Bae',
        status: ConnectorStatus.terputus,
        lastRecordAt: _t0.subtract(const Duration(seconds: 55)),
        gap: const Duration(milliseconds: 4800),
        failuresPerHour: 14,
      ),
      ConnectorHealth(
        cameraId: '34',
        intersectionName: 'Simpang Ngembal',
        status: ConnectorStatus.berhenti,
        lastRecordAt: _t0.subtract(const Duration(minutes: 3, seconds: 27)),
        gap: null,
        failuresPerHour: 63,
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

  testWidgets('KesehatanScreen at 360x800', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        healthApiProvider.overrideWithValue(FakeHealthApi(seed: _fleet())),
      ],
      child: MaterialApp(
        theme: flowSenseTheme(),
        debugShowCheckedModeBanner: false,
        home: const KesehatanScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(KesehatanScreen),
      matchesGoldenFile('kesehatan_screen.png'),
    );
  });
}
