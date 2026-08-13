import 'dart:io';

import 'package:flowsense_mobile/app/bootstrap.dart';
import 'package:flowsense_mobile/data/api/fake_flowsense_api.dart';
import 'package:flowsense_mobile/state/alert_providers.dart';
import 'package:flowsense_mobile/state/health_providers.dart';
import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/data/alerts/alerts_api.dart';
import 'package:flowsense_mobile/data/auth/fake_auth_api.dart';
import 'package:flowsense_mobile/data/auth/token_store.dart';
import 'package:flowsense_mobile/data/health/health_api.dart';
import 'package:flowsense_mobile/data/prefs/app_mode_store.dart';
import 'package:flowsense_mobile/domain/app_mode.dart';
import 'package:flowsense_mobile/state/app_mode_providers.dart';
import 'package:flowsense_mobile/features/operator/akun_screen.dart';
import 'package:flowsense_mobile/features/operator/kesehatan_screen.dart';
import 'package:flowsense_mobile/features/operator/peringatan_screen.dart';
import 'package:flowsense_mobile/state/auth_providers.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the app assembles for itself when no backend is configured.
///
/// Every other test seeds its own fakes, which is exactly how the console
/// shipped with two permanently empty tabs while the suite stayed green: the
/// screens were tested, the **wiring that feeds them** was not. This file
/// exercises `demoOverrides` — the real startup path — and nothing else.
final _t0 = DateTime.utc(2026, 8, 2, 12);

/// The demo fixtures, read once through the asset bundle.
///
/// Loaded in `setUpAll` rather than inside a test body: `rootBundle` I/O never
/// completes inside `testWidgets`, whose body runs in a fake-async zone. The
/// plain `test` cases below still call `demoOverrides` directly — that is what
/// pins the wiring; these strings only let the widget cases render the same
/// data.
late final String _alertsJson;
late final String _connectorsJson;

Future<ProviderContainer> _pumpDemoConsole(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  const config = AppConfig();
  final authApi = FakeAuthApi();

  final container = ProviderContainer(overrides: [
    appConfigProvider.overrideWithValue(config),
    apiProvider.overrideWithValue(FakeFlowSenseApi.fromStrings(
      intersectionsJson:
          File('test/fixtures/intersections.json').readAsStringSync(),
      recordsJsonl: File('test/fixtures/records.jsonl').readAsStringSync(),
      demoJson: File('test/fixtures/demo.json').readAsStringSync(),
      now: () => _t0,
    )),
    // Built from the same fixtures `demoOverrides` loads, fresh per test so
    // one test acknowledging an alert cannot leak into the next.
    alertsApiProvider.overrideWithValue(
      FakeAlertsApi.fromJson(_alertsJson, now: () => _t0),
    ),
    healthApiProvider.overrideWithValue(
      FakeHealthApi.fromJson(_connectorsJson, now: () => _t0),
    ),
    clockProvider.overrideWithValue(FakeClock(_t0)),
    snapshotCacheProvider.overrideWithValue(null),
    authApiProvider.overrideWithValue(authApi),
    tokenStoreProvider.overrideWithValue(FakeTokenStore(authApi.token)),
    appModeStoreProvider.overrideWithValue(FakeAppModeStore(AppMode.operator)),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const FlowSenseApp(),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _alertsJson = await rootBundle.loadString('test/fixtures/alerts.json');
    _connectorsJson =
        await rootBundle.loadString('test/fixtures/connectors.json');
  });

  group('appOverrides', () {
    /// Whether a provider actually gets an override, by installing the list in
    /// a container and checking what comes back — reading the list's shape
    /// would only prove it has the right length.
    Future<bool> isOverridden(
      List<Override> overrides,
      Object Function(ProviderContainer) read,
    ) async {
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);
      final value = read(container);
      // The default fakes are empty; a supplied one is not.
      if (value is FakeAlertsApi) return (await value.alerts()).isNotEmpty;
      if (value is FakeHealthApi) return (await value.connectors()).isNotEmpty;
      return false;
    }

    test('a demo build gets alerts and connector health, not just traffic',
        () async {
      // The regression this file exists for: `buildApi` alone left Kesehatan
      // and Peringatan permanently empty on a device.
      final overrides = await appOverrides(const AppConfig());

      expect(
        await isOverridden(overrides, (c) => c.read(alertsApiProvider)),
        isTrue,
        reason: 'alerts are supplied',
      );
      expect(
        await isOverridden(overrides, (c) => c.read(healthApiProvider)),
        isTrue,
        reason: 'connector health is supplied',
      );
    });

    test('a configured build is given no demo data at all', () async {
      final overrides = await appOverrides(
        const AppConfig(apiBase: 'https://x.test', apiKey: 'k'),
      );

      expect(
        await isOverridden(overrides, (c) => c.read(alertsApiProvider)),
        isFalse,
      );
      expect(
        await isOverridden(overrides, (c) => c.read(healthApiProvider)),
        isFalse,
      );
    });

    test('supplies alerts and connector health when unconfigured', () async {
      final overrides = await demoOverrides(const AppConfig());
      expect(overrides, hasLength(2));
    });

    test('supplies nothing once a real backend is configured', () async {
      // Demo data must never be mixed in with live records.
      final overrides = await demoOverrides(
        const AppConfig(apiBase: 'https://x.test', apiKey: 'k'),
      );
      expect(overrides, isEmpty);
    });

    test('the fixtures actually contain something', () async {
      final alerts = await FakeAlertsApi.fromFixtures(now: () => _t0);
      final health = await FakeHealthApi.fromFixtures(now: () => _t0);

      expect(await alerts.alerts(), isNotEmpty);
      expect(await health.connectors(), isNotEmpty);
    });

    test('alert times are relative, so a demo is never born stale', () async {
      final alerts = await FakeAlertsApi.fromFixtures(now: () => _t0);
      final raised = (await alerts.alerts()).first.raisedAt;

      // Within a day of "now", whenever now happens to be.
      expect(_t0.difference(raised).inHours, lessThan(24));
    });

    test('at least one alert is left unacknowledged', () async {
      // Otherwise the dashboard's `Akui` button — one of only two writes the
      // console has — cannot be demonstrated at all.
      final alerts = await FakeAlertsApi.fromFixtures(now: () => _t0);
      expect((await alerts.alerts()).any((a) => !a.isAcknowledged), isTrue);
    });

    test('the stopped connector matches the stalled camera in demo.json',
        () async {
      // The dashboard and the health screen have to agree about which
      // connector is dead, or the console contradicts itself on two tabs.
      final health = await FakeHealthApi.fromFixtures(now: () => _t0);
      final stopped = (await health.connectors())
          .where((c) => c.status.needsAttention)
          .map((c) => c.cameraId);

      expect(stopped, contains('34'));
    });
  });

  group('the console a demo actually opens', () {
    testWidgets('the dashboard has an alert to acknowledge', (tester) async {
      await _pumpDemoConsole(tester);

      expect(find.text('Tidak ada peringatan aktif'), findsNothing);
      expect(find.text('Akui'), findsWidgets);
    });

    testWidgets('Kesehatan lists connectors', (tester) async {
      await _pumpDemoConsole(tester);

      await tester.tap(find.text('Kesehatan'));
      await tester.pumpAndSettle();

      expect(find.byType(KesehatanScreen), findsOneWidget);
      expect(find.text('Belum ada connector terdaftar.'), findsNothing);
      expect(find.textContaining('Kamera 30'), findsOneWidget);
      expect(find.text('Berhenti'), findsOneWidget);
    });

    testWidgets('Peringatan lists alerts', (tester) async {
      await _pumpDemoConsole(tester);

      await tester.tap(find.text('Peringatan'));
      await tester.pumpAndSettle();

      expect(find.byType(PeringatanScreen), findsOneWidget);
      expect(
        find.text('Tidak ada peringatan pada rentang ini.'),
        findsNothing,
      );
      expect(find.text('Belum diakui'), findsWidgets);
    });

    testWidgets('Akun knows who is signed in', (tester) async {
      await _pumpDemoConsole(tester);

      await tester.tap(find.text('Akun'));
      await tester.pumpAndSettle();

      expect(find.byType(AkunScreen), findsOneWidget);
      expect(find.text('Operator Dinas'), findsOneWidget);
    });

    testWidgets('every tab has content — none is silently empty',
        (tester) async {
      await _pumpDemoConsole(tester);

      for (final tab in ['Kesehatan', 'Peringatan']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();

        // The three ways a screen in this console says "nothing here".
        for (final empty in [
          'Belum ada connector terdaftar.',
          'Tidak ada peringatan pada rentang ini.',
          'Belum ada data masuk dari simpang mana pun.',
        ]) {
          expect(find.text(empty), findsNothing, reason: '$tab: $empty');
        }
      }
    });
  });
}
