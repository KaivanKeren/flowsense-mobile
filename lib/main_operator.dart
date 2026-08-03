import 'app/flavor.dart';

/// Operator build: the worst-first intersection dashboard. Read-only.
///
/// ```bash
/// flutter run --target=lib/main_operator.dart \
///   --dart-define=FLOWSENSE_API_BASE=https://... \
///   --dart-define=FLOWSENSE_API_KEY=...
/// ```
Future<void> main() => bootstrap(Flavor.operator);
