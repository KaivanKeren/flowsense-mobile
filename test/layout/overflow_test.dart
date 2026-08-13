/// Every screen, at every width the brief names, at both text scales, in both
/// themes' worth of layout.
///
/// The point of running the matrix rather than eyeballing 360 px: the failures
/// this catches are all invisible at 360 and 1.0, which is the size a designer
/// checks and the size a phone in a review meeting is set to.
library;

import 'package:flowsense_mobile/features/langganan/langganan_screen.dart';
import 'package:flowsense_mobile/features/operator/akun_screen.dart';
import 'package:flowsense_mobile/features/operator/dashboard_screen.dart';
import 'package:flowsense_mobile/features/operator/detail_screen.dart';
import 'package:flowsense_mobile/features/operator/kalibrasi_screen.dart';
import 'package:flowsense_mobile/features/operator/kesehatan_screen.dart';
import 'package:flowsense_mobile/features/operator/login_screen.dart';
import 'package:flowsense_mobile/features/operator/operator_shell.dart';
import 'package:flowsense_mobile/features/operator/peringatan_screen.dart';
import 'package:flowsense_mobile/features/simpang/simpang_screen.dart';
import 'package:flowsense_mobile/features/tentang/tentang_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_harness.dart';

/// The screens, by name. The map and the citizen shell are absent on purpose:
/// `FlutterMap` needs a tile provider and never settles offline, and its layout
/// is a full-bleed canvas with nothing to overflow. Its sheet is covered by
/// `intersection_sheet_test.dart`.
final _screens = <String, Widget Function()>{
  'DashboardScreen': DashboardScreen.new,
  'KesehatanScreen': KesehatanScreen.new,
  'PeringatanScreen': PeringatanScreen.new,
  'AkunScreen': AkunScreen.new,
  'OperatorShell': OperatorShell.new,
  'DetailScreen': () => const DetailScreen(cameraId: '30'),
  'KalibrasiScreen': () => const KalibrasiScreen(cameraId: '30'),
  'LoginScreen': LoginScreen.new,
  'SimpangScreen': SimpangScreen.new,
  'LanggananScreen': LanggananScreen.new,
  'TentangScreen': TentangScreen.new,
};

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTestFonts();
  });

  for (final entry in _screens.entries) {
    group(entry.key, () {
      for (final width in kTestWidths) {
        for (final scale in kTestTextScales) {
          testWidgets('${width.toInt()}px at ${scale}x', (tester) async {
            await pumpScreen(
              tester,
              entry.value(),
              width: width,
              textScale: scale,
              signedIn: entry.key != 'LoginScreen',
            );

            expectNoOverflow(
              tester,
              screen: entry.key,
              width: width,
              textScale: scale,
            );
          });
        }
      }

      testWidgets('renders in the dark theme', (tester) async {
        await pumpScreen(
          tester,
          entry.value(),
          width: 360,
          textScale: 1.0,
          brightness: Brightness.dark,
          signedIn: entry.key != 'LoginScreen',
        );

        expectNoOverflow(
          tester,
          screen: '${entry.key} (dark)',
          width: 360,
          textScale: 1.0,
        );
      });
    });
  }
}
