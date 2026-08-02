import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Where a formatted log line goes. Injectable so tests capture lines and
/// release builds drop them.
typedef LogSink = void Function(String line);

enum LogLevel { debug, info, warn, error }

/// Discards everything. The default in release builds — an app that ships
/// structured logs to a device console is just burning battery.
void silentSink(String line) {}

/// One JSON line per event, the same shape as `flowsense/telemetry.py`, so
/// connector logs and app logs can be read side by side during the demo.
///
/// ```json
/// {"ts":"2026-08-02T12:00:00.000Z","level":"info","msg":"poll ok","records":3}
/// ```
class FlowLog {
  const FlowLog._();

  /// Reserved top-level keys. A field using one of these names is dropped
  /// rather than silently overwriting the envelope.
  static const Set<String> reservedKeys = {'ts', 'level', 'msg'};

  static LogSink sink = defaultSinkFor(releaseMode: kReleaseMode);

  /// Injectable for deterministic test output.
  static DateTime Function() clock = () => DateTime.now().toUtc();

  static LogSink defaultSinkFor({required bool releaseMode}) =>
      releaseMode ? silentSink : debugPrint;

  /// Restores the shipped defaults. Call from `tearDown` so one test's sink
  /// does not leak into the next.
  static void reset() {
    sink = defaultSinkFor(releaseMode: kReleaseMode);
    clock = () => DateTime.now().toUtc();
  }

  static void event(
    String msg, {
    Map<String, Object?> fields = const {},
    LogLevel level = LogLevel.info,
  }) =>
      sink(format(msg, fields: fields, level: level));

  /// Serialises one event. Exposed so the formatter is testable without
  /// touching the sink.
  static String format(
    String msg, {
    Map<String, Object?> fields = const {},
    LogLevel level = LogLevel.info,
    DateTime? at,
  }) {
    final line = <String, Object?>{
      'ts': (at ?? clock()).toUtc().toIso8601String(),
      'level': level.name,
      'msg': msg,
      for (final entry in fields.entries)
        if (!reservedKeys.contains(entry.key)) entry.key: entry.value,
    };
    // Anything not natively encodable degrades to its toString rather than
    // throwing: a log line must never be able to crash the caller.
    return jsonEncode(line, toEncodable: (Object? o) => '$o');
  }
}
