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
}
