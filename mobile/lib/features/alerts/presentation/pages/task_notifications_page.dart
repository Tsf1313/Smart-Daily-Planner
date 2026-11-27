import 'package:material_ui/material_ui.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/services/task_reminders.dart';

class TaskNotificationsPage extends StatelessWidget {
  const TaskNotificationsPage({
    super.key,
    required this.scheduler,
    required this.openTask,
  });

  final TaskReminderScheduler? scheduler;
  final ValueChanged<String> openTask;

  @override
  Widget build(BuildContext context) {
    final reminders = scheduler;
    if (reminders == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Device reminders are unavailable.')),
      );
    }

    return ListenableBuilder(
      listenable: reminders,
      builder: (context, _) {
        final items = reminders.reminders;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (items.any((item) => !reminders.isRead(item)))
                TextButton(
                  onPressed: reminders.markAllRead,
                  child: const Text('Mark all read'),
                ),
            ],
          ),
          body: items.isEmpty
              ? const Center(child: Text('No task reminders yet.'))
              : StreamBuilder<int>(
                  stream: Stream.periodic(
                    const Duration(seconds: 30),
                    (n) => n,
                  ),
                  builder: (context, _) => ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final read = reminders.isRead(item);
                      final time = TimeOfDay.fromDateTime(
                        item.reminderAt.toLocal(),
                      ).format(context);
                      return Card(
                        margin: EdgeInsets.zero,
                        color: AppColors.surface,
                        elevation: 0,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(
                              read
                                  ? Icons.notifications_none
                                  : Icons.notifications_active_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${item.isDue ? 'Due' : 'Scheduled'} · $time\n'
                            '${item.minutes} min before the task',
                          ),
                          trailing: read
                              ? null
                              : const Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: AppColors.primary,
                                ),
                          onTap: () {
                            reminders.markRead(item);
                            openTask(item.entryId);
                          },
                        ),
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}
