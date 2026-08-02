import 'dart:convert';

import 'package:flowsense_mobile/core/logging/logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final captured = <String>[];

  setUp(() {
    captured.clear();
    FlowLog.sink = captured.add;
    FlowLog.clock = () => DateTime.utc(2026, 8, 2, 12);
  });

  tearDown(FlowLog.reset);

  test('the formatter serialises the envelope plus extra fields', () {
    final line = jsonDecode(FlowLog.format(
      'poll ok',
      fields: {'records': 3, 'camera_id': '30', 'stale': false},
      level: LogLevel.info,
    )) as Map<String, dynamic>;

    expect(line['ts'], '2026-08-02T12:00:00.000Z');
    expect(line['level'], 'info');
    expect(line['msg'], 'poll ok');
    expect(line['records'], 3);
    expect(line['camera_id'], '30');
    expect(line['stale'], isFalse);
  });

  test('the injected sink captures one line per event', () {
    FlowLog.event('poll ok', fields: {'records': 3});
    FlowLog.event('poll gagal', level: LogLevel.error);

    expect(captured, hasLength(2));
    expect(jsonDecode(captured.first), containsPair('msg', 'poll ok'));
    expect(jsonDecode(captured.last), containsPair('level', 'error'));
  });

  test('the default sink is silent in release mode', () {
    expect(FlowLog.defaultSinkFor(releaseMode: true), same(silentSink));
    expect(FlowLog.defaultSinkFor(releaseMode: false),
        isNot(same(silentSink)));
  });

  test('a field cannot overwrite the envelope', () {
    final line = jsonDecode(FlowLog.format(
      'asli',
      fields: {'msg': 'palsu', 'level': 'palsu', 'ts': 0, 'ok': true},
    )) as Map<String, dynamic>;

    expect(line['msg'], 'asli');
    expect(line['level'], 'info');
    expect(line['ts'], '2026-08-02T12:00:00.000Z');
    expect(line['ok'], isTrue);
  });

  test('an unencodable value degrades to its toString, it does not throw', () {
    final line = jsonDecode(FlowLog.format(
      'gagal',
      fields: {'cause': const FormatException('bad json')},
    )) as Map<String, dynamic>;

    expect(line['cause'], contains('bad json'));
  });
}
