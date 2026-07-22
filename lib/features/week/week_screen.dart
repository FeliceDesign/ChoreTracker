import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../logic/free_time.dart';
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
  int _selectedDay = DateTime.now().weekday; // 1..7

  @override
  Widget build(BuildContext context) {
    final weekAsync = ref.watch(weekDataProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Week')),
      body: weekAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (week) {
          return Column(
            children: [
              _WeekOverview(
                week: week,
                selectedDay: _selectedDay,
                onSelect: (d) => setState(() => _selectedDay = d),
              ),
              const Divider(height: 1),
              Expanded(child: _DayDetail(week: week, day: _selectedDay)),
            ],
          );
        },
      ),
    );
  }
}

/// Horizontal strip of 7 day cards, each showing that day's total free time.
class _WeekOverview extends StatelessWidget {
  const _WeekOverview({
    required this.week,
    required this.selectedDay,
    required this.onSelect,
  });

  final WeekData week;
  final int selectedDay;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          for (var d = 1; d <= 7; d++)
            Expanded(
              child: _DayCard(
                weekday: d,
                freeMinutes: week.freeTimeFor(d).freeMinutes,
                selected: d == selectedDay,
                theme: theme,
                onTap: () => onSelect(d),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.weekday,
    required this.freeMinutes,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  final int weekday;
  final int freeMinutes;
  final bool selected;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Column(
              children: [
                Text(
                  kWeekdayShort[weekday - 1],
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatMinutes(freeMinutes),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'free',
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
  const _DayDetail({required this.week, required this.day});

  final WeekData week;
  final int day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = week.configFor(day);
    final result = week.freeTimeFor(day);
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
                    Text(kWeekdayLong[day - 1], style: theme.textTheme.titleMedium),
                    Text(
                      'Awake ${formatMinuteOfDay(cfg.wakeMinute)}–'
                      '${formatMinuteOfDay(cfg.bedMinute)}  ·  '
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
                    defaultDay: day,
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
              day: day,
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
    if (result.freeGaps.isNotEmpty) return result.freeGaps.first.start;
    return fallback;
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
    required this.day,
    required this.config,
    required this.result,
    this.onScheduledTap,
  });

  final WeekData week;
  final int day;
  final DayConfig config;
  final FreeTimeResult result;
  final void Function(ScheduledActivity)? onScheduledTap;

  double _y(int minute) => (minute - config.wakeMinute) * _pxPerMinute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalHeight = (config.bedMinute - config.wakeMinute) * _pxPerMinute;
    if (totalHeight <= 0) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Bed time must be after wake time (edit in Setup).'),
      );
    }

    final children = <Widget>[];

    // Hour grid lines + labels.
    final firstHour = (config.wakeMinute / 60).ceil();
    final lastHour = (config.bedMinute / 60).floor();
    for (var h = firstHour; h <= lastHour; h++) {
      final y = _y(h * 60);
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
          '${h.toString().padLeft(2, '0')}:00',
          textAlign: TextAlign.right,
          style: theme.textTheme.labelSmall,
        ),
      ));
    }

    // Free gaps (drawn first, behind blocks).
    for (final gap in result.freeGaps) {
      if (gap.length < 5) continue;
      children.add(_positionedBlock(
        top: _y(gap.start),
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
    for (final b in week.fixedBlocksOn(day)) {
      children.add(_eventBlock(
        top: _y(b.startMinute),
        height: (b.endMinute - b.startMinute) * _pxPerMinute,
        color: Color(b.colorValue),
        title: b.title,
        subtitle:
            '${formatMinuteOfDay(b.startMinute)}–${formatMinuteOfDay(b.endMinute)}',
      ));
    }

    // Scheduled activities (real blocks with the measured length).
    for (final s in week.scheduledOn(day)) {
      final end = s.startMinute + s.durationMinutes;
      children.add(_eventBlock(
        top: _y(s.startMinute),
        height: s.durationMinutes * _pxPerMinute,
        color: Color(s.colorValue),
        title: s.activityName,
        subtitle:
            '${formatMinuteOfDay(s.startMinute)}–${formatMinuteOfDay(end)} · ${formatDurationSeconds(s.durationSeconds)}',
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
