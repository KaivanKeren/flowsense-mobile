import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/api_exception.dart';
import '../../core/config/app_config.dart';
import '../models/intersection.dart';
import '../models/traffic_record.dart';
import '../models/traffic_snapshot.dart';
import 'flowsense_api.dart';

/// Talks to the FlowSense backend over HTTP.
///
/// Mirrors `flowsense/api.py` deliberately — same header, same retry shape, so
/// the two sides fail the same way and a demo failure is diagnosable from
/// either end.
///
/// Both the transport and the sleep are injected, so tests exercise the retry
/// loop with no network and no wall-clock delay.
class HttpFlowSenseApi implements FlowSenseApi {
  HttpFlowSenseApi(
    this._config, {
    http.Client? client,
    Future<void> Function(Duration)? sleep,
    this.retries = 2,
    this.backoffBase = const Duration(milliseconds: 200),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _sleep = sleep ?? _realSleep;

  static Future<void> _realSleep(Duration d) => Future<void>.delayed(d);

  final AppConfig _config;
  final http.Client _client;
  final bool _ownsClient;
  final Future<void> Function(Duration) _sleep;

  /// Retries *after* the first attempt, so the default means 3 calls at most.
  final int retries;

  /// Delay before retry `n` is `backoffBase * 2^n`, counting from zero.
  final Duration backoffBase;

  @override
  Future<List<Intersection>> intersections() async {
    final body = await _get('/v1/intersections');
    if (body is! List) {
      throw const ApiException('Daftar simpang tidak berbentuk list');
    }
    return [
      for (final e in body)
        if (e is Map<String, dynamic>) Intersection.fromJson(e),
    ];
  }

  @override
  Future<TrafficSnapshot> snapshot() async {
    final body = await _get('/v1/snapshot');
    if (body is! Map<String, dynamic>) {
      throw const ApiException('Snapshot tidak berbentuk objek');
    }
    return TrafficSnapshot.fromJson(body);
  }

  @override
  Future<List<TrafficRecord>> history(
    String id, {
    DateTime? from,
    DateTime? to,
    String bucket = '1m',
  }) async {
    final body = await _get(
      '/v1/intersections/${Uri.encodeComponent(id)}/history',
      query: {
        if (from != null) 'from': _epochSeconds(from),
        if (to != null) 'to': _epochSeconds(to),
        'bucket': bucket,
      },
    );
    if (body is! List) {
      throw const ApiException('Riwayat tidak berbentuk list');
    }
    return [
      for (final e in body)
        if (e is Map<String, dynamic>) TrafficRecord.fromJson(e),
    ];
  }

  @override
  void close() {
    if (_ownsClient) _client.close();
  }

  /// `ts` is epoch **seconds** on both sides of this wire. See the contract.
  static String _epochSeconds(DateTime t) =>
      '${t.millisecondsSinceEpoch ~/ 1000}';

  Uri _uri(String path, Map<String, String>? query) {
    final base = _config.apiBase.endsWith('/')
        ? _config.apiBase.substring(0, _config.apiBase.length - 1)
        : _config.apiBase;
    final uri = Uri.parse('$base$path');
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  /// One request with retry/backoff. Returns decoded JSON.
  ///
  /// Retries only failures that can plausibly resolve themselves — 5xx, 408,
  /// 429, and transport errors. An auth failure or a malformed body is
  /// terminal on the first attempt.
  Future<Object?> _get(String path, {Map<String, String>? query}) async {
    ApiException? last;

    for (var attempt = 0; attempt <= retries; attempt++) {
      if (attempt > 0) await _sleep(backoffBase * (1 << (attempt - 1)));

      final http.Response response;
      try {
        response = await _client.get(
          _uri(path, query),
          headers: {
            'X-FlowSense-Key': _config.apiKey,
            'Accept': 'application/json',
          },
        );
      } catch (e) {
        last = ApiException('Tidak dapat menghubungi server', cause: e);
        continue;
      }

      final status = response.statusCode;
      if (status >= 200 && status < 300) {
        try {
          return jsonDecode(response.body);
        } on FormatException catch (e) {
          throw ApiException(
            'Balasan server bukan JSON yang sah',
            statusCode: status,
            cause: e,
          );
        }
      }

      final failure = ApiException(
        'Server menolak permintaan',
        statusCode: status,
      );
      if (!_isRetryable(status)) throw failure;
      last = failure;
    }

    throw last ?? const ApiException('Permintaan gagal');
  }

  static bool _isRetryable(int status) =>
      status >= 500 || status == 408 || status == 429;
}
