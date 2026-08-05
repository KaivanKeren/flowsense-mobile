import 'dart:io';

import 'package:flowsense_mobile/app/flavor.dart';
import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/data/api/fake_flowsense_api.dart';
import 'package:flowsense_mobile/data/api/http_flowsense_api.dart';
import 'package:flowsense_mobile/features/alerts/notifier.dart';
import 'package:flowsense_mobile/features/common/feed_view.dart';
import 'package:flowsense_mobile/features/map/map_screen.dart';
import 'package:flowsense_mobile/features/operator/dashboard_screen.dart';
import 'package:flowsense_mobile/features/shell/warga_shell.dart';
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

Future<void> _pumpApp(WidgetTester tester, Flavor flavor,
    {AppConfig config = _configured}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      apiProvider.overrideWithValue(_api()),
      clockProvider.overrideWithValue(FakeClock(_t0)),
      snapshotCacheProvider.overrideWithValue(null),
      // The warga shell wires up jam alerts. Nothing here should reach a
      // platform channel, and this makes that a guarantee rather than a hope.
      alertNotifierProvider.overrideWithValue(FakeAlertNotifier()),
    ],
    child: FlowSenseApp(flavor: flavor),
  ));

  // Discrete pumps, not pumpAndSettle: the warga flavor builds the real
  // MapScreen, whose OSM tile layer never reaches a settled state offline.
  await tester.pump();
  await tester.pump();
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

  testWidgets('the warga flavor lands on the map, inside the shell',
      (tester) async {
    await _pumpApp(tester, Flavor.warga);

    expect(find.byType(WargaShell), findsOneWidget);
    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
  });

  testWidgets('the warga shell carries exactly three tabs', (tester) async {
    await _pumpApp(tester, Flavor.warga);

    // Three, and only three. `Laporan` and `Profil` are refused on purpose.
    expect(find.text('peta'), findsOneWidget);
    expect(find.text('simpang'), findsOneWidget);
    expect(find.text('langganan'), findsOneWidget);
    expect(find.text('laporan'), findsNothing);
    expect(find.text('profil'), findsNothing);
  });

  testWidgets('warga is light-only, by decision', (tester) async {
    await _pumpApp(tester, Flavor.warga);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.darkTheme, isNull);
    expect(app.themeMode, ThemeMode.light);
  });

  testWidgets('the operator flavor lands on the dashboard', (tester) async {
    await _pumpApp(tester, Flavor.operator);

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(MapScreen), findsNothing);
    expect(find.text('Papan operator'), findsOneWidget);
  });

  testWidgets('a configured build shows no demo badge', (tester) async {
    await _pumpApp(tester, Flavor.operator);
    expect(find.byType(DemoBadge), findsNothing);
  });

  testWidgets('running on fixtures says so in the app bar', (tester) async {
    // Degrading to fixtures keeps the demo alive; doing it silently would pass
    // canned numbers off as live traffic.
    await _pumpApp(tester, Flavor.operator, config: const AppConfig());

    expect(find.byType(DemoBadge), findsOneWidget);
    expect(find.text('Data contoh'), findsOneWidget);
  });

  testWidgets('the warga flavor says so too', (tester) async {
    await _pumpApp(tester, Flavor.warga, config: const AppConfig());
    expect(find.byType(DemoBadge), findsOneWidget);
  });
}
