import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/data/api/flowsense_api.dart';
import 'package:flowsense_mobile/data/auth/fake_auth_api.dart';
import 'package:flowsense_mobile/data/auth/token_store.dart';
import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/data/models/traffic_snapshot.dart';
import 'package:flowsense_mobile/domain/video_panel_state.dart';
import 'package:flowsense_mobile/widgets/status_chip.dart';
import 'package:flowsense_mobile/features/operator/detail_screen.dart';
import 'package:flowsense_mobile/state/auth_providers.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 8, 4, 16, 42, 7);

const _simpang = Intersection(
  id: '30',
  name: 'Simpang DPRD',
  lat: -6.8047,
  lon: 110.8405,
  lanes: ['kota', 'ploso', 'demak', 'sekoe'],
  capacity: {'kota': 12, 'ploso': 12, 'demak': 12, 'sekoe': 12},
);

TrafficRecord _record(Map<String, int> perLane, {DateTime? ts}) =>
    TrafficRecord(
      ts: ts ?? _t0,
      cameraId: '30',
      cameraName: 'Simpang DPRD',
      totalVehicles: perLane.values.fold(0, (a, b) => a + b),
      perLane: perLane,
    );

/// 9/12 kota is macet, and the reference image's numbers exactly.
TrafficRecord _reference() =>
    _record({'kota': 9, 'ploso': 5, 'demak': 3, 'sekoe': 1});

class _ScriptedApi implements FlowSenseApi {
  _ScriptedApi({required this.record, this.historyPoints = const []});

  final TrafficRecord? record;
  final List<TrafficRecord> historyPoints;

  String? lastBucket;

  @override
  Future<TrafficSnapshot> snapshot() async => TrafficSnapshot(
        fetchedAt: _t0,
        records: [?record],
      );

  @override
  Future<List<Intersection>> intersections() async => [_simpang];

  @override
  Future<List<TrafficRecord>> history(
    String id, {
    DateTime? from,
    DateTime? to,
    String bucket = '1m',
  }) async {
    lastBucket = bucket;
    return historyPoints;
  }

  @override
  void close() {}
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  TrafficRecord? record,
  List<TrafficRecord> history = const [],
  _ScriptedApi? api,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final authApi = FakeAuthApi();
  final container = ProviderContainer(overrides: [
    apiProvider.overrideWithValue(
      api ?? _ScriptedApi(record: record ?? _reference(), historyPoints: history),
    ),
    appConfigProvider.overrideWithValue(const AppConfig(
      apiBase: 'https://x.test',
      apiKey: 'k',
      laneCapacityDefault: 12,
    )),
    clockProvider.overrideWithValue(FakeClock(_t0)),
    snapshotCacheProvider.overrideWithValue(null),
    authApiProvider.overrideWithValue(authApi),
    tokenStoreProvider.overrideWithValue(FakeTokenStore(authApi.token)),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: flowSenseTheme(),
      home: const DetailScreen(cameraId: '30'),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

Finder _laneRow(String lane) => find.byKey(ValueKey('lane-$lane'));

void main() {
  group('header', () {
    testWidgets('names the intersection, its status and how fresh it is',
        (tester) async {
      await _pump(tester);

      expect(find.text('Simpang DPRD'), findsOneWidget);
      expect(find.widgetWithText(StatusChip, 'Macet'), findsOneWidget);
      expect(find.textContaining('18 kendaraan'), findsOneWidget);
      expect(find.textContaining('baru saja'), findsOneWidget);
    });
  });

  group('calibration', () {
    testWidgets('the header offers Kalibrasi, and it goes somewhere real',
        (tester) async {
      await _pump(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Kalibrasi'));
      await tester.pumpAndSettle();

      // The screen names itself in the bar and the intersection in the body.
      // Both used to be one app-bar title, which at 320 px and textScale 1.3
      // was 5 px short of fitting and shipped as `Kalibrasi — Simpang DPR…`.
      expect(find.text('Kalibrasi'), findsOneWidget);
      expect(find.text('Simpang DPRD'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Simpan'), findsOneWidget);
    });
  });

  group('camera panel', () {
    testWidgets('never sits silent — it says which state it is in',
        (tester) async {
      await _pump(tester);

      // No proxy exists yet, so the panel lands in its failed state rather
      // than pretending to be connecting forever.
      expect(find.text(VideoPhase.gagal.label), findsOneWidget);
      expect(find.text('Muat ulang'), findsOneWidget);
    });

    testWidgets('names where the pictures come from', (tester) async {
      await _pump(tester);

      expect(
        find.textContaining('portal CCTV Pemkab Kudus'),
        findsOneWidget,
      );
    });

    testWidgets('reloading puts it back into connecting', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Muat ulang'));
      await tester.pump();

      expect(find.text(VideoPhase.memuat.label), findsOneWidget);
    });
  });

  group('per lane', () {
    testWidgets('one row per lane, with count, capacity and ratio',
        (tester) async {
      await _pump(tester);

      expect(find.text('Per lajur'), findsOneWidget);
      for (final lane in ['kota', 'ploso', 'demak', 'sekoe']) {
        expect(_laneRow(lane), findsOneWidget, reason: lane);
      }

      // The operator gets the capacity and the ratio the citizen app hides.
      expect(
        find.descendant(of: _laneRow('kota'), matching: find.text('9/12')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _laneRow('kota'), matching: find.text('75%')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _laneRow('sekoe'), matching: find.text('8%')),
        findsOneWidget,
      );
    });

    testWidgets('the bar is actually drawn, proportional to the ratio',
        (tester) async {
      // Regression: the fill used to collapse to zero height, so the bars were
      // invisible while every text assertion about them still passed. Only the
      // golden caught it, so the geometry is pinned here too.
      await _pump(tester);

      Size fill(String lane) {
        final box = find.descendant(
          of: _laneRow(lane),
          matching: find.byType(FractionallySizedBox),
        );
        final element = box.evaluate().single;
        return (element.renderObject! as RenderBox).size;
      }

      final kota = fill('kota'); // 9/12
      final sekoe = fill('sekoe'); // 1/12

      expect(kota.height, greaterThan(0), reason: 'the bar has height');
      expect(kota.width, greaterThan(0), reason: 'the bar has width');
      // Nine twelfths against one twelfth.
      expect(kota.width, greaterThan(sekoe.width * 5));
    });

    testWidgets('the ratio is neutral ink, not the level colour',
        (tester) async {
      await _pump(tester);

      // Reserved hues stay reserved. The bar already carries the level, and
      // #D64541 as 13 px text measures 4.09:1 — under the 4.5:1 floor.
      final ratio = tester.widget<Text>(
        find.descendant(of: _laneRow('kota'), matching: find.text('75%')),
      );
      expect(ratio.style!.color, isNot(CongestionColors.light.macet));
    });

    testWidgets('an uncalibrated lane still renders, using the fallback',
        (tester) async {
      await _pump(tester, record: _record({'baru': 6}));

      expect(_laneRow('baru'), findsOneWidget);
      expect(
        find.descendant(of: _laneRow('baru'), matching: find.text('6/12')),
        findsOneWidget,
      );
    });

    testWidgets('an empty per_lane is not rendered as a clear road',
        (tester) async {
      await _pump(tester, record: _record({}));

      expect(find.text('Tidak ada rincian lajur.'), findsOneWidget);
      expect(find.widgetWithText(StatusChip, 'Lancar'), findsNothing);
    });
  });

  group('24-hour history', () {
    testWidgets('asks the server for 15-minute buckets', (tester) async {
      final api = _ScriptedApi(record: _reference());
      await _pump(tester, api: api);

      // Aggregation belongs on the server. Pulling a day of raw records to a
      // phone to bucket them locally is the thing this avoids.
      expect(api.lastBucket, '15m');
    });

    testWidgets('draws 96 bars, one per quarter hour', (tester) async {
      await _pump(tester);

      expect(find.text('Riwayat 24 jam'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('history-bars')),
        findsOneWidget,
      );
      final bars = find.descendant(
        of: find.byKey(const ValueKey('history-bars')),
        matching: find.byType(GestureDetector),
      );
      expect(bars.evaluate(), hasLength(96));
    });

    testWidgets('a quarter hour with no record reads as missing, not zero',
        (tester) async {
      await _pump(tester);

      final bars = find.descendant(
        of: find.byKey(const ValueKey('history-bars')),
        matching: find.byType(GestureDetector),
      );
      // Scrolled into view first: the chart sits below the fold on the default
      // test viewport now that `Kalibrasi` is a header button rather than an
      // app-bar action. A tap that misses reports a warning, not a failure.
      await tester.ensureVisible(bars.first);
      await tester.pumpAndSettle();
      await tester.tap(bars.first);
      await tester.pumpAndSettle();

      expect(find.textContaining('data tidak masuk'), findsOneWidget);
      expect(find.textContaining('0 kendaraan'), findsNothing);
    });

    testWidgets('tapping a bar shows that period above the chart',
        (tester) async {
      await _pump(tester, history: [
        _record({'kota': 9, 'ploso': 1}, ts: _t0),
      ]);

      final bars = find.descendant(
        of: find.byKey(const ValueKey('history-bars')),
        matching: find.byType(GestureDetector),
      );
      await tester.ensureVisible(bars.last);
      await tester.pumpAndSettle();
      await tester.tap(bars.last);
      await tester.pumpAndSettle();

      expect(find.textContaining('10 kendaraan'), findsOneWidget);
    });
  });

  group('source notes', () {
    testWidgets('names the camera, the last record and the connector version',
        (tester) async {
      await _pump(tester);

      await tester.scrollUntilVisible(find.text('Sumber data'), 200);
      expect(find.text('Sumber data'), findsOneWidget);
      expect(find.textContaining('Kamera 30'), findsOneWidget);
      // Seconds included: an operator checking a stalled feed needs them.
      expect(find.textContaining('16:42:07'), findsOneWidget);
    });
  });

  group('the console does not pretend to control anything', () {
    testWidgets('offers no signal control on the detail screen',
        (tester) async {
      await _pump(tester);

      for (final forbidden in [
        'Manual',
        'Hijau',
        'Durasi',
        'Kendali',
        'Ekspor',
        'Preemption',
      ]) {
        expect(find.textContaining(forbidden), findsNothing,
            reason: forbidden);
      }
    });
  });

  testWidgets('content is capped at the 448 px mobile-first width',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester);

    final body = tester.getSize(find.byKey(const ValueKey('detail-body')));
    expect(body.width, inInclusiveRange(1, 448));
  });
}
