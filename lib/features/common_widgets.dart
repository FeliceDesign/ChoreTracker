import 'package:flutter/material.dart';

import '../logic/palette.dart';
import '../logic/recurrence.dart';

/// A selectable recurrence preset shown in the "Repeats" dropdown.
class RecurrenceOption {
  final String label;
  final String type;
  final int interval;
  const RecurrenceOption(this.label, this.type, this.interval);

  bool get isWeekly => type == kRecurWeekly;
}

const List<RecurrenceOption> kRecurrenceOptions = [
  RecurrenceOption('Once', kRecurOnce, 1),
  RecurrenceOption('Weekly', kRecurWeekly, 1),
  RecurrenceOption('Every 2 weeks', kRecurWeekly, 2),
  RecurrenceOption('Every 3 weeks', kRecurWeekly, 3),
  RecurrenceOption('Every 4 weeks', kRecurWeekly, 4),
  RecurrenceOption('Monthly', kRecurMonthly, 1),
];

/// Dropdown for choosing a recurrence preset by its index in [kRecurrenceOptions].
class RecurrenceDropdown extends StatelessWidget {
  const RecurrenceDropdown({
    super.key,
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      value: index,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Repeats',
        border: OutlineInputBorder(),
      ),
      items: [
        for (var i = 0; i < kRecurrenceOptions.length; i++)
          DropdownMenuItem(value: i, child: Text(kRecurrenceOptions[i].label)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// Opens a time picker forced to 24-hour format (no AM/PM) and returns the
/// chosen time as a minute-of-day, or null if cancelled.
Future<int?> pickMinuteOfDay(BuildContext context, int initialMinute) async {
  final t = await showTimePicker(
    context: context,
    initialTime:
        TimeOfDay(hour: initialMinute ~/ 60, minute: initialMinute % 60),
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  return t == null ? null : t.hour * 60 + t.minute;
}

/// A row of selectable colour dots drawn from [kPalette].
class ColorDots extends StatelessWidget {
  const ColorDots({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in kPalette)
          GestureDetector(
            onTap: () => onSelected(c),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected == c
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
