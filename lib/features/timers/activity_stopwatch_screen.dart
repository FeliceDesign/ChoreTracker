import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../logic/time_utils.dart';

/// Clock-app style stopwatch for a single activity. Each completed run is saved
/// as a session; the running average is shown and reused when scheduling.
class ActivityStopwatchScreen extends ConsumerStatefulWidget {
  const ActivityStopwatchScreen({super.key, required this.activity});

  final Activity activity;

  @override
  ConsumerState<ActivityStopwatchScreen> createState() =>
      _ActivityStopwatchScreenState();
}

class _ActivityStopwatchScreenState
    extends ConsumerState<ActivityStopwatchScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;

  bool get _running => _stopwatch.isRunning;
  int get _elapsedSeconds => _stopwatch.elapsed.inSeconds;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    _stopwatch.start();
    _ticker ??= Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => setState(() {}),
    );
    setState(() {});
  }

  Future<void> _stopAndSave() async {
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    final seconds = _elapsedSeconds;
    _stopwatch.reset();
    if (seconds > 0) {
      await ref
          .read(databaseProvider)
          .insertSession(widget.activity.id, seconds);
      ref.invalidate(sessionsProvider(widget.activity.id));
      refreshAllFrom(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved ${formatDurationSeconds(seconds)}')),
        );
      }
    }
    setState(() {});
  }

  void _reset() {
    _stopwatch.stop();
    _ticker?.cancel();
    _ticker = null;
    _stopwatch.reset();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sessionsProvider(widget.activity.id));
    final color = Color(widget.activity.colorValue);

    return Scaffold(
      appBar: AppBar(title: Text(widget.activity.name)),
      body: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            formatStopwatch(_elapsedSeconds),
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w300,
              color: color,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _elapsedSeconds == 0 && !_running ? null : _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
              const SizedBox(width: 16),
              _running
                  ? FilledButton.icon(
                      onPressed: _stopAndSave,
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop & save'),
                    )
                  : FilledButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(_elapsedSeconds == 0 ? 'Start' : 'Resume'),
                    ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          Expanded(
            child: sessionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (sessions) => _SessionList(
                sessions: sessions,
                onDelete: (id) async {
                  await ref.read(databaseProvider).deleteSession(id);
                  ref.invalidate(sessionsProvider(widget.activity.id));
                  refreshAllFrom(ref);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({required this.sessions, required this.onDelete});

  final List<ActivitySession> sessions;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No runs recorded yet.'),
        ),
      );
    }
    final total = sessions.fold<int>(0, (s, e) => s + e.durationSeconds);
    final avg = (total / sessions.length).round();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(label: 'Average', value: formatDurationSeconds(avg)),
              _Stat(label: 'Runs', value: '${sessions.length}'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = sessions[i];
              final when = DateTime.fromMillisecondsSinceEpoch(s.recordedAt);
              return ListTile(
                dense: true,
                leading: const Icon(Icons.history),
                title: Text(formatDurationSeconds(s.durationSeconds)),
                subtitle: Text(_formatDate(when)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onDelete(s.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}  $hh:$mm';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.headlineSmall),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
