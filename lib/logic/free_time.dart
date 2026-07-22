/// Pure, dependency-free logic for computing free time in a day.
///
/// Everything here works on integer minute-of-day values (0..1439) and has no
/// Flutter or database dependencies, so it can be unit tested in isolation.
library;

/// A half-open time interval `[start, end)` measured in minutes-of-day.
class TimeInterval {
  final int start;
  final int end;

  const TimeInterval(this.start, this.end);

  int get length => end - start;

  @override
  String toString() => 'TimeInterval($start, $end)';

  @override
  bool operator ==(Object other) =>
      other is TimeInterval && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Result of a free-time computation for a single day.
class FreeTimeResult {
  final int awakeStart;
  final int awakeEnd;

  /// Merged, non-overlapping occupied intervals (clipped to the awake window).
  final List<TimeInterval> occupied;

  /// The gaps between occupied blocks inside the awake window.
  final List<TimeInterval> freeGaps;

  const FreeTimeResult({
    required this.awakeStart,
    required this.awakeEnd,
    required this.occupied,
    required this.freeGaps,
  });

  int get awakeMinutes => awakeEnd - awakeStart;

  int get occupiedMinutes =>
      occupied.fold(0, (sum, iv) => sum + iv.length);

  int get freeMinutes => awakeMinutes - occupiedMinutes;
}

/// Computes occupied/free intervals for a day.
///
/// [busy] intervals may overlap and may extend outside the awake window; they
/// are clipped to `[awakeStart, awakeEnd)` and merged before free gaps are
/// derived as the complement.
FreeTimeResult computeFreeTime({
  required int awakeStart,
  required int awakeEnd,
  required List<TimeInterval> busy,
}) {
  if (awakeEnd <= awakeStart) {
    return FreeTimeResult(
      awakeStart: awakeStart,
      awakeEnd: awakeStart,
      occupied: const [],
      freeGaps: const [],
    );
  }

  // Clip to the awake window and drop empty intervals.
  final clipped = <TimeInterval>[];
  for (final b in busy) {
    final s = b.start < awakeStart ? awakeStart : b.start;
    final e = b.end > awakeEnd ? awakeEnd : b.end;
    if (e > s) clipped.add(TimeInterval(s, e));
  }

  clipped.sort((a, b) => a.start.compareTo(b.start));

  // Merge overlapping / touching intervals.
  final merged = <TimeInterval>[];
  for (final iv in clipped) {
    if (merged.isEmpty || iv.start > merged.last.end) {
      merged.add(iv);
    } else {
      final last = merged.removeLast();
      merged.add(TimeInterval(last.start, iv.end > last.end ? iv.end : last.end));
    }
  }

  // Free gaps = complement of merged occupied within the awake window.
  final gaps = <TimeInterval>[];
  var cursor = awakeStart;
  for (final m in merged) {
    if (m.start > cursor) gaps.add(TimeInterval(cursor, m.start));
    cursor = m.end;
  }
  if (cursor < awakeEnd) gaps.add(TimeInterval(cursor, awakeEnd));

  return FreeTimeResult(
    awakeStart: awakeStart,
    awakeEnd: awakeEnd,
    occupied: merged,
    freeGaps: gaps,
  );
}

/// Computes free time for a day whose awake window and/or busy intervals may
/// cross midnight.
///
/// [busy] intervals use raw minute-of-day values (0..1439). Two normalisation
/// rules are applied before delegating to [computeFreeTime]:
///  1. if an interval's end is at/before its start it crosses midnight, so the
///     end is pushed to the next day (`end + 1440`);
///  2. if an interval starts before [wakeMinute] it belongs to the post-midnight
///     tail of the same awake day, so it is shifted forward by a full day.
///
/// The awake window itself wraps: a [bedMinute] at/before [wakeMinute] (e.g.
/// `00:00` or a night owl's `06:00`) is treated as the next day.
FreeTimeResult computeDayFreeTime({
  required int wakeMinute,
  required int bedMinute,
  required List<TimeInterval> busy,
}) {
  final awakeEnd = bedMinute > wakeMinute ? bedMinute : bedMinute + 1440;
  final shifted = <TimeInterval>[];
  for (final b in busy) {
    var s = b.start;
    var e = b.end;
    if (e <= s) e += 1440;
    if (s < wakeMinute) {
      s += 1440;
      e += 1440;
    }
    shifted.add(TimeInterval(s, e));
  }
  return computeFreeTime(awakeStart: wakeMinute, awakeEnd: awakeEnd, busy: shifted);
}
