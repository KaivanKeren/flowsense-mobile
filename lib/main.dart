import 'app/bootstrap.dart';

/// The one entry point. Citizens get the traffic map, operators press
/// `Masuk sebagai operator` in Langganan and sign in; the console has a button
/// back the other way in Akun.
///
/// ```bash
/// flutter run \
///   --dart-define=FLOWSENSE_API_BASE=https://... \
///   --dart-define=FLOWSENSE_API_KEY=...
/// ```
Future<void> main() => bootstrap();
