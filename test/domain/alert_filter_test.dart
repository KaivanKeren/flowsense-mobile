import 'package:flowsense_mobile/domain/alert_filter.dart';
import 'package:flowsense_mobile/domain/congestion.dart';
import 'package:flowsense_mobile/domain/operator_alert.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 8, 2, 16, 42);

OperatorAlert _alert({
  required String id,
  String camera = '30',
  int hoursAgo = 1,
  String? by,
  String? note,
}) =>
    OperatorAlert(
      id: id,
      cameraId: camera,
      name: 'Simpang $camera',
      level: CongestionLevel.macet,
      raisedAt: _now.subtract(Duration(hours: hoursAgo)),
      acknowledgedBy: by,
      acknowledgedAt: by == null ? null : _now,
      note: note,
    );

void main() {
  group('window', () {
    test('excludes anything older than the range', () {
      final alerts = [
        _alert(id: 'recent', hoursAgo: 2),
        _alert(id: 'old', hoursAgo: 24 * 9),
      ];

      final week = applyAlertFilter(
        alerts,
        const AlertFilter(),
        _now,
      );
      expect(week.map((a) => a.id), ['recent']);

      final month = applyAlertFilter(
        alerts,
        const AlertFilter(window: AlertWindow.hari30),
        _now,
      );
      expect(month.map((a) => a.id), ['recent', 'old']);
    });

    test('defaults to seven days, matching the chip', () {
      const filter = AlertFilter();
      expect(filter.window, AlertWindow.hari7);
      expect(filter.window.label, '7 hari terakhir');
    });
  });

  group('intersection', () {
    test('null means every intersection', () {
      final all = applyAlertFilter(
        [_alert(id: 'a'), _alert(id: 'b', camera: '31')],
        const AlertFilter(),
        _now,
      );
      expect(all, hasLength(2));
    });

    test('a chosen camera excludes the rest', () {
      final only = applyAlertFilter(
        [_alert(id: 'a'), _alert(id: 'b', camera: '31')],
        const AlertFilter(cameraId: '31'),
        _now,
      );
      expect(only.map((a) => a.id), ['b']);
    });

    test('clearing the camera goes back to all', () {
      const filter = AlertFilter(cameraId: '31');
      expect(filter.copyWith(clearCamera: true).cameraId, isNull);
    });
  });

  group('acknowledgement', () {
    test('filters both ways', () {
      final alerts = [
        _alert(id: 'open'),
        _alert(id: 'done', by: 'Ismail'),
      ];

      expect(
        applyAlertFilter(alerts,
                const AlertFilter(ack: AlertAckFilter.belumDiakui), _now)
            .map((a) => a.id),
        ['open'],
      );
      expect(
        applyAlertFilter(
                alerts, const AlertFilter(ack: AlertAckFilter.diakui), _now)
            .map((a) => a.id),
        ['done'],
      );
    });
  });

  group('ordering', () {
    test('newest first, and acknowledgement does not push a row down', () {
      // Unlike the dashboard, this screen is a record — a record reads in the
      // order things happened.
      final sorted = applyAlertFilter(
        [
          _alert(id: 'old', hoursAgo: 5),
          _alert(id: 'new', hoursAgo: 1, by: 'Ismail'),
          _alert(id: 'mid', hoursAgo: 3),
        ],
        const AlertFilter(),
        _now,
      );

      expect(sorted.map((a) => a.id), ['new', 'mid', 'old']);
    });
  });

  group('formatting', () {
    test('short date and time, for scanning', () {
      expect(shortDateTime(DateTime.utc(2026, 8, 2, 16, 5)), '2 Agu 16:05');
      expect(shortDateTime(DateTime.utc(2026, 1, 15, 9, 0)), '15 Jan 09:00');
    });

    test('the summary names duration, acknowledger and note', () {
      expect(
        alertSummaryLine(
          _alert(id: 'a', hoursAgo: 1, by: 'Ismail', note: 'Ada perbaikan jalan'),
          _now,
        ),
        'Macet 1 jam · Ismail · Ada perbaikan jalan',
      );
    });

    test('an unacknowledged alert is just level and duration', () {
      expect(
        alertSummaryLine(_alert(id: 'a', hoursAgo: 1), _now),
        'Macet 1 jam',
      );
    });

    test('an empty note is omitted rather than trailing a separator', () {
      expect(
        alertSummaryLine(_alert(id: 'a', hoursAgo: 1, by: 'Rina', note: '  '),
            _now),
        'Macet 1 jam · Rina',
      );
    });
  });
}
