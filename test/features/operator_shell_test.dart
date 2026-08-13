import 'dart:io';

import 'package:flowsense_mobile/app/bootstrap.dart';
import 'package:flowsense_mobile/core/api_exception.dart';
import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/core/max_width.dart';
import 'package:flowsense_mobile/data/api/fake_flowsense_api.dart';
import 'package:flowsense_mobile/data/auth/fake_auth_api.dart';
import 'package:flowsense_mobile/data/auth/token_store.dart';
import 'package:flowsense_mobile/data/prefs/app_mode_store.dart';
import 'package:flowsense_mobile/domain/app_mode.dart';
import 'package:flowsense_mobile/state/app_mode_providers.dart';
import 'package:flowsense_mobile/features/operator/akun_screen.dart';
import 'package:flowsense_mobile/features/operator/dashboard_screen.dart';
import 'package:flowsense_mobile/features/operator/kesehatan_screen.dart';
import 'package:flowsense_mobile/features/operator/login_screen.dart';
import 'package:flowsense_mobile/features/operator/operator_shell.dart';
import 'package:flowsense_mobile/features/operator/peringatan_screen.dart';
import 'package:flowsense_mobile/state/auth_providers.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 8, 2, 12);

FakeFlowSenseApi _api() => FakeFlowSenseApi.fromStrings(
      intersectionsJson:
          File('test/fixtures/intersections.json').readAsStringSync(),
      recordsJsonl: File('test/fixtures/records.jsonl').readAsStringSync(),
      now: () => _t0,
    );

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  FakeFlowSenseApi? api,
  FakeTokenStore? store,
  Widget? home,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final authApi = FakeAuthApi();
  final container = ProviderContainer(overrides: [
    apiProvider.overrideWithValue(api ?? _api()),
    appConfigProvider.overrideWithValue(
      const AppConfig(apiBase: 'https://x.test', apiKey: 'k'),
    ),
    clockProvider.overrideWithValue(FakeClock(_t0)),
    snapshotCacheProvider.overrideWithValue(null),
    authApiProvider.overrideWithValue(authApi),
    tokenStoreProvider
        .overrideWithValue(store ?? FakeTokenStore(authApi.token)),
    appModeStoreProvider.overrideWithValue(FakeAppModeStore(AppMode.operator)),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: home ?? const FlowSenseApp(),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('tabs', () {
    testWidgets('exactly four, and no fifth', (tester) async {
      await _pump(tester);

      expect(OperatorTab.values, hasLength(4));
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Kesehatan'), findsOneWidget);
      expect(find.text('Peringatan'), findsOneWidget);
      expect(find.text('Akun'), findsOneWidget);
    });

    testWidgets('opens on the dashboard', (tester) async {
      await _pump(tester);
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('each tab reaches its screen', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Kesehatan'));
      await tester.pumpAndSettle();
      expect(find.byType(KesehatanScreen), findsOneWidget);

      await tester.tap(find.text('Peringatan'));
      await tester.pumpAndSettle();
      expect(find.byType(PeringatanScreen), findsOneWidget);

      await tester.tap(find.text('Akun'));
      await tester.pumpAndSettle();
      expect(find.byType(AkunScreen), findsOneWidget);
    });

    testWidgets('the body is actually visible, not a zero-size box',
        (tester) async {
      // A loose IndexedStack shrink-wraps its children, and a nested Scaffold
      // has no intrinsic height — the citizen shell shipped exactly that bug.
      await _pump(tester);

      final body = tester.getSize(find.byType(IndexedStack));
      expect(body.height, greaterThan(400));
    });

    testWidgets('keeps each tab alive across switches', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Akun'));
      await tester.pumpAndSettle();

      expect(
        find.byType(DashboardScreen, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('the bar caps at 448 px like everything else', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(tester);

      for (final element in find
          .descendant(
            of: find.byType(MaxWidth448),
            matching: find.byType(ConstrainedBox),
          )
          .evaluate()) {
        expect(
          (element.renderObject! as RenderBox).size.width,
          lessThanOrEqualTo(448),
        );
      }
    });
  });

  group('akun', () {
    testWidgets('shows the signed-in operator and the app version',
        (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Akun'));
      await tester.pumpAndSettle();

      expect(find.text('Operator Dinas'), findsOneWidget);
      expect(find.text('operator@flowsense.test'), findsOneWidget);
      expect(find.text('Versi aplikasi'), findsOneWidget);
    });

    testWidgets('has no profile photo', (tester) async {
      // Ruled out by the spec, and the console knows nothing about a person
      // beyond a name and an email anyway.
      await _pump(tester);
      await tester.tap(find.text('Akun'));
      await tester.pumpAndSettle();

      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('signing out asks first, then returns to login',
        (tester) async {
      final store = FakeTokenStore(FakeAuthApi().token);
      final container = await _pump(tester, store: store);

      await tester.tap(find.text('Akun'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sign-out')));
      await tester.pumpAndSettle();

      // An accidental tap in the field costs a password nobody carries.
      expect(find.text('Keluar dari konsol?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Keluar'));
      await tester.pumpAndSettle();

      expect(container.read(authProvider), isA<AuthSignedOut>());
      expect(await store.read(), isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('cancelling keeps the session', (tester) async {
      final container = await _pump(tester);

      await tester.tap(find.text('Akun'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sign-out')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Batal'));
      await tester.pumpAndSettle();

      expect(container.read(authProvider), isA<AuthSignedIn>());
    });
  });

  group('an expired token', () {
    testWidgets('signs the operator out and stops polling', (tester) async {
      // The spec's done-criterion, and what makes "401 is never retried"
      // mean something: without this the console polls forever against a
      // session that is gone.
      final api = _api();
      final store = FakeTokenStore(FakeAuthApi().token);
      final container = await _pump(tester, api: api, store: store);

      expect(find.byType(OperatorShell), findsOneWidget);

      // The server starts rejecting the token mid-poll.
      api.failNext = 1;
      api.failWith = const ApiException('Sesi berakhir', statusCode: 401);
      await container.read(repositoryProvider).poll();
      await tester.pumpAndSettle();

      expect(container.read(authProvider), isA<AuthSignedOut>());
      expect(await store.read(), isNull, reason: 'the token is cleared');
      expect(find.byType(LoginScreen), findsOneWidget);

      // No further request goes out carrying a credential already rejected.
      final callsAfter = api.snapshotCalls;
      await tester.pump(const Duration(seconds: 30));
      expect(api.snapshotCalls, callsAfter);
    });

    testWidgets('a 503 does not sign anyone out', (tester) async {
      // Only 401 means the session is gone. A server having a bad minute is
      // exactly what the last-good-snapshot behaviour is for.
      final api = _api();
      final container = await _pump(tester, api: api);

      api.failNext = 1;
      await container.read(repositoryProvider).poll();
      await tester.pumpAndSettle();

      expect(container.read(authProvider), isA<AuthSignedIn>());
      expect(find.byType(OperatorShell), findsOneWidget);
    });
  });
}
