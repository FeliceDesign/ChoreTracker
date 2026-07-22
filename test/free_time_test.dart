import 'package:choretracker/logic/free_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeFreeTime', () {
    test('empty day = full awake window is free', () {
      final r = computeFreeTime(awakeStart: 420, awakeEnd: 1380, busy: const []);
      expect(r.awakeMinutes, 960);
      expect(r.occupiedMinutes, 0);
      expect(r.freeMinutes, 960);
      expect(r.freeGaps, [const TimeInterval(420, 1380)]);
    });

    test('single block reduces free time by its length', () {
      final r = computeFreeTime(
        awakeStart: 420,
        awakeEnd: 1380,
        busy: const [TimeInterval(540, 1020)], // 09:00-17:00 => 480 min
      );
      expect(r.occupiedMinutes, 480);
      expect(r.freeMinutes, 480);
      expect(r.freeGaps, const [
        TimeInterval(420, 540),
        TimeInterval(1020, 1380),
      ]);
    });

    test('overlapping blocks are merged and counted once', () {
      final r = computeFreeTime(
        awakeStart: 0,
        awakeEnd: 600,
        busy: const [
          TimeInterval(100, 300),
          TimeInterval(250, 400),
          TimeInterval(500, 550),
        ],
      );
      expect(r.occupied, const [
        TimeInterval(100, 400),
        TimeInterval(500, 550),
      ]);
      expect(r.occupiedMinutes, 350);
      expect(r.freeMinutes, 250);
    });

    test('blocks outside the awake window are clipped', () {
      final r = computeFreeTime(
        awakeStart: 420,
        awakeEnd: 1380,
        busy: const [
          TimeInterval(0, 500), // starts before wake
          TimeInterval(1300, 1500), // ends after bed
        ],
      );
      expect(r.occupied, const [
        TimeInterval(420, 500),
        TimeInterval(1300, 1380),
      ]);
      expect(r.occupiedMinutes, 80 + 80);
      expect(r.freeMinutes, 960 - 160);
    });

    test('a scheduled activity reduces free minutes by exactly its duration', () {
      final base = computeFreeTime(
        awakeStart: 420,
        awakeEnd: 1380,
        busy: const [TimeInterval(540, 1020)],
      );
      final withChore = computeFreeTime(
        awakeStart: 420,
        awakeEnd: 1380,
        busy: const [
          TimeInterval(540, 1020),
          TimeInterval(1100, 1130), // 30-minute chore in a free gap
        ],
      );
      expect(withChore.freeMinutes, base.freeMinutes - 30);
    });

    test('touching intervals merge into one', () {
      final r = computeFreeTime(
        awakeStart: 0,
        awakeEnd: 100,
        busy: const [TimeInterval(10, 40), TimeInterval(40, 60)],
      );
      expect(r.occupied, const [TimeInterval(10, 60)]);
      expect(r.freeMinutes, 50);
    });

    test('degenerate window yields no free time', () {
      final r = computeFreeTime(awakeStart: 600, awakeEnd: 600, busy: const []);
      expect(r.freeMinutes, 0);
      expect(r.freeGaps, isEmpty);
    });
  });

  group('computeDayFreeTime (crossing midnight)', () {
    test('bed at midnight extends the awake window to 24:00', () {
      // wake 09:00, bed 00:00 => 15h awake; work 13:00-21:15 (8h15m).
      final r = computeDayFreeTime(
        wakeMinute: 9 * 60,
        bedMinute: 0,
        busy: const [TimeInterval(13 * 60, 21 * 60 + 15)],
      );
      expect(r.awakeMinutes, 15 * 60);
      expect(r.occupiedMinutes, 8 * 60 + 15);
      expect(r.freeMinutes, 6 * 60 + 45);
    });

    test('night worker with a shift that crosses midnight', () {
      // wake 14:00 (840), bed 06:00 (360 -> 1800) => 16h awake window.
      // Shift 22:00-06:00 given as raw (1320, 360) => 8h occupied.
      final r = computeDayFreeTime(
        wakeMinute: 14 * 60,
        bedMinute: 6 * 60,
        busy: const [TimeInterval(22 * 60, 6 * 60)],
      );
      expect(r.awakeMinutes, 16 * 60);
      expect(r.occupiedMinutes, 8 * 60);
      expect(r.freeMinutes, 8 * 60);
    });

    test('a post-midnight chore is shifted into the awake tail', () {
      // wake 09:00, bed 02:00 (120 -> 1560); chore 00:30-01:30 raw (30, 90).
      final r = computeDayFreeTime(
        wakeMinute: 9 * 60,
        bedMinute: 2 * 60,
        busy: const [TimeInterval(30, 90)],
      );
      expect(r.occupiedMinutes, 60);
      expect(r.freeMinutes, r.awakeMinutes - 60);
    });

    test('bed equal to wake means a full 24h window', () {
      final r = computeDayFreeTime(
        wakeMinute: 9 * 60,
        bedMinute: 9 * 60,
        busy: const [],
      );
      expect(r.awakeMinutes, 24 * 60);
      expect(r.freeMinutes, 24 * 60);
    });
  });
}
