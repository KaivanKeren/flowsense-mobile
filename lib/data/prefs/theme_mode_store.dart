import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers whether the user asked for light, dark, or the system's choice.
///
/// Device-local, like every other preference here, and holding nothing
/// sensitive — it is a display setting, not an identity.
abstract class ThemeModeStore {
  Future<ThemeMode?> load();

  Future<void> save(ThemeMode mode);
}

/// Parses [name] back into a [ThemeMode].
///
/// Top-level and total: an unrecognised or absent value yields null, which the
/// caller reads as "never chosen" and answers with [ThemeMode.system]. A
/// preferences file written by an older build must not crash the app.
ThemeMode? tryParseThemeMode(String? name) => switch (name) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => null,
    };

class PrefsThemeModeStore implements ThemeModeStore {
  const PrefsThemeModeStore();

  static const String key = 'flowsense.theme.v1';

  @override
  Future<ThemeMode?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return tryParseThemeMode(prefs.getString(key));
    } on Object {
      // Unreadable preferences must not stop the app from starting. Falling
      // back to null means the system's choice, which is the safe default.
      return null;
    }
  }

  @override
  Future<void> save(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, mode.name);
    } on Object {
      // A failed write costs one wrong theme on the next cold start. Throwing
      // here would break the toggle itself, which is worse.
    }
  }
}

/// In-memory stand-in. Tests never touch the platform channel.
class FakeThemeModeStore implements ThemeModeStore {
  FakeThemeModeStore([this._mode]);

  ThemeMode? _mode;

  int saves = 0;

  @override
  Future<ThemeMode?> load() async => _mode;

  @override
  Future<void> save(ThemeMode mode) async {
    saves++;
    _mode = mode;
  }
}
