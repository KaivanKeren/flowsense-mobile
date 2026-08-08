import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/api_exception.dart';
import '../../core/config/app_config.dart';
import '../models/operator_account.dart';
import 'auth_api.dart';

/// Talks to `/v1/auth/*`.
///
/// Deliberately **not** retried. A wrong password does not become right on the
/// second attempt, and silently re-posting credentials is how an account
/// lockout counter gets tripped by a flaky signal.
class HttpAuthApi implements AuthApi {
  HttpAuthApi(this._config, {http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final AppConfig _config;
  final http.Client _client;
  final bool _ownsClient;

  Uri _uri(String path) => Uri.parse('${_config.apiBase}$path');

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final http.Response response;
    try {
      response = await _client.post(
        _uri('/v1/auth/login'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
    } on Object catch (e) {
      throw ApiException('Tidak dapat menghubungi server', cause: e);
    }

    if (response.statusCode == 401) {
      throw const ApiException(
        'Email atau kata sandi salah',
        statusCode: 401,
      );
    }
    if (response.statusCode >= 400) {
      throw ApiException(
        'Masuk gagal',
        statusCode: response.statusCode,
      );
    }

    return AuthSession.fromJson(_object(response.body));
  }

  @override
  Future<void> logout(String token) async {
    try {
      await _client.post(
        _uri('/v1/auth/logout'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } on Object {
      // A failed logout must never trap someone in a session they asked to
      // leave. The local token is cleared regardless by the caller.
    }
  }

  @override
  Future<OperatorAccount> me(String token) async {
    final http.Response response;
    try {
      response = await _client.get(
        _uri('/v1/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } on Object catch (e) {
      throw ApiException('Tidak dapat menghubungi server', cause: e);
    }

    if (response.statusCode == 401) {
      throw const ApiException('Sesi berakhir', statusCode: 401);
    }
    if (response.statusCode >= 400) {
      throw ApiException('Gagal memuat akun', statusCode: response.statusCode);
    }
    return OperatorAccount.fromJson(_object(response.body));
  }

  /// Malformed JSON surfaces as [ApiException], never a raw [FormatException] —
  /// the same rule the traffic API follows.
  Map<String, dynamic> _object(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (e) {
      throw ApiException('Balasan server tidak dapat dibaca', cause: e);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Balasan server tidak berbentuk objek');
    }
    return decoded;
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
