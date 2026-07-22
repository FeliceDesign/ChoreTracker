import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/repositories.dart';
import '../../logic/palette.dart';
import '../../logic/time_utils.dart';

class SetupScreen extends ConsumerWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekAsync = ref.watch(weekDataProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Setup')),
      body: weekAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (week) => _SetupBody(week: week),
      ),
    );
  }
}

class _SetupBody extends ConsumerWidget {
  const _SetupBody({required this.week});

  final WeekData week;

  Future<int?> _pickTime(BuildContext context, int initialMinute) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialMinute ~/ 60, minute: initialMinute % 60),
    );
    if (t == null) return null;
    return t.hour * 60 + t.minute;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final configs = week.dayConfigs;

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        const _SectionHeader(
          icon: Icons.bedtime_outlined,
          title: 'Wake & sleep',
          subtitle: 'Everything before wake and after bed counts as unavailable.',
        ),
        for (final cfg in configs)
          ListTile(
            dense: true,
            leading: SizedBox(
              width: 40,
              child: Text(
                kWeekdayShort[cfg.weekday - 1],
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            title: Row(
              children: [
                _TimeChip(
                  icon: Icons.wb_sunny_outlined,
                  label: formatMinuteOfDay(cfg.wakeMinute),
                  onTap: () async {
                    final m = await _pickTime(context, cfg.wakeMinute);
                    if (m != null) {
                      await db.updateDayConfig(cfg.weekday, m, cfg.bedMinute);
                      refreshAllFrom(ref);
                    }
                  },
                ),
                const SizedBox(width: 8),
                _TimeChip(
                  icon: Icons.nightlight_outlined,
                  label: formatMinuteOfDay(cfg.bedMinute),
                  onTap: () async {
                    final m = await _pickTime(context, cfg.bedMinute);
                    if (m != null) {
                      await db.updateDayConfig(cfg.weekday, cfg.wakeMinute, m);
                      refreshAllFrom(ref);
                    }
                  },
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.copy_all_outlined),
              label: const Text('Copy Monday to all days'),
              onPressed: () async {
                final mon = week.configFor(1);
                await db.copyDayConfigToAll(mon.wakeMinute, mon.bedMinute);
                refreshAllFrom(ref);
              },
            ),
          ),
        ),
        const Divider(),
        const _SectionHeader(
          icon: Icons.event_outlined,
          title: 'Fixed appointments',
          subtitle: 'Work hours and other recurring commitments.',
        ),
        if (week.fixedBlocks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('No fixed appointments yet.'),
          ),
        for (final b in week.fixedBlocks)
          ListTile(
            leading: CircleAvatar(
              radius: 10,
              backgroundColor: Color(b.colorValue),
            ),
            title: Text(b.title),
            subtitle: Text(
              '${maskLabel(b.weekdayMask)}  ·  '
              '${formatMinuteOfDay(b.startMinute)}–${formatMinuteOfDay(b.endMinute)}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await db.deleteFixedBlock(b.id);
                refreshAllFrom(ref);
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.add),
            label: const Text('Add appointment'),
            onPressed: () async {
              final saved = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _AppointmentSheet(db: db),
              );
              if (saved == true) refreshAllFrom(ref);
            },
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

/// Bottom sheet to create a fixed appointment (work or custom).
class _AppointmentSheet extends StatefulWidget {
  const _AppointmentSheet({required this.db});

  final AppDatabase db;

  @override
  State<_AppointmentSheet> createState() => _AppointmentSheetState();
}

class _AppointmentSheetState extends State<_AppointmentSheet> {
  final _titleController = TextEditingController();
  String _type = 'work';
  int _weekdayMask = 0;
  int _startMinute = 9 * 60;
  int _endMinute = 17 * 60;
  int _colorValue = kWorkColor;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default work appointment to weekdays Mon–Fri.
    _weekdayMask = 0;
    for (var w = 1; w <= 5; w++) {
      _weekdayMask |= weekdayBit(w);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pick(bool isStart) async {
    final initial = isStart ? _startMinute : _endMinute;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
    );
    if (t == null) return;
    setState(() {
      final m = t.hour * 60 + t.minute;
      if (isStart) {
        _startMinute = m;
      } else {
        _endMinute = m;
      }
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim().isEmpty
        ? (_type == 'work' ? 'Work' : 'Appointment')
        : _titleController.text.trim();
    if (_weekdayMask == 0) {
      setState(() => _error = 'Pick at least one day.');
      return;
    }
    if (_endMinute <= _startMinute) {
      setState(() => _error = 'End time must be after start time.');
      return;
    }
    await widget.db.insertFixedBlock(
      title: title,
      type: _type,
      weekdayMask: _weekdayMask,
      startMinute: _startMinute,
      endMinute: _endMinute,
      colorValue: _type == 'work' ? kWorkColor : _colorValue,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New appointment', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Work, Gym, Class',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'work', label: Text('Work'), icon: Icon(Icons.work_outline)),
                ButtonSegment(value: 'custom', label: Text('Custom'), icon: Icon(Icons.event)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            const Text('Days'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                for (var w = 1; w <= 7; w++)
                  FilterChip(
                    label: Text(kWeekdayShort[w - 1]),
                    selected: maskHasDay(_weekdayMask, w),
                    onSelected: (_) =>
                        setState(() => _weekdayMask = toggleDay(_weekdayMask, w)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text('Start ${formatMinuteOfDay(_startMinute)}'),
                    onPressed: () => _pick(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text('End ${formatMinuteOfDay(_endMinute)}'),
                    onPressed: () => _pick(false),
                  ),
                ),
              ],
            ),
            if (_type == 'custom') ...[
              const SizedBox(height: 12),
              const Text('Colour'),
              const SizedBox(height: 4),
              _ColorPicker(
                selected: _colorValue,
                onSelected: (c) => setState(() => _colorValue = c),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
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
                  color: selected == c ? Colors.black : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
