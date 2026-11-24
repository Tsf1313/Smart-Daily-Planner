import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'features/alerts/presentation/pages/alerts_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  final notifications = FlutterLocalNotificationsPlugin();
  await notifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  runApp(MaterialApp(home: ReminderDemo(notifications: notifications)));
}

enum _ReminderOption {
  off('Off', null),
  fifteen('15 min before', 15),
  thirty('30 min before', 30);

  const _ReminderOption(this.label, this.minutes);

  final String label;
  final int? minutes;
}

class ReminderDemo extends StatefulWidget {
  const ReminderDemo({super.key, required this.notifications});

  final FlutterLocalNotificationsPlugin notifications;

  @override
  State<ReminderDemo> createState() => _ReminderDemoState();
}

class _ReminderDemoState extends State<ReminderDemo> {
  static const _notificationId = 2;

  final _dueTime = tz.TZDateTime.now(
    tz.getLocation('Asia/Kuala_Lumpur'),
  ).add(const Duration(minutes: 31));

  _ReminderOption _option = _ReminderOption.off;
  bool _saving = false;
  DateTime? _savedReminderAt;
  bool _alertRead = false;
  String _message = 'Choose a reminder option, then tap Save Reminder.';

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  Future<void> _saveReminder() async {
    final minutes = _option.minutes;
    setState(() => _saving = true);

    try {
      DateTime? savedTime;
      String result;

      if (minutes == null) {
        await widget.notifications.cancel(id: _notificationId);
        result = 'Reminder is off.';
      } else {
        final android = widget.notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        final notificationsAllowed =
            await android?.requestNotificationsPermission();
        if (!mounted) return;
        if (notificationsAllowed != true) {
          setState(() => _message = 'Allow notifications in Android Settings.');
          return;
        }

        final exactAlarmsAllowed = await android?.requestExactAlarmsPermission();
        if (!mounted) return;
        if (exactAlarmsAllowed != true) {
          setState(() => _message = 'Allow Alarms & reminders, then try again.');
          return;
        }

        final reminderTime = _dueTime.subtract(Duration(minutes: minutes));
        if (!reminderTime.isAfter(DateTime.now())) {
          setState(() => _message = 'Test time passed. Restart the demo.');
          return;
        }

        await widget.notifications.zonedSchedule(
          id: _notificationId,
          title: 'SmartPlan: Submit report',
          body: 'Your sample deadline is in $minutes minutes.',
          scheduledDate: reminderTime,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'reminder_demo',
              'Reminder Demo',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );

        savedTime = reminderTime;
        result = 'Scheduled for ${_formatTime(reminderTime)} MYT.';
      }

      if (!mounted) return;
      setState(() {
        _savedReminderAt = savedTime;
        _alertRead = false;
        _message = result;
      });

      final pending = await widget.notifications.pendingNotificationRequests();
      final count = pending.where((item) => item.id == _notificationId).length;
      if (!mounted) return;
      setState(() {
        _message = '$result\nPending reminders for this task: $count';
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Reminder check failed: ${error.code}');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _openAlerts() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => AlertsPage(
          reminderAt: _savedReminderAt,
          isRead: _alertRead,
          onMarkRead: () {
            setState(() => _alertRead = true);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder Demo'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _openAlerts,
            child: const Text('Alerts'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Sample deadline: Submit report'),
          Text('Due at ${_formatTime(_dueTime)} MYT'),
          const SizedBox(height: 16),
          DropdownButton<_ReminderOption>(
            value: _option,
            onChanged: _saving
                ? null
                : (option) {
                    if (option != null) {
                      setState(() => _option = option);
                    }
                  },
            items: [
              for (final option in _ReminderOption.values)
                DropdownMenuItem(value: option, child: Text(option.label)),
            ],
          ),
          FilledButton(
            onPressed: _saving ? null : _saveReminder,
            child: const Text('Save Reminder'),
          ),
          const SizedBox(height: 16),
          Text(_message),
        ],
      ),
    );
  }
}