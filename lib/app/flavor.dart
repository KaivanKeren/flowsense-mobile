import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/logging/logger.dart';
import '../data/api/fake_flowsense_api.dart';
import '../data/api/flowsense_api.dart';
import '../data/api/http_flowsense_api.dart';
import '../features/alerts/notifier.dart';
import '../features/operator/operator_shell.dart';
import '../features/operator/session_watcher.dart';
import '../features/operator/login_screen.dart';
import '../features/shell/warga_shell.dart';
import '../state/auth_providers.dart';
import '../state/providers.dart';
import 'theme.dart';

/// The two audiences, from one codebase.
///
/// Not a runtime setting: each flavor is a separate entry point and a separate
/// APK, so a citizen build cannot be talked into rendering the operator view.
enum Flavor {
  warga,
  operator;

  String get appTitle => switch (this) {
        Flavor.warga => 'FlowSense',
        Flavor.operator => 'FlowSense Operator',
      };
}

/// The home screen for [flavor].
///
/// Jam alerts ride with `warga` only. The copy tells a rider to consider
/// another route, which is advice for someone on the road — an operator is
/// already looking at the dashboard that would have raised it.
Widget homeFor(Flavor flavor) => switch (flavor) {
      Flavor.warga => const JamAlertListener(child: WargaShell()),
      Flavor.operator => const OperatorGate(),
    };

/// Login, or the console — never both, and never the console first.
///
/// The console is gated rather than merely *linked to* a login screen: an
/// operator build that rendered the dashboard before checking the session
/// would start polling with no credentials and paper the screen in errors.
class OperatorGate extends ConsumerWidget {
  const OperatorGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (
      ref.watch(authProvider)) {
        // A stored token is being checked. Showing the login form here would
        // flash it at somebody who is already signed in.
        AuthRestoring() => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        AuthSignedOut() => const LoginScreen(),
        AuthSignedIn() => const SessionWatcher(child: OperatorShell()),
      };
}

/// Picks the API implementation for [config].
///
/// An unconfigured build degrades to bundled fixtures rather than failing to
/// start: a demo must not die on a missing `--dart-define`. The app bar carries
/// a `Data contoh` badge whenever this happens, so nothing canned is ever passed
/// off as live.
///
/// Requires `WidgetsFlutterBinding.ensureInitialized()` — the fixture path reads
/// the asset bundle.
Future<FlowSenseApi> buildApi(AppConfig config) async =>
    config.isConfigured ? HttpFlowSenseApi(config) : FakeFlowSenseApi.fromFixtures();

/// Everything both entry points do.
///
/// `lib/main_warga.dart` and `lib/main_operator.dart` are one line each on
/// purpose: a flavor is a choice of home screen, not a fork of the app.
Future<void> bootstrap(Flavor flavor) async {
  // The fixture fallback reads the asset bundle, which needs the binding up.
  WidgetsFlutterBinding.ensureInitialized();

  const config = AppConfig.fromEnvironment();
  final api = await buildApi(config);

  // Logged without the key, and without the base URL — the fact that a backend
  // was configured is the diagnostic; its address is not needed here.
  FlowLog.event('app start', fields: {
    'flavor': flavor.name,
    'configured': config.isConfigured,
  });

  runApp(ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      apiProvider.overrideWithValue(api),
    ],
    child: FlowSenseApp(flavor: flavor),
  ));
}

/// The shared app shell. Everything flavor-specific arrives through [flavor];
/// there is no second `MaterialApp`.
class FlowSenseApp extends StatelessWidget {
  const FlowSenseApp({super.key, required this.flavor});

  final Flavor flavor;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: flavor.appTitle,
        theme: flowSenseTheme(),
        // Warga is light-only, by decision rather than omission: the layout
        // spec files dark mode under "deliberately not built" — it scores
        // nothing and doubles the contrast checking. Operator has no such
        // spec and keeps following the system.
        darkTheme: flavor == Flavor.warga
            ? null
            : flowSenseTheme(brightness: Brightness.dark),
        themeMode: flavor == Flavor.warga ? ThemeMode.light : ThemeMode.system,
        home: homeFor(flavor),
      );
}
