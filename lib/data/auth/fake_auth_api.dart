import 'dart:async';

import '../../core/api_exception.dart';
import '../models/operator_account.dart';
import 'auth_api.dart';

/// The demo account.
///
/// Not a secret, and deliberately not a real one: it authenticates only against
/// [FakeAuthApi], which exists because there is no backend yet. A build with
/// `FLOWSENSE_API_BASE` set never consults it.
///
/// This is the one place the global "no credentials in source" rule is bent,
/// and it is bent knowingly — the layout spec asks for the demo credentials to
/// be **pre-filled**, because mistyping a password twice in front of an
/// examiner is a bad way to open a presentation. Pre-filling only happens when
/// the app is already running on fixtures.
abstract final class DemoOperator {
  static const email = 'operator@flowsense.test';
  static const password = 'demo1234';

  static const account = OperatorAccount(
    id: '1',
    nama: 'Operator Dinas',
    email: email,
  );
}

/// An [AuthApi] with no backend behind it.
///
/// Keeps the operator flavor demoable end to end, including the failure path:
/// any password other than the demo one produces the same 401 a real server
/// would, so the error line on the login screen is reachable without a server
/// to reject anything.
class FakeAuthApi implements AuthApi {
  FakeAuthApi({this.token = 'fake-operator-token'});

  final String token;

  int loginCalls = 0;
  int logoutCalls = 0;

  /// Set to make the next call fail with something other than bad credentials,
  /// so the "server unreachable" branch is reachable too.
  ApiException? failWith;

  /// Holds [login] open until completed.
  ///
  /// Without this a fake resolves within the same microtask drain as the tap,
  /// so the in-flight button state exists for no frame at all and cannot be
  /// asserted on — a spinner nobody can catch is a spinner nobody has tested.
  Completer<void>? gate;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    if (gate != null) await gate!.future;
    final failure = failWith;
    if (failure != null) {
      failWith = null;
      throw failure;
    }

    // Case-insensitive on the email, exact on the password: an examiner typing
    // `Operator@...` should still get in, and a password check that ignores
    // case would be teaching the wrong lesson.
    if (email.trim().toLowerCase() != DemoOperator.email ||
        password != DemoOperator.password) {
      throw const ApiException('Email atau kata sandi salah', statusCode: 401);
    }

    return AuthSession(token: token, operator: DemoOperator.account);
  }

  @override
  Future<void> logout(String token) async => logoutCalls++;

  @override
  Future<OperatorAccount> me(String token) async {
    if (token != this.token) {
      throw const ApiException('Sesi berakhir', statusCode: 401);
    }
    return DemoOperator.account;
  }
}
