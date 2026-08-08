import '../../core/api_exception.dart';
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
