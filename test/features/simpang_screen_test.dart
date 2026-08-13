import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/data/api/flowsense_api.dart';
import 'package:flowsense_mobile/data/location/location_source.dart';
import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/data/models/traffic_snapshot.dart';
import 'package:flowsense_mobile/features/simpang/simpang_screen.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flowsense_mobile/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 8, 2, 12);

final _intersections = [
  // Deliberately declared in an order that is neither worst-first nor
  // nearest-first, so a passing sort test cannot be an accident.
  const Intersection(
    id: '32',
    name: 'Simpang Jati',
    lat: -6.7983,
    lon: 110.8461,
    lanes: ['kudus'],
    capacity: {'kudus': 10},
  ),
  const Intersection(
    id: '30',
    name: 'Simpang DPRD',
    lat: -6.8047,
    lon: 110.8405,
    lanes: ['kota'],
    capacity: {'kota': 10},
  ),
  const Intersection(
    id: '31',
    name: 'Simpang Tujuh',
    lat: -6.8089,
    lon: 110.8372,
    lanes: ['barat'],
    capacity: {'barat': 10},
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

Future<void> _pump(
  WidgetTester tester, {
  required TrafficSnapshot snapshot,
  DeviceLocation? location,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiProvider.overrideWithValue(_ScriptedApi(snapshot)),
      appConfigProvider.overrideWithValue(const AppConfig(
        apiBase: 'https://x.test',
        apiKey: 'k',
        laneCapacityDefault: 10,
      )),
      clockProvider.overrideWithValue(FakeClock(_t0)),
      snapshotCacheProvider.overrideWithValue(null),
      locationSourceProvider
          .overrideWithValue(FakeLocationSource(location: location)),
    ],
    child: MaterialApp(
      theme: flowSenseTheme(),
      home: const SimpangScreen(),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Row titles in rendered order.
List<String> _names(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data)
    .whereType<String>()
    .where((s) => s.startsWith('Simpang '))
    .toList();

TrafficSnapshot _mixed() => TrafficSnapshot(fetchedAt: _t0, records: [
      _record('32', {'kudus': 1}), // lancar
      _record('30', {'kota': 9}), //  macet
      _record('31', {'barat': 5}), // padat
    ]);

void main() {
  testWidgets('sorts worst-first by default', (tester) async {
    await _pump(tester, snapshot: _mixed());

    expect(_names(tester), [
      'Simpang DPRD', // macet
      'Simpang Tujuh', // padat
      'Simpang Jati', // lancar
    ]);
  });

  testWidgets('a camera with no record sorts last, not first', (tester) async {
    // Unknown must never top a worst-first list, but it is not free flow
    // either — it simply cannot be ranked.
    await _pump(
      tester,
      snapshot: TrafficSnapshot(fetchedAt: _t0, records: [
        _record('30', {'kota': 1}),
        _record('31', {'barat': 1}),
      ]),
    );

    expect(_names(tester).last, 'Simpang Jati');
  });

  testWidgets('each row carries count, age and status', (tester) async {
    await _pump(tester, snapshot: _mixed());

    expect(find.textContaining('9 kendaraan'), findsOneWidget);
    expect(find.textContaining('baru saja'), findsWidgets);
    expect(find.widgetWithText(StatusChip, 'Macet'), findsOneWidget);
    expect(find.widgetWithText(StatusChip, 'Padat'), findsOneWidget);
    expect(find.widgetWithText(StatusChip, 'Lancar'), findsOneWidget);
  });

  testWidgets('a stale row reads Data basi and says how old it is',
      (tester) async {
    await _pump(
      tester,
      snapshot: TrafficSnapshot(fetchedAt: _t0, records: [
        _record('30', {'kota': 9},
            ts: _t0.subtract(const Duration(minutes: 4))),
        _record('31', {'barat': 1}),
        _record('32', {'kudus': 1}),
      ]),
    );

    expect(find.widgetWithText(StatusChip, 'Data basi'), findsOneWidget);
    expect(find.textContaining('4 menit lalu'), findsOneWidget);
  });

  group('location', () {
    testWidgets('with no fix, distance is hidden and nearest is not offered',
        (tester) async {
      await _pump(tester, snapshot: _mixed());

      // The list still works. That is the whole requirement.
      expect(find.text('Terparah dulu'), findsOneWidget);
      expect(find.text('Terdekat dulu'), findsNothing);
      expect(find.textContaining(' km'), findsNothing);
      expect(_names(tester), hasLength(3));
    });

    testWidgets('with a fix, distance renders and nearest can be chosen',
        (tester) async {
      await _pump(
        tester,
        snapshot: _mixed(),
        // Sitting on Simpang Jati.
        location: const DeviceLocation(lat: -6.7983, lon: 110.8461),
      );

      expect(find.text('Terdekat dulu'), findsOneWidget);
      expect(find.textContaining(' m'), findsWidgets);

      await tester.tap(find.text('Terdekat dulu'));
      await tester.pumpAndSettle();

      expect(_names(tester).first, 'Simpang Jati');
    });

    testWidgets('switching back to worst-first still works', (tester) async {
      await _pump(
        tester,
        snapshot: _mixed(),
        location: const DeviceLocation(lat: -6.7983, lon: 110.8461),
      );

      await tester.tap(find.text('Terdekat dulu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terparah dulu'));
      await tester.pumpAndSettle();

      expect(_names(tester).first, 'Simpang DPRD');
    });
  });

  testWidgets('every row is readable by a screen reader', (tester) async {
    // The reason this screen is a peer of the map rather than a supplement:
    // TalkBack cannot read a map, and this carries the same facts.
    await _pump(tester, snapshot: _mixed());

    expect(
      find.bySemanticsLabel(RegExp(r'Simpang DPRD, macet, 9 kendaraan')),
      findsOneWidget,
    );
  });

  testWidgets('an empty snapshot renders the failure state, not a spinner',
      (tester) async {
    await _pump(tester, snapshot: TrafficSnapshot.empty(_t0));

    expect(
      find.text('Belum ada data masuk dari simpang mana pun.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('content is capped at the 448 px mobile-first width',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, snapshot: _mixed());

    expect(tester.getSize(find.byType(ListView)).width, lessThanOrEqualTo(448));
  });
}
