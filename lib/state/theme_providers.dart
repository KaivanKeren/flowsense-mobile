import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/prefs/theme_mode_store.dart';

/// Overridden with [FakeThemeModeStore] in tests, so no widget test reaches
/// `shared_preferences` over a platform channel.
final themeModeStoreProvider =
    Provider<ThemeModeStore>((ref) => const PrefsThemeModeStore());

/// Light, dark, or whatever the phone is set to.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  /// True once the user has chosen by hand. A restore that lands after that
  /// must not undo it — the stored value is a memory of the last session, not
  /// an instruction.
  bool _chosen = false;

  @override
  ThemeMode build() {
    // Kicked off, not awaited: the first frame follows the system and swaps if
    // a stored preference says otherwise. Blocking startup on a disk read to
    // avoid one frame of the wrong theme is the wrong trade.
    unawaited(_restore());
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    final stored = await ref.read(themeModeStoreProvider).load();
    if (stored == null || _chosen) return;
    state = stored;
  }

  Future<void> setMode(ThemeMode mode) async {
    _chosen = true;
    if (state == mode) return;

    state = mode;
    await ref.read(themeModeStoreProvider).save(mode);
  }
}

/// The label each option carries in the settings screens.
String themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.system => 'Ikuti sistem',
      ThemeMode.light => 'Terang',
      ThemeMode.dark => 'Gelap',
    };
