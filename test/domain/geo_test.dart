import 'package:flowsense_mobile/domain/geo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('distanceKm', () {
    test('is zero for the same point', () {
      expect(distanceKm(-6.8047, 110.8405, -6.8047, 110.8405), closeTo(0, 1e-9));
    });

    test('measures a known short hop across Kudus', () {
      // Simpang DPRD to Simpang Ngembal in the fixtures: roughly 2 km.
      final km = distanceKm(-6.8047, 110.8405, -6.8175, 110.8534);
      expect(km, closeTo(1.99, 0.15));
    });

    test('is symmetric', () {
      final there = distanceKm(-6.80, 110.84, -6.79, 110.83);
      final back = distanceKm(-6.79, 110.83, -6.80, 110.84);
      expect(there, closeTo(back, 1e-12));
    });

    test('one degree of latitude is about 111 km', () {
      expect(distanceKm(0, 0, 1, 0), closeTo(111.2, 0.5));
    });
  });

  group('formatDistance', () {
    test('uses metres below a kilometre, rounded to ten', () {
      // GPS on a phone is not accurate to the metre, and printing one would
      // overstate what is known.
      expect(formatDistance(0.45), '450 m');
      expect(formatDistance(0.4567), '460 m');
      expect(formatDistance(0.004), '0 m');
    });

    test('uses one decimal and an Indonesian comma above a kilometre', () {
      expect(formatDistance(1.2), '1,2 km');
      expect(formatDistance(4.06), '4,1 km');
      expect(formatDistance(12.0), '12,0 km');
    });

    test('rounding up to a kilometre says km, not 1000 m', () {
      expect(formatDistance(0.999), '1,0 km');
      expect(formatDistance(0.994), '990 m');
      expect(formatDistance(1.0), '1,0 km');
    });
  });
}
