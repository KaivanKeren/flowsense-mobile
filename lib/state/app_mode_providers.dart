import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/logger.dart';
import '../data/prefs/app_mode_store.dart';
import '../domain/app_mode.dart';

/// Overridden with [FakeAppModeStore] in tests, so no widget test reaches
/// `shared_preferences` over a platform channel.
final appModeStoreProvider =
    Provider<AppModeStore>((ref) => const PrefsAppModeStore());

/// Which side of the app is on screen. The one piece of state that replaced
/// the build-time flavor.
final appModeProvider = NotifierProvider<AppModeNotifier, AppMode>(
  AppModeNotifier.new,
);

class AppModeNotifier extends Notifier<AppMode> {
  /// True once the user has switched by hand. A restore that lands after that
  /// must not undo it — the stored value is a memory of the last session, not
  /// an instruction.
  bool _switched = false;

  @override
  AppMode build() {
    // Kicked off, not awaited: the first frame renders the citizen map — the
    // side that needs no account — and swaps if the stored mode says operator.
    unawaited(_restore());
    return AppMode.warga;
  }

  Future<void> _restore() async {
    final stored = await ref.read(appModeStoreProvider).load();
    if (stored == null || _switched) return;
    state = stored;
  }

  Future<void> switchTo(AppMode mode) async {
    _switched = true;
    if (state == mode) return;

    state = mode;
    FlowLog.event('mode switched', fields: {'mode': mode.name});
    await ref.read(appModeStoreProvider).save(mode);
  }
}
