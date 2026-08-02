import 'dart:convert';

import 'package:flowsense_mobile/core/api_exception.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/data/api/http_flowsense_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _config = AppConfig(
  apiBase: 'https://flowsense.test',
  apiKey: 'secret-key',
);

const _snapshotBody = '{"ts":1755000004,"items":['
    '{"ts":1755000004,"camera_id":30,"camera":"Simpang DPRD Arah Kota",'
    '"total_vehicles":6,"per_lane":{"kota":4,"ploso":2}}]}';

/// Records every sleep the retry loop asks for, so backoff is asserted
/// without a real delay.
class _SleepSpy {
  final List<Duration> calls = [];
  Future<void> call(Duration d) async => calls.add(d);
}

void main() {
  test('snapshot parses a 200 response', () async {
    final api = HttpFlowSenseApi(
      _config,
      client: MockClient((_) async => http.Response(_snapshotBody, 200)),
    );

    final snap = await api.snapshot();
    expect(snap.records, hasLength(1));
    expect(snap.forCamera('30')!.perLane['kota'], 4);
  });

  test('sends the API key header and hits the contract path', () async {
    late http.Request seen;
    final api = HttpFlowSenseApi(
      _config,
      client: MockClient((req) async {
        seen = req;
        return http.Response(_snapshotBody, 200);
      }),
    );

    await api.snapshot();
    expect(seen.headers['X-FlowSense-Key'], 'secret-key');
    expect(seen.url.toString(), 'https://flowsense.test/v1/snapshot');
  });

  test('history builds the documented query string', () async {
    late http.Request seen;
    final api = HttpFlowSenseApi(
      _config,
      client: MockClient((req) async {
        seen = req;
        return http.Response('[]', 200);
      }),
    );

    await api.history(
      '30',
      from: DateTime.fromMillisecondsSinceEpoch(1755000000000, isUtc: true),
      to: DateTime.fromMillisecondsSinceEpoch(1755003600000, isUtc: true),
    );

    expect(seen.url.path, '/v1/intersections/30/history');
    expect(seen.url.queryParameters,
        {'from': '1755000000', 'to': '1755003600', 'bucket': '1m'});
  });

  test('retries twice, then succeeds — three calls total', () async {
    var calls = 0;
    final sleeps = _SleepSpy();
    final api = HttpFlowSenseApi(
      _config,
      sleep: sleeps.call,
      client: MockClient((_) async {
        calls++;
        if (calls < 3) return http.Response('boom', 503);
        return http.Response(_snapshotBody, 200);
      }),
    );

    final snap = await api.snapshot();
    expect(calls, 3);
    expect(snap.records, hasLength(1));
    // base * 2^attempt, with no sleep before the first attempt.
    expect(sleeps.calls, [
      const Duration(milliseconds: 200),
      const Duration(milliseconds: 400),
    ]);
  });

  test('exhausting the retries throws ApiException carrying the status',
      () async {
    var calls = 0;
    final api = HttpFlowSenseApi(
      _config,
      sleep: _SleepSpy().call,
      client: MockClient((_) async {
        calls++;
        return http.Response('boom', 503);
      }),
    );

    await expectLater(
      api.snapshot(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 503)),
    );
    expect(calls, 3);
  });

  test('a 401 throws immediately without retrying', () async {
    var calls = 0;
    final api = HttpFlowSenseApi(
      _config,
      sleep: _SleepSpy().call,
      client: MockClient((_) async {
        calls++;
        return http.Response('unauthorized', 401);
      }),
    );

    await expectLater(
      api.snapshot(),
      throwsA(isA<ApiException>().having((e) => e.isAuthFailure, 'isAuthFailure', isTrue)),
    );
    expect(calls, 1, reason: 'a bad key will never fix itself');
  });

  test('malformed JSON throws ApiException, not FormatException', () async {
    final api = HttpFlowSenseApi(
      _config,
      sleep: _SleepSpy().call,
      client: MockClient((_) async => http.Response('<html>nope</html>', 200)),
    );

    await expectLater(
      api.snapshot(),
      throwsA(isA<ApiException>()
          .having((e) => e.cause, 'cause', isA<FormatException>())),
    );
  });

  test('a valid-JSON-but-wrong-shape body is an ApiException too', () async {
    final api = HttpFlowSenseApi(
      _config,
      sleep: _SleepSpy().call,
      client: MockClient((_) async => http.Response('"just a string"', 200)),
    );

    await expectLater(api.snapshot(), throwsA(isA<ApiException>()));
  });

  test('a transport failure is retried, then wrapped', () async {
    var calls = 0;
    final api = HttpFlowSenseApi(
      _config,
      sleep: _SleepSpy().call,
      client: MockClient((_) async {
        calls++;
        throw http.ClientException('connection reset');
      }),
    );

    await expectLater(
      api.snapshot(),
      throwsA(isA<ApiException>()
          .having((e) => e.cause, 'cause', isA<http.ClientException>())),
    );
    expect(calls, 3);
  });

  test('intersections parses the list endpoint', () async {
    final api = HttpFlowSenseApi(
      _config,
      client: MockClient((_) async => http.Response(
            jsonEncode([
              {
                'id': '30',
                'name': 'Simpang DPRD',
                'lat': -6.8047,
                'lon': 110.8405,
                'lanes': ['kota'],
                'capacity': {'kota': 14},
              }
            ]),
            200,
          )),
    );

    final list = await api.intersections();
    expect(list, hasLength(1));
    expect(list.single.capacityFor('kota', fallback: 12), 14);
  });
}
