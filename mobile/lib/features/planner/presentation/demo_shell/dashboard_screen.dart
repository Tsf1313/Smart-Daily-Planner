import 'package:material_ui/material_ui.dart';
import '../../../../app/app_theme.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/task_store.dart';
import '../pages/add_task_screen.dart';
import '../pages/task_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback? onSeeAllTasks;
  const DashboardScreen({super.key, this.onSeeAllTasks});

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final tasks = store.tasks;
        final total = store.totalCount;
        final done = store.completedCount;
        final pending = store.pendingCount;
        final overdue = store.overdueCount;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(context, store.userName, total, done),
                  if (store.offlineMode)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.cloud_off, size: 16, color: AppColors.warning),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Offline Read-Only Mode active',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildStatsRow(pending, done, overdue),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Today's Tasks",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        TextButton(
                          onPressed: onSeeAllTasks,
                          child: const Text('See all →'),
                        ),
                      ],
                    ),
                  ),
                  if (tasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No tasks yet. Tap + to create one!',
                          style: TextStyle(color: AppColors.textSecondary)),
                    )
                  else
                    ...tasks.take(4).map((task) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: _DashboardTaskTile(
                            task: task,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TaskDetailScreen(task: task),
                              ),
                            ),
                            onToggle: () {
                              if (store.offlineMode) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Offline mode: connect to internet to edit.'),
                                  ),
                                );
                                return;
                              }
                              if (task.id != null) store.toggleComplete(task.id!);
                            },
                          ),
                        )),
                  const SizedBox(height: 20),
                  if (overdue > 0) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: AppColors.error, size: 18),
                          SizedBox(width: 6),
                          Text('Overdue Tasks',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildOverdueTasks(context, store, tasks),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: AppColors.warning, size: 18),
                        SizedBox(width: 6),
                        Text('Upcoming Deadlines',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildUpcomingDeadlines(context, tasks),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: store.offlineMode ? Colors.grey : AppColors.primary,
            onPressed: () async {
              if (store.offlineMode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Offline mode: cannot add tasks.')),
                );
                return;
              }
              final newTask = await Navigator.push<Task>(
                context,
                MaterialPageRoute(builder: (_) => const AddTaskScreen()),
              );
              if (newTask != null) {
                store.addTask(newTask);
              }
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, String userName, int total, int done) {
    final now = DateTime.now();
    final progress = total > 0 ? done / total : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good ${_greetingTime(now.hour)}, $userName 👋',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  _dateLabel(now),
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Today's Progress",
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white30,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  borderRadius: BorderRadius.circular(10),
                  minHeight: 8,
                ),
                const SizedBox(height: 4),
                Text(
                  '$done of $total Tasks completed',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: Colors.white30,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int pending, int done, int overdue) {
    return Row(
      children: [
        _StatCard(icon: Icons.pending_actions, label: 'Pending', value: '$pending', color: AppColors.warning),
        const SizedBox(width: 10),
        _StatCard(icon: Icons.check_circle_outline, label: 'Completed', value: '$done', color: AppColors.success),
        const SizedBox(width: 10),
        _StatCard(icon: Icons.error_outline, label: 'Overdue', value: '$overdue', color: AppColors.error),
      ],
    );
  }

  Widget _buildOverdueTasks(BuildContext context, TaskStore store, List<Task> tasks) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final overdueList = tasks.where((t) {
      if (t.isCompletedOn(today)) return false;
      final dueDay = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      return dueDay.isBefore(today);
    }).toList();

    return Column(
      children: overdueList
          .map((task) => GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.error.withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(task.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            Text(
                              _overdueLabel(task.dueDate, today),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          if (store.offlineMode) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Offline mode: connect to internet to edit.'),
                              ),
                            );
                            return;
                          }
                          if (task.id != null) store.toggleComplete(task.id!);
                        },
                        icon: const Icon(
                          Icons.radio_button_unchecked,
                          color: AppColors.error,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  String _overdueLabel(DateTime dueDate, DateTime today) {
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final days = today.difference(dueDay).inDays;
    if (days == 1) return 'Overdue by 1 day';
    return 'Overdue by $days days';
  }

  Widget _buildUpcomingDeadlines(BuildContext context, List<Task> tasks) {
    final upcoming = tasks
        .where((t) => !t.isCompleted && t.dueDate.isAfter(DateTime.now()))
        .take(3)
        .toList();

    if (upcoming.isEmpty) {
      return const Text('No upcoming deadlines 🎉',
          style: TextStyle(color: AppColors.textSecondary));
    }

    return Column(
      children: upcoming
          .map((task) => GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(task.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            Text('Due: ${_dueDateLabel(task.dueDate)}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(task.category,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.warning)),
                      ),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  String _greetingTime(int hour) {
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  String _dateLabel(DateTime d) {
    const days = [
      '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${days[d.weekday]}, ${d.day} ${months[d.month]} ${d.year}';
  }

  String _dueDateLabel(DateTime d) {
    final now = DateTime.now();
    final diff = DateTime(d.year, d.month, d.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return 'In $diff days';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _DashboardTaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _DashboardTaskTile({
    required this.task,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDoneToday = task.isCompletedOn(DateTime.now());
    final priorityColor = task.priority == 'high'
        ? AppColors.error
        : task.priority == 'medium'
            ? AppColors.warning
            : AppColors.success;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      decoration: isDoneToday ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: priorityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(task.priority,
                            style: TextStyle(fontSize: 10, color: priorityColor)),
                      ),
                      const SizedBox(width: 6),
                      Text(task.category,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onToggle,
              icon: Icon(
                isDoneToday ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isDoneToday ? AppColors.success : AppColors.textHint,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
