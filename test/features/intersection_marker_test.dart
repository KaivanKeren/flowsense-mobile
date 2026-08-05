import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/domain/congestion.dart';
import 'package:flowsense_mobile/features/map/intersection_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 8, 4, 16, 30);

const _simpang = Intersection(
  id: '30',
  name: 'Simpang DPRD',
  lat: -6.8,
  lon: 110.84,
  lanes: ['kota', 'ploso', 'demak', 'sekoe'],
  capacity: {'kota': 12, 'ploso': 10, 'demak': 8, 'sekoe': 6},
);

TrafficRecord _record(Map<String, int> perLane) => TrafficRecord(
      ts: _t0,
      cameraId: '30',
      cameraName: 'Simpang DPRD',
      totalVehicles: perLane.values.fold(0, (a, b) => a + b),
      perLane: perLane,
    );

Future<void> _pump(
  WidgetTester tester,
  IntersectionMarker marker,
) =>
    tester.pumpWidget(MaterialApp(
      theme: flowSenseTheme(),
      home: Scaffold(body: Center(child: marker)),
    ));

void main() {
  group('sizing', () {
    test('scales between 38 and 46 against the busiest on screen', () {
      expect(IntersectionMarker.diameterFor(0, busiest: 20), 38);
      expect(IntersectionMarker.diameterFor(20, busiest: 20), 46);
      expect(IntersectionMarker.diameterFor(10, busiest: 20), 42);
    });

    test('an empty or all-zero map gives every marker the floor size', () {
      // Never a divide-by-zero, and never a NaN radius.
      expect(IntersectionMarker.diameterFor(0, busiest: 0), 38);
      expect(IntersectionMarker.diameterFor(5, busiest: 0), 38);
    });

    test('a marker above the busiest is clamped, not oversized', () {
      expect(IntersectionMarker.diameterFor(99, busiest: 20), 46);
    });
  });

  group('rendering', () {
    testWidgets('the core carries the vehicle count', (tester) async {
      await _pump(
        tester,
        IntersectionMarker(
          intersection: _simpang,
          record: _record({'kota': 9, 'ploso': 5, 'demak': 3, 'sekoe': 1}),
          level: CongestionLevel.macet,
          isStale: false,
          busiestVehicles: 18,
        ),
      );

      expect(find.text('18'), findsOneWidget);
    });

    testWidgets('no data shows a question mark, not a zero', (tester) async {
      await _pump(
        tester,
        const IntersectionMarker(
          intersection: _simpang,
          record: null,
          level: CongestionLevel.unknown,
          isStale: true,
          busiestVehicles: 18,
        ),
      );

      expect(find.text('?'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('an empty per_lane still counts as no data', (tester) async {
      await _pump(
        tester,
        IntersectionMarker(
          intersection: _simpang,
          record: _record({}),
          level: CongestionLevel.unknown,
          isStale: false,
          busiestVehicles: 18,
        ),
      );

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('unselected markers dim to 0.55 when one is chosen',
        (tester) async {
      await _pump(
        tester,
        IntersectionMarker(
          intersection: _simpang,
          record: _record({'kota': 1}),
          level: CongestionLevel.lancar,
          isStale: false,
          busiestVehicles: 18,
          isDimmed: true,
        ),
      );

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, IntersectionMarker.dimmedOpacity);
    });

    testWidgets('the selected marker is not dimmed', (tester) async {
      await _pump(
        tester,
        IntersectionMarker(
          intersection: _simpang,
          record: _record({'kota': 1}),
          level: CongestionLevel.lancar,
          isStale: false,
          busiestVehicles: 18,
          isSelected: true,
        ),
      );

      expect(find.byType(Opacity), findsNothing);
    });
  });

  group('colour', () {
    test('stale wins over the level, in grey rather than a washed-out hue',
        () {
      // A faded red still reads as red, and a colour here must mean one thing.
      expect(
        IntersectionMarker.colorFor(
          CongestionColors.light,
          CongestionLevel.macet,
          isStale: true,
        ),
        CongestionColors.light.unknown,
      );
      expect(
        IntersectionMarker.colorFor(
          CongestionColors.light,
          CongestionLevel.macet,
          isStale: false,
        ),
        CongestionColors.light.macet,
      );
    });
  });

  group('semantics', () {
    testWidgets('spells out the name, status and count', (tester) async {
      final marker = IntersectionMarker(
        intersection: _simpang,
        record: _record({'kota': 9, 'ploso': 5, 'demak': 3, 'sekoe': 1}),
        level: CongestionLevel.macet,
        isStale: false,
        busiestVehicles: 18,
      );

      // The status is spoken, never left to the fill colour — red-green colour
      // blindness is exactly the relevant case for a traffic app.
      expect(marker.semanticsLabel, 'Simpang DPRD, macet, 18 kendaraan');

      await _pump(tester, marker);
      expect(
        find.bySemanticsLabel('Simpang DPRD, macet, 18 kendaraan'),
        findsOneWidget,
      );
    });

    testWidgets('a stale marker announces Data basi, not its old level',
        (tester) async {
      const marker = IntersectionMarker(
        intersection: _simpang,
        record: null,
        level: CongestionLevel.macet,
        isStale: true,
        busiestVehicles: 18,
      );

      expect(marker.semanticsLabel, 'Simpang DPRD, data basi');
    });
  });
}
