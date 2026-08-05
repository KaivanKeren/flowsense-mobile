import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/domain/history.dart';
import 'package:flowsense_mobile/features/detail/history_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _end = DateTime.utc(2026, 8, 4, 16, 30);

const _simpang = Intersection(
  id: '30',
  name: 'Simpang DPRD',
  lat: -6.8,
  lon: 110.84,
  lanes: ['kota', 'ploso'],
  capacity: {'kota': 12, 'ploso': 10},
);

TrafficRecord _at(int minutesAgo, Map<String, int> perLane) => TrafficRecord(
      ts: _end.subtract(Duration(minutes: minutesAgo)),
      cameraId: '30',
      cameraName: 'Simpang DPRD',
      totalVehicles: perLane.values.fold(0, (a, b) => a + b),
      perLane: perLane,
    );

Future<String?> _pumpChart(
  WidgetTester tester, {
  required List<TrafficRecord> records,
  int minutes = 60,
}) async {
  String? selectedLane;
  await tester.pumpWidget(MaterialApp(
    theme: flowSenseTheme(),
    home: Scaffold(
      body: StatefulBuilder(
        builder: (context, setState) => HistoryChart(
          buckets: bucketHistory(
            records: records,
            intersection: _simpang,
            end: _end,
            minutes: minutes,
            lane: selectedLane,
          ),
          lanes: _simpang.lanes,
          selectedLane: selectedLane,
          onLaneChanged: (lane) => setState(() => selectedLane = lane),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return selectedLane;
}

void main() {
  testWidgets('renders its heading, legend and direction chips',
      (tester) async {
    await _pumpChart(
      tester,
      records: [for (var i = 0; i < 60; i++) _at(i, {'kota': 4, 'ploso': 2})],
    );

    expect(find.text('60 menit terakhir'), findsOneWidget);
    // `Data hilang` is a state the chart shows, not an error it hides.
    expect(find.text('Data hilang'), findsOneWidget);
    expect(find.text('Semua arah'), findsOneWidget);
    expect(find.text('Arah kota'), findsOneWidget);
    expect(find.text('Arah ploso'), findsOneWidget);
  });

  testWidgets('the x-axis ends at sekarang and has no y-axis', (tester) async {
    await _pumpChart(
      tester,
      records: [for (var i = 0; i < 60; i++) _at(i, {'kota': 4, 'ploso': 2})],
    );

    expect(find.text('sekarang'), findsOneWidget);
    expect(find.text('15:31'), findsOneWidget); // window start
  });

  testWidgets('the readout reports the latest reading until a bar is tapped',
      (tester) async {
    await _pumpChart(
      tester,
      records: [
        _at(1, {'kota': 2, 'ploso': 1}),
        _at(0, {'kota': 9, 'ploso': 1}), // 9/12 -> macet
      ],
      minutes: 2,
    );

    // The readout's separators distinguish it from the "Tertinggi 10
    // kendaraan pukul ..." summary line below the chart.
    expect(find.textContaining('· 10 kendaraan ·'), findsOneWidget);
    expect(find.textContaining('macet'), findsOneWidget);
    expect(find.textContaining('semua arah'), findsOneWidget);
  });

  testWidgets('tapping a bar retargets the readout to that minute',
      (tester) async {
    await _pumpChart(
      tester,
      records: [
        _at(1, {'kota': 2, 'ploso': 1}), // 3 vehicles
        _at(0, {'kota': 9, 'ploso': 1}), // 10 vehicles
      ],
      minutes: 2,
    );

    // Tap the older of the two bars.
    final bars = find.descendant(
      of: find.byType(Row).first,
      matching: find.byType(GestureDetector),
    );
    await tester.tap(bars.first);
    await tester.pumpAndSettle();

    expect(find.textContaining('3 kendaraan'), findsOneWidget);
  });

  testWidgets('the bar touch target is the full chart height', (tester) async {
    // Called out explicitly in the layout spec. A one-vehicle minute is three
    // pixels tall; requiring a rider to hit three pixels would make the chart
    // decorative rather than interactive.
    await _pumpChart(
      tester,
      records: [
        _at(1, {'kota': 1, 'ploso': 0}), // tiny bar
        _at(0, {'kota': 12, 'ploso': 10}), // tall bar
      ],
      minutes: 2,
    );

    final targets = find.descendant(
      of: find.byType(Row).first,
      matching: find.byType(GestureDetector),
    );

    expect(targets.evaluate(), hasLength(2));
    for (final element in targets.evaluate()) {
      expect(
        (element.renderObject! as RenderBox).size.height,
        HistoryChart.chartHeight,
        reason: 'every bar is tappable over the whole chart height',
      );
    }
  });

  testWidgets('a minute with no data reads as such, not as zero vehicles',
      (tester) async {
    await _pumpChart(
      tester,
      records: [_at(0, {'kota': 4, 'ploso': 2})],
      minutes: 3,
    );

    final bars = find.descendant(
      of: find.byType(Row).first,
      matching: find.byType(GestureDetector),
    );
    await tester.tap(bars.first);
    await tester.pumpAndSettle();

    expect(find.textContaining('data tidak masuk'), findsOneWidget);
    expect(find.textContaining('0 kendaraan'), findsNothing);
  });

  testWidgets('choosing a direction rescales the readout to that lane',
      (tester) async {
    await _pumpChart(
      tester,
      records: [_at(0, {'kota': 9, 'ploso': 1})],
      minutes: 1,
    );

    expect(find.textContaining('· 10 kendaraan ·'), findsOneWidget);

    await tester.tap(find.text('Arah ploso'));
    await tester.pumpAndSettle();

    // The same minute, a completely different story: 1/10 is lancar.
    expect(find.textContaining('· 1 kendaraan ·'), findsOneWidget);
    expect(find.textContaining('lancar'), findsOneWidget);
  });

  testWidgets('summary lines appear under the chart', (tester) async {
    await _pumpChart(
      tester,
      records: [
        _at(4, {'kota': 1, 'ploso': 1}),
        _at(3, {'kota': 6, 'ploso': 1}),
        _at(2, {'kota': 6, 'ploso': 1}),
        _at(1, {'kota': 6, 'ploso': 1}),
        _at(0, {'kota': 6, 'ploso': 1}),
      ],
      minutes: 5,
    );

    expect(find.textContaining('belum ada tanda reda'), findsOneWidget);
    expect(find.textContaining('Tertinggi'), findsOneWidget);
  });

  testWidgets('an hour with no data draws sixty gaps, not an empty chart',
      (tester) async {
    // Not "no history" — an hour of silence, drawn as an hour of silence. The
    // distinction is the point of the whole widget.
    await _pumpChart(tester, records: const [], minutes: 60);

    expect(find.textContaining('data tidak masuk'), findsOneWidget);
    expect(find.textContaining('kendaraan'), findsNothing);
    // Nothing can be summarised from a window with no readings in it.
    expect(find.textContaining('Tertinggi'), findsNothing);

    final bars = find.descendant(
      of: find.byType(Row).first,
      matching: find.byType(GestureDetector),
    );
    expect(bars.evaluate(), hasLength(60));
  });
}
