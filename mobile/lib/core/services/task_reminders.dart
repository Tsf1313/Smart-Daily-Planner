import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class TaskReminder {
  const TaskReminder({
    required this.entryId,
    required this.occurrenceId,
    required this.title,
    required this.activityAt,
    required this.minutes,
  });

  final String entryId;
  final String occurrenceId;
  final String title;
  final DateTime activityAt;
  final int minutes;

  DateTime get reminderAt => activityAt.subtract(Duration(minutes: minutes));
  bool get isDue => !reminderAt.isAfter(DateTime.now());
  String get key => jsonEncode([entryId, occurrenceId]);
}

class TaskReminderScheduler extends ChangeNotifier {
  TaskReminderScheduler(this._notifications, {required this.ownerId});

  final FlutterLocalNotificationsPlugin _notifications;
  final String ownerId;
  final _scheduled = <String, TaskReminder>{};
  final _read = <String>{};
  Future<void> _queue = Future.value();
  bool _closed = false;

  List<TaskReminder> get reminders =>
      _scheduled.values.toList()
        ..sort((a, b) => a.reminderAt.compareTo(b.reminderAt));

  bool isRead(TaskReminder item) => _read.contains(item.key);

  void markRead(TaskReminder item) {
    _read.add(item.key);
    notifyListeners();
  }

  void markAllRead() {
    _read.addAll(_scheduled.keys);
    notifyListeners();
  }

  String payloadFor(String entryId, String occurrenceId) =>
      jsonEncode(['smartplan', ownerId, entryId, occurrenceId]);

  List<dynamic>? _ownedPayload(String? payload) {
    if (payload == null) return null;
    try {
      final value = jsonDecode(payload);
      if (value is List &&
          value.length == 4 &&
          value[0] == 'smartplan' &&
          value[1] == ownerId) {
        return value;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  String? entryFromPayload(String? payload) =>
      _ownedPayload(payload)?[2] as String?;

  Future<String?> replaceForEntry(
    String entryId,
    List<TaskReminder> reminders, {
    bool requestPermission = false,
  }) {
    final operation = _queue.then((_) async {
      if (_closed) return null;
      try {
        return await _replace(entryId, reminders, requestPermission);
      } catch (_) {
        return 'Task saved, but its device reminders could not be updated.';
      }
    });
    _queue = operation.then<void>((_) {});
    return operation;
  }

  Future<String?> _replace(
    String entryId,
    List<TaskReminder> reminders,
    bool requestPermission,
  ) async {
    final previous = await _notifications.pendingNotificationRequests();
    final desired = {for (final reminder in reminders) reminder.key: reminder};
    final dueRecords = _scheduled.values.where((item) {
      final replacement = desired[item.key];
      return item.entryId == entryId &&
          item.isDue &&
          replacement?.reminderAt == item.reminderAt &&
          replacement?.title == item.title;
    }).toList();

    final unchanged = <String, TaskReminder>{};
    for (final pending in previous) {
      final payload = _ownedPayload(pending.payload);
      if (payload == null || payload[2] != entryId) continue;
      final key = jsonEncode([payload[2], payload[3]]);
      final item = _scheduled[key];
      final replacement = desired[key];
      if (item != null &&
          replacement != null &&
          item.reminderAt == replacement.reminderAt &&
          item.title == replacement.title) {
        unchanged[key] = replacement;
      } else {
        await _notifications.cancel(id: pending.id);
      }
    }
    _scheduled.removeWhere((_, item) => item.entryId == entryId);
    for (final item in dueRecords) {
      _scheduled[item.key] = item;
    }
    _scheduled.addAll(unchanged);
    _read.retainAll(_scheduled.keys.toSet());
    notifyListeners();

    final future = reminders
        .where((item) => !item.isDue && !unchanged.containsKey(item.key))
        .toList();
    if (future.isEmpty) {
      return requestPermission && reminders.isNotEmpty && unchanged.isEmpty
          ? 'Task saved. Its reminder time has already passed.'
          : null;
    }

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      return requestPermission
          ? 'Task saved. Device reminders require Android.'
          : null;
    }
    var allowed = await android.areNotificationsEnabled();
    if (allowed != true && requestPermission) {
      allowed = await android.requestNotificationsPermission();
    }
    if (allowed != true) {
      return requestPermission
          ? 'Task saved. Allow notifications to receive reminders.'
          : null;
    }
    var exact = await android.canScheduleExactNotifications();
    if (exact != true && requestPermission) {
      exact = await android.requestExactAlarmsPermission();
    }
    if (exact != true) {
      return requestPermission
          ? 'Task saved. Allow Alarms & reminders in Android settings.'
          : null;
    }

    final usedIds = {
      for (final pending in previous) pending.id,
      for (final active in await _notifications.getActiveNotifications())
        if (active.id case final int id) id,
    };
    for (final item in future) {
      if (item.isDue) continue;
      final payload = payloadFor(item.entryId, item.occurrenceId);
      var id = 37;
      for (final unit in payload.codeUnits) {
        id = (31 * id + unit) & 0x7fffffff;
      }
      while (!usedIds.add(id)) {
        id = (id + 1) & 0x7fffffff;
      }
      await _notifications.zonedSchedule(
        id: id,
        title: item.title,
        body: 'Starts or is due in ${item.minutes} minutes.',
        scheduledDate: tz.TZDateTime.from(
          item.reminderAt,
          tz.getLocation('Asia/Kuala_Lumpur'),
        ),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'smartplan_task_reminders',
            'SmartPlan task reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      _scheduled[item.key] = item;
      notifyListeners();
    }
    return null;
  }

  Future<void> closeSession() async {
    _closed = true;
    await cancelAllUserReminders();
  }

  Future<void> cancelAllUserReminders() async {
    await _queue;
    for (final pending in await _notifications.pendingNotificationRequests()) {
      if (entryFromPayload(pending.payload) != null) {
        await _notifications.cancel(id: pending.id);
      }
    }
    _scheduled.clear();
    _read.clear();
    notifyListeners();
  }
}
