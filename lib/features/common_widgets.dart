import 'package:flutter/material.dart';

import '../logic/palette.dart';

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
