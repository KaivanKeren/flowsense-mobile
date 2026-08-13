import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/data/api/flowsense_api.dart';
import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/data/models/traffic_snapshot.dart';
import 'package:flowsense_mobile/data/prefs/app_mode_store.dart';
import 'package:flowsense_mobile/features/langganan/langganan_screen.dart';
import 'package:flowsense_mobile/state/app_mode_providers.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _t0 = DateTime.utc(2026, 8, 2, 12);

class _ScriptedApi implements FlowSenseApi {
  @override
  Future<TrafficSnapshot> snapshot() async => TrafficSnapshot.empty(_t0);

  @override
  Future<List<Intersection>> intersections() async => const [
        Intersection(
          id: '30',
          name: 'Simpang DPRD',
          lat: -6.8047,
          lon: 110.8405,
          lanes: ['kota', 'ploso'],
          capacity: {'kota': 10, 'ploso': 10},
        ),
        Intersection(
          id: '31',
          name: 'Simpang Tujuh',
          lat: -6.8112,
          lon: 110.8348,
          lanes: ['barat'],
          capacity: {'barat': 10},
        ),
      ];

  @override
  Future<List<TrafficRecord>> history(
    String id, {
    DateTime? from,
    DateTime? to,
    String bucket = '1m',
  }) async =>
      const [];

  @override
  void close() {}
}

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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('LanggananScreen at 360x800', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(_ScriptedApi()),
        appModeStoreProvider.overrideWithValue(FakeAppModeStore()),
      ],
      child: MaterialApp(
        theme: flowSenseTheme(),
        debugShowCheckedModeBanner: false,
        home: const LanggananScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LanggananScreen),
      matchesGoldenFile('langganan_screen.png'),
    );
  });
}
