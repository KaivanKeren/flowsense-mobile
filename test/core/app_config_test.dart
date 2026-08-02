import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults are safe when nothing is defined', () {
    const cfg = AppConfig();
    expect(cfg.apiKey, isEmpty);
    expect(cfg.isConfigured, isFalse);
    expect(cfg.pollInterval, const Duration(seconds: 5));
    expect(cfg.staleAfter, const Duration(seconds: 30));
  });

  test('explicit values win', () {
    const cfg = AppConfig(
      apiBase: 'https://example.test',
      apiKey: 'k',
      pollInterval: Duration(seconds: 2),
    );
    expect(cfg.isConfigured, isTrue);
    expect(cfg.pollInterval, const Duration(seconds: 2));
  });
}
