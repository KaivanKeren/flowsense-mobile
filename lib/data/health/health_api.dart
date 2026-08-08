import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/api_exception.dart';
import '../../domain/connector_health.dart';

/// Connector vitals.
///
/// **Not in `docs/api-contract.md`.** Proposed here alongside the alert
/// endpoints, and still to be agreed with whoever builds the service:
///
/// ```
/// GET /v1/connectors → [ConnectorHealth]
/// ```
///
/// This is the one endpoint that must not be inferred from the traffic feed.
/// "No records arriving" is exactly as consistent with an empty road as with a
/// dead process, and telling those apart is the entire purpose of the screen
/// it backs — so the connector has to report on itself.
abstract class HealthApi {
  Future<List<ConnectorHealth>> connectors();
}

/// In-memory vitals so the console is demoable with no backend.
class FakeHealthApi implements HealthApi {
  FakeHealthApi({this.seed = const []});

  /// Parses `test/fixtures/connectors.json`.
  ///
  /// The file stores **offsets from now**, not absolute stamps: a fixture with
  /// a fixed timestamp would show every connector as hours stale the moment
  /// the demo is run, which is the opposite of what it is for.
  factory FakeHealthApi.fromJson(String source, {DateTime Function()? now}) {
    final at = (now ?? DateTime.now)();
    final decoded = jsonDecode(source);
    final entries =
        (decoded is Map<String, dynamic> ? decoded['connectors'] : decoded);

    return FakeHealthApi(seed: [
      if (entries is List)
        for (final e in entries)
          if (e is Map<String, dynamic>)
            ConnectorHealth(
              cameraId: '${e['camera_id'] ?? ''}',
              intersectionName: e['name'] as String? ?? '',
              status: ConnectorStatus.values.firstWhere(
                (s) => s.name == e['status'],
                orElse: () => ConnectorStatus.terputus,
              ),
              lastRecordAt: e['last_record_seconds_ago'] == null
                  ? null
                  : at.subtract(Duration(
                      seconds: (e['last_record_seconds_ago'] as num).toInt(),
                    )),
              gap: e['gap_seconds'] == null
                  ? null
                  : Duration(
                      milliseconds:
                          ((e['gap_seconds'] as num).toDouble() * 1000).round(),
                    ),
              failuresPerHour: (e['failures_per_hour'] as num?)?.toInt() ?? 0,
            ),
    ]);
  }

  /// Loads the fixture out of the asset bundle — the path the running app
  /// takes when no backend is configured.
  static Future<FakeHealthApi> fromFixtures({DateTime Function()? now}) async =>
      FakeHealthApi.fromJson(
        await rootBundle.loadString('test/fixtures/connectors.json'),
        now: now,
      );

  final List<ConnectorHealth> seed;

  int failNext = 0;

  @override
  Future<List<ConnectorHealth>> connectors() async {
    if (failNext > 0) {
      failNext--;
      throw const ApiException('Fake sedang disetel untuk gagal',
          statusCode: 503);
    }
    return List.unmodifiable(seed);
  }
}
