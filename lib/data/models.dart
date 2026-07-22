/// Plain data models mirroring the SQLite tables. No code generation.

class DayConfig {
  final int weekday; // 1..7 (Mon..Sun)
  final int wakeMinute;
  final int bedMinute;

  const DayConfig({
    required this.weekday,
    required this.wakeMinute,
    required this.bedMinute,
  });

  factory DayConfig.fromMap(Map<String, Object?> m) => DayConfig(
        weekday: m['weekday'] as int,
        wakeMinute: m['wakeMinute'] as int,
        bedMinute: m['bedMinute'] as int,
      );
}

/// A recurring occupied block: work hours or any fixed appointment.
class FixedBlock {
  final int id;
  final String title;
  final String type; // 'work' | 'custom'
  final int weekdayMask;
  final int startMinute;
  final int endMinute;
  final int colorValue;

  const FixedBlock({
    required this.id,
    required this.title,
    required this.type,
    required this.weekdayMask,
    required this.startMinute,
    required this.endMinute,
    required this.colorValue,
  });

  factory FixedBlock.fromMap(Map<String, Object?> m) => FixedBlock(
        id: m['id'] as int,
        title: m['title'] as String,
        type: m['type'] as String,
        weekdayMask: m['weekdayMask'] as int,
        startMinute: m['startMinute'] as int,
        endMinute: m['endMinute'] as int,
        colorValue: m['colorValue'] as int,
      );
}

class Activity {
  final int id;
  final String name;
  final int colorValue;
  final int createdAt;

  const Activity({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
  });

  factory Activity.fromMap(Map<String, Object?> m) => Activity(
        id: m['id'] as int,
        name: m['name'] as String,
        colorValue: m['colorValue'] as int,
        createdAt: m['createdAt'] as int,
      );
}

/// An activity together with its derived timing statistics.
class ActivityWithStats {
  final Activity activity;
  final int sessionCount;
  final double? averageSeconds;

  const ActivityWithStats({
    required this.activity,
    required this.sessionCount,
    required this.averageSeconds,
  });

  /// Average duration rounded to whole seconds, or null if no sessions.
  int? get averageSecondsRounded =>
      averageSeconds == null ? null : averageSeconds!.round();
}

class ActivitySession {
  final int id;
  final int activityId;
  final int durationSeconds;
  final int recordedAt;

  const ActivitySession({
    required this.id,
    required this.activityId,
    required this.durationSeconds,
    required this.recordedAt,
  });

  factory ActivitySession.fromMap(Map<String, Object?> m) => ActivitySession(
        id: m['id'] as int,
        activityId: m['activityId'] as int,
        durationSeconds: m['durationSeconds'] as int,
        recordedAt: m['recordedAt'] as int,
      );
}

/// An activity placed on the weekly grid, carrying a snapshot of the duration.
class ScheduledActivity {
  final int id;
  final int activityId;
  final String activityName;
  final int colorValue;
  final int weekdayMask;
  final int startMinute;
  final int durationSeconds;

  const ScheduledActivity({
    required this.id,
    required this.activityId,
    required this.activityName,
    required this.colorValue,
    required this.weekdayMask,
    required this.startMinute,
    required this.durationSeconds,
  });

  factory ScheduledActivity.fromMap(Map<String, Object?> m) => ScheduledActivity(
        id: m['id'] as int,
        activityId: m['activityId'] as int,
        activityName: m['name'] as String,
        colorValue: m['colorValue'] as int,
        weekdayMask: m['weekdayMask'] as int,
        startMinute: m['startMinute'] as int,
        durationSeconds: m['durationSeconds'] as int,
      );

  int get durationMinutes => (durationSeconds / 60).ceil();
}
