import 'package:flowsense_mobile/domain/connector_health.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 8, 4, 16, 42, 7);

ConnectorHealth _health({
  String id = '30',
  ConnectorStatus status = ConnectorStatus.berjalan,
  DateTime? last,
  Duration? gap = const Duration(seconds: 2),
  int failures = 0,
}) =>
    ConnectorHealth(
      cameraId: id,
      intersectionName: 'Simpang DPRD',
      status: status,
      lastRecordAt: last ?? _t0,
      gap: gap,
      failuresPerHour: failures,
    );

void main() {
  group('status', () {
    test('reads in Indonesian, worst last', () {
      expect(ConnectorStatus.berjalan.label, 'Berjalan');
      expect(ConnectorStatus.terputus.label, 'Terputus');
      expect(ConnectorStatus.berhenti.label, 'Berhenti');

      expect(ConnectorStatus.berhenti.severity,
          greaterThan(ConnectorStatus.terputus.severity));
      expect(ConnectorStatus.terputus.severity,
          greaterThan(ConnectorStatus.berjalan.severity));
    });

    test('only berjalan is free of concern', () {
      expect(ConnectorStatus.berjalan.needsAttention, isFalse);
      expect(ConnectorStatus.terputus.needsAttention, isTrue);
      expect(ConnectorStatus.berhenti.needsAttention, isTrue);
    });
  });

  group('parsing', () {
    test('reads the proposed payload', () {
      final health = ConnectorHealth.fromJson({
        'camera_id': 30,
        'name': 'Simpang DPRD',
        'status': 'berjalan',
        'last_record_at': _t0.millisecondsSinceEpoch ~/ 1000,
        'gap_seconds': 2.0,
        'failures_per_hour': 0,
      });

      expect(health.cameraId, '30');
      expect(health.status, ConnectorStatus.berjalan);
      expect(health.gap, const Duration(seconds: 2));
      expect(health.title, 'Kamera 30 — Simpang DPRD');
    });

    test('an unknown status is never assumed healthy', () {
      // A console that guesses "probably fine" about a state it does not
      // understand is the exact failure this screen exists to prevent.
      final health = ConnectorHealth.fromJson(const {
        'camera_id': 30,
        'status': 'sesuatuYangBaru',
      });
      expect(health.status, ConnectorStatus.terputus);
      expect(health.status.needsAttention, isTrue);
    });

    test('missing vitals degrade rather than throw', () {
      final health = ConnectorHealth.fromJson(const {'camera_id': 30});
      expect(health.lastRecordAt, isNull);
      expect(health.gap, isNull);
      expect(health.failuresPerHour, 0);
    });

    test('a fractional gap survives the round trip', () {
      final health = ConnectorHealth.fromJson(const {
        'camera_id': 33,
        'gap_seconds': 4.8,
      });
      expect(health.gap, const Duration(milliseconds: 4800));
    });
  });

  group('formatting', () {
    test('times are exact to the second, not relative', () {
      // An operator is comparing this against the connector's own log.
      expect(clockSeconds(_t0), '16:42:07');
      expect(clockSeconds(DateTime.utc(2026, 8, 4, 9, 5, 3)), '09:05:03');
    });

    test('gaps use one decimal and an Indonesian comma', () {
      expect(gapIndonesian(const Duration(seconds: 2)), '2,0 detik');
      expect(gapIndonesian(const Duration(milliseconds: 2100)), '2,1 detik');
      expect(gapIndonesian(const Duration(milliseconds: 4800)), '4,8 detik');
    });
  });

  group('detail line', () {
    test('states what arrived, how often, and what is failing', () {
      expect(
        healthDetail(_health(failures: 2, gap: const Duration(milliseconds: 2100))),
        'record terakhir 16:42:07 · jeda 2,1 detik · 2 gagal/jam',
      );
    });

    test('a stopped connector has no cadence, so none is printed', () {
      // `0,0 detik` would read as "instantaneous" rather than "not running".
      final line = healthDetail(_health(
        status: ConnectorStatus.berhenti,
        gap: null,
        failures: 63,
      ));

      expect(line, 'record terakhir 16:42:07 · 63 gagal/jam');
      expect(line, isNot(contains('jeda')));
    });

    test('a camera that never reported says so', () {
      // Built directly: the `_health` helper defaults `last`, so going through
      // it would quietly test the wrong branch.
      const never = ConnectorHealth(
        cameraId: '35',
        intersectionName: 'Simpang Baru',
        status: ConnectorStatus.berhenti,
        lastRecordAt: null,
        gap: null,
        failuresPerHour: 0,
      );

      expect(healthDetail(never), 'belum ada record · 0 gagal/jam');
      expect(healthDetail(never), isNot(contains('record terakhir')));
    });
  });

  group('ordering', () {
    test('worst first, then noisiest, then by camera', () {
      final sorted = sortByHealth([
        _health(id: '30'),
        _health(id: '33', status: ConnectorStatus.terputus, failures: 14),
        _health(id: '34', status: ConnectorStatus.berhenti, failures: 63),
        _health(id: '31', failures: 2),
      ]);

      expect(sorted.map((h) => h.cameraId), ['34', '33', '31', '30']);
    });

    test('does not mutate its argument', () {
      final input = [
        _health(id: '30'),
        _health(id: '34', status: ConnectorStatus.berhenti),
      ];
      sortByHealth(input);
      expect(input.first.cameraId, '30');
    });
  });
}
