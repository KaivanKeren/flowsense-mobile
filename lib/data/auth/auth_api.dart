import '../models/operator_account.dart';

/// The three auth endpoints from the operator layout spec.
///
/// Deliberately small. There is no registration, no password reset, no
/// invitation flow, and no role hierarchy — accounts are issued by the dinas
/// through a seeder. Every one of those would be days of work for no marks.
abstract class AuthApi {
  /// `POST /v1/auth/login`
  ///
  /// Throws [ApiException] with `statusCode` 401 when the credentials are
  /// wrong. Everything else is a transport or server failure.
  Future<AuthSession> login({
    required String email,
    required String password,
  });

  /// `POST /v1/auth/logout`
  Future<void> logout(String token);

  /// `GET /v1/auth/me` — used to revive a stored token on a cold start.
  Future<OperatorAccount> me(String token);
}
