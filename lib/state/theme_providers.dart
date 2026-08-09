import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the operator's theme preference lives: on the device, in the same
/// SharedPreferences the subscription store uses. There is no account and no
/// server-side record — theme is a per-install choice.
///
/// Warga does not read this: `flavor.dart` pins its `MaterialApp` to
/// [ThemeMode.light] regardless, because the citizen layout spec files dark
/// mode under "deliberately not built".
class ThemeModeStore {
  const ThemeModeStore();

  static const String key = 'flowsense.themeMode.v1';

  Future<ThemeMode?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      return switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };
    } on Object {
      // A corrupted or missing pref must not stop the app from starting. The
      // caller falls back to the flavor's default.
      return null;
    }
  }

  Future<void> save(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, mode.name);
  }
}

final themeModeStoreProvider =
    Provider<ThemeModeStore>((ref) => const ThemeModeStore());

/// The operator's chosen theme mode. Defaults to [ThemeMode.dark] — the
/// refinement spec (§12) names dark as the primary operational interface —
/// then replaces itself with the persisted value when it arrives.
///
/// The default renders immediately, so the first frame does not spin waiting
/// for a SharedPreferences read.
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    unawaited(_restore());
    return ThemeMode.dark;
  }

  Future<void> _restore() async {
    final stored = await ref.read(themeModeStoreProvider).load();
    if (stored != null) state = stored;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(themeModeStoreProvider).save(mode);
  }
}
