import 'dart:typed_data';

import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/core/max_width.dart';
import 'package:flowsense_mobile/data/api/flowsense_api.dart';
import 'package:flowsense_mobile/data/location/location_source.dart';
import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/data/models/traffic_snapshot.dart';
import 'package:flowsense_mobile/features/langganan/langganan_screen.dart';
import 'package:flowsense_mobile/features/map/map_screen.dart';
import 'package:flowsense_mobile/features/shell/warga_shell.dart';
import 'package:flowsense_mobile/features/simpang/simpang_screen.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _t0 = DateTime.utc(2026, 8, 2, 12);

final _blankPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _BlankTileProvider extends TileProvider {
  @override
  ImageProvider<Object> getImage(
          TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_blankPng);
}

const _intersections = [
  Intersection(
    id: '30',
    name: 'Simpang DPRD',
    lat: -6.8047,
    lon: 110.8405,
    lanes: ['kota'],
    capacity: {'kota': 10},
  ),
];

class _StubApi implements FlowSenseApi {
  @override
  Future<TrafficSnapshot> snapshot() async =>
      TrafficSnapshot(fetchedAt: _t0, records: [
        TrafficRecord(
          ts: _t0,
          cameraId: '30',
          cameraName: 'Simpang DPRD',
          totalVehicles: 4,
          perLane: const {'kota': 4},
        ),
      ]);

  @override
  Future<List<Intersection>> intersections() async => _intersections;

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

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiProvider.overrideWithValue(_StubApi()),
      appConfigProvider.overrideWithValue(const AppConfig(
        apiBase: 'https://x.test',
        apiKey: 'k',
        laneCapacityDefault: 10,
      )),
      clockProvider.overrideWithValue(FakeClock(_t0)),
      snapshotCacheProvider.overrideWithValue(null),
      locationSourceProvider.overrideWithValue(FakeLocationSource()),
    ],
    child: MaterialApp(
      theme: flowSenseTheme(),
      home: WargaShell(mapTileProvider: _BlankTileProvider()),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('opens on the map', (tester) async {
    await _pump(tester);
    expect(find.byType(MapScreen), findsOneWidget);
  });

  testWidgets('the map is actually visible, not a zero-size box',
      (tester) async {
    // The shell runs MapScreen inside an IndexedStack, which the map's own
    // tests never exercise. A screen that is present in the widget tree but
    // laid out at 0x0 looks, on a device, exactly like a missing screen.
    await _pump(tester);

    final map = tester.getSize(find.byType(FlutterMap));
    final shell = tester.getSize(find.byType(WargaShell));

    expect(map.width, greaterThan(0), reason: 'map has width');
    expect(map.height, greaterThan(0), reason: 'map has height');
    expect(map.height, greaterThan(shell.height * 0.5),
        reason: 'the map is the canvas, not a strip');
  });

  testWidgets('has exactly three tabs, and not the two that were refused',
      (tester) async {
    await _pump(tester);

    expect(WargaTab.values, hasLength(3));
    expect(find.text('peta'), findsOneWidget);
    expect(find.text('simpang'), findsOneWidget);
    expect(find.text('notifikasi'), findsOneWidget);

    // Both turned up as autofill in the design tool's output and are refused
    // on purpose: reports need moderation, and there is no account.
    expect(find.text('laporan'), findsNothing);
    expect(find.text('profil'), findsNothing);
  });

  testWidgets('switches to the intersection list', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('simpang'));
    await tester.pumpAndSettle();

    expect(find.byType(SimpangScreen), findsOneWidget);
    expect(find.text('Simpang'), findsOneWidget); // the app bar title
  });

  testWidgets('switches to subscriptions', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('notifikasi'));
    await tester.pumpAndSettle();

    expect(find.byType(LanggananScreen), findsOneWidget);
    expect(find.text('Notifikasi'), findsOneWidget);
  });

  testWidgets('keeps each tab alive, so the map does not reload',
      (tester) async {
    await _pump(tester);

    // An IndexedStack rather than a swapped child: the map keeps its camera
    // position when a rider checks the list and comes back.
    await tester.tap(find.text('simpang'));
    await tester.pumpAndSettle();

    expect(find.byType(MapScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(SimpangScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets('Tentang is not in the tab bar', (tester) async {
    await _pump(tester);
    expect(find.text('tentang'), findsNothing);
  });

  testWidgets('every tab caps its content at 448 px, tab bar included',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester);

    for (final tab in ['peta', 'simpang', 'notifikasi']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();

      final caps = find.byType(MaxWidth448);
      expect(caps, findsWidgets, reason: '$tab wraps its content');

      // The ConstrainedBox inside each cap is what actually holds the line.
      final boxes = find.descendant(
        of: caps,
        matching: find.byType(ConstrainedBox),
      );
      for (final element in boxes.evaluate()) {
        expect(
          (element.renderObject! as RenderBox).size.width,
          lessThanOrEqualTo(448.0),
          reason: '$tab content stays within the mobile-first ceiling',
        );
      }
    }
  });
}
