import 'dart:io';

import 'package:flowsense_mobile/core/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kAppVersion matches pubspec.yaml', () {
    // The Tentang screen shows a hand-written constant rather than reaching
    // for a platform channel. This is what stops it drifting from the real
    // build version.
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final version = line.split(':')[1].trim().split('+').first;

    expect(kAppVersion, version);
  });
}
