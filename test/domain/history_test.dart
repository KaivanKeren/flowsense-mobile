import 'package:flowsense_mobile/data/models/intersection.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';
import 'package:flowsense_mobile/domain/congestion.dart';
import 'package:flowsense_mobile/domain/history.dart';
import 'package:flutter_test/flutter_test.dart';

final _end = DateTime.utc(2026, 8, 4, 16, 30);

const _simpang = Intersection(
  id: '30',
  name: 'Simpang DPRD',
  lat: -6.8,
  lon: 110.8,
  lanes: ['kota', 'ploso'],
  capacity: {'kota': 12, 'ploso': 10},
);

TrafficRecord _at(int minutesAgo, Map<String, int> perLane) => TrafficRecord(
      ts: _end.subtract(Duration(minutes: minutesAgo)),
      cameraId: '30',
      cameraName: 'Simpang DPRD',
      totalVehicles: perLane.values.fold(0, (a, b) => a + b),
      perLane: perLane,
    );

void main() {
  group('bucketing', () {
    test('produces one bucket per minute, oldest first', () {
      final buckets = bucketHistory(
        records: [for (var i = 0; i < 60; i++) _at(i, {'kota': 1, 'ploso': 1})],
        intersection: _simpang,
        end: _end,
      );

      expect(buckets, hasLength(60));
      expect(buckets.first.minute,
          _end.subtract(const Duration(minutes: 59)));
      expect(buckets.last.minute, _end);
      for (var i = 1; i < buckets.length; i++) {
        expect(buckets[i].minute.isAfter(buckets[i - 1].minute), isTrue);
      }
    });

    test('a minute with no record is null, never zero', () {
      // The failure this whole type exists to prevent: a silent connector
      // rendered as an empty road.
      final buckets = bucketHistory(
        records: [_at(0, {'kota': 4, 'ploso': 2})],
        intersection: _simpang,
        end: _end,
        count: 3,
      );

      expect(buckets[0].hasData, isFalse);
      expect(buckets[0].count, isNull);
      expect(buckets[0].count, isNot(0));
      expect(buckets[0].level, CongestionLevel.unknown);
      expect(buckets[2].count, 6);
    });

    test('gaps are never interpolated across', () {
      final buckets = bucketHistory(
        records: [
          _at(4, {'kota': 2, 'ploso': 2}),
          _at(0, {'kota': 10, 'ploso': 2}),
        ],
        intersection: _simpang,
        end: _end,
        count: 5,
      );

      // Minutes 1-3 sit between two real readings and stay empty.
      expect(buckets.map((b) => b.count), [4, null, null, null, 12]);
    });

    test('the level follows the worst lane, not the total', () {
      final buckets = bucketHistory(
        records: [_at(0, {'kota': 9, 'ploso': 1})], // 9/12 = 0.75 -> macet
        intersection: _simpang,
        end: _end,
        count: 1,
      );
      expect(buckets.single.level, CongestionLevel.macet);
      expect(buckets.single.count, 10);
    });

    test('a lane filter rescales height and level to that approach', () {
      final records = [_at(0, {'kota': 9, 'ploso': 1})];

      final all = bucketHistory(
        records: records,
        intersection: _simpang,
        end: _end,
        count: 1,
      ).single;
      final ploso = bucketHistory(
        records: records,
        intersection: _simpang,
        end: _end,
        count: 1,
        lane: 'ploso',
      ).single;

      expect(all.count, 10);
      expect(all.level, CongestionLevel.macet);
      // 1/10 for ploso alone — the same minute, a completely different story.
      expect(ploso.count, 1);
      expect(ploso.level, CongestionLevel.lancar);
    });

    test('a lane absent from a record is missing data, not zero', () {
      final buckets = bucketHistory(
        records: [_at(0, {'kota': 5})],
        intersection: _simpang,
        end: _end,
        count: 1,
        lane: 'ploso',
      );
      expect(buckets.single.hasData, isFalse);
    });

    test('the latest record wins when a minute carries several', () {
      final buckets = bucketHistory(
        records: [
          TrafficRecord(
            ts: _end.subtract(const Duration(seconds: 50)),
            cameraId: '30',
            cameraName: 'x',
            totalVehicles: 2,
            perLane: const {'kota': 2},
          ),
          TrafficRecord(
            ts: _end.subtract(const Duration(seconds: 5)),
            cameraId: '30',
            cameraName: 'x',
            totalVehicles: 8,
            perLane: const {'kota': 8},
          ),
        ],
        intersection: _simpang,
        end: _end,
        count: 2,
      );
      // Both records fall in the minute before `end`; the later one wins.
      expect(buckets.first.count, 8);
    });

    group('coarser buckets, for the operator console', () {
      test('96 fifteen-minute slots cover a full day', () {
        final buckets = bucketHistory(
          records: const [],
          intersection: _simpang,
          end: _end,
          count: 96,
          bucketSize: const Duration(minutes: 15),
        );

        expect(buckets, hasLength(96));
        expect(
          buckets.last.minute.difference(buckets.first.minute),
          const Duration(hours: 23, minutes: 45),
        );
      });

      test('slot boundaries land on :00, :15, :30, :45', () {
        // Anchored to the epoch, not to `end` — two operators looking at the
        // same jam have to see the same bars.
        final buckets = bucketHistory(
          records: const [],
          intersection: _simpang,
          // 16:37 is deliberately not on a boundary.
          end: DateTime.utc(2026, 8, 4, 16, 37),
          count: 4,
          bucketSize: const Duration(minutes: 15),
        );

        expect(buckets.map((b) => b.minute.minute), [45, 0, 15, 30]);
      });

      test('several records inside one slot collapse to the latest', () {
        final buckets = bucketHistory(
          records: [
            _at(14, {'kota': 2, 'ploso': 1}),
            _at(2, {'kota': 9, 'ploso': 1}),
          ],
          intersection: _simpang,
          end: _end,
          count: 1,
          bucketSize: const Duration(minutes: 15),
        );

        // _end is 16:30, so the single slot is 16:30-16:45 and only the
        // 16:28 record... both fall before it. The slot is therefore empty,
        // which is the honest answer rather than a borrowed reading.
        expect(buckets.single.hasData, isFalse);
      });

      test('a quarter hour with no records is still a gap, not a zero', () {
        final buckets = bucketHistory(
          records: [_at(0, {'kota': 4, 'ploso': 2})],
          intersection: _simpang,
          end: _end,
          count: 3,
          bucketSize: const Duration(minutes: 15),
        );

        expect(buckets[0].hasData, isFalse);
        expect(buckets[1].hasData, isFalse);
        expect(buckets[2].count, 6);
      });
    });

    test('no records at all yields a full window of empties', () {
      final buckets = bucketHistory(
        records: const [],
        intersection: _simpang,
        end: _end,
      );
      expect(buckets, hasLength(60));
      expect(buckets.every((b) => !b.hasData), isTrue);
    });
  });

  group('summary lines', () {
    test('reports a jam that is still going', () {
      final buckets = bucketHistory(
        records: [
          _at(4, {'kota': 1, 'ploso': 1}),
          _at(3, {'kota': 6, 'ploso': 1}), // 0.5 -> padat
          _at(2, {'kota': 6, 'ploso': 1}),
          _at(1, {'kota': 6, 'ploso': 1}),
          _at(0, {'kota': 6, 'ploso': 1}),
        ],
        intersection: _simpang,
        end: _end,
        count: 5,
      );

      expect(
        historySummary(buckets).first,
        'Padat sejak ${hourMinute(_end.subtract(const Duration(minutes: 3)))}, '
        'belum ada tanda reda',
      );
    });

    test('a jam that already eased is not announced', () {
      final buckets = bucketHistory(
        records: [
          _at(3, {'kota': 10, 'ploso': 1}),
          _at(2, {'kota': 10, 'ploso': 1}),
          _at(1, {'kota': 1, 'ploso': 1}),
          _at(0, {'kota': 1, 'ploso': 1}),
        ],
        intersection: _simpang,
        end: _end,
        count: 4,
      );
      expect(
        historySummary(buckets).any((l) => l.contains('belum ada tanda reda')),
        isFalse,
      );
    });

    test('a single busy minute is a blip, not a trend', () {
      final buckets = bucketHistory(
        records: [
          _at(1, {'kota': 1, 'ploso': 1}),
          _at(0, {'kota': 6, 'ploso': 1}),
        ],
        intersection: _simpang,
        end: _end,
        count: 2,
      );
      expect(
        historySummary(buckets).any((l) => l.contains('sejak')),
        isFalse,
      );
    });

    test('reports the peak and when it happened', () {
      final buckets = bucketHistory(
        records: [
          _at(2, {'kota': 3, 'ploso': 1}),
          _at(1, {'kota': 15, 'ploso': 5}),
          _at(0, {'kota': 2, 'ploso': 1}),
        ],
        intersection: _simpang,
        end: _end,
        count: 3,
      );

      expect(
        historySummary(buckets),
        contains('Tertinggi 20 kendaraan pukul '
            '${hourMinute(_end.subtract(const Duration(minutes: 1)))}'),
      );
    });

    test('reports the longest silence, with its length and start', () {
      final buckets = bucketHistory(
        records: [
          _at(5, {'kota': 2, 'ploso': 1}),
          // minutes 4, 3, 2 missing
          _at(1, {'kota': 2, 'ploso': 1}),
          _at(0, {'kota': 2, 'ploso': 1}),
        ],
        intersection: _simpang,
        end: _end,
        count: 6,
      );

      expect(
        historySummary(buckets),
        contains('Data tidak masuk 3 menit pukul '
            '${hourMinute(_end.subtract(const Duration(minutes: 4)))}'),
      );
    });

    test('no gaps means no gap line', () {
      final buckets = bucketHistory(
        records: [for (var i = 0; i < 5; i++) _at(i, {'kota': 2, 'ploso': 1})],
        intersection: _simpang,
        end: _end,
        count: 5,
      );
      expect(
        historySummary(buckets).any((l) => l.contains('Data tidak masuk')),
        isFalse,
      );
    });

    test('never more than three lines', () {
      final buckets = bucketHistory(
        records: [
          _at(9, {'kota': 2, 'ploso': 1}),
          _at(6, {'kota': 6, 'ploso': 1}),
          _at(5, {'kota': 6, 'ploso': 1}),
          _at(4, {'kota': 6, 'ploso': 1}),
          _at(3, {'kota': 20, 'ploso': 1}),
          _at(2, {'kota': 6, 'ploso': 1}),
          _at(1, {'kota': 6, 'ploso': 1}),
          _at(0, {'kota': 6, 'ploso': 1}),
        ],
        intersection: _simpang,
        end: _end,
        count: 10,
      );
      expect(historySummary(buckets).length, lessThanOrEqualTo(3));
    });

    test('an empty window says nothing rather than guessing', () {
      final buckets = bucketHistory(
        records: const [],
        intersection: _simpang,
        end: _end,
      );
      expect(historySummary(buckets), isEmpty);
    });
  });

  group('axis', () {
    test('three labels: start, middle, and sekarang', () {
      final buckets = bucketHistory(
        records: const [],
        intersection: _simpang,
        end: _end,
      );
      final labels = historyAxisLabels(buckets);

      expect(labels, hasLength(3));
      expect(labels.first, hourMinute(_end.subtract(const Duration(minutes: 59))));
      expect(labels.last, 'sekarang');
    });

    test('an empty series has no axis', () {
      expect(historyAxisLabels(const []), isEmpty);
    });
  });
}
