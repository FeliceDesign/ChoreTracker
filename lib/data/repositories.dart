import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/free_time.dart';
import '../logic/time_utils.dart';
import 'database.dart';
import 'models.dart';

/// Single database instance for the app.
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

/// Activities with their derived timing stats (average + run count).
final activitiesProvider =
    FutureProvider.autoDispose<List<ActivityWithStats>>((ref) async {
  return ref.read(databaseProvider).getActivitiesWithStats();
});

/// Recorded stopwatch sessions for a single activity.
final sessionsProvider = FutureProvider.autoDispose
    .family<List<ActivitySession>, int>((ref, activityId) async {
  return ref.read(databaseProvider).getSessions(activityId);
});

/// Everything needed to render the weekly calendar in one shot.
class WeekData {
  final List<DayConfig> dayConfigs;
  final List<FixedBlock> fixedBlocks;
  final List<ScheduledActivity> scheduled;

  const WeekData(this.dayConfigs, this.fixedBlocks, this.scheduled);

  DayConfig configFor(int weekday) {
    for (final c in dayConfigs) {
      if (c.weekday == weekday) return c;
    }
    return DayConfig(weekday: weekday, wakeMinute: 7 * 60, bedMinute: 23 * 60);
  }

  /// Computes the free-time breakdown for a given weekday (1..7).
  FreeTimeResult freeTimeFor(int weekday) {
    final cfg = configFor(weekday);
    final busy = <TimeInterval>[];
    for (final b in fixedBlocks) {
      if (maskHasDay(b.weekdayMask, weekday)) {
        busy.add(TimeInterval(b.startMinute, b.endMinute));
      }
    }
    for (final s in scheduled) {
      if (maskHasDay(s.weekdayMask, weekday)) {
        busy.add(TimeInterval(s.startMinute, s.startMinute + s.durationMinutes));
      }
    }
    return computeFreeTime(
      awakeStart: cfg.wakeMinute,
      awakeEnd: cfg.bedMinute,
      busy: busy,
    );
  }

  /// Fixed blocks occurring on [weekday], sorted by start time.
  List<FixedBlock> fixedBlocksOn(int weekday) {
    final list = fixedBlocks
        .where((b) => maskHasDay(b.weekdayMask, weekday))
        .toList()
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
    return list;
  }

  /// Scheduled activities occurring on [weekday], sorted by start time.
  List<ScheduledActivity> scheduledOn(int weekday) {
    final list = scheduled
        .where((s) => maskHasDay(s.weekdayMask, weekday))
        .toList()
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
    return list;
  }
}

final weekDataProvider = FutureProvider.autoDispose<WeekData>((ref) async {
  final db = ref.read(databaseProvider);
  final configs = await db.getDayConfigs();
  final blocks = await db.getFixedBlocks();
  final scheduled = await db.getScheduledActivities();
  return WeekData(configs, blocks, scheduled);
});

/// Invalidates every data provider so all screens refresh after a mutation.
void refreshAllFrom(WidgetRef ref) {
  ref.invalidate(activitiesProvider);
  ref.invalidate(weekDataProvider);
}
