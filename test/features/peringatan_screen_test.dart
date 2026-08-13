import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/data/alerts/alerts_api.dart';
import 'package:flowsense_mobile/data/api/flowsense_api.dart';
import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/data/models/traffic_snapshot.dart';
import 'package:flowsense_mobile/domain/congestion.dart';
import 'package:flowsense_mobile/domain/operator_alert.dart';
import 'package:flowsense_mobile/features/operator/peringatan_screen.dart';
import 'package:flowsense_mobile/state/alert_providers.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 8, 2, 16, 42);

const _intersections = [
  Intersection(
    id: '30',
    name: 'Simpang DPRD',
    lat: -6.8,
    lon: 110.84,
    lanes: ['kota'],
    capacity: {'kota': 12},
  ),
  Intersection(
    id: '31',
    name: 'Simpang Tujuh',
    lat: -6.81,
    lon: 110.83,
    lanes: ['barat'],
    capacity: {'barat': 12},
  ),
];

class _StubApi implements FlowSenseApi {
  @override
  Future<TrafficSnapshot> snapshot() async => TrafficSnapshot.empty(_t0);

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

OperatorAlert _alert({
  required String id,
  String camera = '30',
  String name = 'Simpang DPRD',
  int minutesAgo = 37,
  String? by,
  String? note,
}) =>
    OperatorAlert(
      id: id,
      cameraId: camera,
      name: name,
      level: CongestionLevel.macet,
      raisedAt: _t0.subtract(Duration(minutes: minutesAgo)),
      acknowledgedBy: by,
      acknowledgedAt: by == null ? null : _t0,
      note: note,
    );

List<OperatorAlert> _history() => [
      _alert(id: '1'),
      _alert(
        id: '2',
        camera: '31',
        name: 'Simpang Tujuh',
        minutesAgo: 80,
        by: 'Ismail',
        note: 'Ada perbaikan jalan',
      ),
      _alert(id: '3', minutesAgo: 60 * 8, by: 'Ismail'),
      _alert(id: '4', minutesAgo: 60 * 24 * 20, by: 'Rina'),
    ];

Future<void> _pump(
  WidgetTester tester, {
  List<OperatorAlert>? alerts,
  FakeAlertsApi? api,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiProvider.overrideWithValue(_StubApi()),
      appConfigProvider.overrideWithValue(
        const AppConfig(apiBase: 'https://x.test', apiKey: 'k'),
      ),
      clockProvider.overrideWithValue(FakeClock(_t0)),
      snapshotCacheProvider.overrideWithValue(null),
      alertsApiProvider.overrideWithValue(
        api ?? FakeAlertsApi(seed: alerts ?? _history(), now: () => _t0),
      ),
    ],
    child: MaterialApp(
      theme: flowSenseTheme(),
      home: const PeringatanScreen(),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Brings a filter chip into view.
///
/// The spec makes this row "satu baris chip yang bisa digeser mendatar", so at
/// 360 px the third chip genuinely starts off-screen — scrolling to it is the
/// intended interaction, not a workaround.
Future<void> _revealChip(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    120,
    scrollable: find.descendant(
      of: find.byType(PeringatanScreen),
      matching: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _cards(WidgetTester tester) => find
    .byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('alert-'))
    .evaluate()
    .map((e) => (e.widget.key! as ValueKey<String>).value)
    .toList();

void main() {
  group('cards', () {
    testWidgets('a card per alert, newest first', (tester) async {
      await _pump(tester);

      // The 20-day-old one is outside the default 7-day window.
      expect(_cards(tester), ['alert-1', 'alert-2', 'alert-3']);
    });

    testWidgets('shows time, intersection, duration, acknowledger and note',
        (tester) async {
      await _pump(tester);

      expect(find.text('2 Agu 16:05'), findsOneWidget);
      expect(find.text('Simpang Tujuh'), findsOneWidget);
      expect(
        find.text('Macet 1 jam 20 menit · Ismail · Ada perbaikan jalan'),
        findsOneWidget,
      );
    });

    testWidgets('is a list of cards, never a table', (tester) async {
      // Columns on 360 px become horizontal scrolling, which the spec forbids.
      await _pump(tester);

      expect(find.byType(DataTable), findsNothing);
      expect(_cards(tester), isNotEmpty);
    });

    testWidgets('marks what still needs a person', (tester) async {
      await _pump(tester);

      expect(find.text('Belum diakui'), findsOneWidget);
      expect(find.text('Diakui'), findsNWidgets(2));
    });

    testWidgets('the attention colour marks unacknowledged, not acknowledged',
        (tester) async {
      await _pump(tester);

      final open = tester.widget<Text>(find.text('Belum diakui'));
      expect(open.style!.color, FlowSurfaces.light.errorPill.ink);
      // Green is spoken for by `Lancar`.
      expect(open.style!.color, isNot(CongestionColors.light.lancar));
    });
  });

  group('filters', () {
    testWidgets('three chips: time, intersection, status', (tester) async {
      await _pump(tester);

      expect(find.text('7 hari terakhir'), findsOneWidget);
      expect(find.text('Semua simpang'), findsOneWidget);

      await _revealChip(tester, 'filter-ack');
      expect(find.text('Semua status'), findsOneWidget);
    });

    testWidgets('widening the window reveals older alerts', (tester) async {
      await _pump(tester);
      expect(_cards(tester), hasLength(3));

      await tester.tap(find.byKey(const ValueKey('filter-window')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 hari terakhir').last);
      await tester.pumpAndSettle();

      expect(_cards(tester), hasLength(4));
    });

    testWidgets('choosing an intersection narrows the list', (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(const ValueKey('filter-camera')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpang Tujuh').last);
      await tester.pumpAndSettle();

      expect(_cards(tester), ['alert-2']);
    });

    testWidgets('filtering to unacknowledged shows only what needs action',
        (tester) async {
      await _pump(tester);

      await _revealChip(tester, 'filter-ack');
      await tester.tap(find.byKey(const ValueKey('filter-ack')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Belum diakui').last);
      await tester.pumpAndSettle();

      expect(_cards(tester), ['alert-1']);
    });

    testWidgets('an empty result says so rather than showing a blank page',
        (tester) async {
      await _pump(tester, alerts: const []);

      expect(
        find.text('Tidak ada peringatan pada rentang ini.'),
        findsOneWidget,
      );
    });
  });

  group('scope', () {
    testWidgets('offers no export and no drawer', (tester) async {
      await _pump(tester);

      // Export is out of scope, and a drawer would be navigation the spec
      // does not have — the bar at the bottom is the whole of it.
      expect(find.textContaining('Ekspor'), findsNothing);
      expect(find.byType(Drawer), findsNothing);
      expect(find.byTooltip('Open navigation menu'), findsNothing);
    });
  });

  testWidgets('content is capped at the 448 px mobile-first width',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester);

    expect(
      tester.getSize(find.byKey(const ValueKey('peringatan-body'))).width,
      inInclusiveRange(1, 448),
    );
  });
}
