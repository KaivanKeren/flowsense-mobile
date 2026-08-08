import 'package:flowsense_mobile/domain/calibration.dart';
import 'package:flowsense_mobile/domain/congestion.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 8, 2, 9, 14);

void main() {
  group('formatting', () {
    test('dates read in Indonesian, with a full-stop time separator', () {
      expect(indonesianDateTime(_t0), '2 Agustus 2026 09.14');
      expect(
        indonesianDateTime(DateTime.utc(2026, 1, 15, 16, 5)),
        '15 Januari 2026 16.05',
      );
    });

    test('names who last changed it', () {
      const calibration = CapacityCalibration(
        cameraId: '30',
        capacity: {'kota': 12},
        updatedBy: 'Ismail',
      );
      expect(
        lastChangedLine(CapacityCalibration(
          cameraId: calibration.cameraId,
          capacity: calibration.capacity,
          updatedBy: 'Ismail',
          updatedAt: _t0,
        )),
        'Terakhir diubah Ismail, 2 Agustus 2026 09.14.',
      );
    });

    test('an uncalibrated intersection says nothing rather than inventing a date',
        () {
      const fresh =
          CapacityCalibration(cameraId: '30', capacity: {'kota': 12});
      expect(fresh.hasBeenCalibrated, isFalse);
      expect(lastChangedLine(fresh), isNull);
    });
  });

  group('validation', () {
    test('accepts a positive whole number', () {
      expect(capacityError('12'), isNull);
      expect(capacityError(' 16 '), isNull);
    });

    test('rejects zero, because zero means uncalibrated downstream', () {
      // `levelForLane` reads a non-positive capacity as "no calibration" and
      // returns unknown, so saving a zero would blank the lane rather than
      // classify it.
      expect(levelForLane(9, 0), CongestionLevel.unknown);
      expect(capacityError('0'), 'Kapasitas harus lebih dari 0');
      expect(capacityError('-4'), 'Kapasitas harus lebih dari 0');
    });

    test('rejects empty and non-numeric input', () {
      expect(capacityError(''), 'Kapasitas harus diisi');
      expect(capacityError('   '), 'Kapasitas harus diisi');
      expect(capacityError('duabelas'), 'Kapasitas harus berupa angka');
      expect(capacityError('12.5'), 'Kapasitas harus berupa angka');
    });

    test('rejects an implausible number', () {
      expect(capacityError('1000'), 'Kapasitas terlalu besar');
    });
  });

  group('change detection', () {
    test('no edits means nothing to save', () {
      expect(
        hasCapacityChanges(const {'kota': 12}, const {'kota': 12}),
        isFalse,
      );
    });

    test('a changed value counts', () {
      expect(
        hasCapacityChanges(const {'kota': 12}, const {'kota': 16}),
        isTrue,
      );
    });

    test('a lane appearing or disappearing counts', () {
      expect(
        hasCapacityChanges(const {'kota': 12}, const {'kota': 12, 'baru': 8}),
        isTrue,
      );
    });
  });

  group('the preview the operator is shown', () {
    test('changing capacity changes the level, immediately and purely', () {
      // The spec's own example: 9 vehicles at capacity 12 is macet; raise the
      // capacity to 16 and the same 9 is padat.
      expect(levelForLane(9, 12), CongestionLevel.macet);
      expect(levelForLane(9, 16), CongestionLevel.padat);
    });
  });

  group('parsing', () {
    test('round-trips through JSON', () {
      final original = CapacityCalibration(
        cameraId: '30',
        capacity: const {'kota': 16, 'ploso': 12},
        updatedBy: 'Ismail',
        updatedAt: _t0,
      );
      final restored = CapacityCalibration.fromJson(original.toJson());

      expect(restored.cameraId, '30');
      expect(restored.capacity, original.capacity);
      expect(restored.updatedBy, 'Ismail');
      expect(restored.updatedAt, _t0);
    });

    test('a payload with no calibration history degrades cleanly', () {
      final restored = CapacityCalibration.fromJson(const {'camera_id': 30});
      expect(restored.capacity, isEmpty);
      expect(restored.hasBeenCalibrated, isFalse);
    });
  });
}
