import 'package:flowsense_mobile/domain/congestion.dart';
import 'package:flowsense_mobile/domain/operator_alert.dart';
import 'package:flowsense_mobile/domain/status_summary.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 8, 4, 16, 42);

OperatorAlert _alert({
  required String id,
  int minutesAgo = 37,
  String? by,
}) =>
    OperatorAlert(
      id: id,
      cameraId: '3$id',
      name: 'Simpang $id',
      level: CongestionLevel.macet,
      raisedAt: _now.subtract(Duration(minutes: minutesAgo)),
      acknowledgedBy: by,
      acknowledgedAt: by == null ? null : _now,
    );

void main() {
  group('age', () {
    test('measures how long the jam has been running', () {
      expect(_alert(id: '1').age(_now), const Duration(minutes: 37));
    });

    test('clock skew never shows a negative duration', () {
      final future = OperatorAlert(
        id: '1',
        cameraId: '30',
        name: 'x',
        level: CongestionLevel.macet,
        raisedAt: _now.add(const Duration(minutes: 5)),
      );
      expect(future.age(_now), Duration.zero);
    });
  });

  group('acknowledgement', () {
    test('records who and when, and does not delete the alert', () {
      final acknowledged =
          _alert(id: '1').acknowledge(by: 'Ismail', at: _now);

      expect(acknowledged.isAcknowledged, isTrue);
      expect(acknowledged.acknowledgedBy, 'Ismail');
      expect(acknowledged.acknowledgedAt, _now);
      // Everything that made it an alert survives.
      expect(acknowledged.id, '1');
      expect(acknowledged.raisedAt, _alert(id: '1').raisedAt);
    });

    test('an unacknowledged alert says so', () {
      expect(_alert(id: '1').isAcknowledged, isFalse);
    });

    test('round-trips through JSON', () {
      final original = _alert(id: '1', by: 'Ismail');
      final restored = OperatorAlert.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.level, original.level);
      expect(restored.raisedAt, original.raisedAt);
      expect(restored.acknowledgedBy, 'Ismail');
    });
  });

  group('sorting', () {
    test('unacknowledged first, then newest', () {
      final sorted = sortAlerts([
        _alert(id: 'a', minutesAgo: 10, by: 'Ismail'),
        _alert(id: 'b', minutesAgo: 60),
        _alert(id: 'c', minutesAgo: 5),
      ]);

      expect(sorted.map((a) => a.id), ['c', 'b', 'a']);
    });

    test('acknowledged alerts are kept, never dropped', () {
      // Their history is the accountability the console exists to provide.
      final sorted = sortAlerts([_alert(id: 'a', by: 'Ismail')]);
      expect(sorted, hasLength(1));
    });
  });

  group('durationIndonesian', () {
    test('reads as a duration, not a clock time', () {
      expect(durationIndonesian(const Duration(seconds: 30)), 'baru saja');
      expect(durationIndonesian(const Duration(minutes: 37)), '37 menit');
      expect(durationIndonesian(const Duration(minutes: 60)), '1 jam');
      expect(durationIndonesian(const Duration(minutes: 125)), '2 jam 5 menit');
    });
  });

  group('clockTime', () {
    test('pads to two digits', () {
      expect(clockTime(DateTime.utc(2026, 8, 4, 16, 5)), '16:05');
      expect(clockTime(DateTime.utc(2026, 8, 4, 9, 0)), '09:00');
    });
  });

  group('summary', () {
    ({CongestionLevel level, bool isStale}) row(
      CongestionLevel level, {
      bool stale = false,
    }) =>
        (level: level, isStale: stale);

    test('counts one per intersection', () {
      final s = summarise([
        row(CongestionLevel.macet),
        row(CongestionLevel.padat),
        row(CongestionLevel.lancar),
        row(CongestionLevel.lancar),
        row(CongestionLevel.unknown),
      ]);

      expect(s.macet, 1);
      expect(s.padat, 1);
      expect(s.lancar, 2);
      expect(s.tanpaData, 1);
      expect(s.total, 5);
    });

    test('a stale reading counts as tanpa data, not as its old level', () {
      // The single most dangerous thing this console could do is let a dead
      // connector read as an empty road.
      final s = summarise([
        row(CongestionLevel.lancar, stale: true),
        row(CongestionLevel.macet, stale: true),
      ]);

      expect(s.lancar, 0);
      expect(s.macet, 0);
      expect(s.tanpaData, 2);
    });

    test('an empty list is all zeroes, not a crash', () {
      final s = summarise(const []);
      expect(s.total, 0);
    });
  });
}
