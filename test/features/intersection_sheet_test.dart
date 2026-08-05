import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/domain/congestion.dart';
import 'package:flowsense_mobile/features/common/relative_time.dart';
import 'package:flowsense_mobile/features/common/status_pill.dart';
import 'package:flowsense_mobile/features/detail/intersection_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The lane rows, in the order they are rendered.
///
/// Matched by key rather than by text: the chart legend and the direction
/// chips further down the sheet repeat the same words, and scanning every
/// `Text` would pick those up too.
List<String> _laneOrder(WidgetTester tester) => find
    .byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('lane-'))
    .evaluate()
    .map((e) => (e.widget.key! as ValueKey<String>).value)
    .toList();

Finder _laneRow(String lane) => find.byKey(ValueKey('lane-$lane'));

final _t0 = DateTime.utc(2026, 8, 2, 12);

const _simpang = Intersection(
  id: '30',
  name: 'Simpang DPRD',
  lat: -6.8047,
  lon: 110.8405,
  lanes: ['kota', 'ploso'],
  capacity: {'kota': 10, 'ploso': 10},
);

Future<void> _pumpSheet(
  WidgetTester tester, {
  required TrafficRecord? record,
  required CongestionLevel level,
  bool isStale = false,
  DateTime? now,
  List<TrafficRecord> history = const [],
  List<NearbyIntersection> nearby = const [],
}) =>
    tester.pumpWidget(MaterialApp(
      theme: flowSenseTheme(),
      home: Scaffold(
        body: IntersectionSheet(
          intersection: _simpang,
          record: record,
          level: level,
          isStale: isStale,
          now: now ?? _t0,
          history: history,
          nearby: nearby,
          laneCapacityDefault: 12,
        ),
      ),
    ));

TrafficRecord _record(Map<String, int> perLane, {DateTime? ts}) =>
    TrafficRecord(
      ts: ts ?? _t0,
      cameraId: '30',
      cameraName: 'Simpang DPRD',
      totalVehicles: perLane.values.fold(0, (a, b) => a + b),
      perLane: perLane,
    );

void main() {
  group('compact stage', () {
    testWidgets('shows the name, status pill, count and age', (tester) async {
      await _pumpSheet(
        tester,
        record: _record({'kota': 8, 'ploso': 2}),
        level: CongestionLevel.macet,
      );

      expect(find.text('Simpang DPRD'), findsOneWidget);
      expect(find.widgetWithText(StatusPill, 'Macet'), findsOneWidget);
      expect(find.text('10 kendaraan · baru saja'), findsOneWidget);
    });

    testWidgets('names the approach that set the level', (tester) async {
      // The single colour on the map is accounted for by this line.
      await _pumpSheet(
        tester,
        record: _record({'kota': 8, 'ploso': 2}),
        level: CongestionLevel.macet,
      );

      expect(find.text('Arah kota paling padat'), findsOneWidget);
    });

    testWidgets('shows how old the reading is', (tester) async {
      await _pumpSheet(
        tester,
        record:
            _record({'kota': 1}, ts: _t0.subtract(const Duration(minutes: 2))),
        level: CongestionLevel.lancar,
        isStale: true,
      );

      expect(find.text('1 kendaraan · 2 menit lalu'), findsOneWidget);
    });

    testWidgets('a stale reading reads as Data basi, not its old level',
        (tester) async {
      await _pumpSheet(
        tester,
        record:
            _record({'kota': 9}, ts: _t0.subtract(const Duration(minutes: 4))),
        level: CongestionLevel.macet,
        isStale: true,
      );

      expect(find.widgetWithText(StatusPill, 'Data basi'), findsOneWidget);
      expect(find.widgetWithText(StatusPill, 'Macet'), findsNothing);
      expect(find.text('Perangkat tidak mengirim data'), findsOneWidget);
    });
  });

  group('lanes', () {
    testWidgets('one row per lane, labelled as a direction', (tester) async {
      await _pumpSheet(
        tester,
        record: _record({'kota': 8, 'ploso': 2}),
        level: CongestionLevel.macet,
      );

      expect(_laneRow('kota'), findsOneWidget);
      expect(_laneRow('ploso'), findsOneWidget);
      expect(
        find.descendant(of: _laneRow('kota'), matching: find.text('Arah kota')),
        findsOneWidget,
      );
      // The count stands alone; capacity is carried by the bar's fill.
      expect(
        find.descendant(of: _laneRow('kota'), matching: find.text('8')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _laneRow('ploso'), matching: find.text('2')),
        findsOneWidget,
      );
    });

    testWidgets('lane order follows the intersection, extras appended',
        (tester) async {
      // 'ploso' is declared second; 'lajur-baru' appeared mid-session.
      await _pumpSheet(
        tester,
        record: _record({'lajur-baru': 3, 'ploso': 2, 'kota': 1}),
        level: CongestionLevel.lancar,
      );

      expect(_laneOrder(tester), [
        'lane-kota',
        'lane-ploso',
        'lane-lajur-baru',
      ]);
    });

    testWidgets('a lane appearing mid-session is rendered, not dropped',
        (tester) async {
      await _pumpSheet(
        tester,
        record: _record({'lajur-baru': 6}),
        level: CongestionLevel.padat,
      );

      expect(_laneRow('lajur-baru'), findsOneWidget);
      expect(
        find.descendant(
          of: _laneRow('lajur-baru'),
          matching: find.text('6'),
        ),
        findsOneWidget,
      );
    });
  });

  group('absence of data', () {
    testWidgets('a camera with no record says so instead of showing zeros',
        (tester) async {
      await _pumpSheet(tester, record: null, level: CongestionLevel.unknown);

      expect(find.text('Belum ada data untuk simpang ini'), findsOneWidget);
      expect(find.text('Tidak ada rincian lajur.'), findsOneWidget);
      expect(find.widgetWithText(StatusPill, 'Tidak ada data'), findsOneWidget);
    });

    testWidgets('an empty per_lane is not rendered as a clear road',
        (tester) async {
      // The most dangerous mistake this app could make.
      await _pumpSheet(
        tester,
        record: _record({}),
        level: CongestionLevel.unknown,
      );

      expect(find.widgetWithText(StatusPill, 'Tidak ada data'), findsOneWidget);
      expect(find.text('Tidak ada rincian lajur.'), findsOneWidget);
      expect(find.widgetWithText(StatusPill, 'Lancar'), findsNothing);
      expect(_laneOrder(tester), isEmpty);
    });
  });

  group('later stages', () {
    testWidgets('the history section is present with its legend',
        (tester) async {
      await _pumpSheet(
        tester,
        record: _record({'kota': 4, 'ploso': 2}),
        level: CongestionLevel.padat,
      );

      expect(find.text('60 menit terakhir'), findsOneWidget);
      expect(find.text('Data hilang'), findsOneWidget);
      expect(find.text('Semua arah'), findsOneWidget);
    });

    testWidgets('the camera panel sits last and carries its caption',
        (tester) async {
      await _pumpSheet(
        tester,
        record: _record({'kota': 4, 'ploso': 2}),
        level: CongestionLevel.padat,
      );

      await tester.scrollUntilVisible(
        find.text('Diperbarui tiap 20 detik'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Diperbarui tiap 20 detik'), findsOneWidget);
      expect(find.text('Kamera tidak tersedia'), findsOneWidget);
    });

    testWidgets('nearby intersections render as a row of cards',
        (tester) async {
      await _pumpSheet(
        tester,
        record: _record({'kota': 4, 'ploso': 2}),
        level: CongestionLevel.padat,
        nearby: const [
          NearbyIntersection(
            intersection: Intersection(
              id: '31',
              name: 'Simpang Tujuh',
              lat: -6.81,
              lon: 110.83,
              lanes: [],
              capacity: {},
            ),
            level: CongestionLevel.lancar,
            isStale: false,
          ),
        ],
      );

      await tester.scrollUntilVisible(
        find.text('Simpang terdekat'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Simpang Tujuh'), findsOneWidget);
    });
  });

  group('relativeIndonesian', () {
    test('rounds down and never overstates freshness', () {
      expect(relativeIndonesian(const Duration(seconds: 3)), 'baru saja');
      expect(relativeIndonesian(const Duration(seconds: 45)), '45 detik lalu');
      expect(relativeIndonesian(const Duration(seconds: 119)), '1 menit lalu');
      expect(relativeIndonesian(const Duration(minutes: 90)), '1 jam lalu');
      expect(relativeIndonesian(const Duration(days: 2)), '2 hari lalu');
    });

    test('clock skew reads as fresh, not as a negative age', () {
      expect(relativeIndonesian(const Duration(seconds: -5)), 'baru saja');
    });
  });
}
