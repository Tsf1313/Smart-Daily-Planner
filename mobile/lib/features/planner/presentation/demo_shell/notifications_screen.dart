import 'package:material_ui/material_ui.dart';
import '../../../../app/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<_NotifItem> _notifications = [
    _NotifItem(
      icon: Icons.alarm,
      color: AppColors.primary,
      title: 'Task Reminder',
      body: 'Submit Assignment Report is due in 1 hour!',
      time: '10 min ago',
      isRead: false,
      tag: 'Reminder',
    ),
    _NotifItem(
      icon: Icons.warning_amber,
      color: AppColors.error,
      title: 'Overdue Task',
      body: 'Library Book Return was due yesterday.',
      time: '1 hour ago',
      isRead: false,
      tag: 'Overdue',
    ),
    _NotifItem(
      icon: Icons.check_circle,
      color: AppColors.success,
      title: 'Task Completed',
      body: 'Great job! You completed "Study for Midterm".',
      time: '2 hours ago',
      isRead: true,
      tag: 'Complete',
    ),
    _NotifItem(
      icon: Icons.calendar_today,
      color: AppColors.secondary,
      title: 'Upcoming Deadline',
      body: 'Lab Report is due tomorrow at 11:59 PM.',
      time: 'Yesterday',
      isRead: true,
      tag: 'Deadline',
    ),
    _NotifItem(
      icon: Icons.alarm,
      color: AppColors.primary,
      title: 'Task Reminder',
      body: 'Group Meeting starts in 30 minutes.',
      time: 'Yesterday',
      isRead: true,
      tag: 'Reminder',
    ),
    _NotifItem(
      icon: Icons.info_outline,
      color: AppColors.warning,
      title: 'Weekly Summary',
      body: 'You completed 8 out of 12 tasks this week. Keep it up!',
      time: '3 days ago',
      isRead: true,
      tag: 'Info',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.surface,
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => setState(() {
                for (var n in _notifications) { n.isRead = true; }
              }),
              child: const Text('Mark all read', style: TextStyle(color: AppColors.primary, fontSize: 13)),
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? _buildEmpty()
          : Column(
              children: [
                if (unread > 0)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'You have $unread unread notification${unread > 1 ? 's' : ''}',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, i) => _NotificationCard(
                      item: _notifications[i],
                      onTap: () => setState(() => _notifications[i].isRead = true),
                      onDismiss: () => setState(() => _notifications.removeAt(i)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmpty() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.notifications_none, size: 64, color: AppColors.textHint),
        SizedBox(height: 16),
        Text('No notifications yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        SizedBox(height: 8),
        Text("You're all caught up!", style: TextStyle(color: AppColors.textSecondary)),
      ],
    ),
  );
}

class _NotifItem {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;
  final String tag;
  bool isRead;

  _NotifItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
    required this.tag,
    this.isRead = false,
  });
}

class _NotificationCard extends StatelessWidget {
  final _NotifItem item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({required this.item, required this.onTap, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.isRead ? AppColors.surface : AppColors.primaryLight.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isRead ? const Color(0xFFE5E7EB) : AppColors.primary.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(item.title,
                              style: TextStyle(
                                fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
                                fontSize: 14,
                              )),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(item.tag,
                              style: TextStyle(fontSize: 10, color: item.color, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(item.body,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 12, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(item.time, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                        if (!item.isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 7, height: 7,
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
