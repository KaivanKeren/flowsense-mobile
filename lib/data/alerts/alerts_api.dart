import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/api_exception.dart';
import '../../domain/congestion.dart';
import '../../domain/operator_alert.dart';

/// Raised jams, and the record of who saw them.
///
/// **These endpoints are not in `docs/api-contract.md`.** That document covers
/// the four read endpoints the citizen app needs; the operator console's alert
/// list and its one write are proposed here and still have to be agreed with
/// whoever builds the service:
///
/// ```
/// GET  /v1/alerts?active=            → [OperatorAlert]
/// POST /v1/alerts/{id}/acknowledge   → OperatorAlert
/// ```
///
/// Until then [FakeAlertsApi] backs the screen, exactly as `FakeFlowSenseApi`
/// backs the traffic feed.
abstract class AlertsApi {
  Future<List<OperatorAlert>> alerts();

  /// Records that [by] saw the alert. Returns the updated alert.
  ///
  /// Acknowledging never deletes a row — the history is the whole point.
  Future<OperatorAlert> acknowledge(String id, {required String by});
}

/// In-memory alerts so the console is demoable with no backend.
class FakeAlertsApi implements AlertsApi {
  FakeAlertsApi({List<OperatorAlert> seed = const [], DateTime Function()? now})
      : _alerts = [...seed],
        _now = now ?? DateTime.now;

  /// Parses `test/fixtures/alerts.json`.
  ///
  /// Offsets from now rather than absolute stamps, so a demo always opens on a
  /// jam that started a plausible while ago instead of one from months back.
  factory FakeAlertsApi.fromJson(String source, {DateTime Function()? now}) {
    final clock = now ?? DateTime.now;
    final at = clock();
    final decoded = jsonDecode(source);
    final entries = decoded is Map<String, dynamic> ? decoded['alerts'] : decoded;

    DateTime? ago(Object? minutes) => minutes == null
        ? null
        : at.subtract(Duration(minutes: (minutes as num).toInt()));

    return FakeAlertsApi(
      now: clock,
      seed: [
        if (entries is List)
          for (final e in entries)
            if (e is Map<String, dynamic>)
              OperatorAlert(
                id: '${e['id'] ?? ''}',
                cameraId: '${e['camera_id'] ?? ''}',
                name: e['name'] as String? ?? '',
                level: CongestionLevel.values.firstWhere(
                  (l) => l.name == e['level'],
                  orElse: () => CongestionLevel.macet,
                ),
                raisedAt: ago(e['raised_minutes_ago']) ?? at,
                acknowledgedBy: e['acknowledged_by'] as String?,
                acknowledgedAt: ago(e['acknowledged_minutes_ago']),
                note: e['note'] as String?,
              ),
      ],
    );
  }

  /// Loads the fixture out of the asset bundle — the path the running app
  /// takes when no backend is configured.
  static Future<FakeAlertsApi> fromFixtures({DateTime Function()? now}) async =>
      FakeAlertsApi.fromJson(
        await rootBundle.loadString('test/fixtures/alerts.json'),
        now: now,
      );

  final List<OperatorAlert> _alerts;
  final DateTime Function() _now;

  /// Number of upcoming **reads** that will throw.
  int failNext = 0;

  /// Number of upcoming **acknowledgements** that will throw.
  ///
  /// Separate from [failNext] on purpose: a test about a write failing must
  /// not also break the read that populates the list, or there is nothing on
  /// screen left to press.
  int failAcknowledgeNext = 0;

  int acknowledgeCalls = 0;

  void _maybeFail() {
    if (failNext <= 0) return;
    failNext--;
    throw const ApiException('Fake sedang disetel untuk gagal',
        statusCode: 503);
  }

  @override
  Future<List<OperatorAlert>> alerts() async {
    _maybeFail();
    return List.unmodifiable(_alerts);
  }

  @override
  Future<OperatorAlert> acknowledge(String id, {required String by}) async {
    acknowledgeCalls++;
    if (failAcknowledgeNext > 0) {
      failAcknowledgeNext--;
      throw const ApiException('Fake sedang disetel untuk gagal',
          statusCode: 503);
    }

    final index = _alerts.indexWhere((a) => a.id == id);
    if (index < 0) {
      throw ApiException('Peringatan $id tidak ditemukan', statusCode: 404);
    }
    final updated = _alerts[index].acknowledge(by: by, at: _now());
    _alerts[index] = updated;
    return updated;
  }
}
