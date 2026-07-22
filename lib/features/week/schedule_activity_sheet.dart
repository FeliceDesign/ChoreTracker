import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../logic/recurrence.dart';
import '../../logic/time_utils.dart';
import '../common_widgets.dart';

/// Shows the "schedule an activity" bottom sheet anchored on [date]. Returns
/// true if something was scheduled so the caller can refresh.
Future<bool?> showScheduleActivitySheet(
  BuildContext context, {
  required DateTime date,
  int defaultStartMinute = 18 * 60,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ScheduleSheet(
      date: date,
      defaultStartMinute: defaultStartMinute,
    ),
  );
}

class _ScheduleSheet extends ConsumerStatefulWidget {
  const _ScheduleSheet({
    required this.date,
    required this.defaultStartMinute,
  });

  final DateTime date;
  final int defaultStartMinute;

  @override
  ConsumerState<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends ConsumerState<_ScheduleSheet> {
  int? _activityId;
  int _weekdayMask = 0;
  late int _startMinute;
  int _recurIndex = 1; // Weekly
  bool _customLength = false;
  int _customMinutes = 15;
  String? _error;

  @override
  void initState() {
    super.initState();
    _weekdayMask = weekdayBit(widget.date.weekday);
    _startMinute = widget.defaultStartMinute;
  }

  Future<void> _pickStart() async {
    final m = await pickMinuteOfDay(context, _startMinute);
    if (m == null) return;
    setState(() => _startMinute = m);
  }

  Future<void> _save(List<ActivityWithStats> activities) async {
    final option = kRecurrenceOptions[_recurIndex];
    if (_activityId == null) {
      setState(() => _error = 'Pick an activity.');
      return;
    }
    if (option.isWeekly && _weekdayMask == 0) {
      setState(() => _error = 'Pick at least one day.');
      return;
    }
    final stats = activities.firstWhere((a) => a.activity.id == _activityId);
    final avg = stats.averageSecondsRounded;

    int durationSeconds;
    if (_customLength || avg == null) {
      if (_customMinutes <= 0) {
        setState(() => _error = 'Length must be greater than zero.');
        return;
      }
      durationSeconds = _customMinutes * 60;
    } else {
      durationSeconds = avg;
    }

    await ref.read(databaseProvider).insertScheduledActivity(
          activityId: _activityId!,
          weekdayMask:
              option.isWeekly ? _weekdayMask : weekdayMaskForDate(widget.date),
          startMinute: _startMinute,
          durationSeconds: durationSeconds,
          recurrenceType: option.type,
          intervalCount: option.interval,
          anchorEpochDay: ordinalDay(widget.date),
          monthlyDay: widget.date.day,
        );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(activitiesProvider);
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom + media.padding.bottom;
    final option = kRecurrenceOptions[_recurIndex];

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: activitiesAsync.when(
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) =>
            SizedBox(height: 120, child: Center(child: Text('Error: $e'))),
        data: (activities) {
          if (activities.isEmpty) {
            return const SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  'Create a timer first in the Timers tab, then schedule it here.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          _activityId ??= activities.first.activity.id;
          final selected =
              activities.firstWhere((a) => a.activity.id == _activityId);
          final avg = selected.averageSecondsRounded;

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Schedule activity',
                    style: Theme.of(context).textTheme.titleLarge),
                Text(
                  'Starting ${kWeekdayLong[widget.date.weekday - 1]}, '
                  '${formatDayMonth(widget.date)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: _activityId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Activity',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final a in activities)
                      DropdownMenuItem(
                        value: a.activity.id,
                        child: Text(
                          a.averageSecondsRounded == null
                              ? a.activity.name
                              : '${a.activity.name} · ${formatDurationSeconds(a.averageSecondsRounded!)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _activityId = v;
                    _customLength = false;
                  }),
                ),
                const SizedBox(height: 8),
                if (avg == null)
                  Text(
                    'No measured average yet — enter an estimated length below.',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  )
                else
                  Text('Average length: ${formatDurationSeconds(avg)}'),
                const SizedBox(height: 12),
                RecurrenceDropdown(
                  index: _recurIndex,
                  onChanged: (i) => setState(() => _recurIndex = i),
                ),
                const SizedBox(height: 12),
                if (option.isWeekly) ...[
                  const Text('Days'),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (var w = 1; w <= 7; w++)
                        FilterChip(
                          label: Text(kWeekdayShort[w - 1]),
                          selected: maskHasDay(_weekdayMask, w),
                          onSelected: (_) => setState(
                              () => _weekdayMask = toggleDay(_weekdayMask, w)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ] else if (option.type == kRecurMonthly) ...[
                  Text('On day ${widget.date.day} of each month',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text('Start at ${formatMinuteOfDay(_startMinute)}'),
                  onPressed: _pickStart,
                ),
                const SizedBox(height: 8),
                if (avg != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Custom length'),
                    subtitle: const Text('Override the measured average'),
                    value: _customLength,
                    onChanged: (v) => setState(() => _customLength = v),
                  ),
                if (_customLength || avg == null)
                  Row(
                    children: [
                      const Text('Length (minutes):'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Slider(
                          value: _customMinutes.clamp(1, 240).toDouble(),
                          min: 1,
                          max: 240,
                          divisions: 239,
                          label: '$_customMinutes min',
                          onChanged: (v) =>
                              setState(() => _customMinutes = v.round()),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text('$_customMinutes',
                            textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _save(activities),
                      child: const Text('Add to week'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
