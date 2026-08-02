/// Runtime configuration. Values come from --dart-define; nothing is hardcoded.
class AppConfig {
  const AppConfig({
    this.apiBase = '',
    this.apiKey = '',
    this.pollInterval = const Duration(seconds: 5),
    this.staleAfter = const Duration(seconds: 30),
    this.laneCapacityDefault = 12,
  });

  const AppConfig.fromEnvironment()
      : apiBase = const String.fromEnvironment('FLOWSENSE_API_BASE'),
        apiKey = const String.fromEnvironment('FLOWSENSE_API_KEY'),
        pollInterval = const Duration(
          seconds:
              int.fromEnvironment('FLOWSENSE_POLL_SECONDS', defaultValue: 5),
        ),
        staleAfter = const Duration(
          seconds:
              int.fromEnvironment('FLOWSENSE_STALE_SECONDS', defaultValue: 30),
        ),
        laneCapacityDefault =
            const int.fromEnvironment('FLOWSENSE_LANE_CAPACITY',
                defaultValue: 12);

  final String apiBase;
  final String apiKey;
  final Duration pollInterval;
  final Duration staleAfter;
  final int laneCapacityDefault;

  bool get isConfigured => apiBase.isNotEmpty && apiKey.isNotEmpty;
}
