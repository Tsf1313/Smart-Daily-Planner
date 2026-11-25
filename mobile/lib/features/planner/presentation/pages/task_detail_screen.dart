import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../app/app_theme.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/task_store.dart';
import '../../../../core/widgets/priority_badge.dart';
import 'add_task_screen.dart';

class TaskDetailScreen extends StatelessWidget {
  final Task task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final currentTask = store.tasks.cast<Task?>().firstWhere(
              (t) => t?.id == task.id,
              orElse: () => task,
            )!;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Task Detail'),
            backgroundColor: AppColors.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (!store.offlineMode) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                  onPressed: () async {
                    final updated = await Navigator.push<Task>(
                      context,
                      MaterialPageRoute(builder: (_) => AddTaskScreen(task: currentTask)),
                    );
                    if (updated != null) {
                      store.updateTask(updated);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
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
                // Header card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.08),
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
                          PriorityBadge(priority: currentTask.priority),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: currentTask.isCompleted
                                  ? AppColors.success.withOpacity(0.1)
                                  : AppColors.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              currentTask.isCompleted ? '✓ Completed' : 'Pending',
                              style: TextStyle(
                                color: currentTask.isCompleted
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
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

                // Details grid
                _buildInfoGrid(currentTask),
                const SizedBox(height: 16),

                // Location
                if (currentTask.locationName != null)
                  _buildInfoTile(
                    Icons.location_on_outlined,
                    'Location',
                    currentTask.locationName!,
                    AppColors.primary,
                  ),

                // Photo
                if (currentTask.photoPath != null) ...[
                  const SizedBox(height: 12),
                  _buildSectionLabel('Attached Photo'),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(currentTask.photoPath!),
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 100,
                        alignment: Alignment.center,
                        color: AppColors.primaryLight,
                        child: const Text('Photo unavailable offline'),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                // Complete / Reopen button
                if (!store.offlineMode)
                  ElevatedButton.icon(
                    onPressed: () {
                      if (currentTask.id != null) {
                        store.toggleComplete(currentTask.id!);
                      }
                      Navigator.pop(context);
                    },
                    icon: Icon(
                      currentTask.isCompleted
                          ? Icons.replay
                          : Icons.check_circle_outline,
                    ),
                    label: Text(
                      currentTask.isCompleted ? 'Reopen Task' : 'Mark as Complete',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentTask.isCompleted
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

  void _confirmDelete(BuildContext context, TaskStore store, Task currentTask) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (currentTask.id != null) {
                store.deleteTask(currentTask.id!);
              }
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // exit detail screen
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(Task t) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            Icons.calendar_today_outlined,
            'Due Date',
            '${t.dueDate.day}/${t.dueDate.month}/${t.dueDate.year}',
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

  Widget _buildInfoCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, Color color) {
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
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
}
