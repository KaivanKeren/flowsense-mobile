import 'package:flowsense_mobile/theme/app_theme.dart';
import 'package:flowsense_mobile/theme/tokens.dart';
import 'package:flowsense_mobile/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The four widths the brief names, and the two text scales.
const _widths = [320.0, 360.0, 414.0, 448.0];
const _scales = [1.0, 1.3];

Future<void> _pumpAt(
  WidgetTester tester,
  Widget child, {
  required double width,
  required double scale,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: flowSenseTheme(brightness: brightness),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(FlowSpace.lg),
          child: child,
        ),
      ),
    ),
  ));
}

/// Runs [build] at every width and text scale and asserts nothing overflowed.
///
/// A `RenderFlex overflowed` is thrown during paint, so `takeException` is what
/// catches it — a finder that still locates the widget proves nothing, which is
/// how the truncated tab labels survived review.
Future<void> _survivesEveryWidth(
  WidgetTester tester,
  String what,
  Widget Function() build,
) async {
  for (final width in _widths) {
    for (final scale in _scales) {
      await _pumpAt(tester, build(), width: width, scale: scale);
      expect(
        tester.takeException(),
        isNull,
        reason: '$what overflowed at ${width}px, textScale $scale',
      );
    }
  }
}

void main() {
  group('MetricCard', () {
    testWidgets('shows the label, the figure and the unit', (tester) async {
      await _pumpAt(
        tester,
        const MetricCard(
          label: 'Persimpangan aktif',
          value: '12',
          unit: 'simpang',
        ),
        width: 360,
        scale: 1.0,
      );

      // The label is uppercased on screen…
      expect(find.text('PERSIMPANGAN AKTIF'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('simpang'), findsOneWidget);
    });

    testWidgets('announces the label in sentence case', (tester) async {
      // …and stays sentence case for the screen reader: TalkBack handed
      // `PERSIMPANGAN AKTIF` may spell it out letter by letter.
      await _pumpAt(
        tester,
        const MetricCard(label: 'Persimpangan aktif', value: '12'),
        width: 360,
        scale: 1.0,
      );
      expect(
        find.bySemanticsLabel('Persimpangan aktif, 12'),
        findsOneWidget,
      );
    });

    testWidgets('a five-digit figure shrinks rather than overflowing',
        (tester) async {
      await _survivesEveryWidth(
        tester,
        'MetricCard with a long figure',
        () => const SizedBox(
          width: 140,
          child: MetricCard(
            label: 'Rata-rata antrean',
            value: '12345',
            unit: 'kendaraan',
            trend: MetricTrend.up,
            trendLabel: 'vs 1 jam lalu',
          ),
        ),
      );
    });
  });

  group('MetricGrid', () {
    testWidgets('four cards fit at every width', (tester) async {
      // The bug this replaces: a horizontal row of metric cards cut in half at
      // the right edge, with nothing on screen to say more existed.
      await _survivesEveryWidth(
        tester,
        'MetricGrid',
        () => const MetricGrid(children: [
          MetricCard(label: 'Macet', value: '1'),
          MetricCard(label: 'Padat', value: '1'),
          MetricCard(label: 'Lancar', value: '2'),
          MetricCard(label: 'Tanpa data', value: '1'),
        ]),
      );
    });

    testWidgets('every card is on screen, none hidden to the right',
        (tester) async {
      await _pumpAt(
        tester,
        const MetricGrid(children: [
          MetricCard(label: 'Macet', value: '1'),
          MetricCard(label: 'Padat', value: '1'),
          MetricCard(label: 'Lancar', value: '2'),
          MetricCard(label: 'Tanpa data', value: '1'),
        ]),
        width: 320,
        scale: 1.0,
      );

      final viewport = tester.view.physicalSize.width;
      for (final label in ['MACET', 'PADAT', 'LANCAR', 'TANPA DATA']) {
        final box = tester.getRect(find.text(label));
        expect(box.right, lessThanOrEqualTo(viewport),
            reason: '$label runs off the right edge');
      }
    });

    testWidgets('drops to one column when two would not fit', (tester) async {
      await _pumpAt(
        tester,
        const SizedBox(
          width: 200,
          child: MetricGrid(children: [
            MetricCard(label: 'Macet', value: '1'),
            MetricCard(label: 'Padat', value: '1'),
          ]),
        ),
        width: 320,
        scale: 1.0,
      );

      final first = tester.getRect(find.text('MACET'));
      final second = tester.getRect(find.text('PADAT'));
      expect(second.top, greaterThan(first.top),
          reason: 'the second card should be below, not beside');
    });
  });

  group('LiveIndicator', () {
    testWidgets('stays on one line in a narrow box', (tester) async {
      // The bug this replaces: `Diperbarui 8 dtk lalu` broken across two lines
      // inside a fixed-width chip.
      await _survivesEveryWidth(
        tester,
        'LiveIndicator',
        () => const SizedBox(
          width: 110,
          child: LiveIndicator(age: Duration(seconds: 8)),
        ),
      );
    });

    testWidgets('says how old the data is in words', (tester) async {
      await _pumpAt(
        tester,
        const LiveIndicator(age: Duration(seconds: 20)),
        width: 360,
        scale: 1.0,
      );
      expect(find.text('Diperbarui 20 detik lalu'), findsOneWidget);
    });

    testWidgets('anything under ten seconds is "baru saja"', (tester) async {
      // `relativeIndonesian` rounds down and refuses to count single seconds,
      // so the indicator never claims a precision the poll interval does not
      // have.
      await _pumpAt(
        tester,
        const LiveIndicator(age: Duration(seconds: 8)),
        width: 360,
        scale: 1.0,
      );
      expect(find.text('Diperbarui baru saja'), findsOneWidget);
    });

    testWidgets('a stale feed says so in words, not only in the dot',
        (tester) async {
      await _pumpAt(
        tester,
        const LiveIndicator(
          age: Duration(minutes: 12),
          isStale: true,
          prefix: 'Data tersimpan',
        ),
        width: 360,
        scale: 1.0,
      );
      expect(find.text('Data tersimpan 12 menit lalu'), findsOneWidget);
    });
  });

  group('SectionHeader', () {
    testWidgets('the qualifier wraps beneath rather than overflowing',
        (tester) async {
      await _survivesEveryWidth(
        tester,
        'SectionHeader',
        () => const SectionHeader(
          title: 'Peringatan aktif hari ini',
          trailing: Text('urut terparah dulu'),
        ),
      );
    });

    testWidgets('mono capitals are opt-in', (tester) async {
      await _pumpAt(
        tester,
        const SectionHeader(title: 'Simpang', mono: true),
        width: 360,
        scale: 1.0,
      );
      expect(find.text('SIMPANG'), findsOneWidget);

      await _pumpAt(
        tester,
        const SectionHeader(title: 'Simpang'),
        width: 360,
        scale: 1.0,
      );
      expect(find.text('Simpang'), findsOneWidget);
    });
  });

  group('AlertBanner', () {
    testWidgets('an emergency override survives every width', (tester) async {
      await _survivesEveryWidth(
        tester,
        'AlertBanner',
        () => AlertBanner.emergency(
          title: 'Override darurat aktif di Simpang DPRD',
          detail: 'Disetel petugas lapangan 16:04 · berlaku 20 menit',
          actionLabel: 'Tinjau',
          onAction: () {},
        ),
      );
    });

    testWidgets('carries an icon as well as a tint', (tester) async {
      await _pumpAt(
        tester,
        const AlertBanner(title: 'Feed tertinggal', tone: StatusTone.warning),
        width: 360,
        scale: 1.0,
      );
      expect(find.byIcon(StatusChip.iconFor(StatusTone.warning)),
          findsOneWidget);
    });
  });

  group('state views', () {
    testWidgets('the error state always offers a way on', (tester) async {
      var retried = false;
      await _pumpAt(
        tester,
        MessageState.error(
          message: 'Riwayat peringatan tidak dapat dimuat.',
          actionLabel: 'Coba lagi',
          onAction: () => retried = true,
        ),
        width: 360,
        scale: 1.0,
      );

      await tester.tap(find.text('Coba lagi'));
      expect(retried, isTrue);
    });

    testWidgets('the skeleton says it is loading, for a screen reader too',
        (tester) async {
      await _pumpAt(tester, const SkeletonList(), width: 360, scale: 1.0);
      expect(find.bySemanticsLabel('Memuat data'), findsOneWidget);
    });

    testWidgets('every state survives every width', (tester) async {
      await _survivesEveryWidth(
        tester,
        'MessageState',
        () => const MessageState.empty(
          title: 'Belum ada peringatan',
          message: 'Tidak ada peringatan pada rentang waktu yang dipilih.',
        ),
      );
      await _survivesEveryWidth(
        tester,
        'SkeletonList',
        () => const SkeletonList(hasLeading: true),
      );
      await _survivesEveryWidth(
        tester,
        'StaleNotice',
        () => StaleNotice(
          message: 'Data tersimpan. Data terakhir 12 menit lalu',
          onRetry: () {},
        ),
      );
    });
  });

  group('AppCard', () {
    testWidgets('a tappable card is one button, not a pile of nodes',
        (tester) async {
      await _pumpAt(
        tester,
        AppCard(
          onTap: () {},
          semanticsLabel: 'Simpang DPRD, macet, 18 kendaraan',
          child: const Column(children: [Text('Simpang DPRD'), Text('18')]),
        ),
        width: 360,
        scale: 1.0,
      );

      expect(find.bySemanticsLabel('Simpang DPRD, macet, 18 kendaraan'),
          findsOneWidget);
      // The inner texts are excluded, so a screen reader does not read the
      // count twice.
      expect(find.bySemanticsLabel('18'), findsNothing);
    });
  });

  testWidgets('every component renders in the dark theme', (tester) async {
    await _pumpAt(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Ringkasan', mono: true),
          const SizedBox(height: FlowSpace.md),
          const MetricGrid(children: [
            MetricCard(label: 'Macet', value: '1'),
            MetricCard(label: 'Lancar', value: '2'),
          ]),
          const SizedBox(height: FlowSpace.md),
          const LiveIndicator(age: Duration(seconds: 8)),
          const SizedBox(height: FlowSpace.md),
          AlertBanner.emergency(title: 'Override darurat aktif'),
          const SizedBox(height: FlowSpace.md),
          const StatusChip(label: 'Berjalan', tone: StatusTone.normal),
          const SizedBox(height: FlowSpace.md),
          const SkeletonList(rows: 2),
        ],
      ),
      width: 360,
      scale: 1.0,
      brightness: Brightness.dark,
    );

    expect(tester.takeException(), isNull);
  });
}
