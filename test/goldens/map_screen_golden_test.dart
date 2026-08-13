import 'dart:io';
import 'dart:typed_data';

import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/data/api/flowsense_api.dart';
import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/data/models/traffic_snapshot.dart';
import 'package:flowsense_mobile/features/map/map_screen.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 8, 2, 12);

/// A 1x1 transparent PNG, so the golden never reaches for an OSM tile.
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
    lanes: ['kota', 'ploso'],
    capacity: {'kota': 10, 'ploso': 10},
  ),
  Intersection(
    id: '31',
    name: 'Simpang Tanjung',
    lat: -6.8112,
    lon: 110.8348,
    lanes: ['utara', 'selatan'],
    capacity: {'utara': 10, 'selatan': 10},
  ),
];

class _ScriptedApi implements FlowSenseApi {
  @override
  Future<TrafficSnapshot> snapshot() async => TrafficSnapshot(
        fetchedAt: _t0,
        records: [
          TrafficRecord(
            ts: _t0,
            cameraId: '30',
            cameraName: 'Simpang DPRD',
            totalVehicles: 2,
            perLane: {'kota': 1, 'ploso': 1},
          ),
          TrafficRecord(
            ts: _t0,
            cameraId: '31',
            cameraName: 'Simpang Tanjung',
            totalVehicles: 10,
            perLane: {'utara': 9, 'selatan': 1},
          ),
        ],
      );

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

  testWidgets('MapScreen at 360x800', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(_ScriptedApi()),
        appConfigProvider.overrideWithValue(const AppConfig(
          apiBase: 'https://x.test',
          apiKey: 'k',
          laneCapacityDefault: 10,
        )),
        clockProvider.overrideWithValue(FakeClock(_t0)),
        snapshotCacheProvider.overrideWithValue(null),
      ],
      child: MaterialApp(
        theme: flowSenseTheme(),
        debugShowCheckedModeBanner: false,
        home: MapScreen(tileProvider: _BlankTileProvider()),
      ),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MapScreen),
      matchesGoldenFile('map_screen.png'),
    );
  });
}
