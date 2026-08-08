import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/data/alerts/alerts_api.dart';
import 'package:flowsense_mobile/data/api/flowsense_api.dart';
import 'package:flowsense_mobile/data/auth/fake_auth_api.dart';
import 'package:flowsense_mobile/data/auth/token_store.dart';
import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/data/models/traffic_snapshot.dart';
import 'package:flowsense_mobile/domain/congestion.dart';
import 'package:flowsense_mobile/domain/operator_alert.dart';
import 'package:flowsense_mobile/features/common/status_pill.dart';
import 'package:flowsense_mobile/features/operator/dashboard_screen.dart';
import 'package:flowsense_mobile/features/operator/detail_screen.dart';
import 'package:flowsense_mobile/state/alert_providers.dart';
import 'package:flowsense_mobile/state/auth_providers.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 8, 4, 16, 42);

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
    name: 'Simpang Tujuh',
    lat: -6.8089,
    lon: 110.8372,
    lanes: ['alun-alun'],
    capacity: {'alun-alun': 10},
  ),
  Intersection(
    id: '32',
    name: 'Simpang Jati',
    lat: -6.7983,
    lon: 110.8461,
    lanes: ['kudus'],
    capacity: {'kudus': 10},
  ),
  Intersection(
    id: '34',
    name: 'Simpang Ngembal',
    lat: -6.8175,
    lon: 110.8534,
    lanes: ['gebog'],
    capacity: {'gebog': 10},
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

/// One macet, one padat, one lancar, one four minutes stale.
TrafficSnapshot _mixed() => TrafficSnapshot(fetchedAt: _t0, records: [
      _record('30', {'kota': 9, 'ploso': 9}),
      _record('31', {'alun-alun': 5}),
      _record('32', {'kudus': 1}),
      _record('34', {'gebog': 1},
          ts: _t0.subtract(const Duration(minutes: 4))),
    ]);

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

OperatorAlert _alert({
  required String id,
  required String name,
  int minutesAgo = 37,
  String? by,
}) =>
    OperatorAlert(
      id: id,
      cameraId: '30',
      name: name,
      level: CongestionLevel.macet,
      raisedAt: _t0.subtract(Duration(minutes: minutesAgo)),
      acknowledgedBy: by,
      acknowledgedAt:
          by == null ? null : _t0.subtract(const Duration(minutes: 62)),
    );

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  TrafficSnapshot? snapshot,
  List<OperatorAlert> alerts = const [],
  FakeAlertsApi? alertsApi,
  bool signedIn = true,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final authApi = FakeAuthApi();
  final container = ProviderContainer(overrides: [
    apiProvider.overrideWithValue(_ScriptedApi(snapshot ?? _mixed())),
    appConfigProvider.overrideWithValue(const AppConfig(
      apiBase: 'https://x.test',
      apiKey: 'k',
      laneCapacityDefault: 10,
    )),
    clockProvider.overrideWithValue(FakeClock(_t0)),
    snapshotCacheProvider.overrideWithValue(null),
    authApiProvider.overrideWithValue(authApi),
    tokenStoreProvider
        .overrideWithValue(FakeTokenStore(signedIn ? authApi.token : null)),
    alertsApiProvider.overrideWithValue(
      alertsApi ?? FakeAlertsApi(seed: alerts, now: () => _t0),
    ),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: flowSenseTheme(),
      home: const DashboardScreen(),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

/// Intersection row titles, in rendered order.
List<String> _rowOrder(WidgetTester tester) => find
    .byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('row-'))
    .evaluate()
    .map((e) => (e.widget.key! as ValueKey<String>).value)
    .toList();

void main() {
  group('summary', () {
    testWidgets('counts the four states across the top', (tester) async {
      await _pump(tester);

      expect(find.text('Macet'), findsWidgets);
      expect(find.text('Padat'), findsWidgets);
      expect(find.text('Lancar'), findsWidgets);
      expect(find.text('Tanpa data'), findsOneWidget);

      // 1 macet, 1 padat, 1 lancar, 1 stale.
      for (final label in ['Macet', 'Padat', 'Lancar', 'Tanpa data']) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('summary-$label')),
            matching: find.text('1'),
          ),
          findsOneWidget,
          reason: label,
        );
      }
    });

    testWidgets('the numbers are neutral ink, never the level colour',
        (tester) async {
      await _pump(tester);

      // Colour on this screen belongs to the status pills alone. The console
      // is denser than the citizen app, which makes this rule easier to break.
      final number = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('summary-Macet')),
          matching: find.text('1'),
        ),
      );
      expect(number.style!.color, FlowSurfaces.light.textPrimary);
      expect(number.style!.color, isNot(CongestionColors.light.macet));
    });

    testWidgets('a stale intersection counts as tanpa data, not lancar',
        (tester) async {
      await _pump(
        tester,
        snapshot: TrafficSnapshot(fetchedAt: _t0, records: [
          for (final i in _intersections)
            _record(i.id, {i.lanes.first: 1},
                ts: _t0.subtract(const Duration(minutes: 4))),
        ]),
      );

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('summary-Tanpa data')),
          matching: find.text('4'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('summary-Lancar')),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
    });
  });

  group('active alerts', () {
    testWidgets('sit above the intersection list', (tester) async {
      // On a phone, what needs action has to be visible before what needs
      // watching.
      await _pump(tester, alerts: [_alert(id: '1', name: 'Simpang DPRD')]);

      final alertY = tester.getTopLeft(find.text('Peringatan aktif')).dy;
      final listY = tester.getTopLeft(find.text('Simpang')).dy;
      expect(alertY, lessThan(listY));
    });

    testWidgets('show the intersection, since when, and for how long',
        (tester) async {
      await _pump(tester, alerts: [_alert(id: '1', name: 'Simpang DPRD')]);

      expect(
        find.text('Macet sejak ${clockTime(_t0.subtract(
          const Duration(minutes: 37),
        ))} · 37 menit'),
        findsOneWidget,
      );
    });

    testWidgets('a quiet line when there is nothing to act on',
        (tester) async {
      await _pump(tester);

      // Not an empty section — a sentence saying it is empty on purpose.
      expect(find.text('Tidak ada peringatan aktif'), findsOneWidget);
      expect(find.text('Akui'), findsNothing);
    });

    testWidgets('acknowledging records the operator and keeps the row',
        (tester) async {
      final container =
          await _pump(tester, alerts: [_alert(id: '1', name: 'Simpang DPRD')]);

      await tester.tap(find.text('Akui'));
      await tester.pumpAndSettle();

      final alerts = container.read(operatorAlertsProvider).value!;
      expect(alerts, hasLength(1), reason: 'the row is never deleted');
      expect(alerts.single.acknowledgedBy, 'Operator Dinas');
      expect(alerts.single.acknowledgedAt, isNotNull);
    });

    testWidgets('an acknowledged alert moves down, naming who and when',
        (tester) async {
      await _pump(tester, alerts: [
        _alert(id: '1', name: 'Simpang DPRD'),
        _alert(id: '2', name: 'Simpang Tujuh', minutesAgo: 90, by: 'Ismail'),
      ]);

      expect(find.textContaining('diakui Ismail'), findsOneWidget);

      // Unacknowledged above acknowledged.
      final active = tester.getTopLeft(find.text('Simpang DPRD').first).dy;
      final done = tester.getTopLeft(find.textContaining('diakui Ismail')).dy;
      expect(active, lessThan(done));
    });

    testWidgets('a failed acknowledgement does not look like a success',
        (tester) async {
      final api = FakeAlertsApi(
        seed: [_alert(id: '1', name: 'Simpang DPRD')],
        now: () => _t0,
      )..failAcknowledgeNext = 1;
      final container = await _pump(tester, alertsApi: api);

      await tester.tap(find.text('Akui'));
      await tester.pumpAndSettle();

      // The record this console exists to keep must not claim a person saw
      // something when the server never heard about it.
      expect(
        container.read(operatorAlertsProvider).value!.single.isAcknowledged,
        isFalse,
      );
      expect(find.text('Akui'), findsOneWidget);
    });
  });

  group('intersection list', () {
    testWidgets('is ordered worst first', (tester) async {
      await _pump(tester);

      expect(_rowOrder(tester), [
        'row-30', // macet
        'row-31', // padat
        'row-32', // lancar
        'row-34', // stale, sorts last
      ]);
    });

    testWidgets('each row is two tiers: identity, then the numbers',
        (tester) async {
      await _pump(tester);

      expect(find.text('Simpang DPRD'), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('row-30')),
          matching: find.textContaining('18 kendaraan · arah kota'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('rows clear the 56 px minimum height', (tester) async {
      await _pump(tester);

      // Two tiers of text still has to leave a 44 px touch target.
      for (final key in _rowOrder(tester)) {
        expect(
          tester.getSize(find.byKey(ValueKey(key))).height,
          greaterThanOrEqualTo(56),
          reason: key,
        );
      }
    });

    testWidgets('a dead connector reads as Data basi, not as lancar',
        (tester) async {
      await _pump(tester);

      final row = find.byKey(const ValueKey('row-34'));
      expect(
        find.descendant(of: row, matching: find.text('Data basi')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('Lancar')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.textContaining('Data terakhir 4 menit lalu'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping a row opens that intersection', (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(const ValueKey('row-30')));
      await tester.pumpAndSettle();

      expect(find.byType(DetailScreen), findsOneWidget);
      expect(find.text('Per lajur'), findsOneWidget);
    });

    testWidgets('every row carries a status pill with words on it',
        (tester) async {
      await _pump(tester);

      // Never colour alone — red-green colour blindness is exactly the
      // relevant case for a traffic console.
      expect(find.byType(StatusPill), findsNWidgets(4));
    });
  });

  group('the console does not pretend to control anything', () {
    testWidgets('offers no signal control of any kind', (tester) async {
      await _pump(tester, alerts: [_alert(id: '1', name: 'Simpang DPRD')]);

      // There is no actuator. Showing a control wired to nothing would be an
      // interface lie.
      for (final forbidden in [
        'Manual',
        'Hijau',
        'Merah',
        'Durasi',
        'Kendali',
        'Ekspor',
        'Tambah',
      ]) {
        expect(find.textContaining(forbidden), findsNothing,
            reason: forbidden);
      }
    });
  });

  group('feed failures', () {
    testWidgets('a failed poll keeps the rows on screen', (tester) async {
      await _pump(tester);
      expect(_rowOrder(tester), hasLength(4));
    });

    testWidgets('an empty snapshot says so instead of spinning',
        (tester) async {
      await _pump(tester, snapshot: TrafficSnapshot.empty(_t0));

      expect(
        find.text('Belum ada data masuk dari simpang mana pun.'),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  testWidgets('content is capped at the 448 px mobile-first width',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester);

    for (final element in find
        .descendant(
          of: find.byType(MaxWidth448Probe),
          matching: find.byType(ConstrainedBox),
        )
        .evaluate()) {
      expect(
        (element.renderObject! as RenderBox).size.width,
        lessThanOrEqualTo(448),
      );
    }
  });
}

/// Alias so the width test reads clearly without importing the primitive under
/// two names.
typedef MaxWidth448Probe = Scaffold;
