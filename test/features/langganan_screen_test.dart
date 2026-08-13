import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/data/api/flowsense_api.dart';
import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/data/models/traffic_snapshot.dart';
import 'package:flowsense_mobile/data/prefs/app_mode_store.dart';
import 'package:flowsense_mobile/data/prefs/subscription_store.dart';
import 'package:flowsense_mobile/domain/app_mode.dart';
import 'package:flowsense_mobile/domain/subscription.dart';
import 'package:flowsense_mobile/features/langganan/langganan_screen.dart';
import 'package:flowsense_mobile/features/tentang/tentang_screen.dart';
import 'package:flowsense_mobile/state/app_mode_providers.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _intersections = [
  const Intersection(
    id: '30',
    name: 'Simpang DPRD',
    lat: -6.8,
    lon: 110.84,
    lanes: ['kota'],
    capacity: {'kota': 10},
  ),
  const Intersection(
    id: '31',
    name: 'Simpang Tujuh',
    lat: -6.81,
    lon: 110.83,
    lanes: ['barat'],
    capacity: {'barat': 10},
  ),
];

class _StubApi implements FlowSenseApi {
  @override
  Future<TrafficSnapshot> snapshot() async =>
      TrafficSnapshot.empty(DateTime.utc(2026, 8, 2, 12));

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

Future<ProviderContainer> _pump(WidgetTester tester) async {
  late ProviderContainer container;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiProvider.overrideWithValue(_StubApi()),
      appModeStoreProvider.overrideWithValue(FakeAppModeStore()),
    ],
    child: MaterialApp(
      theme: flowSenseTheme(),
      home: Consumer(builder: (context, ref, _) {
        container = ProviderScope.containerOf(context);
        return const LanggananScreen();
      }),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() {
    // No platform channel: shared_preferences is mocked, per the project's
    // standing rule that tests touch neither the network nor a plugin.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('lists every intersection with a switch, all off by default',
      (tester) async {
    await _pump(tester);

    expect(find.text('Simpang DPRD'), findsOneWidget);
    expect(find.text('Simpang Tujuh'), findsOneWidget);

    final switches = tester.widgetList<Switch>(find.byType(Switch));
    expect(switches, hasLength(2));
    // The app never opts anyone in on their behalf.
    expect(switches.every((s) => s.value), isFalse);
  });

  testWidgets('toggling a switch subscribes that intersection',
      (tester) async {
    final container = await _pump(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(container.read(subscriptionProvider).isSubscribed('30'), isTrue);
    expect(container.read(subscriptionProvider).isSubscribed('31'), isFalse);
  });

  testWidgets('a subscription is written to the device', (tester) async {
    await _pump(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    // Device-local, and nowhere else. There is no endpoint that receives it.
    final stored = await const SubscriptionStore().load();
    expect(stored.isSubscribed('30'), isTrue);
  });

  testWidgets('the threshold defaults to macet only and can be changed',
      (tester) async {
    final container = await _pump(tester);

    expect(
      container.read(subscriptionProvider).threshold,
      AlertThreshold.macetSaja,
    );

    await tester.tap(find.text('Padat dan macet'));
    await tester.pumpAndSettle();

    expect(
      container.read(subscriptionProvider).threshold,
      AlertThreshold.padatDanMacet,
    );
  });

  testWidgets('the commute peaks are shown as the default active hours',
      (tester) async {
    await _pump(tester);

    // Losing these is how the app starts notifying people at 2am.
    expect(find.text('06.00 – 09.00'), findsOneWidget);
    expect(find.text('15.00 – 19.00'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Di luar jam ini, notifikasi tidak dikirim.'),
      200,
    );
    expect(find.text('Di luar jam ini, notifikasi tidak dikirim.'),
        findsOneWidget);
  });

  testWidgets('a time range can be removed', (tester) async {
    final container = await _pump(tester);

    await tester.tap(find.byTooltip('Hapus rentang').first);
    await tester.pumpAndSettle();

    expect(container.read(subscriptionProvider).activeHours, hasLength(1));
    expect(find.text('06.00 – 09.00'), findsNothing);
  });

  testWidgets('Tentang is reached from here, not from the tab bar',
      (tester) async {
    await _pump(tester);

    await tester.scrollUntilVisible(find.text('Tentang dan sumber data'), 200);
    await tester.tap(find.text('Tentang dan sumber data'));
    await tester.pumpAndSettle();

    expect(find.byType(TentangScreen), findsOneWidget);
  });

  testWidgets('the console is reachable from here, and only from here',
      (tester) async {
    // The one door into the operator side now that the two builds are one app.
    // It sits below Tentang rather than in the tab bar: the citizen shell has
    // three tabs, and that number is a decision.
    final container = await _pump(tester);

    await tester.scrollUntilVisible(find.text('Masuk sebagai operator'), 200);
    await tester.tap(find.byKey(const ValueKey('switch-to-operator')));
    await tester.pumpAndSettle();

    expect(container.read(appModeProvider), AppMode.operator);
  });

  testWidgets('stored settings are restored on open', (tester) async {
    await const SubscriptionStore().save(const SubscriptionSettings(
      cameraIds: {'31'},
      threshold: AlertThreshold.padatDanMacet,
    ));

    final container = await _pump(tester);

    expect(container.read(subscriptionProvider).isSubscribed('31'), isTrue);
    expect(
      container.read(subscriptionProvider).threshold,
      AlertThreshold.padatDanMacet,
    );
  });
}
