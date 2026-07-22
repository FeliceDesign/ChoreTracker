import 'package:choretracker/logic/time_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('weekday mask', () {
    test('bit set and query', () {
      var mask = 0;
      mask = toggleDay(mask, 1); // Mon
      mask = toggleDay(mask, 3); // Wed
      expect(maskHasDay(mask, 1), isTrue);
      expect(maskHasDay(mask, 2), isFalse);
      expect(maskHasDay(mask, 3), isTrue);
    });

    test('toggle removes a day', () {
      var mask = weekdayBit(5);
      expect(maskHasDay(mask, 5), isTrue);
      mask = toggleDay(mask, 5);
      expect(maskHasDay(mask, 5), isFalse);
    });

    test('maskLabel formats correctly', () {
      expect(maskLabel(0), 'No days');
      expect(maskLabel(0x7F), 'Every day');
      expect(maskLabel(weekdayBit(1) | weekdayBit(3) | weekdayBit(5)),
          'Mon, Wed, Fri');
    });
  });

  group('formatting', () {
    test('formatMinuteOfDay', () {
      expect(formatMinuteOfDay(0), '00:00');
      expect(formatMinuteOfDay(420), '07:00');
      expect(formatMinuteOfDay(1380), '23:00');
      expect(formatMinuteOfDay(9 * 60 + 5), '09:05');
    });

    test('formatMinutes', () {
      expect(formatMinutes(0), '0m');
      expect(formatMinutes(45), '45m');
      expect(formatMinutes(60), '1h');
      expect(formatMinutes(150), '2h 30m');
    });

    test('formatDurationSeconds', () {
      expect(formatDurationSeconds(42), '42s');
      expect(formatDurationSeconds(372), '6m 12s');
      expect(formatDurationSeconds(3660), '1h 01m');
    });

    test('formatStopwatch', () {
      expect(formatStopwatch(0), '00:00');
      expect(formatStopwatch(75), '01:15');
      expect(formatStopwatch(3661), '1:01:01');
    });
  });
}
