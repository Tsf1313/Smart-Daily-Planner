import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/network/planner_client.dart';
import '../../../planner/data/repositories/task_store.dart';
import '../../../planner/presentation/pages/task_detail_screen.dart';
import '../../../../core/storage/deadline_cache.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.api,
    required this.cache,
    this.store,
    this.displayName,
  });

  final TaskStore? store;
  final String? displayName;
  final PlannerClient api;
  final DeadlineCache cache;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Deadline> entries = [];
  String? notice;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      notice = null;
      entries = [];
    });
    try {
      final fresh = await widget.api.deadlines();
      if (!mounted) return;
      entries = fresh;
      try {
        await widget.cache.save(fresh);
      } on FileSystemException {
        notice = 'Loaded deadlines. Offline saving is unavailable.';
      }
    } catch (e) {
      debugPrint('Dashboard load failed: ${e.runtimeType}: $e');
      if (!mounted) return;
      final offline =
          e is TimeoutException ||
          e is SocketException ||
          e is http.ClientException ||
          (e is FirebaseAuthException && e.code == 'network-request-failed');
      if (offline) {
        try {
          final saved = await widget.cache.read();
          entries = saved ?? [];
          notice = saved == null
              ? 'Offline. Open the dashboard online to save a copy.'
              : 'Offline · Showing your last saved deadlines';
        } catch (_) {
          notice = 'Your saved deadlines could not be opened.';
        }
      } else if (e is ApiFailure && (e.status == 401 || e.status == 403)) {
        notice = 'Access denied. Check your account or sign in again.';
        try {
          await widget.cache.clear();
        } on FileSystemException {
          /* Keep access blocked. */
        }
      } else {
        notice = 'Could not load deadlines. Check the server and try again.';
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = entries
        .where((e) => !DateTime.parse(e.dueDate).isBefore(today))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.store case final TaskStore store)
          ListenableBuilder(
            listenable: store,
            builder: (context, _) => _TodaySummary(
              store: store,
              today: today,
              displayName: widget.displayName,
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Text(
                'Upcoming deadlines',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Refresh deadlines',
              onPressed: load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(notice!),
          ),
        if (upcoming.isEmpty &&
            (notice == null ||
                entries.isNotEmpty ||
                notice!.startsWith('Offline ·')))
          const Text('No upcoming deadlines.'),
        for (final e in upcoming)
          Card(
            elevation: 0,
            color: AppColors.surface,
            child: ListTile(
              leading: const Icon(
                Icons.event_outlined,
                color: AppColors.primary,
              ),
              title: Text(e.title),
              subtitle: Text('Due ${e.dueDate}'),
            ),
          ),
      ],
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({
    required this.store,
    required this.today,
    this.displayName,
  });

  final TaskStore store;
  final DateTime today;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final tasks = store.tasks.where((task) => task.occursOn(today)).toList();
    final done = tasks.where((task) => task.isCompletedOn(today)).length;
    final now = DateTime.now();
    final count = tasks.where((task) {
      if (task.isCompletedOn(today)) return true;
      if (task.isDeadline) return task.dueAt?.isAfter(now) ?? true;
      final endTime = task.endTime;
      return endTime == null ||
          endTime.hour * 60 + endTime.minute > now.hour * 60 + now.minute;
    }).length;
    final progress = count == 0 ? 0.0 : done / count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName?.isNotEmpty == true
                    ? 'Hello, $displayName'
                    : 'Today’s Progress',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                MaterialLocalizations.of(context).formatFullDate(today),
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    color: Colors.white,
                    backgroundColor: Colors.white30,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    count == 0
                        ? 'No data'
                        : '${(progress * 100).round()}% · $done of $count complete',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Today’s Tasks', style: Theme.of(context).textTheme.titleLarge),
        if (tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No tasks scheduled for today.'),
          ),
        for (final task in tasks)
          Card(
            elevation: 0,
            color: AppColors.surface,
            child: ListTile(
              leading: Icon(
                task.isCompletedOn(today)
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: task.isCompletedOn(today)
                    ? AppColors.success
                    : AppColors.primary,
              ),
              title: Text(task.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => TaskDetailScreen(
                    task: task,
                    store: store,
                    occurrenceDate: today,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
