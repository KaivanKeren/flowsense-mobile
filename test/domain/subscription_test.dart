import 'package:flowsense_mobile/domain/congestion.dart';
import 'package:flowsense_mobile/domain/subscription.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _at(int hour, [int minute = 0]) =>
    DateTime(2026, 8, 4, hour, minute);

void main() {
  group('TimeRange', () {
    test('contains its start and excludes its end', () {
      const range = TimeRange.hours(6, 9);
      expect(range.contains(6 * 60), isTrue);
      expect(range.contains(8 * 60 + 59), isTrue);
      expect(range.contains(9 * 60), isFalse);
      expect(range.contains(5 * 60 + 59), isFalse);
    });

    test('a range that ends before it starts wraps past midnight', () {
      const overnight = TimeRange.hours(22, 6);
      expect(overnight.contains(23 * 60), isTrue);
      expect(overnight.contains(2 * 60), isTrue);
      expect(overnight.contains(12 * 60), isFalse);
    });

    test('a zero-width range contains nothing', () {
      const empty = TimeRange.hours(8, 8);
      expect(empty.contains(8 * 60), isFalse);
    });

    test('labels use the Indonesian full-stop separator', () {
      expect(const TimeRange.hours(6, 9).label, '06.00 – 09.00');
      expect(
        const TimeRange(startMinute: 15 * 60 + 30, endMinute: 19 * 60).label,
        '15.30 – 19.00',
      );
    });

    test('round-trips through JSON', () {
      const range = TimeRange.hours(15, 19);
      expect(TimeRange.fromJson(range.toJson()), range);
    });
  });

  group('thresholds', () {
    test('macet only covers macet', () {
      const t = AlertThreshold.macetSaja;
      expect(t.covers(CongestionLevel.macet), isTrue);
      expect(t.covers(CongestionLevel.padat), isFalse);
      expect(t.covers(CongestionLevel.lancar), isFalse);
    });

    test('padat dan macet covers both, but never unknown', () {
      const t = AlertThreshold.padatDanMacet;
      expect(t.covers(CongestionLevel.macet), isTrue);
      expect(t.covers(CongestionLevel.padat), isTrue);
      expect(t.covers(CongestionLevel.unknown), isFalse);
    });

    test('no threshold ever covers unknown', () {
      // A connector that stopped reporting is not a traffic jam.
      for (final t in AlertThreshold.values) {
        expect(t.covers(CongestionLevel.unknown), isFalse);
      }
    });
  });

  group('defaults', () {
    test('nothing is subscribed until the user says so', () {
      const settings = SubscriptionSettings();
      expect(settings.cameraIds, isEmpty);
      expect(settings.isSubscribed('30'), isFalse);
    });

    test('the commute peaks are the default active hours', () {
      // Removing these is how you get the app uninstalled.
      const settings = SubscriptionSettings();
      expect(settings.activeHours, [
        const TimeRange.hours(6, 9),
        const TimeRange.hours(15, 19),
      ]);
      expect(settings.isWithinActiveHours(_at(7)), isTrue);
      expect(settings.isWithinActiveHours(_at(16)), isTrue);
      expect(settings.isWithinActiveHours(_at(2)), isFalse);
      expect(settings.isWithinActiveHours(_at(12)), isFalse);
    });
  });

  group('allows', () {
    const subscribed = SubscriptionSettings(
      cameraIds: {'30'},
      threshold: AlertThreshold.macetSaja,
    );

    test('a subscribed macet inside the window passes', () {
      expect(
        subscribed.allows(
          cameraId: '30',
          level: CongestionLevel.macet,
          isStale: false,
          now: _at(7),
        ),
        isTrue,
      );
    });

    test('stale data never passes, whatever the settings say', () {
      expect(
        subscribed.allows(
          cameraId: '30',
          level: CongestionLevel.macet,
          isStale: true,
          now: _at(7),
        ),
        isFalse,
      );
    });

    test('an unsubscribed camera never passes', () {
      expect(
        subscribed.allows(
          cameraId: '31',
          level: CongestionLevel.macet,
          isStale: false,
          now: _at(7),
        ),
        isFalse,
      );
    });

    test('two in the morning never passes', () {
      expect(
        subscribed.allows(
          cameraId: '30',
          level: CongestionLevel.macet,
          isStale: false,
          now: _at(2),
        ),
        isFalse,
      );
    });

    test('an empty active-hours list is a valid way to say never', () {
      const muted = SubscriptionSettings(
        cameraIds: {'30'},
        activeHours: [],
      );
      expect(
        muted.allows(
          cameraId: '30',
          level: CongestionLevel.macet,
          isStale: false,
          now: _at(7),
        ),
        isFalse,
      );
    });
  });

  group('editing', () {
    test('toggle adds then removes', () {
      const settings = SubscriptionSettings();
      final on = settings.toggle('30');
      expect(on.isSubscribed('30'), isTrue);
      expect(on.toggle('30').isSubscribed('30'), isFalse);
    });

    test('toggle does not mutate the original', () {
      const settings = SubscriptionSettings(cameraIds: {'30'});
      settings.toggle('31');
      expect(settings.cameraIds, {'30'});
    });

    test('round-trips through JSON', () {
      const settings = SubscriptionSettings(
        cameraIds: {'30', '32'},
        threshold: AlertThreshold.padatDanMacet,
        activeHours: [TimeRange.hours(6, 9)],
      );
      final restored = SubscriptionSettings.fromJson(settings.toJson());

      expect(restored.cameraIds, settings.cameraIds);
      expect(restored.threshold, AlertThreshold.padatDanMacet);
      expect(restored.activeHours, settings.activeHours);
    });

    test('an unknown threshold in stored JSON degrades to the safe one', () {
      // A settings file from a future build must not crash this one, and the
      // quieter option is the safe direction to fall back to.
      final restored = SubscriptionSettings.fromJson(const {
        'cameraIds': ['30'],
        'threshold': 'sesuatuYangBaru',
      });
      expect(restored.threshold, AlertThreshold.macetSaja);
    });
  });
}
