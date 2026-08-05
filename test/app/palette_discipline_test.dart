import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The layout spec's first done-criterion, enforced rather than reviewed:
///
/// > Empat warna kepadatan hanya muncul lewat `CongestionColors`; `git grep`
/// > tidak menemukan hex kepadatan di luar `theme.dart`
///
/// A reviewer checks this once. A test checks it on every commit, which is the
/// difference between a rule and an intention.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.endsWith('app/theme.dart'))
      .toList();

  test('there are files to check', () {
    // Guards against the suite passing because the glob silently matched
    // nothing.
    expect(dartFiles.length, greaterThan(10));
  });

  test('no colour literal appears outside theme.dart', () {
    final offenders = <String>[];

    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (RegExp(r'Color\(0x').hasMatch(line) ||
            RegExp(r'Color\.fromARGB').hasMatch(line) ||
            RegExp(r'Color\.fromRGBO').hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'colour belongs in theme.dart, looked up through a '
            'ThemeExtension — never inlined in a widget');
  });

  test('no named Material colour is used as a palette choice', () {
    // `Colors.transparent` is exempt: it is the absence of a colour, not a
    // choice of one, and it is how a layout keeps a border's height without
    // drawing it.
    final offenders = <String>[];

    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        final match = RegExp(r'\bColors\.([a-zA-Z]+)').firstMatch(line);
        if (match == null) continue;
        if (match.group(1) == 'transparent') continue;
        offenders.add('${file.path}:${i + 1}: ${line.trim()}');
      }
    }

    expect(offenders, isEmpty,
        reason: 'the palette is the token table, not Material defaults');
  });

  test('each congestion hex is declared exactly once, in theme.dart', () {
    // Comments are skipped: the doc on PillColors quotes #D64541 to explain
    // why the pill ink is *not* that value, and that explanation is worth
    // more than a tidier regex.
    final code = File('lib/app/theme.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('///'))
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    for (final hex in ['1F9D62', 'E0A32E', 'D64541']) {
      expect(
        RegExp(hex, caseSensitive: false).allMatches(code).length,
        1,
        reason: '$hex is the single source for one congestion level',
      );
    }
  });
}
