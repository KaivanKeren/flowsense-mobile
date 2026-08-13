import 'dart:io';

import 'package:flowsense_mobile/app/bootstrap.dart';
import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/data/api/fake_flowsense_api.dart';
import 'package:flowsense_mobile/data/api/http_flowsense_api.dart';
import 'package:flowsense_mobile/data/auth/fake_auth_api.dart';
import 'package:flowsense_mobile/data/auth/token_store.dart';
import 'package:flowsense_mobile/data/prefs/app_mode_store.dart';
import 'package:flowsense_mobile/domain/app_mode.dart';
import 'package:flowsense_mobile/features/alerts/notifier.dart';
import 'package:flowsense_mobile/features/common/feed_view.dart';
import 'package:flowsense_mobile/features/map/map_screen.dart';
import 'package:flowsense_mobile/features/operator/dashboard_screen.dart';
import 'package:flowsense_mobile/features/operator/login_screen.dart';
import 'package:flowsense_mobile/features/shell/warga_shell.dart';
import 'package:flowsense_mobile/state/app_mode_providers.dart';
import 'package:flowsense_mobile/state/auth_providers.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 8, 2, 12);

const _configured = AppConfig(apiBase: 'https://x.test', apiKey: 'k');

/// Reads the fixtures off disk rather than through `rootBundle`: inside
/// `testWidgets` the asset bundle's I/O never completes, because the body runs
/// in a fake-async zone. `fromFixtures` is covered in fake_flowsense_api_test.
FakeFlowSenseApi _api() => FakeFlowSenseApi.fromStrings(
      intersectionsJson:
          File('test/fixtures/intersections.json').readAsStringSync(),
      recordsJsonl: File('test/fixtures/records.jsonl').readAsStringSync(),
      now: () => _t0,
    );

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  AppMode mode, {
  AppConfig config = _configured,

  /// Operator only. A stored token means the gate opens onto the console;
  /// without one it opens onto the login screen, which is the whole point of
  /// the gate.
  bool signedIn = true,
}) async {
  final authApi = FakeAuthApi();
  final container = ProviderContainer(overrides: [
    appConfigProvider.overrideWithValue(config),
    apiProvider.overrideWithValue(_api()),
    clockProvider.overrideWithValue(FakeClock(_t0)),
    snapshotCacheProvider.overrideWithValue(null),
    // The warga shell wires up jam alerts. Nothing here should reach a
    // platform channel, and this makes that a guarantee rather than a hope.
    alertNotifierProvider.overrideWithValue(FakeAlertNotifier()),
    // Neither does the token store: `SecureTokenStore` would go to the
    // Keystore over a method channel.
    authApiProvider.overrideWithValue(authApi),
    tokenStoreProvider.overrideWithValue(
      FakeTokenStore(signedIn ? authApi.token : null),
    ),
    // Which side the last session left open. In the app this is
    // `shared_preferences`; here it is memory, and it is also what lets a test
    // start on the console.
    appModeStoreProvider.overrideWithValue(FakeAppModeStore(mode)),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const FlowSenseApp(),
  ));

  // Discrete pumps, not pumpAndSettle: warga builds the real MapScreen, whose
  // OSM tile layer never reaches a settled state offline.
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildApi talks HTTP when a backend is configured', () async {
    final api = await buildApi(_configured);
    addTearDown(api.close);
    expect(api, isA<HttpFlowSenseApi>());
  });

  test('buildApi degrades to fixtures rather than failing to start', () async {
    // No base URL, no key — the state a demo machine is in five minutes before
    // it is needed.
    final api = await buildApi(const AppConfig());
    addTearDown(api.close);

    expect(api, isA<FakeFlowSenseApi>());
    expect((await api.snapshot()).records, isNotEmpty);
  });

  testWidgets('warga mode lands on the map, inside the shell', (tester) async {
    await _pumpApp(tester, AppMode.warga);

    expect(find.byType(WargaShell), findsOneWidget);
    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
  });

  testWidgets('the warga shell carries exactly three tabs', (tester) async {
    await _pumpApp(tester, AppMode.warga);

    // Three, and only three. `Laporan` and `Profil` are refused on purpose.
    expect(find.text('peta'), findsOneWidget);
    expect(find.text('simpang'), findsOneWidget);
    expect(find.text('langganan'), findsOneWidget);
    expect(find.text('laporan'), findsNothing);
    expect(find.text('profil'), findsNothing);
  });

  testWidgets('warga is light-only, by decision', (tester) async {
    await _pumpApp(tester, AppMode.warga);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.darkTheme, isNull);
    expect(app.themeMode, ThemeMode.light);
  });

  testWidgets('the console follows the system theme', (tester) async {
    // Not a symmetric decision: only warga has a layout spec that rules dark
    // mode out. Switching mode has to move the theme with it, or the console
    // inherits a rule written for the citizen app.
    await _pumpApp(tester, AppMode.operator);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.darkTheme, isNotNull);
    expect(app.themeMode, ThemeMode.system);
  });

  testWidgets('a signed-in operator lands on the dashboard', (tester) async {
    await _pumpApp(tester, AppMode.operator);

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(MapScreen), findsNothing);
    // Twice over: the screen's own title, and its tab in the bar below.
    expect(find.text('Dashboard'), findsNWidgets(2));
  });

  testWidgets('a signed-out operator lands on login, not the console',
      (tester) async {
    // The console must never render before the session is checked: it would
    // start polling with no credentials and paper the screen in errors.
    await _pumpApp(tester, AppMode.operator, signedIn: false);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
  });

  testWidgets('warga mode has no login at all', (tester) async {
    // No account, no identity, no auth layer — for the citizen side that is a
    // deliberate deletion, not an omission.
    await _pumpApp(tester, AppMode.warga, signedIn: false);

    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(WargaShell), findsOneWidget);
  });

  group('switching sides', () {
    testWidgets('the console swaps to the citizen map and back',
        (tester) async {
      // The whole point of merging the two entry points: one install, and a
      // button in each direction.
      final container = await _pumpApp(tester, AppMode.operator);

      await tester.tap(find.text('Akun'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('switch-to-warga')));
      await tester.pump();
      await tester.pump();

      expect(container.read(appModeProvider), AppMode.warga);
      expect(find.byType(WargaShell), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);

      // And back, without asking for the password again.
      await container.read(appModeProvider.notifier).switchTo(AppMode.operator);
      await tester.pump();
      await tester.pump();

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('switching view keeps the session', (tester) async {
      // Distinct from `Keluar`, which is a different row and a different
      // decision: an operator who looks at the citizen map should not have to
      // re-authenticate to come back.
      final container = await _pumpApp(tester, AppMode.operator);

      await tester.tap(find.text('Akun'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('switch-to-warga')));
      await tester.pump();
      await tester.pump();

      expect(container.read(authProvider), isA<AuthSignedIn>());
    });

    testWidgets('someone without an account is not stranded on the login form',
        (tester) async {
      // Anyone can press `Masuk sebagai operator`; the gate is what stops
      // them, and this is the way back out.
      final container = await _pumpApp(
        tester,
        AppMode.operator,
        signedIn: false,
      );
      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('back-to-warga')));
      await tester.pump();
      await tester.pump();

      expect(container.read(appModeProvider), AppMode.warga);
      expect(find.byType(WargaShell), findsOneWidget);
    });

    testWidgets('the choice is remembered for the next cold start',
        (tester) async {
      final store = FakeAppModeStore(AppMode.warga);
      final container = ProviderContainer(overrides: [
        appModeStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);

      await container.read(appModeProvider.notifier).switchTo(AppMode.operator);

      expect(await store.load(), AppMode.operator);
    });

    testWidgets('a restore landing late never undoes a deliberate switch',
        (tester) async {
      // `build` returns warga immediately and the stored value arrives after;
      // a switch made in between is the user's, and wins.
      final container = ProviderContainer(overrides: [
        appModeStoreProvider.overrideWithValue(FakeAppModeStore(AppMode.warga)),
      ]);
      addTearDown(container.dispose);

      expect(container.read(appModeProvider), AppMode.warga);
      await container.read(appModeProvider.notifier).switchTo(AppMode.operator);
      await tester.pump();

      expect(container.read(appModeProvider), AppMode.operator);
    });
  });

  testWidgets('a configured build shows no demo badge', (tester) async {
    await _pumpApp(tester, AppMode.operator);
    expect(find.byType(DemoBadge), findsNothing);
  });

  testWidgets('running on fixtures says so in the app bar', (tester) async {
    // Degrading to fixtures keeps the demo alive; doing it silently would pass
    // canned numbers off as live traffic.
    await _pumpApp(tester, AppMode.operator, config: const AppConfig());

    expect(find.byType(DemoBadge), findsOneWidget);
    expect(find.text('Data contoh'), findsOneWidget);
  });

  testWidgets('warga mode says so too', (tester) async {
    await _pumpApp(tester, AppMode.warga, config: const AppConfig());
    expect(find.byType(DemoBadge), findsOneWidget);
  });
}
