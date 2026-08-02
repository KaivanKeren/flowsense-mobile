import '../models/intersection.dart';
import '../models/traffic_record.dart';
import '../models/traffic_snapshot.dart';

/// The four read endpoints from `docs/api-contract.md`.
///
/// Read-only by design: there is no write surface here, and neither flavor
/// sends control commands or signal actuation.
///
/// Every method throws [ApiException] and nothing else.
abstract class FlowSenseApi {
  /// `GET /v1/intersections`
  Future<List<Intersection>> intersections();

  /// `GET /v1/snapshot` — latest record for every intersection, one call.
  Future<TrafficSnapshot> snapshot();

  /// `GET /v1/intersections/{id}/history?from=&to=&bucket=`
  Future<List<TrafficRecord>> history(
    String id, {
    DateTime? from,
    DateTime? to,
    String bucket = '1m',
  });

  /// Releases the underlying transport. Safe to call more than once.
  void close();
}
