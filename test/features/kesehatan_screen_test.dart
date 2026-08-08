import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/data/health/health_api.dart';
import 'package:flowsense_mobile/domain/connector_health.dart';
import 'package:flowsense_mobile/features/operator/kesehatan_screen.dart';
import 'package:flowsense_mobile/state/health_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 8, 4, 16, 42, 7);

ConnectorHealth _health({
  required String id,
  required String name,
  ConnectorStatus status = ConnectorStatus.berjalan,
  Duration? gap = const Duration(seconds: 2),
  int failures = 0,
  DateTime? last,
}) =>
    ConnectorHealth(
      cameraId: id,
      intersectionName: name,
      status: status,
      lastRecordAt: last ?? _t0,
      gap: gap,
      failuresPerHour: failures,
    );

/// The reference image's five connectors.
List<ConnectorHealth> _fleet() => [
      _health(id: '30', name: 'Simpang DPRD'),
      _health(
        id: '31',
        name: 'Simpang Tujuh',
        gap: const Duration(milliseconds: 2100),
        failures: 2,
        last: _t0.subtract(const Duration(seconds: 2)),
      ),
      _health(id: '32', name: 'Simpang Jati'),
      _health(
        id: '33',
        name: 'Simpang Bae',
        status: ConnectorStatus.terputus,
        gap: const Duration(milliseconds: 4800),
        failures: 14,
        last: _t0.subtract(const Duration(seconds: 55)),
      ),
      _health(
        id: '34',
        name: 'Simpang Ngembal',
        status: ConnectorStatus.berhenti,
        gap: null,
        failures: 63,
        last: _t0.subtract(const Duration(minutes: 3, seconds: 27)),
      ),
    ];

Future<void> _pump(
  WidgetTester tester, {
  List<ConnectorHealth>? fleet,
  FakeHealthApi? api,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      healthApiProvider
          .overrideWithValue(api ?? FakeHealthApi(seed: fleet ?? _fleet())),
    ],
    child: MaterialApp(
      theme: flowSenseTheme(),
      home: const KesehatanScreen(),
    ),
  ));
  await tester.pumpAndSettle();
}

List<String> _rowOrder(WidgetTester tester) => find
    .byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('connector-'))
    .evaluate()
    .map((e) => (e.widget.key! as ValueKey<String>).value)
    .toList();

Finder _row(String id) => find.byKey(ValueKey('connector-$id'));

void main() {
  group('header', () {
    testWidgets('says what the screen is for', (tester) async {
      await _pump(tester);

      expect(find.text('Kesehatan connector'), findsOneWidget);
      expect(
        find.textContaining('perangkat lunak yang memproses citra'),
        findsOneWidget,
      );
    });
  });

  group('rows', () {
    testWidgets('one two-tier row per connector', (tester) async {
      await _pump(tester);

      expect(_rowOrder(tester), hasLength(5));
      expect(
        find.descendant(
          of: _row('30'),
          matching: find.text('Kamera 30 — Simpang DPRD'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _row('30'),
          matching:
              find.text('record terakhir 16:42:07 · jeda 2,0 detik · 0 gagal/jam'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ordered worst first', (tester) async {
      // The connector that needs looking at is on the first screen without
      // anyone scrolling for it.
      await _pump(tester);

      expect(_rowOrder(tester), [
        'connector-34', // berhenti
        'connector-33', // terputus
        'connector-31', // berjalan, 2 failures
        'connector-30',
        'connector-32',
      ]);
    });

    testWidgets('rows clear the 56 px minimum height', (tester) async {
      await _pump(tester);

      for (final key in _rowOrder(tester)) {
        expect(
          tester.getSize(find.byKey(ValueKey(key))).height,
          greaterThanOrEqualTo(56),
          reason: key,
        );
      }
    });

    testWidgets('a stopped connector shows no cadence', (tester) async {
      await _pump(tester);

      final detail = find.descendant(
        of: _row('34'),
        matching: find.textContaining('gagal/jam'),
      );
      expect(detail, findsOneWidget);
      // `0,0 detik` would read as instantaneous rather than not running.
      expect(
        find.descendant(of: _row('34'), matching: find.textContaining('jeda')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: _row('34'),
          matching: find.textContaining('63 gagal/jam'),
        ),
        findsOneWidget,
      );
    });
  });

  group('status pills', () {
    testWidgets('every status is spelled out, never colour alone',
        (tester) async {
      await _pump(tester);

      expect(find.text('Berjalan'), findsNWidgets(3));
      expect(find.text('Terputus'), findsOneWidget);
      expect(find.text('Berhenti'), findsOneWidget);
    });

    testWidgets('health never borrows the congestion palette', (tester) async {
      // On the dashboard a health mark sits on the same row as a congestion
      // pill. Green meaning both "clear road" and "process alive" is exactly
      // the ambiguity the reserved-hue rule prevents.
      await _pump(tester);

      final running = tester.widget<Text>(find.text('Berjalan').first);
      final stopped = tester.widget<Text>(find.text('Berhenti'));

      for (final style in [running.style!, stopped.style!]) {
        expect(style.color, isNot(CongestionColors.light.lancar));
        expect(style.color, isNot(CongestionColors.light.macet));
        expect(style.color, isNot(CongestionColors.light.padat));
      }
      expect(stopped.style!.color, FlowSurfaces.light.errorPill.ink);
    });
  });

  group('failure', () {
    testWidgets('a failed fetch says so and offers a retry', (tester) async {
      await _pump(tester, api: FakeHealthApi()..failNext = 1);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Coba lagi'), findsOneWidget);
    });

    testWidgets('an empty fleet says so rather than showing a blank page',
        (tester) async {
      await _pump(tester, fleet: const []);

      expect(find.text('Belum ada connector terdaftar.'), findsOneWidget);
    });
  });

  testWidgets('every row is readable by a screen reader', (tester) async {
    await _pump(tester);

    expect(
      find.bySemanticsLabel(
        RegExp(r'Kamera 34 — Simpang Ngembal, berhenti'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('content is capped at the 448 px mobile-first width',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester);

    expect(
      tester.getSize(find.byKey(const ValueKey('kesehatan-list'))).width,
      inInclusiveRange(1, 448),
    );
  });
}
