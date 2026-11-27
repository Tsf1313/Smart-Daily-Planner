import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../../../app/app_theme.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/task_store.dart';
import '../../../../core/widgets/priority_badge.dart';
import 'add_task_screen.dart';
import '../widgets/task_photo_preview.dart';

class TaskDetailScreen extends StatelessWidget {
  final Task task;
  final DateTime? occurrenceDate;
  const TaskDetailScreen({
    super.key,
    required this.task,
    this.occurrenceDate,
    this.store,
  });
  final TaskStore? store;

  @override
  Widget build(BuildContext context) {
    final store = this.store ?? TaskStore.instance;
    final targetDate = occurrenceDate ?? DateTime.now();

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final currentTask = store.tasks.cast<Task?>().firstWhere(
          (t) => t?.id == task.id,
          orElse: () => task,
        )!;
        final isDone = currentTask.isCompletedOn(targetDate);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              currentTask.isRoutine ? 'Routine Detail' : 'Deadline Detail',
            ),
            backgroundColor: AppColors.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (!store.offlineMode) ...[
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.primary,
                  ),
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AddTaskScreen(task: currentTask, store: store),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                  onPressed: () => _confirmDelete(context, store, currentTask),
                ),
              ],
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              currentTask.isRoutine ? 'Routine' : 'Deadline',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PriorityBadge(priority: currentTask.priority),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDone
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isDone ? '✓ Completed' : 'Pending',
                              style: TextStyle(
                                color: isDone
                                    ? AppColors.success
                                    : AppColors.warning,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currentTask.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (currentTask.description != null &&
                          currentTask.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          currentTask.description!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _buildInfoGrid(currentTask),

                if (currentTask.isRoutine) ...[
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    Icons.access_time,
                    'Time',
                    _formatRoutineTime(currentTask),
                    AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    Icons.repeat,
                    'Repeat',
                    _formatRepeat(currentTask),
                    AppColors.primary,
                  ),
                ],

                const SizedBox(height: 12),
                _buildInfoTile(
                  Icons.notifications_none,
                  'Reminder',
                  currentTask.reminderMinutes != null
                      ? '${currentTask.reminderMinutes} minutes before'
                      : 'Off',
                  AppColors.secondary,
                ),

                if (currentTask.locationName != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoTile(
                    Icons.location_on_outlined,
                    'Location',
                    currentTask.locationName!,
                    AppColors.primary,
                  ),
                ],

                if (store.api != null && currentTask.photoId != null) ...[
                  const SizedBox(height: 12),
                  _buildSectionLabel('Attached Photo'),
                  TaskPhotoPreview(
                    key: ValueKey(currentTask.photoId),
                    photoId: currentTask.photoId!,
                    api: store.api!.attachments,
                  ),
                ] else if (currentTask.photoPath != null) ...[
                  const SizedBox(height: 12),
                  _buildSectionLabel('Attached Photo'),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(currentTask.photoPath!),
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        height: 100,
                        alignment: Alignment.center,
                        color: AppColors.primaryLight,
                        child: const Text('Photo unavailable offline'),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                if (!store.offlineMode)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final id = currentTask.id;
                      if (id == null) return;
                      final warning = await store.toggleComplete(
                        id,
                        date: targetDate,
                      );
                      if (!context.mounted) return;
                      if (warning != null) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(warning)));
                      }
                    },
                    icon: Icon(
                      isDone ? Icons.replay : Icons.check_circle_outline,
                    ),
                    label: Text(isDone ? 'Reopen Task' : 'Mark as Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDone
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatRoutineTime(Task t) {
    final start = t.startTime?.format() ?? '09:00 AM';
    final end = t.endTime?.format() ?? '10:00 AM';
    return '$start – $end';
  }

  String _formatRepeat(Task t) {
    switch (t.repeatRule) {
      case 'daily':
        return 'Daily';
      case 'weekdays':
        const names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        if (t.weekdays.isEmpty) return 'Weekly';
        return 'Weekly (${t.weekdays.map((d) => names[d]).join(', ')})';
      default:
        return 'Never';
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TaskStore store,
    Task task,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete Task?'),
        content: Text('Delete "${task.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    final id = task.id;
    if (!context.mounted || confirmed != true || id == null) return;
    final warning = await store.deleteTask(id);
    if (!context.mounted) return;
    if (warning != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(warning)));
    }
    if (!store.tasks.any((entry) => entry.id == id)) Navigator.pop(context);
  }

  Widget _buildInfoGrid(Task t) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            Icons.calendar_today_outlined,
            t.isRoutine ? 'Start Date' : 'Due Date',
            '${t.dueDate.day} ${_monthName(t.dueDate.month)} ${t.dueDate.year}',
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
            Icons.category_outlined,
            'Category',
            t.category,
            AppColors.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month];
  }
}
