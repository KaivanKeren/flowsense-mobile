import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/data/api/flowsense_api.dart';
import 'package:flowsense_mobile/data/auth/fake_auth_api.dart';
import 'package:flowsense_mobile/data/auth/token_store.dart';
import 'package:flowsense_mobile/data/calibration/calibration_api.dart';
import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/data/models/traffic_snapshot.dart';
import 'package:flowsense_mobile/features/operator/kalibrasi_screen.dart';
import 'package:flowsense_mobile/widgets/widgets.dart';
import 'package:flowsense_mobile/state/auth_providers.dart';
import 'package:flowsense_mobile/state/calibration_providers.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 8, 2, 9, 14);

const _simpang = Intersection(
  id: '30',
  name: 'Simpang DPRD',
  lat: -6.8047,
  lon: 110.8405,
  lanes: ['kota', 'ploso', 'demak', 'sekoe'],
  capacity: {'kota': 12, 'ploso': 12, 'demak': 12, 'sekoe': 12},
);

/// The reference image's counts: 9, 5, 3, 1.
TrafficRecord _record() => TrafficRecord(
      ts: _t0,
      cameraId: '30',
      cameraName: 'Simpang DPRD',
      totalVehicles: 18,
      perLane: const {'kota': 9, 'ploso': 5, 'demak': 3, 'sekoe': 1},
    );

class _StubApi implements FlowSenseApi {
  @override
  Future<TrafficSnapshot> snapshot() async =>
      TrafficSnapshot(fetchedAt: _t0, records: [_record()]);

  @override
  Future<List<Intersection>> intersections() async => [_simpang];

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

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  FakeCalibrationApi? api,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final authApi = FakeAuthApi();
  final container = ProviderContainer(overrides: [
    apiProvider.overrideWithValue(_StubApi()),
    appConfigProvider.overrideWithValue(const AppConfig(
      apiBase: 'https://x.test',
      apiKey: 'k',
      laneCapacityDefault: 12,
    )),
    clockProvider.overrideWithValue(FakeClock(_t0)),
    snapshotCacheProvider.overrideWithValue(null),
    authApiProvider.overrideWithValue(authApi),
    tokenStoreProvider.overrideWithValue(FakeTokenStore(authApi.token)),
    calibrationApiProvider
        .overrideWithValue(api ?? FakeCalibrationApi(now: () => _t0)),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: flowSenseTheme(),
      home: const KalibrasiScreen(cameraId: '30'),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

Finder _field(String lane) => find.descendant(
      of: find.byKey(ValueKey('capacity-$lane')),
      matching: find.byType(EditableText),
    );

Finder _pill(String lane) => find.descendant(
      of: find.byKey(ValueKey('capacity-$lane')),
      matching: find.byType(StatusChip),
    );

void main() {

  group('layout', () {
    testWidgets('names the intersection and explains what capacity means',
        (tester) async {
      await _pump(tester);

      // The bar names the screen and the body names the intersection. One
      // combined app-bar title was 5 px short of fitting at 320 px and
      // textScale 1.3, and shipped as `Kalibrasi — Simpang DPR…`.
      expect(find.text('Kalibrasi'), findsOneWidget);
      expect(find.text('Simpang DPRD'), findsOneWidget);
      expect(
        find.text(
          'Kapasitas adalah jumlah kendaraan yang memenuhi lajur saat '
          'berhenti total.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('one row per lane, showing the current count', (tester) async {
      await _pump(tester);

      expect(find.text('Arah kota'), findsOneWidget);
      expect(find.text('sekarang 9 kendaraan'), findsOneWidget);
      expect(find.text('sekarang 1 kendaraan'), findsOneWidget);
    });

    testWidgets('offers Simpan and Batal, with no autosave', (tester) async {
      await _pump(tester);

      expect(find.widgetWithText(FilledButton, 'Simpan'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Batal'), findsOneWidget);
    });
  });

  group('live preview', () {
    testWidgets('shows the level the current capacity produces',
        (tester) async {
      await _pump(tester);

      // 9/12 is macet, 3/12 is lancar.
      expect(
        find.descendant(of: _pill('kota'), matching: find.text('Macet')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _pill('demak'), matching: find.text('Lancar')),
        findsOneWidget,
      );
    });

    testWidgets('editing the capacity changes the level immediately',
        (tester) async {
      // The spec's own example, and the reason this screen has a preview at
      // all: the operator sees the consequence before committing to it.
      await _pump(tester);

      await tester.enterText(_field('kota'), '16');
      await tester.pump();

      // 9/16 is padat, where 9/12 was macet.
      expect(
        find.descendant(of: _pill('kota'), matching: find.text('Padat')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _pill('kota'), matching: find.text('Macet')),
        findsNothing,
      );
    });

    testWidgets('the preview does not lie while the input is invalid',
        (tester) async {
      await _pump(tester);

      await tester.enterText(_field('kota'), '0');
      await tester.pump();

      // Zero means "uncalibrated" downstream, so the preview must not claim a
      // level it cannot compute.
      expect(
        find.descendant(
          of: _pill('kota'),
          matching: find.text('Tidak ada data'),
        ),
        findsOneWidget,
      );
      expect(find.text('Kapasitas harus lebih dari 0'), findsOneWidget);
    });
  });

  group('saving', () {
    testWidgets('nothing is written until Simpan is pressed', (tester) async {
      final api = FakeCalibrationApi(now: () => _t0);
      await _pump(tester, api: api);

      await tester.enterText(_field('kota'), '16');
      await tester.pump();

      expect(api.saveCalls, 0, reason: 'no autosave');
    });

    testWidgets('Simpan writes every lane and records who did it',
        (tester) async {
      final api = FakeCalibrationApi(now: () => _t0);
      await _pump(tester, api: api);

      await tester.enterText(_field('kota'), '16');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();

      final saved = await api.calibration('30');
      expect(saved.capacity['kota'], 16);
      expect(saved.capacity['ploso'], 12);
      expect(saved.updatedBy, 'Operator Dinas');
      expect(saved.updatedAt, _t0);
    });

    testWidgets('after saving it says who and when', (tester) async {
      await _pump(tester);

      await tester.enterText(_field('kota'), '16');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();

      expect(
        find.text('Terakhir diubah Operator Dinas, 2 Agustus 2026 09.14.'),
        findsOneWidget,
      );
    });

    testWidgets('an invalid lane blocks the save entirely', (tester) async {
      final api = FakeCalibrationApi(now: () => _t0);
      await _pump(tester, api: api);

      await tester.enterText(_field('kota'), '0');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();

      // Partially saving a calibration would leave the classification in a
      // state nobody chose.
      expect(api.saveCalls, 0);
    });

    testWidgets('a failed save does not claim success', (tester) async {
      final api = FakeCalibrationApi(now: () => _t0)..failNext = 1;
      await _pump(tester, api: api);

      await tester.enterText(_field('kota'), '16');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Gagal menyimpan'), findsOneWidget);
      expect(find.textContaining('Terakhir diubah'), findsNothing);
    });

    testWidgets('Batal restores the stored values', (tester) async {
      await _pump(tester);

      await tester.enterText(_field('kota'), '16');
      await tester.pump();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Batal'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: _pill('kota'), matching: find.text('Macet')),
        findsOneWidget,
      );
    });
  });

  testWidgets('the screen writes capacity and nothing else', (tester) async {
    await _pump(tester);

    // Capacity and alert acknowledgement are the only two writes the console
    // has. Nothing here may touch a signal.
    for (final forbidden in ['Hijau', 'Durasi', 'Manual', 'Kendali']) {
      expect(find.textContaining(forbidden), findsNothing, reason: forbidden);
    }
  });
}
