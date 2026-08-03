import 'app/flavor.dart';

/// Citizen build: the traffic map, plus jam alerts.
///
/// ```bash
/// flutter run --target=lib/main_warga.dart \
///   --dart-define=FLOWSENSE_API_BASE=https://... \
///   --dart-define=FLOWSENSE_API_KEY=...
/// ```
Future<void> main() => bootstrap(Flavor.warga);
