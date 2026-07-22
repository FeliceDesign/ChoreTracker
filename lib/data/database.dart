import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Thin data-access layer over a local SQLite database (sqflite).
///
/// The database is opened lazily on first use so the surrounding provider can
/// be constructed synchronously.
class AppDatabase {
  Database? _db;

  static const int _defaultWake = 7 * 60; // 07:00
  static const int _defaultBed = 23 * 60; // 23:00

  Future<Database> get _database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'choretracker.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE day_config (
        weekday INTEGER PRIMARY KEY,
        wakeMinute INTEGER NOT NULL,
        bedMinute INTEGER NOT NULL
      )
    ''');
    for (var w = 1; w <= 7; w++) {
      await db.insert('day_config', {
        'weekday': w,
        'wakeMinute': _defaultWake,
        'bedMinute': _defaultBed,
      });
    }

    await db.execute('''
      CREATE TABLE fixed_blocks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        weekdayMask INTEGER NOT NULL,
        startMinute INTEGER NOT NULL,
        endMinute INTEGER NOT NULL,
        colorValue INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        colorValue INTEGER NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE activity_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activityId INTEGER NOT NULL,
        durationSeconds INTEGER NOT NULL,
        recordedAt INTEGER NOT NULL,
        FOREIGN KEY (activityId) REFERENCES activities (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE scheduled_activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activityId INTEGER NOT NULL,
        weekdayMask INTEGER NOT NULL,
        startMinute INTEGER NOT NULL,
        durationSeconds INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        FOREIGN KEY (activityId) REFERENCES activities (id) ON DELETE CASCADE
      )
    ''');
  }

  // ----- Day config -----------------------------------------------------

  Future<List<DayConfig>> getDayConfigs() async {
    final db = await _database;
    final rows = await db.query('day_config', orderBy: 'weekday');
    return rows.map(DayConfig.fromMap).toList();
  }

  Future<void> updateDayConfig(int weekday, int wakeMinute, int bedMinute) async {
    final db = await _database;
    await db.update(
      'day_config',
      {'wakeMinute': wakeMinute, 'bedMinute': bedMinute},
      where: 'weekday = ?',
      whereArgs: [weekday],
    );
  }

  /// Copies one day's wake/bed times to all seven days.
  Future<void> copyDayConfigToAll(int wakeMinute, int bedMinute) async {
    final db = await _database;
    await db.update('day_config', {
      'wakeMinute': wakeMinute,
      'bedMinute': bedMinute,
    });
  }

  // ----- Fixed blocks ---------------------------------------------------

  Future<List<FixedBlock>> getFixedBlocks() async {
    final db = await _database;
    final rows = await db.query('fixed_blocks', orderBy: 'startMinute');
    return rows.map(FixedBlock.fromMap).toList();
  }

  Future<int> insertFixedBlock({
    required String title,
    required String type,
    required int weekdayMask,
    required int startMinute,
    required int endMinute,
    required int colorValue,
  }) async {
    final db = await _database;
    return db.insert('fixed_blocks', {
      'title': title,
      'type': type,
      'weekdayMask': weekdayMask,
      'startMinute': startMinute,
      'endMinute': endMinute,
      'colorValue': colorValue,
    });
  }

  Future<void> deleteFixedBlock(int id) async {
    final db = await _database;
    await db.delete('fixed_blocks', where: 'id = ?', whereArgs: [id]);
  }

  // ----- Activities & sessions -----------------------------------------

  Future<List<ActivityWithStats>> getActivitiesWithStats() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT a.id, a.name, a.colorValue, a.createdAt,
             COUNT(s.id) AS cnt,
             AVG(s.durationSeconds) AS avgSec
      FROM activities a
      LEFT JOIN activity_sessions s ON s.activityId = a.id
      GROUP BY a.id
      ORDER BY a.name COLLATE NOCASE
    ''');
    return rows.map((r) {
      return ActivityWithStats(
        activity: Activity(
          id: r['id'] as int,
          name: r['name'] as String,
          colorValue: r['colorValue'] as int,
          createdAt: r['createdAt'] as int,
        ),
        sessionCount: (r['cnt'] as int?) ?? 0,
        averageSeconds: (r['avgSec'] as num?)?.toDouble(),
      );
    }).toList();
  }

  Future<int> insertActivity(String name, int colorValue) async {
    final db = await _database;
    return db.insert('activities', {
      'name': name,
      'colorValue': colorValue,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteActivity(int id) async {
    final db = await _database;
    await db.delete('activities', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ActivitySession>> getSessions(int activityId) async {
    final db = await _database;
    final rows = await db.query(
      'activity_sessions',
      where: 'activityId = ?',
      whereArgs: [activityId],
      orderBy: 'recordedAt DESC',
    );
    return rows.map(ActivitySession.fromMap).toList();
  }

  Future<int> insertSession(int activityId, int durationSeconds) async {
    final db = await _database;
    return db.insert('activity_sessions', {
      'activityId': activityId,
      'durationSeconds': durationSeconds,
      'recordedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteSession(int id) async {
    final db = await _database;
    await db.delete('activity_sessions', where: 'id = ?', whereArgs: [id]);
  }

  /// Average duration in seconds for an activity, or null if it has no sessions.
  Future<double?> averageSecondsFor(int activityId) async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT AVG(durationSeconds) AS avgSec FROM activity_sessions WHERE activityId = ?',
      [activityId],
    );
    return (rows.first['avgSec'] as num?)?.toDouble();
  }

  // ----- Scheduled activities ------------------------------------------

  Future<List<ScheduledActivity>> getScheduledActivities() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT sc.id, sc.activityId, sc.weekdayMask, sc.startMinute,
             sc.durationSeconds, a.name AS name, a.colorValue AS colorValue
      FROM scheduled_activities sc
      JOIN activities a ON a.id = sc.activityId
      ORDER BY sc.startMinute
    ''');
    return rows.map(ScheduledActivity.fromMap).toList();
  }

  Future<int> insertScheduledActivity({
    required int activityId,
    required int weekdayMask,
    required int startMinute,
    required int durationSeconds,
  }) async {
    final db = await _database;
    return db.insert('scheduled_activities', {
      'activityId': activityId,
      'weekdayMask': weekdayMask,
      'startMinute': startMinute,
      'durationSeconds': durationSeconds,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateScheduledDuration(int id, int durationSeconds) async {
    final db = await _database;
    await db.update(
      'scheduled_activities',
      {'durationSeconds': durationSeconds},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteScheduledActivity(int id) async {
    final db = await _database;
    await db.delete('scheduled_activities', where: 'id = ?', whereArgs: [id]);
  }
}
