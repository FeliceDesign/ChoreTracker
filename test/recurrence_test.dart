import 'package:choretracker/logic/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('date helpers', () {
    test('isoWeekNumber matches known values', () {
      // 2026-01-01 is a Thursday -> ISO week 1.
      expect(isoWeekNumber(DateTime(2026, 1, 1)), 1);
      // 2026-07-22 is in ISO week 30.
      expect(isoWeekNumber(DateTime(2026, 7, 22)), 30);
      // 2021-01-01 (Friday) belongs to ISO week 53 of 2020.
      expect(isoWeekNumber(DateTime(2021, 1, 1)), 53);
    });

    test('mondayOfWeek returns the Monday', () {
      final mon = mondayOfWeek(DateTime(2026, 7, 22)); // Wed
      expect(mon.weekday, DateTime.monday);
      expect(mon.day, 20);
    });

    test('weekIndex increments by one each week', () {
      final a = DateTime(2026, 7, 20); // Monday
      final b = DateTime(2026, 7, 27); // next Monday
      expect(weekIndex(b) - weekIndex(a), 1);
      expect(weekIndex(DateTime(2026, 7, 26)) - weekIndex(a), 0); // same week
    });
  });

  group('occursOn — weekly', () {
    final anchor = DateTime(2026, 7, 20); // Monday, week anchor
    final anchorOrd = ordinalDay(anchor);
    final mask = weekdayMaskForDate(DateTime(2026, 7, 22)); // Wednesday

    test('weekly interval 1 occurs every matching weekday', () {
      expect(
        occursOn(
          type: kRecurWeekly,
          intervalCount: 1,
          weekdayMask: mask,
          anchorEpochDay: anchorOrd,
          monthlyDay: 1,
          date: DateTime(2026, 7, 22),
        ),
        isTrue,
      );
      expect(
        occursOn(
          type: kRecurWeekly,
          intervalCount: 1,
          weekdayMask: mask,
          anchorEpochDay: anchorOrd,
          monthlyDay: 1,
          date: DateTime(2026, 7, 29), // next Wednesday
        ),
        isTrue,
      );
      // Wrong weekday.
      expect(
        occursOn(
          type: kRecurWeekly,
          intervalCount: 1,
          weekdayMask: mask,
          anchorEpochDay: anchorOrd,
          monthlyDay: 1,
          date: DateTime(2026, 7, 23),
        ),
        isFalse,
      );
    });

    test('every 2 weeks skips the off week', () {
      bool on(DateTime d) => occursOn(
            type: kRecurWeekly,
            intervalCount: 2,
            weekdayMask: mask,
            anchorEpochDay: anchorOrd,
            monthlyDay: 1,
            date: d,
          );
      expect(on(DateTime(2026, 7, 22)), isTrue); // anchor week
      expect(on(DateTime(2026, 7, 29)), isFalse); // +1 week
      expect(on(DateTime(2026, 8, 5)), isTrue); // +2 weeks
    });

    test('does not occur before the anchor week', () {
      expect(
        occursOn(
          type: kRecurWeekly,
          intervalCount: 1,
          weekdayMask: mask,
          anchorEpochDay: anchorOrd,
          monthlyDay: 1,
          date: DateTime(2026, 7, 15), // previous Wednesday
        ),
        isFalse,
      );
    });
  });

  group('occursOn — monthly & once', () {
    test('monthly on the same day-of-month', () {
      final anchor = DateTime(2026, 7, 22);
      bool on(DateTime d) => occursOn(
            type: kRecurMonthly,
            intervalCount: 1,
            weekdayMask: 0,
            anchorEpochDay: ordinalDay(anchor),
            monthlyDay: 22,
            date: d,
          );
      expect(on(DateTime(2026, 8, 22)), isTrue);
      expect(on(DateTime(2026, 8, 21)), isFalse);
      expect(on(DateTime(2026, 6, 22)), isFalse); // before anchor
    });

    test('monthly day clamps to short months', () {
      final anchor = DateTime(2026, 1, 31);
      expect(
        occursOn(
          type: kRecurMonthly,
          intervalCount: 1,
          weekdayMask: 0,
          anchorEpochDay: ordinalDay(anchor),
          monthlyDay: 31,
          date: DateTime(2026, 2, 28), // Feb has no 31st
        ),
        isTrue,
      );
    });

    test('once occurs only on the anchor date', () {
      final anchor = DateTime(2026, 7, 22);
      expect(
        occursOn(
          type: kRecurOnce,
          intervalCount: 1,
          weekdayMask: 0,
          anchorEpochDay: ordinalDay(anchor),
          monthlyDay: 22,
          date: DateTime(2026, 7, 22),
        ),
        isTrue,
      );
      expect(
        occursOn(
          type: kRecurOnce,
          intervalCount: 1,
          weekdayMask: 0,
          anchorEpochDay: ordinalDay(anchor),
          monthlyDay: 22,
          date: DateTime(2026, 7, 29),
        ),
        isFalse,
      );
    });
  });
}
