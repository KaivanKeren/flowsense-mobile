import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../core/logging/logger.dart';
import '../data/auth/auth_api.dart';
import '../data/auth/fake_auth_api.dart';
import '../data/auth/http_auth_api.dart';
import '../data/auth/token_store.dart';
import '../data/models/operator_account.dart';
import 'providers.dart';

/// Where the operator stands with the backend.
sealed class AuthState {
  const AuthState();
}

/// Reading the stored token on a cold start. Distinct from signed-out so the
/// app does not flash the login screen at someone who is already signed in.
class AuthRestoring extends AuthState {
  const AuthRestoring();
}

class AuthSignedOut extends AuthState {
  const AuthSignedOut({this.message});

  /// Why they are here, when it was not their choice — an expired token
  /// mid-session, for instance.
  final String? message;
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn({required this.token, required this.operator});

  final String token;
  final OperatorAccount operator;
}

/// Overridden in tests and by the operator entry point.
final authApiProvider = Provider<AuthApi>((ref) {
  final config = ref.watch(appConfigProvider);
  return config.isConfigured ? HttpAuthApi(config) : FakeAuthApi();
});

final tokenStoreProvider =
    Provider<TokenStore>((ref) => const SecureTokenStore());

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Kicked off, not awaited: the screen renders `AuthRestoring` immediately
    // and swaps when the answer arrives.
    unawaited(_restore());
    return const AuthRestoring();
  }

  Future<void> _restore() async {
    final store = ref.read(tokenStoreProvider);
    final token = await store.read();
    if (token == null || token.isEmpty) {
      state = const AuthSignedOut();
      return;
    }
    try {
      final operator = await ref.read(authApiProvider).me(token);
      state = AuthSignedIn(token: token, operator: operator);
    } on ApiException {
      // A stored token the server no longer honours is worse than none: it
      // would let the app start polling and fail on every request.
      await store.clear();
      state = const AuthSignedOut();
    }
  }

  /// Returns the error to show, or null on success. The screen renders it as a
  /// line above the button — never a snackbar, which disappears before it can
  /// be read.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final session = await ref.read(authApiProvider).login(
            email: email.trim(),
            password: password,
          );
      await ref.read(tokenStoreProvider).write(session.token);
      FlowLog.event('operator signed in', fields: {
        'operator_id': session.operator.id,
      });
      state = AuthSignedIn(
        token: session.token,
        operator: session.operator,
      );
      return null;
    } on ApiException catch (e) {
      // The credential message is the server's; anything else is a connection
      // problem and should not be reported as a rejected password.
      return e.statusCode == 401
          ? 'Email atau kata sandi salah'
          : 'Tidak dapat menghubungi server. Coba lagi.';
    }
  }

  Future<void> signOut() async {
    final current = state;
    if (current is AuthSignedIn) {
      await ref.read(authApiProvider).logout(current.token);
    }
    await ref.read(tokenStoreProvider).clear();
    state = const AuthSignedOut();
  }

  /// A 401 arriving mid-poll. Clears the token and drops to the login screen
  /// with an explanation, rather than leaving the console retrying forever
  /// against a session that is gone.
  Future<void> expire() async {
    await ref.read(tokenStoreProvider).clear();
    FlowLog.event('operator session expired');
    state = const AuthSignedOut(message: 'Sesi berakhir. Masuk lagi.');
  }
}

/// Whether the demo credentials should be pre-filled.
///
/// Only when there is no backend configured — the fixtures build. A build
/// pointed at a real server starts with empty fields, because pre-filling a
/// real account's address on a shared device is a different thing entirely.
final prefillDemoCredentialsProvider =
    Provider<bool>((ref) => !ref.watch(appConfigProvider).isConfigured);
