import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../logic/palette.dart';
import '../../logic/time_utils.dart';
import '../common_widgets.dart';
import 'activity_stopwatch_screen.dart';

class TimersScreen extends ConsumerWidget {
  const TimersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(activitiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Timers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addActivity(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New timer'),
      ),
      body: activitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (activities) {
          if (activities.isEmpty) {
            return const _EmptyTimers();
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: activities.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final a = activities[i];
              return _ActivityTile(stats: a);
            },
          );
        },
      ),
    );
  }

  Future<void> _addActivity(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_NewActivity>(
      context: context,
      builder: (_) => const _NewActivityDialog(),
    );
    if (result != null && result.name.isNotEmpty) {
      await ref.read(databaseProvider).insertActivity(result.name, result.color);
      refreshAllFrom(ref);
    }
  }
}

class _ActivityTile extends ConsumerWidget {
  const _ActivityTile({required this.stats});

  final ActivityWithStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avg = stats.averageSecondsRounded;
    final subtitle = avg == null
        ? 'No runs yet — start the timer to measure it'
        : 'avg ${formatDurationSeconds(avg)}  ·  ${stats.sessionCount} run${stats.sessionCount == 1 ? '' : 's'}';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Color(stats.activity.colorValue),
        child: const Icon(Icons.timer_outlined, color: Colors.white),
      ),
      title: Text(stats.activity.name),
      subtitle: Text(subtitle),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'delete') {
            await ref.read(databaseProvider).deleteActivity(stats.activity.id);
            refreshAllFrom(ref);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ActivityStopwatchScreen(activity: stats.activity),
          ),
        );
      },
    );
  }
}

class _EmptyTimers extends StatelessWidget {
  const _EmptyTimers();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, size: 64),
            const SizedBox(height: 16),
            Text(
              'Create a timer for a chore',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'e.g. "Empty the dishwasher". Start it while you do the task, '
              'stop when done. Do it a few times and the app learns how long '
              'it really takes.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NewActivity {
  final String name;
  final int color;
  const _NewActivity(this.name, this.color);
}

class _NewActivityDialog extends StatefulWidget {
  const _NewActivityDialog();

  @override
  State<_NewActivityDialog> createState() => _NewActivityDialogState();
}

class _NewActivityDialogState extends State<_NewActivityDialog> {
  final _controller = TextEditingController();
  int _color = kPalette.first;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New timer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Activity name',
              hintText: 'Empty the dishwasher',
            ),
          ),
          const SizedBox(height: 16),
          ColorDots(
            selected: _color,
            onSelected: (c) => setState(() => _color = c),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            Navigator.of(context).pop(_NewActivity(name, _color));
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
