/// Small pure helpers for formatting minutes/durations and working with the
/// weekday bitmask used throughout the app.
library;

const List<String> kWeekdayShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> kWeekdayLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> kMonthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Formats a date as e.g. "Jul 22".
String formatDayMonth(DateTime d) => '${kMonthShort[d.month - 1]} ${d.day}';

/// Returns the bitmask bit for a weekday. Monday = 1..Sunday = 7.
int weekdayBit(int weekday) => 1 << (weekday - 1);

/// Whether [weekday] (1..7) is set in [mask].
bool maskHasDay(int mask, int weekday) => (mask & weekdayBit(weekday)) != 0;

/// Toggles [weekday] in [mask] and returns the new mask.
int toggleDay(int mask, int weekday) => mask ^ weekdayBit(weekday);

/// Human list of the weekdays present in [mask], e.g. "Mon, Wed, Fri".
String maskLabel(int mask) {
  final parts = <String>[];
  for (var w = 1; w <= 7; w++) {
    if (maskHasDay(mask, w)) parts.add(kWeekdayShort[w - 1]);
  }
  if (parts.isEmpty) return 'No days';
  if (parts.length == 7) return 'Every day';
  return parts.join(', ');
}

/// The effective bed time in minutes, wrapping past midnight when bed is at or
/// before wake (e.g. bed 00:00 with wake 09:00 => 24:00 = 1440).
int effectiveBedMinute(int wakeMinute, int bedMinute) =>
    bedMinute > wakeMinute ? bedMinute : bedMinute + 1440;

/// Formats a minute-of-day (0..1439) as "HH:mm".
String formatMinuteOfDay(int minute) {
  final h = (minute ~/ 60) % 24;
  final m = minute % 60;
  final hh = h.toString().padLeft(2, '0');
  final mm = m.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// Formats a number of minutes as e.g. "2h 30m", "45m" or "0m".
String formatMinutes(int minutes) {
  if (minutes <= 0) return '0m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// Formats a duration in seconds as e.g. "6m 12s", "1h 05m" or "42s".
String formatDurationSeconds(int seconds) {
  if (seconds <= 0) return '0s';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) {
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
  if (m > 0) {
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
  return '${s}s';
}

/// Formats a running stopwatch value (seconds) as "MM:SS" or "H:MM:SS".
String formatStopwatch(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:$mm:$ss';
  return '$mm:$ss';
}
