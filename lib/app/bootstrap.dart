import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/logging/logger.dart';
import '../data/alerts/alerts_api.dart';
import '../data/api/fake_flowsense_api.dart';
import '../data/api/flowsense_api.dart';
import '../data/api/http_flowsense_api.dart';
import '../data/health/health_api.dart';
import '../domain/app_mode.dart';
import '../features/alerts/notifier.dart';
import '../features/operator/operator_shell.dart';
import '../features/operator/session_watcher.dart';
import '../features/operator/login_screen.dart';
import '../features/shell/warga_shell.dart';
import '../state/alert_providers.dart';
import '../state/app_mode_providers.dart';
import '../state/auth_providers.dart';
import '../state/health_providers.dart';
import '../state/providers.dart';
import 'theme.dart';

/// The home screen for [mode].
///
/// Jam alerts ride with `warga` only. The copy tells a rider to consider
/// another route, which is advice for someone on the road — an operator is
/// already looking at the dashboard that would have raised it. Switching to the
/// console therefore stops jam notifications, by construction: the listener is
/// part of the citizen shell, not of the app.
Widget homeFor(AppMode mode) => switch (mode) {
      AppMode.warga => const JamAlertListener(child: WargaShell()),
      AppMode.operator => const OperatorGate(),
    };

/// Login, or the console — never both, and never the console first.
///
/// The console is gated rather than merely *linked to* a login screen: this is
/// what keeps a runtime mode switch honest. Anyone can press the button into
/// operator mode; without a session it lands them on the login form, and the
/// dashboard never renders, never polls, and never papers the screen in errors
/// from requests carrying no credential.
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

/// Fixture-backed overrides for everything the traffic feed does **not**
/// cover: alerts, connector health, and lane calibration.
///
/// Without these the operator console starts on empty fakes and the Kesehatan
/// and Peringatan tabs render their honest-but-useless "nothing here" state,
/// while the dashboard's `Akui` button — one of only two writes the console
/// has — is unreachable. `buildApi` alone is not enough to satisfy "runs fully
/// on FakeFlowSenseApi": that criterion covers the whole console, not just the
/// traffic feed.
///
/// Empty for a configured build. These are demo data, and a build pointed at a
/// real backend must never quietly mix them in with live records.
Future<List<Override>> demoOverrides(AppConfig config) async {
  if (config.isConfigured) return const [];
  return [
    alertsApiProvider.overrideWithValue(await FakeAlertsApi.fromFixtures()),
    healthApiProvider.overrideWithValue(await FakeHealthApi.fromFixtures()),
  ];
}

/// Every override the running app installs.
///
/// One function rather than a list assembled inline in [bootstrap], so the
/// wiring is a thing a test can hold. The previous shape — `bootstrap`
/// building the list itself — is how the console shipped with two permanently
/// empty tabs: `demoOverrides` can be correct and still never be called, and
/// nothing would have noticed.
Future<List<Override>> appOverrides(AppConfig config) async => [
      appConfigProvider.overrideWithValue(config),
      apiProvider.overrideWithValue(await buildApi(config)),
      ...await demoOverrides(config),
    ];

/// Everything `lib/main.dart` does.
///
/// One entry point, one APK, both audiences. Which shell opens is
/// [appModeProvider]'s answer, restored from the last session and changed by
/// the switch buttons in Langganan and Akun.
Future<void> bootstrap() async {
  // The fixture fallback reads the asset bundle, which needs the binding up.
  WidgetsFlutterBinding.ensureInitialized();

  const config = AppConfig.fromEnvironment();
  final overrides = await appOverrides(config);

  // Logged without the key, and without the base URL — the fact that a backend
  // was configured is the diagnostic; its address is not needed here.
  FlowLog.event('app start', fields: {'configured': config.isConfigured});

  runApp(ProviderScope(
    overrides: overrides,
    child: const FlowSenseApp(),
  ));
}

/// The shared app shell. There is one `MaterialApp`, and the mode only chooses
/// what it puts on screen.
class FlowSenseApp extends ConsumerWidget {
  const FlowSenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appModeProvider);
    final isWarga = mode == AppMode.warga;

    return MaterialApp(
      title: mode.appTitle,
      theme: flowSenseTheme(),
      // Warga is light-only, by decision rather than omission: the layout
      // spec files dark mode under "deliberately not built" — it scores
      // nothing and doubles the contrast checking. Operator has no such
      // spec and keeps following the system.
      darkTheme: isWarga ? null : flowSenseTheme(brightness: Brightness.dark),
      themeMode: isWarga ? ThemeMode.light : ThemeMode.system,
      home: homeFor(mode),
    );
  }
}
