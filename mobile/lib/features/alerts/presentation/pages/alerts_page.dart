import 'dart:async';

import 'package:material_ui/material_ui.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({
    super.key,
    required this.reminderAt,
    required this.isRead,
    required this.onMarkRead,
  });

  final DateTime? reminderAt;
  final bool isRead;
  final VoidCallback onMarkRead;

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  Timer? _timer;
  late bool _isRead;

  @override
  void initState() {
    super.initState();
    _isRead = widget.isRead;

    final reminderAt = widget.reminderAt;
    if (reminderAt == null) return;

    final remaining = reminderAt.difference(DateTime.now());
    if (remaining > Duration.zero) {
      _timer = Timer(remaining, () {
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reminderAt = widget.reminderAt;

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: reminderAt == null
          ? const Center(child: Text('No reminders'))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text('Submit report'),
                Text(
                  'Reminder time: '
                  '${TimeOfDay.fromDateTime(reminderAt).format(context)} MYT',
                ),
                Text(
                  reminderAt.isAfter(DateTime.now()) ? 'Scheduled' : 'Due',
                ),
                Text(_isRead ? 'Read' : 'Unread'),
                if (!_isRead)
                  TextButton(
                    onPressed: () {
                      setState(() => _isRead = true);
                      widget.onMarkRead();
                    },
                    child: const Text('Mark as read'),
                  ),
              ],
            ),
    );
  }
}