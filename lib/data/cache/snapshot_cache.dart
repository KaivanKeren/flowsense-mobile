import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/traffic_snapshot.dart';

/// Persists the last good snapshot, so a cold start on a dead network shows
/// something — clearly marked stale — instead of a spinner that never resolves.
///
/// Every read is best-effort: corrupt or superseded cache data returns null
/// rather than throwing. A cache is never worth crashing over.
class SnapshotCache {
  const SnapshotCache({this.key = 'flowsense.snapshot.v1'});

  final String key;

  Future<TrafficSnapshot?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return TrafficSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(TrafficSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(snapshot.toJson()));
    } catch (_) {
      // A failed write costs us the offline fallback, not the session.
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {
      // Ignored for the same reason as save().
    }
  }
}
