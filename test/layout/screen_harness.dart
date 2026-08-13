/// One place to pump any screen at any width and text scale.
///
/// Shared by `overflow_test.dart` and anything else that needs a real screen
/// with fixture data behind it. Every provider that would reach a platform
/// channel — preferences, the secure token store, the notification plugin — is
/// overridden here, so a layout test never depends on a device.
library;

import 'dart:io';

import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/data/alerts/alerts_api.dart';
import 'package:flowsense_mobile/data/api/fake_flowsense_api.dart';
import 'package:flowsense_mobile/data/auth/fake_auth_api.dart';
import 'package:flowsense_mobile/data/auth/token_store.dart';
import 'package:flowsense_mobile/data/health/health_api.dart';
import 'package:flowsense_mobile/data/prefs/app_mode_store.dart';
import 'package:flowsense_mobile/data/prefs/theme_mode_store.dart';
import 'package:flowsense_mobile/domain/congestion.dart';
import 'package:flowsense_mobile/domain/connector_health.dart';
import 'package:flowsense_mobile/domain/operator_alert.dart';
import 'package:flowsense_mobile/features/alerts/notifier.dart';
import 'package:flowsense_mobile/state/alert_providers.dart';
import 'package:flowsense_mobile/state/app_mode_providers.dart';
import 'package:flowsense_mobile/state/auth_providers.dart';
import 'package:flowsense_mobile/state/health_providers.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flowsense_mobile/state/theme_providers.dart';
import 'package:flowsense_mobile/theme/app_theme.dart';
import 'package:flowsense_mobile/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The four widths the brief names. 320 is a Galaxy A03 in display-zoom, which
/// is a phone people at a bus stop in Kudus actually hold; 448 is the cap.
const List<double> kTestWidths = [320, 360, 414, 448];

/// 1.0 and 1.3. The second is roughly Android's "Besar" font setting, and it
/// is the one an older rider is likely to have on.
const List<double> kTestTextScales = [1.0, 1.3];

final DateTime t0 = DateTime.utc(2026, 8, 4, 16, 42);

/// Loads the bundled font before any layout assertion runs.
///
/// Without this the suite lays out in the test harness's fallback font, which
/// is wider per character than Plus Jakarta Sans — so it reports overflows that
/// do not happen on a device and, worse, gives false confidence about the
/// widths that pass. Call it from `setUpAll`.
Future<void> loadTestFonts() async {
  for (final weight in ['400', '500']) {
    final loader = FontLoader(kFontFamily)
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$weight.ttf'));
    await loader.load();
  }
}

/// Reads fixtures off disk rather than through `rootBundle`: inside
/// `testWidgets` the asset bundle's I/O never completes, because the body runs
/// in a fake-async zone.
FakeFlowSenseApi trafficApi() => FakeFlowSenseApi.fromStrings(
      intersectionsJson:
          File('test/fixtures/intersections.json').readAsStringSync(),
      recordsJsonl: File('test/fixtures/records.jsonl').readAsStringSync(),
      demoJson: File('test/fixtures/demo.json').readAsStringSync(),
      now: () => t0,
    );

/// One alert waiting for someone and one already seen, so both halves of the
/// alerts section are on screen.
List<OperatorAlert> alerts() => [
      OperatorAlert(
        id: '1',
        cameraId: '30',
        name: 'Simpang DPRD',
        level: CongestionLevel.macet,
        raisedAt: t0.subtract(const Duration(minutes: 37)),
      ),
      OperatorAlert(
        id: '2',
        cameraId: '31',
        name: 'Simpang Tujuh',
        level: CongestionLevel.macet,
        raisedAt: t0.subtract(const Duration(minutes: 90)),
        acknowledgedBy: 'Ismail',
        acknowledgedAt: t0.subtract(const Duration(minutes: 62)),
      ),
    ];

/// One healthy connector and one stopped, plus the longest intersection name
/// in the fixtures — a layout test wants the hard case, not the tidy one.
List<ConnectorHealth> connectors() => [
      ConnectorHealth(
        cameraId: '30',
        intersectionName: 'Simpang DPRD',
        status: ConnectorStatus.berjalan,
        lastRecordAt: t0.subtract(const Duration(seconds: 8)),
        gap: const Duration(seconds: 20),
        failuresPerHour: 0,
      ),
      ConnectorHealth(
        cameraId: '34',
        intersectionName: 'Simpang Ngembal Kulon',
        status: ConnectorStatus.berhenti,
        lastRecordAt: t0.subtract(const Duration(minutes: 41)),
        gap: null,
        failuresPerHour: 12,
      ),
    ];

/// Every override a screen needs to render without touching a device.
List<Override> screenOverrides({bool signedIn = true}) {
  final authApi = FakeAuthApi();
  return [
    apiProvider.overrideWithValue(trafficApi()),
    appConfigProvider.overrideWithValue(const AppConfig()),
    clockProvider.overrideWithValue(FakeClock(t0)),
    snapshotCacheProvider.overrideWithValue(null),
    authApiProvider.overrideWithValue(authApi),
    tokenStoreProvider.overrideWithValue(
      FakeTokenStore(signedIn ? authApi.token : null),
    ),
    alertsApiProvider
        .overrideWithValue(FakeAlertsApi(seed: alerts(), now: () => t0)),
    healthApiProvider.overrideWithValue(FakeHealthApi(seed: connectors())),
    alertNotifierProvider.overrideWithValue(FakeAlertNotifier()),
    appModeStoreProvider.overrideWithValue(FakeAppModeStore()),
    themeModeStoreProvider.overrideWithValue(FakeThemeModeStore()),
  ];
}

/// Pumps [screen] at [width] logical pixels and [textScale].
///
/// The height is deliberately generous: this harness is looking for
/// **horizontal** overflow and for rows that collide, not for the fact that a
/// long page needs scrolling.
Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  required double width,
  required double textScale,
  Brightness brightness = Brightness.light,
  bool signedIn = true,
  List<Override> extraOverrides = const [],
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [...screenOverrides(signedIn: signedIn), ...extraOverrides],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: flowSenseTheme(brightness: brightness),
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(textScale),
        ),
        child: screen,
      ),
    ),
  ));

  // Discrete pumps rather than pumpAndSettle: some screens carry an
  // indeterminate progress indicator, and the map's tile layer never settles
  // offline.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return container;
}

/// Asserts nothing overflowed, naming the size that broke it.
///
/// `RenderFlex overflowed` is thrown during layout and paint, so
/// `takeException` is what catches it. A finder that still locates the widget
/// proves nothing — which is exactly how a bottom-nav label truncated to
/// `Ove` passes every test that only looks for the widget.
void expectNoOverflow(
  WidgetTester tester, {
  required String screen,
  required double width,
  required double textScale,
}) {
  final error = tester.takeException();
  expect(
    error,
    isNull,
    reason: '$screen overflowed at ${width.toInt()}px, textScale $textScale\n'
        '$error',
  );
}
