import 'dart:async';

import 'package:flowsense_mobile/app/theme.dart';
import 'package:flowsense_mobile/core/api_exception.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/core/max_width.dart';
import 'package:flowsense_mobile/data/auth/fake_auth_api.dart';
import 'package:flowsense_mobile/data/auth/token_store.dart';
import 'package:flowsense_mobile/features/operator/login_screen.dart';
import 'package:flowsense_mobile/state/auth_providers.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps the screen at the phone size the spec names, 360x800.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  FakeAuthApi? api,
  FakeTokenStore? store,
  AppConfig config = const AppConfig(),
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(overrides: [
    appConfigProvider.overrideWithValue(config),
    authApiProvider.overrideWithValue(api ?? FakeAuthApi()),
    tokenStoreProvider.overrideWithValue(store ?? FakeTokenStore()),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: flowSenseTheme(),
      home: const LoginScreen(),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

/// The text-entry widget inside a keyed field.
Finder _input(String field) => find.descendant(
      of: find.byKey(ValueKey('field-$field')),
      matching: find.byType(EditableText),
    );

void main() {
  group('layout', () {
    testWidgets('shows the wordmark, subtitle and both field labels',
        (tester) async {
      await _pump(tester);

      expect(find.text('FlowSense'), findsOneWidget);
      expect(find.text('Konsol operator'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Kata sandi'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Masuk'), findsOneWidget);
    });

    testWidgets('carries the line about how accounts are issued',
        (tester) async {
      await _pump(tester);

      // Answers "can I sign up?" on the screen, so nobody has to ask.
      expect(
        find.text(
          'Akun diterbitkan oleh dinas. Hubungi administrator bila lupa sandi.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('offers no self-service account routes', (tester) async {
      await _pump(tester);

      // Registration, password reset and OAuth are all listed under
      // "deliberately not built". None of them may appear as a dead link.
      expect(find.textContaining('Daftar'), findsNothing);
      expect(find.textContaining('Lupa sandi'), findsNothing);
      expect(find.textContaining('Google'), findsNothing);
    });

    testWidgets('is one full-width column, not a floating card',
        (tester) async {
      await _pump(tester);

      expect(find.byType(Card), findsNothing);
      expect(find.byType(MaxWidth448), findsOneWidget);
    });

    testWidgets('the button spans the content width', (tester) async {
      await _pump(tester);

      final button = tester.getSize(find.byType(FilledButton));
      // 360 wide, less the 24 px margin on each side.
      expect(button.width, closeTo(312, 1));
      expect(button.height, greaterThanOrEqualTo(44));
    });
  });

  group('password visibility', () {
    testWidgets('starts obscured and can be revealed', (tester) async {
      await _pump(tester);

      EditableText passwordField() => tester.widget<EditableText>(
            _input('password'),
          );

      expect(passwordField().obscureText, isTrue);

      await tester.tap(find.byKey(const ValueKey('toggle-password')));
      await tester.pumpAndSettle();

      expect(passwordField().obscureText, isFalse);
    });

    testWidgets('the email field is never obscured', (tester) async {
      await _pump(tester);

      final email = tester.widget<EditableText>(
        _input('email'),
      );
      expect(email.obscureText, isFalse);
    });
  });

  group('demo credentials', () {
    testWidgets('are pre-filled when running on fixtures', (tester) async {
      // The spec asks for this: mistyping a password twice in front of an
      // examiner is a bad way to open a presentation.
      await _pump(tester);

      expect(find.text(DemoOperator.email), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Masuk'),
        findsOneWidget,
      );
    });

    testWidgets('are absent once a real backend is configured',
        (tester) async {
      await _pump(
        tester,
        config: const AppConfig(apiBase: 'https://x.test', apiKey: 'k'),
      );

      expect(find.text(DemoOperator.email), findsNothing);
    });
  });

  group('signing in', () {
    testWidgets('a correct password signs the operator in', (tester) async {
      final store = FakeTokenStore();
      final container = await _pump(tester, store: store);

      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pumpAndSettle();

      expect(container.read(authProvider), isA<AuthSignedIn>());
      // The token reaches secure storage, not shared_preferences.
      expect(store.writes, 1);
      expect(await store.read(), isNotNull);
    });

    testWidgets('a wrong password shows a line, not a snackbar',
        (tester) async {
      await _pump(tester);

      await tester.enterText(
        _input('password'),
        'salah',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pumpAndSettle();

      // A snackbar disappears before it can be read.
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Email atau kata sandi salah'), findsOneWidget);
    });

    testWidgets('the error sits above the button', (tester) async {
      await _pump(tester);

      await tester.enterText(
        _input('password'),
        'salah',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pumpAndSettle();

      final error = tester.getTopLeft(find.text('Email atau kata sandi salah'));
      final button = tester.getTopLeft(find.byType(FilledButton));
      expect(error.dy, lessThan(button.dy));
    });

    testWidgets('the error is not the macet red', (tester) async {
      await _pump(tester);

      await tester.enterText(
        _input('password'),
        'salah',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pumpAndSettle();

      // The four congestion hues mean congestion and nothing else. This is the
      // console screen where breaking that is most tempting.
      final style =
          tester.widget<Text>(find.text('Email atau kata sandi salah')).style;
      expect(style!.color, FlowSurfaces.light.errorInk);
      expect(style.color, isNot(CongestionColors.light.macet));
    });

    testWidgets('a server failure is not reported as a bad password',
        (tester) async {
      final api = FakeAuthApi()
        ..failWith = const ApiException('boom', statusCode: 503);
      await _pump(tester, api: api);

      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Email atau kata sandi salah'), findsNothing);
      expect(
        find.text('Tidak dapat menghubungi server. Coba lagi.'),
        findsOneWidget,
      );
    });

    testWidgets('the button shows loading in place, opening no dialog',
        (tester) async {
      final api = FakeAuthApi()..gate = Completer<void>();
      await _pump(tester, api: api);

      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pump(); // request is held open by the gate

      // The spec: the button enters a loading state, it does not open a
      // dialog.
      expect(find.byType(Dialog), findsNothing);
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      api.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a second tap while in flight does not sign in twice',
        (tester) async {
      // Re-posting credentials is how a lockout counter gets tripped by a
      // flaky signal.
      final api = FakeAuthApi()..gate = Completer<void>();
      await _pump(tester, api: api);

      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pump();
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump();

      api.gate!.complete();
      await tester.pumpAndSettle();

      expect(api.loginCalls, 1);
    });

    testWidgets('an empty email is refused before any request',
        (tester) async {
      final api = FakeAuthApi();
      await _pump(
        tester,
        api: api,
        config: const AppConfig(apiBase: 'https://x.test', apiKey: 'k'),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pumpAndSettle();

      expect(api.loginCalls, 0);
      expect(find.text('Email dan kata sandi harus diisi'), findsOneWidget);
    });
  });

  testWidgets('an expired session explains why the screen is showing',
      (tester) async {
    final container = await _pump(tester);
    container.read(authProvider.notifier).state =
        const AuthSignedOut(message: 'Sesi berakhir. Masuk lagi.');
    await tester.pumpAndSettle();

    expect(find.text('Sesi berakhir. Masuk lagi.'), findsOneWidget);
  });
}
