import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/logging/logger.dart';
import '../data/api/fake_flowsense_api.dart';
import '../data/api/flowsense_api.dart';
import '../data/api/http_flowsense_api.dart';
import '../features/alerts/notifier.dart';
import '../features/map/map_screen.dart';
import '../features/operator/dashboard_screen.dart';
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
      Flavor.warga => const JamAlertListener(child: MapScreen()),
      Flavor.operator => const DashboardScreen(),
    };

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
        darkTheme: flowSenseTheme(brightness: Brightness.dark),
        home: homeFor(flavor),
      );
}
