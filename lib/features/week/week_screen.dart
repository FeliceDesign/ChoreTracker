import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../logic/free_time.dart';
import '../../logic/recurrence.dart';
import '../../logic/time_utils.dart';
import 'schedule_activity_sheet.dart';

const double _pxPerMinute = 1.4;
const double _gutterWidth = 46;

class WeekScreen extends ConsumerStatefulWidget {
  const WeekScreen({super.key});

  @override
  ConsumerState<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends ConsumerState<WeekScreen> {
  DateTime _selectedDate = dateOnly(DateTime.now());

  DateTime get _monday => mondayOfWeek(_selectedDate);

  void _shiftWeek(int deltaWeeks) => setState(() =>
      _selectedDate = dateOnly(_selectedDate.add(Duration(days: 7 * deltaWeeks))));

  void _shiftDay(int delta) => setState(
      () => _selectedDate = dateOnly(_selectedDate.add(Duration(days: delta))));

  @override
  Widget build(BuildContext context) {
    final weekAsync = ref.watch(weekDataProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Week'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Go to today',
            onPressed: () =>
                setState(() => _selectedDate = dateOnly(DateTime.now())),
          ),
        ],
      ),
      body: weekAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (week) {
          final monday = _monday;
          return Column(
            children: [
              _WeekNavBar(
                monday: monday,
                onPrev: () => _shiftWeek(-1),
                onNext: () => _shiftWeek(1),
              ),
              _WeekOverview(
                week: week,
                monday: monday,
                selectedDate: _selectedDate,
                onSelect: (d) => setState(() => _selectedDate = d),
              ),
              const Divider(height: 1),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragEnd: (details) {
                    final v = details.primaryVelocity ?? 0;
                    if (v < -200) {
                      _shiftDay(1);
                    } else if (v > 200) {
                      _shiftDay(-1);
                    }
                  },
                  child: _DayDetail(week: week, date: _selectedDate),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Week navigation header showing the ISO week number and date range.
class _WeekNavBar extends StatelessWidget {
  const _WeekNavBar({
    required this.monday,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime monday;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sunday = monday.add(const Duration(days: 6));
    final range = '${formatDayMonth(monday)} – ${formatDayMonth(sunday)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
          ),
          Expanded(
            child: Column(
              children: [
                Text('KW ${isoWeekNumber(monday)}',
                    style: theme.textTheme.titleMedium),
                Text('$range · ${monday.year}',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

/// Horizontal strip of 7 day cards, each showing the date and free time.
class _WeekOverview extends StatelessWidget {
  const _WeekOverview({
    required this.week,
    required this.monday,
    required this.selectedDate,
    required this.onSelect,
  });

  final WeekData week;
  final DateTime monday;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: _DayCard(
                date: monday.add(Duration(days: i)),
                free: week.freeTimeForDate(monday.add(Duration(days: i))),
                selectedDate: selectedDate,
                today: today,
                theme: theme,
                onSelect: onSelect,
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.date,
    required this.free,
    required this.selectedDate,
    required this.today,
    required this.theme,
    required this.onSelect,
  });

  final DateTime date;
  final FreeTimeResult free;
  final DateTime selectedDate;
  final DateTime today;
  final ThemeData theme;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = isSameDate(date, selectedDate);
    final isToday = isSameDate(date, today);
    final bg = selected
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final fg = selected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onSelect(date),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Column(
              children: [
                Text(
                  kWeekdayShort[date.weekday - 1],
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${date.day}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    decoration:
                        isToday ? TextDecoration.underline : TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatMinutes(free.freeMinutes),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Detailed vertical timeline for a single day.
class _DayDetail extends ConsumerWidget {
  const _DayDetail({required this.week, required this.date});

  final WeekData week;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = week.configFor(date.weekday);
    final result = week.freeTimeForDate(date);
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${kWeekdayLong[date.weekday - 1]}, ${formatDayMonth(date)}',
                        style: theme.textTheme.titleMedium),
                    Text(
                      'Awake ${formatMinuteOfDay(cfg.wakeMinute)}–'
                      '${formatMinuteOfDay(cfg.bedMinute)}'
                      '${cfg.bedMinute <= cfg.wakeMinute ? ' +1' : ''}  ·  '
                      'Free ${formatMinutes(result.freeMinutes)} '
                      'of ${formatMinutes(result.awakeMinutes)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add),
                label: const Text('Schedule'),
                onPressed: () async {
                  final saved = await showScheduleActivitySheet(
                    context,
                    date: date,
                    defaultStartMinute: _suggestStart(result, cfg.wakeMinute),
                  );
                  if (saved == true) refreshAllFrom(ref);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            child: _Timeline(
              week: week,
              date: date,
              config: cfg,
              result: result,
              onScheduledTap: (s) => _onScheduledTap(context, ref, s),
            ),
          ),
        ),
      ],
    );
  }

  int _suggestStart(FreeTimeResult result, int fallback) {
    // Free-gap starts can be absolute (past midnight); wrap back to 0..1439.
    if (result.freeGaps.isNotEmpty) return result.freeGaps.first.start % 1440;
    return fallback % 1440;
  }

  Future<void> _onScheduledTap(
    BuildContext context,
    WidgetRef ref,
    ScheduledActivity s,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(s.activityName),
              subtitle: Text('${formatMinuteOfDay(s.startMinute)} · '
                  '${formatDurationSeconds(s.durationSeconds)}'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Update length to current average'),
              onTap: () => Navigator.of(context).pop('refresh'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove from week'),
              onTap: () => Navigator.of(context).pop('remove'),
            ),
          ],
        ),
      ),
    );

    final db = ref.read(databaseProvider);
    if (action == 'remove') {
      await db.deleteScheduledActivity(s.id);
      refreshAllFrom(ref);
    } else if (action == 'refresh') {
      final avg = await db.averageSecondsFor(s.activityId);
      if (avg != null) {
        await db.updateScheduledDuration(s.id, avg.round());
        refreshAllFrom(ref);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No recorded runs to average yet.')),
        );
      }
    }
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.week,
    required this.date,
    required this.config,
    required this.result,
    this.onScheduledTap,
  });

  final WeekData week;
  final DateTime date;
  final DayConfig config;
  final FreeTimeResult result;
  final void Function(ScheduledActivity)? onScheduledTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final awakeEnd = effectiveBedMinute(config.wakeMinute, config.bedMinute);
    final totalHeight = (awakeEnd - config.wakeMinute) * _pxPerMinute;
    if (totalHeight <= 0) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Bed time must differ from wake time (edit in Setup).'),
      );
    }

    // Places a raw block (0..1439 start/end) into the awake window, applying the
    // same normalisation as the free-time math and clamping to the window.
    ({double top, double height}) place(int rawStart, int rawEnd) {
      var s = rawStart;
      var e = rawEnd;
      if (e <= s) e += 1440;
      if (s < config.wakeMinute) {
        s += 1440;
        e += 1440;
      }
      final top = (s - config.wakeMinute) * _pxPerMinute;
      var height = (e - s) * _pxPerMinute;
      final maxH = totalHeight - top;
      if (height > maxH) height = maxH;
      return (top: top, height: height);
    }

    final children = <Widget>[];

    // Hour grid lines + labels (may run past 24:00 into the early hours).
    final firstHour = (config.wakeMinute / 60).ceil();
    final lastHour = (awakeEnd / 60).floor();
    for (var h = firstHour; h <= lastHour; h++) {
      final y = (h * 60 - config.wakeMinute) * _pxPerMinute;
      children.add(Positioned(
        top: y,
        left: _gutterWidth,
        right: 0,
        child: Divider(height: 1, color: theme.dividerColor),
      ));
      children.add(Positioned(
        top: y - 6,
        left: 0,
        width: _gutterWidth - 6,
        child: Text(
          formatMinuteOfDay((h * 60) % 1440),
          textAlign: TextAlign.right,
          style: theme.textTheme.labelSmall,
        ),
      ));
    }

    // Free gaps (drawn first, behind blocks). Gap minutes are already absolute.
    for (final gap in result.freeGaps) {
      if (gap.length < 5) continue;
      children.add(_positionedBlock(
        top: (gap.start - config.wakeMinute) * _pxPerMinute,
        height: gap.length * _pxPerMinute,
        color: Colors.green.withAlpha(28),
        borderColor: Colors.green.withAlpha(90),
        child: gap.length >= 20
            ? Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  'Free ${formatMinutes(gap.length)}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              )
            : null,
      ));
    }

    // Fixed blocks.
    for (final b in week.fixedBlocksOnDate(date)) {
      final pos = place(b.startMinute, b.endMinute);
      final crosses = b.endMinute < b.startMinute;
      children.add(_eventBlock(
        top: pos.top,
        height: pos.height,
        color: Color(b.colorValue),
        title: b.title,
        subtitle:
            '${formatMinuteOfDay(b.startMinute)}–${formatMinuteOfDay(b.endMinute)}'
            '${crosses ? ' +1' : ''}',
      ));
    }

    // Scheduled activities (real blocks with the measured length).
    for (final s in week.scheduledOnDate(date)) {
      final rawEnd = s.startMinute + s.durationMinutes;
      final pos = place(s.startMinute, rawEnd);
      final crosses = rawEnd > 1440;
      children.add(_eventBlock(
        top: pos.top,
        height: pos.height,
        color: Color(s.colorValue),
        title: s.activityName,
        subtitle:
            '${formatMinuteOfDay(s.startMinute)}–${formatMinuteOfDay(rawEnd % 1440)}'
            '${crosses ? ' +1' : ''} · ${formatDurationSeconds(s.durationSeconds)}',
        icon: Icons.timer,
        onTap: onScheduledTap == null ? null : () => onScheduledTap!(s),
      ));
    }

    return SizedBox(
      height: totalHeight,
      child: Stack(children: children),
    );
  }

  Widget _positionedBlock({
    required double top,
    required double height,
    required Color color,
    required Color borderColor,
    Widget? child,
  }) {
    return Positioned(
      top: top,
      left: _gutterWidth + 4,
      right: 4,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor),
        ),
        alignment: Alignment.topLeft,
        child: child,
      ),
    );
  }

  Widget _eventBlock({
    required double top,
    required double height,
    required Color color,
    required String title,
    required String subtitle,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    final clampedHeight = height < 18 ? 18.0 : height;
    return Positioned(
      top: top,
      left: _gutterWidth + 4,
      right: 4,
      height: clampedHeight,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (clampedHeight > 30)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
