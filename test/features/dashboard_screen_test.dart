import 'package:fl_chart/fl_chart.dart';
import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/data/api/fake_flowsense_api.dart';
import 'package:flowsense_mobile/data/api/flowsense_api.dart';
import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/data/models/traffic_snapshot.dart';
import 'package:flowsense_mobile/domain/congestion.dart';
import 'package:flowsense_mobile/features/common/stale_banner.dart';
import 'package:flowsense_mobile/features/operator/dashboard_screen.dart';
import 'package:flowsense_mobile/features/operator/history_chart.dart';
import 'package:flowsense_mobile/features/operator/lane_bars.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 8, 2, 12);

/// Capacity 10 everywhere, so a lane count reads straight off as a percentage:
/// 1 is lancar, 5 is padat, 9 is macet.
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
  Intersection(
    id: '32',
    name: 'Simpang Jember',
    lat: -6.7983,
    lon: 110.8461,
    lanes: ['terminal', 'pasar'],
    capacity: {'terminal': 10, 'pasar': 10},
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
  _ScriptedApi(this.snapshotToServe, {this.historyToServe = const []});

  final TrafficSnapshot snapshotToServe;
  final List<TrafficRecord> historyToServe;

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
      historyToServe;

  @override
  void close() {}
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required FlowSenseApi api,
  DateTime? now,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiProvider.overrideWithValue(api),
      appConfigProvider.overrideWithValue(const AppConfig(
        apiBase: 'https://x.test',
        apiKey: 'k',
        laneCapacityDefault: 10,
      )),
      clockProvider.overrideWithValue(FakeClock(now ?? _t0)),
      snapshotCacheProvider.overrideWithValue(null),
    ],
    child: MaterialApp(
      theme: flowSenseTheme(),
      home: const DashboardScreen(),
    ),
  ));
  await tester.pumpAndSettle();
}

/// The intersection names in the order the list actually rendered them.
List<String> _renderedOrder(WidgetTester tester) => tester
    .widgetList<IntersectionCard>(find.byType(IntersectionCard))
    .map((c) => c.status.intersection.name)
    .toList();

void main() {
  group('rankWorstFirst', () {
    List<CongestionLevel> levelsOf(TrafficSnapshot snapshot) => rankWorstFirst(
          intersections: _intersections,
          snapshot: snapshot,
          now: _t0,
          staleAfter: const Duration(seconds: 30),
          laneCapacityDefault: 10,
        ).map((s) => s.level).toList();

    test('macet sorts above padat sorts above lancar', () {
      expect(
        levelsOf(TrafficSnapshot(fetchedAt: _t0, records: [
          _record('30', {'kota': 1, 'ploso': 1}), // lancar
          _record('31', {'utara': 5, 'selatan': 1}), // padat
          _record('32', {'terminal': 9, 'pasar': 1}), // macet
        ])),
        [
          CongestionLevel.macet,
          CongestionLevel.padat,
          CongestionLevel.lancar,
        ],
      );
    });

    test('a camera with no record sorts last, not first', () {
      final ranked = rankWorstFirst(
        intersections: _intersections,
        snapshot: TrafficSnapshot(fetchedAt: _t0, records: [
          _record('30', {'kota': 1, 'ploso': 1}), // lancar
          _record('31', {'utara': 9, 'selatan': 1}), // macet
        ]),
        now: _t0,
        staleAfter: const Duration(seconds: 30),
        laneCapacityDefault: 10,
      );

      expect(ranked.map((s) => s.intersection.id), ['31', '30', '32']);
      expect(ranked.last.level, CongestionLevel.unknown,
          reason: 'a dead feed must never bury a real jam');
    });

    test('ties break on volume, then name, so the list holds still', () {
      final ranked = rankWorstFirst(
        intersections: _intersections,
        snapshot: TrafficSnapshot(fetchedAt: _t0, records: [
          _record('30', {'kota': 1, 'ploso': 1}), // lancar, 2
          _record('31', {'utara': 1, 'selatan': 1}), // lancar, 2
          _record('32', {'terminal': 3, 'pasar': 1}), // lancar, 4
        ]),
        now: _t0,
        staleAfter: const Duration(seconds: 30),
        laneCapacityDefault: 10,
      );

      // Jember leads on volume; DPRD and Tanjung tie and fall back to name.
      expect(ranked.map((s) => s.intersection.name), [
        'Simpang Jember',
        'Simpang DPRD',
        'Simpang Tanjung',
      ]);
    });
  });

  group('DashboardScreen', () {
    testWidgets('renders the list worst-first', (tester) async {
      await _pumpDashboard(
        tester,
        api: _ScriptedApi(TrafficSnapshot(fetchedAt: _t0, records: [
          _record('30', {'kota': 1, 'ploso': 1}), // lancar
          _record('31', {'utara': 5, 'selatan': 1}), // padat
          _record('32', {'terminal': 9, 'pasar': 1}), // macet
        ])),
      );

      expect(_renderedOrder(tester), [
        'Simpang Jember',
        'Simpang Tanjung',
        'Simpang DPRD',
      ]);
      expect(find.text('Macet'), findsNothing,
          reason: 'the level rides in a combined line, not a bare label');
      expect(find.textContaining('Macet · '), findsOneWidget);
    });

    testWidgets('per-lane bars render one row per key in per_lane',
        (tester) async {
      await _pumpDashboard(
        tester,
        api: _ScriptedApi(TrafficSnapshot(fetchedAt: _t0, records: [
          _record('30', {'kota': 4, 'ploso': 2}),
          _record('31', {'utara': 1, 'selatan': 1}),
          _record('32', {'terminal': 1, 'pasar': 1}),
        ])),
      );

      expect(find.byType(LaneBars), findsNWidgets(3));
      expect(find.text('kota'), findsOneWidget);
      expect(find.text('4/10'), findsOneWidget);
      expect(find.text('ploso'), findsOneWidget);
      expect(find.text('2/10'), findsOneWidget);
      // Six lanes across three intersections, each with its own bar.
      expect(find.byType(LinearProgressIndicator), findsNWidgets(6));
    });

    testWidgets('a lane appearing mid-session is rendered, not dropped',
        (tester) async {
      await _pumpDashboard(
        tester,
        api: _ScriptedApi(TrafficSnapshot(fetchedAt: _t0, records: [
          // `barat` is not in the intersection's declared lanes and has no
          // calibrated capacity — the connector added it after the geometry
          // was published, which it is allowed to do.
          _record('30', {'kota': 4, 'ploso': 2, 'barat': 7}),
          _record('31', {'utara': 1, 'selatan': 1}),
          _record('32', {'terminal': 1, 'pasar': 1}),
        ])),
      );

      expect(find.text('barat'), findsOneWidget);
      // Falls back to the configured default capacity rather than vanishing.
      expect(find.text('7/10'), findsOneWidget);
    });

    testWidgets('tapping a row charts its history', (tester) async {
      await _pumpDashboard(
        tester,
        api: _ScriptedApi(
          TrafficSnapshot(fetchedAt: _t0, records: [
            _record('30', {'kota': 9, 'ploso': 1}),
          ]),
          historyToServe: [
            for (var i = 10; i > 0; i--)
              _record('30', {'kota': i, 'ploso': 1},
                  ts: _t0.subtract(Duration(minutes: i))),
          ],
        ),
      );

      expect(find.byType(LineChart), findsNothing,
          reason: 'history is fetched only for the row the operator opens');

      await tester.tap(find.text('Simpang DPRD'));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryChart), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
      expect(find.text('Kendaraan per menit, satu jam terakhir'),
          findsOneWidget);
    });

    testWidgets('the history chart shows an empty state for zero points',
        (tester) async {
      await _pumpDashboard(
        tester,
        api: _ScriptedApi(
          TrafficSnapshot(fetchedAt: _t0, records: [
            _record('30', {'kota': 9, 'ploso': 1}),
          ]),
        ),
      );

      await tester.tap(find.text('Simpang DPRD'));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryChart), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
      expect(find.text('Belum ada riwayat satu jam terakhir.'), findsOneWidget);
    });

    testWidgets('the stale banner appears here too', (tester) async {
      await _pumpDashboard(
        tester,
        api: _ScriptedApi(TrafficSnapshot(fetchedAt: _t0, records: [
          _record('30', {'kota': 9, 'ploso': 1},
              ts: _t0.subtract(const Duration(minutes: 2))),
          _record('31', {'utara': 1, 'selatan': 1},
              ts: _t0.subtract(const Duration(minutes: 2))),
          _record('32', {'terminal': 1, 'pasar': 1},
              ts: _t0.subtract(const Duration(minutes: 2))),
        ])),
      );

      expect(find.byType(StaleBanner), findsOneWidget);
      expect(find.textContaining('Data terakhir 2 menit lalu'), findsOneWidget);
    });

    testWidgets('a failed poll keeps the rows on screen', (tester) async {
      final api = FakeFlowSenseApi(
        intersections: _intersections,
        records: [
          _record('30', {'kota': 1, 'ploso': 1}),
          _record('31', {'utara': 2, 'selatan': 2}),
          _record('32', {'terminal': 2, 'pasar': 2}),
        ],
        now: () => _t0,
      );

      await _pumpDashboard(tester, api: api);
      expect(find.byType(IntersectionCard), findsNWidgets(3));

      api.failNext = 1;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DashboardScreen)),
        listen: false,
      );
      await container.read(repositoryProvider).poll();
      await tester.pumpAndSettle();

      expect(find.byType(StaleBanner), findsOneWidget);
      expect(find.byType(IntersectionCard), findsNWidgets(3),
          reason: 'a failed poll must not blank the dashboard');
    });

    testWidgets('an empty snapshot renders the empty state, not a spinner',
        (tester) async {
      await _pumpDashboard(tester, api: _ScriptedApi(TrafficSnapshot.empty(_t0)));

      expect(find.text('Belum ada data lalu lintas'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(IntersectionCard), findsNothing);
    });

    testWidgets('content is capped at the 448 px mobile-first width',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpDashboard(
        tester,
        api: _ScriptedApi(TrafficSnapshot(fetchedAt: _t0, records: [
          _record('30', {'kota': 1, 'ploso': 1}),
        ])),
      );

      expect(tester.getSize(find.byType(ListView)).width,
          lessThanOrEqualTo(448));
    });
  });
}
