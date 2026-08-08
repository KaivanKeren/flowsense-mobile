import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../data/alerts/alerts_api.dart';
import '../domain/operator_alert.dart';
import 'auth_providers.dart';

/// Overridden at the root and in tests. There is no HTTP implementation yet —
/// the endpoints in [AlertsApi] are proposed, not agreed.
final alertsApiProvider = Provider<AlertsApi>((ref) => FakeAlertsApi());

/// Raised jams, newest and unacknowledged first.
final operatorAlertsProvider =
    AsyncNotifierProvider<OperatorAlertsNotifier, List<OperatorAlert>>(
  OperatorAlertsNotifier.new,
);

class OperatorAlertsNotifier extends AsyncNotifier<List<OperatorAlert>> {
  @override
  Future<List<OperatorAlert>> build() async =>
      sortAlerts(await ref.watch(alertsApiProvider).alerts());

  /// Records that the signed-in operator saw this alert.
  ///
  /// Returns an error message, or null on success. The row is **not** removed
  /// on success — it moves down the list carrying who acknowledged it and
  /// when.
  Future<String?> acknowledge(String id) async {
    final auth = ref.read(authProvider);
    if (auth is! AuthSignedIn) return 'Masuk dulu untuk mengakui peringatan.';

    final previous = state.valueOrNull ?? const <OperatorAlert>[];
    try {
      final updated = await ref
          .read(alertsApiProvider)
          .acknowledge(id, by: auth.operator.nama);

      state = AsyncData(sortAlerts([
        for (final alert in previous)
          if (alert.id == updated.id) updated else alert,
      ]));
      return null;
    } on ApiException {
      // The list is left exactly as it was. An acknowledgement that did not
      // reach the server must not look like one that did — this is the record
      // the console exists to keep honest.
      return 'Gagal menyimpan pengakuan. Coba lagi.';
    }
  }
}
