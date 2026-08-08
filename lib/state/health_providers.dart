import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/health/health_api.dart';
import '../domain/connector_health.dart';

/// Overridden at the root and in tests. There is no HTTP implementation yet —
/// the endpoint is proposed, not agreed.
final healthApiProvider = Provider<HealthApi>((ref) => FakeHealthApi());

/// Connector vitals, worst first.
///
/// Deliberately **not** derived from the traffic snapshot. Absence of records
/// is equally consistent with an empty road and a dead process, so the health
/// of a connector has to come from the connector rather than be inferred from
/// its silence.
final connectorHealthProvider = FutureProvider<List<ConnectorHealth>>(
  (ref) async => sortByHealth(await ref.watch(healthApiProvider).connectors()),
);
