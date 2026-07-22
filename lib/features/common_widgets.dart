import 'package:flutter/material.dart';

import '../logic/palette.dart';

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
