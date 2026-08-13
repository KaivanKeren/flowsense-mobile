import 'dart:typed_data';

import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/data/api/fake_flowsense_api.dart';
import 'package:flowsense_mobile/data/api/flowsense_api.dart';
import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/data/models/traffic_snapshot.dart';
import 'package:flowsense_mobile/domain/congestion.dart';
import 'package:flowsense_mobile/features/detail/intersection_sheet.dart';
import 'package:flowsense_mobile/features/map/intersection_marker.dart';
import 'package:flowsense_mobile/features/map/map_screen.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flowsense_mobile/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 8, 2, 12);

/// A 1x1 transparent PNG, so no widget test ever reaches for an OSM tile.
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

final _intersections = [
  const Intersection(
    id: '30',
    name: 'Simpang DPRD',
    lat: -6.8047,
    lon: 110.8405,
    lanes: ['kota', 'ploso'],
    capacity: {'kota': 10, 'ploso': 10},
  ),
  const Intersection(
    id: '31',
    name: 'Simpang Tanjung',
    lat: -6.8112,
    lon: 110.8348,
    lanes: ['utara', 'selatan'],
    capacity: {'utara': 10, 'selatan': 10},
  ),
];

TrafficRecord _record(String id, Map<String, int> perLane, {DateTime? ts}) =>
    TrafficRecord(
      ts: ts ?? _t0,
      cameraId: id,
      cameraName: 'Simpang $id',
      totalVehicles: perLane.values.fold(0, (a, b) => a + b),
      perLane: perLane,
    );

/// Serves one fixed state forever, so a widget test asserts on exactly the
/// situation it names.
class _ScriptedApi implements FlowSenseApi {
  _ScriptedApi(this.snapshotToServe);

  final TrafficSnapshot snapshotToServe;

  @override
  Future<TrafficSnapshot> snapshot() async => snapshotToServe;

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

Future<void> _pumpMap(
  WidgetTester tester, {
  required FlowSenseApi api,
  DateTime? now,
  Duration staleAfter = const Duration(seconds: 30),
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiProvider.overrideWithValue(api),
      appConfigProvider.overrideWithValue(AppConfig(
        apiBase: 'https://x.test',
        apiKey: 'k',
        staleAfter: staleAfter,
        laneCapacityDefault: 10,
      )),
      clockProvider.overrideWithValue(FakeClock(now ?? _t0)),
      snapshotCacheProvider.overrideWithValue(null),
    ],
    child: MaterialApp(
      theme: flowSenseTheme(),
      home: MapScreen(tileProvider: _BlankTileProvider()),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders one marker per intersection, carrying its level',
      (tester) async {
    await _pumpMap(
      tester,
      api: _ScriptedApi(TrafficSnapshot(fetchedAt: _t0, records: [
        _record('30', {'kota': 1, 'ploso': 1}), // 0.1 -> lancar
        _record('31', {'utara': 9, 'selatan': 1}), // 0.9 -> macet
      ])),
    );

    final markers = tester
        .widgetList<IntersectionMarker>(find.byType(IntersectionMarker))
        .toList();

    expect(markers, hasLength(2));
    expect(markers.firstWhere((m) => m.intersection.id == '30').level,
        CongestionLevel.lancar);
    expect(markers.firstWhere((m) => m.intersection.id == '31').level,
        CongestionLevel.macet);
    expect(markers.every((m) => m.isStale), isFalse);
  });

  testWidgets('tapping a marker opens the sheet with that lane breakdown',
      (tester) async {
    await _pumpMap(
      tester,
      api: _ScriptedApi(TrafficSnapshot(fetchedAt: _t0, records: [
        _record('30', {'kota': 4, 'ploso': 2}),
        _record('31', {'utara': 1, 'selatan': 1}),
      ])),
    );

    await tester.tap(find.bySemanticsLabel(RegExp('Simpang DPRD')));
    await tester.pumpAndSettle();

    expect(find.byType(IntersectionSheet), findsOneWidget);
    expect(find.text('Simpang DPRD'), findsOneWidget);

    // The compact stage answers the only question a rider has, with no
    // further gesture: how bad, how old, and which approach.
    expect(find.text('6 kendaraan · baru saja'), findsOneWidget);
    expect(find.text('Arah kota paling padat'), findsOneWidget);

    // The lane breakdown belongs to this camera, not its neighbour.
    expect(find.byKey(const ValueKey('lane-kota')), findsOneWidget);
    expect(find.byKey(const ValueKey('lane-ploso')), findsOneWidget);
    expect(find.byKey(const ValueKey('lane-utara')), findsNothing);
  });

  testWidgets('the sheet opens at the compact snap size', (tester) async {
    await _pumpMap(
      tester,
      api: _ScriptedApi(TrafficSnapshot(fetchedAt: _t0, records: [
        _record('30', {'kota': 4, 'ploso': 2}),
      ])),
    );

    await tester.tap(find.bySemanticsLabel(RegExp('Simpang DPRD')));
    await tester.pumpAndSettle();

    final sheetHeight = tester.getSize(find.byType(IntersectionSheet)).height;
    final screenHeight = tester.getSize(find.byType(MapScreen)).height;
    expect(sheetHeight / screenHeight, closeTo(0.28, 0.02));
  });

  testWidgets('a stale snapshot shows the banner and greys the markers',
      (tester) async {
    await _pumpMap(
      tester,
      api: _ScriptedApi(TrafficSnapshot(fetchedAt: _t0, records: [
        _record('30', {'kota': 1, 'ploso': 1},
            ts: _t0.subtract(const Duration(minutes: 2))),
        _record('31', {'utara': 9, 'selatan': 1},
            ts: _t0.subtract(const Duration(minutes: 2))),
      ])),
    );

    expect(find.byType(StaleNotice), findsOneWidget);
    expect(find.textContaining('Data terakhir 2 menit lalu'), findsOneWidget);

    final markers =
        tester.widgetList<IntersectionMarker>(find.byType(IntersectionMarker));
    expect(markers.every((m) => m.isStale), isTrue);
    // Grey wins over the level colour while the data cannot be trusted.
    expect(
      IntersectionMarker.colorFor(
          CongestionColors.light, CongestionLevel.macet, isStale: true),
      CongestionColors.light.unknown,
    );
  });

  testWidgets('an error with a last good snapshot keeps the markers on screen',
      (tester) async {
    // First poll succeeds and populates lastGood; the fake then fails.
    final api = FakeFlowSenseApi(
      intersections: _intersections,
      records: [
        _record('30', {'kota': 1, 'ploso': 1}),
        _record('31', {'utara': 2, 'selatan': 2}),
      ],
      now: () => _t0,
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(api),
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
        home: MapScreen(tileProvider: _BlankTileProvider()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(IntersectionMarker), findsNWidgets(2));

    // Force a failing poll through the live repository.
    api.failNext = 1;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapScreen)),
      listen: false,
    );
    await container.read(repositoryProvider).poll();
    await tester.pumpAndSettle();

    expect(find.byType(StaleNotice), findsOneWidget);
    expect(find.byType(IntersectionMarker), findsNWidgets(2),
        reason: 'a failed poll must not blank the map');
  });

  testWidgets('an empty snapshot renders the empty state, not a spinner',
      (tester) async {
    await _pumpMap(
      tester,
      api: _ScriptedApi(TrafficSnapshot.empty(_t0)),
    );

    expect(
      find.text('Belum ada data masuk dari simpang mana pun.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(IntersectionMarker), findsNothing);
    // One sentence, one pressable button. Never an endless spinner.
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  testWidgets('OSM attribution is present — a licence obligation',
      (tester) async {
    await _pumpMap(
      tester,
      api: _ScriptedApi(TrafficSnapshot(fetchedAt: _t0, records: [
        _record('30', {'kota': 1, 'ploso': 1}),
      ])),
    );

    expect(find.byType(RichAttributionWidget), findsOneWidget);
  });

  testWidgets('content is capped at the 448 px mobile-first width',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpMap(
      tester,
      api: _ScriptedApi(TrafficSnapshot(fetchedAt: _t0, records: [
        _record('30', {'kota': 1, 'ploso': 1}),
      ])),
    );

    // A range, not a ceiling. `lessThanOrEqualTo(448)` is also satisfied by
    // zero, which is exactly how a collapsed Stack once passed this test while
    // the map was invisible on a real device.
    final size = tester.getSize(find.byType(FlutterMap));
    expect(size.width, inInclusiveRange(1, 448));
    expect(size.height, greaterThan(0));
  });

  testWidgets('the map fills the screen behind the sheet', (tester) async {
    // The bug this pins: every child of the screen's Stack is Positioned, and
    // MaxWidth448 hands it loose constraints — so without StackFit.expand the
    // whole body renders at 0x0 and only the tab bar is visible.
    await _pumpMap(
      tester,
      api: _ScriptedApi(TrafficSnapshot(fetchedAt: _t0, records: [
        _record('30', {'kota': 1, 'ploso': 1}),
      ])),
    );

    final map = tester.getSize(find.byType(FlutterMap));
    final screen = tester.getSize(find.byType(MapScreen));

    expect(map.height, greaterThan(screen.height * 0.5),
        reason: 'the map is the canvas, not a strip');
    expect(map.width, greaterThan(0));
  });
}
