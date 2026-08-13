import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/app_mode.dart';

/// Remembers which side of the app was last open.
///
/// Device-local, like every other preference here. It is not a permission and
/// not an identity — an operator who reopens the app lands back on the console
/// instead of on the citizen map, and that is the whole of it. The session
/// token still lives in the secure store; this holds nothing sensitive.
abstract class AppModeStore {
  Future<AppMode?> load();

  Future<void> save(AppMode mode);
}

class PrefsAppModeStore implements AppModeStore {
  const PrefsAppModeStore();

  static const String key = 'flowsense.mode.v1';

  @override
  Future<AppMode?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return AppMode.tryParse(prefs.getString(key));
    } on Object {
      // Unreadable preferences must not stop the app from starting. Falling
      // back to null means the citizen map, which is the safe default: it is
      // the side that needs no account.
      return null;
    }
  }

  @override
  Future<void> save(AppMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, mode.name);
    } on Object {
      // A failed write costs one wrong landing screen on the next cold start.
      // Throwing here would break the switch itself, which is worse.
    }
  }
}

/// In-memory stand-in. Tests never touch the platform channel.
class FakeAppModeStore implements AppModeStore {
  FakeAppModeStore([this._mode]);

  AppMode? _mode;

  int saves = 0;

  @override
  Future<AppMode?> load() async => _mode;

  @override
  Future<void> save(AppMode mode) async {
    saves++;
    _mode = mode;
  }
}
