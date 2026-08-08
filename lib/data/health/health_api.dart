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
