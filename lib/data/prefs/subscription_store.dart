import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/subscription.dart';

/// Where subscriptions live: on the device, and nowhere else.
///
/// There is no account and no server-side record of what anyone watches. That
/// is a privacy position, not an oversight — a list of the junctions somebody
/// checks every morning describes their commute, and the app has no reason to
/// know it.
class SubscriptionStore {
  const SubscriptionStore();

  static const String key = 'flowsense.subscriptions.v1';

  Future<SubscriptionSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return const SubscriptionSettings();
      return SubscriptionSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object {
      // A settings file written by an older build, or corrupted, must not stop
      // the app from starting. Defaults are safe: nothing subscribed, so the
      // worst case is silence rather than a 2am notification.
      return const SubscriptionSettings();
    }
  }

  Future<void> save(SubscriptionSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(settings.toJson()));
  }
}
