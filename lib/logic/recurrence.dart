/// Pure date math and recurrence logic. No Flutter/DB dependencies.
library;

import 'time_utils.dart' show maskHasDay, weekdayBit;

/// Recurrence type identifiers (stored as text in the database).
const String kRecurOnce = 'once';
const String kRecurWeekly = 'weekly';
const String kRecurMonthly = 'monthly';

/// UTC-based day ordinal (days since 1970-01-01). DST-safe for whole-day math.
int ordinalDay(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;

/// Reconstructs a local date-only [DateTime] from a day ordinal.
DateTime dateFromOrdinal(int ordinal) {
  final utc = DateTime.fromMillisecondsSinceEpoch(
    ordinal * Duration.millisecondsPerDay,
    isUtc: true,
  );
  return DateTime(utc.year, utc.month, utc.day);
}

/// Strips the time component, returning local midnight of [d].
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// True if [a] and [b] are the same calendar day.
bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The Monday date of the week containing [d].
DateTime mondayOfWeek(DateTime d) {
  final base = dateOnly(d);
  return base.subtract(Duration(days: base.weekday - 1));
}

/// Contiguous Monday-aligned week index. 1970-01-05 (ordinal 4) was a Monday.
int weekIndex(DateTime d) {
  final o = ordinalDay(d) - 4;
  return o >= 0 ? o ~/ 7 : ((o - 6) ~/ 7); // floor division for negatives
}

/// ISO-8601 week number (1..53).
int isoWeekNumber(DateTime date) {
  final ord = ordinalDay(date);
  final wd = dateOnly(date).weekday; // Mon=1..Sun=7
  final thursdayOrd = ord + (4 - wd);
  final thursday = dateFromOrdinal(thursdayOrd);
  final isoYear = thursday.year;
  final jan4 = DateTime(isoYear, 1, 4);
  final week1MondayOrd = ordinalDay(jan4) - (jan4.weekday - 1);
  return ((thursdayOrd - week1MondayOrd) ~/ 7) + 1;
}

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Whether a recurring item occurs on [date].
///
/// - [kRecurOnce]: only on the exact anchor date.
/// - [kRecurWeekly]: on weekdays in [weekdayMask], every [intervalCount] weeks
///   measured from the anchor week (and not before it).
/// - [kRecurMonthly]: on [monthlyDay] (clamped to the month length), every
///   [intervalCount] months from the anchor month (and not before it).
bool occursOn({
  required String type,
  required int intervalCount,
  required int weekdayMask,
  required int anchorEpochDay,
  required int monthlyDay,
  required DateTime date,
}) {
  final interval = intervalCount < 1 ? 1 : intervalCount;
  final d = dateOnly(date);

  if (type == kRecurOnce) {
    return ordinalDay(d) == anchorEpochDay;
  }

  if (type == kRecurMonthly) {
    final anchor = dateFromOrdinal(anchorEpochDay);
    final monthsSince = (d.year - anchor.year) * 12 + (d.month - anchor.month);
    if (monthsSince < 0 || monthsSince % interval != 0) return false;
    final dim = _daysInMonth(d.year, d.month);
    final target = monthlyDay > dim ? dim : monthlyDay;
    return d.day == target;
  }

  // Weekly family.
  if (!maskHasDay(weekdayMask, d.weekday)) return false;
  final anchorWeek = weekIndex(dateFromOrdinal(anchorEpochDay));
  final wi = weekIndex(d);
  if (wi < anchorWeek) return false;
  return (wi - anchorWeek) % interval == 0;
}

/// Short human summary of a recurrence for display in lists.
String recurrenceSummary({
  required String type,
  required int intervalCount,
  required int monthlyDay,
}) {
  final n = intervalCount < 1 ? 1 : intervalCount;
  switch (type) {
    case kRecurOnce:
      return 'Once';
    case kRecurMonthly:
      return n == 1 ? 'Monthly (day $monthlyDay)' : 'Every $n months';
    default:
      return n == 1 ? 'Weekly' : 'Every $n weeks';
  }
}

/// A default weekday mask covering just the given date's weekday.
int weekdayMaskForDate(DateTime date) => weekdayBit(dateOnly(date).weekday);
