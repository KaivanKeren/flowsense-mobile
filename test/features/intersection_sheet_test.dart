import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/domain/congestion.dart';
import 'package:flowsense_mobile/features/common/stale_banner.dart';
import 'package:flowsense_mobile/features/detail/intersection_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
          laneCapacityDefault: 12,
        ),
      ),
    ));

TrafficRecord _record(Map<String, int> perLane, {DateTime? ts}) =>
    TrafficRecord(
      ts: ts ?? _t0,
      cameraId: '30',
      cameraName: 'Simpang DPRD Arah Kota',
      totalVehicles: perLane.values.fold(0, (a, b) => a + b),
      perLane: perLane,
    );

void main() {
  testWidgets('shows the name, level label, and one row per lane',
      (tester) async {
    await _pumpSheet(
      tester,
      record: _record({'kota': 8, 'ploso': 2}),
      level: CongestionLevel.macet,
    );

    expect(find.text('Simpang DPRD'), findsOneWidget);
    expect(find.text('Macet'), findsOneWidget);
    expect(find.text('kota'), findsOneWidget);
    expect(find.text('8/10'), findsOneWidget);
    expect(find.text('ploso'), findsOneWidget);
    expect(find.text('2/10'), findsOneWidget);
  });

  testWidgets('lane order follows the intersection, extras appended',
      (tester) async {
    // 'ploso' is declared second; 'lajur-baru' appeared mid-session.
    await _pumpSheet(
      tester,
      record: _record({'lajur-baru': 3, 'ploso': 2, 'kota': 1}),
      level: CongestionLevel.lancar,
    );

    final lanes = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => ['kota', 'ploso', 'lajur-baru'].contains(s))
        .toList();

    expect(lanes, ['kota', 'ploso', 'lajur-baru']);
  });

  testWidgets('an uncalibrated lane falls back to the default capacity',
      (tester) async {
    await _pumpSheet(
      tester,
      record: _record({'lajur-baru': 6}),
      level: CongestionLevel.padat,
    );

    expect(find.text('6/12'), findsOneWidget);
  });

  testWidgets('shows how old the reading is', (tester) async {
    await _pumpSheet(
      tester,
      record: _record({'kota': 1}, ts: _t0.subtract(const Duration(minutes: 2))),
      level: CongestionLevel.lancar,
      isStale: true,
    );

    expect(find.text('Data terakhir 2 menit lalu'), findsOneWidget);
  });

  testWidgets('a camera with no record says so instead of showing zeros',
      (tester) async {
    await _pumpSheet(
      tester,
      record: null,
      level: CongestionLevel.unknown,
    );

    expect(find.text('Belum ada data untuk simpang ini'), findsOneWidget);
    expect(find.text('Tidak ada rincian lajur.'), findsOneWidget);
    expect(find.text('Tidak ada data'), findsOneWidget);
  });

  testWidgets('an empty per_lane is not rendered as a clear road',
      (tester) async {
    await _pumpSheet(
      tester,
      record: _record({}),
      level: CongestionLevel.unknown,
    );

    expect(find.text('Tidak ada data'), findsOneWidget);
    expect(find.text('Tidak ada rincian lajur.'), findsOneWidget);
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
