import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/services/task_reminders.dart';
import '../models/task_model.dart';
import 'planner_entries_api.dart';
import 'entry_attachments_api.dart';

class TaskStore extends ChangeNotifier {
  TaskStore._() : api = null, campusSearchOrigin = null;
  TaskStore.authenticated(this.api, this.reminders, {this.campusSearchOrigin}) {
    _tasks.clear();
  }

  final PlannerEntriesApi? api;
  final ({double latitude, double longitude})? campusSearchOrigin;
  TaskReminderScheduler? reminders;
  bool _disposed = false;
  int _revision = 0;
  bool loading = false;
  String? loadError;
  final Set<String> _changedInPreview = {};
  List<RoutineOccurrence> _occurrences = [];
  DateTime? _viewDate;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static final TaskStore instance = TaskStore._();

  // User profile state
  String userName = 'Ahmad';
  String userEmail = 'ahmad@student.edu.my';
  String userPhone = '+60 12-345 6789';

  // App preferences state
  bool notificationsEnabled = true;
  int? defaultReminderMinutes = 15; // null = Off, 15, 30
  bool weekStartsMonday = true;
  bool offlineMode = false;

  // Shared tasks list across Dashboard, Task List, and Calendar
  final List<Task> _tasks = [
    Task(
      id: '1',
      type: 'deadline',
      title: 'Submit Assignment Report',
      description: 'Upload final PDF for CSS3344 Mobile App Development.',
      category: 'Assignment',
      priority: 'high',
      dueDate: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
      isCompleted: false,
      reminderEnabled: true,
      reminderMinutes: 30,
      locationName: 'UTS Library',
    ),
    Task(
      id: '2',
      type: 'deadline',
      title: 'Library Book Return',
      description: 'Return Flutter & Dart reference books at counter.',
      category: 'Personal',
      priority: 'medium',
      dueDate: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
      isCompleted: false,
      reminderEnabled: true,
      reminderMinutes: 15,
      locationName: 'UTS Library',
    ),
    Task(
      id: '3',
      type: 'routine',
      title: 'Morning Lecture – CSC301',
      description: 'Software Engineering lecture at Chancellor Hall.',
      category: 'Study',
      priority: 'medium',
      dueDate: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 11, minute: 0),
      repeatRule: 'weekdays',
      weekdays: const [1, 3, 5],
      completedDates: {Task.dateKey(DateTime.now())},
      reminderEnabled: true,
      reminderMinutes: 15,
      locationName: 'Chancellor Hall',
    ),
    Task(
      id: '4',
      type: 'deadline',
      title: 'Study for Midterm',
      description: 'Chapter 1–5 revision and past year questions.',
      category: 'Study',
      priority: 'low',
      dueDate: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ).add(const Duration(days: 2)),
      isCompleted: false,
      reminderEnabled: false,
    ),
    Task(
      id: '5',
      type: 'deadline',
      title: 'Overdue Lab Report',
      description: 'Submit lab sheet 4 to lecturer.',
      category: 'Assignment',
      priority: 'high',
      dueDate: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ).subtract(const Duration(days: 1)),
      isCompleted: false,
      reminderEnabled: true,
      reminderMinutes: 15,
    ),
  ];

  List<Task> get tasks => List.unmodifiable(_tasks);

  int get totalCount => _tasks.length;
  int get completedCount =>
      _tasks.where((t) => t.isCompletedOn(DateTime.now())).length;
  int get pendingCount =>
      _tasks.where((t) => !t.isCompletedOn(DateTime.now())).length;
  int get overdueCount => _tasks.where((t) {
    if (t.isCompletedOn(DateTime.now())) return false;
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final d = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
    return d.isBefore(today);
  }).length;

  Future<void> load({DateTime? around}) async {
    final remote = api;
    if (remote == null || loading || _disposed) return;
    _viewDate = around ?? _viewDate ?? DateTime.now();
    final view = _viewDate!;
    final revision = _revision;
    final from = DateTime(view.year, view.month, view.day - 13);
    final to = DateTime(view.year, view.month, view.day + 17);
    loading = true;
    notifyListeners();
    try {
      final entries = await remote.list(from, to);
      final viewOccurrences = await remote.occurrences(from, to);
      final today = tz.TZDateTime.now(tz.getLocation('Asia/Kuala_Lumpur'));
      final reminderEnd = DateTime(today.year, today.month, today.day + 7);
      final reminderRangeCovered =
          !DateTime(today.year, today.month, today.day).isBefore(from) &&
          !reminderEnd.isAfter(to);
      final reminderOccurrences = reminderRangeCovered
          ? viewOccurrences
          : await remote.occurrences(today, reminderEnd);
      if (_disposed || revision != _revision) return;
      _occurrences = reminderOccurrences;
      final completedByEntry = <String, Set<String>>{};
      for (final occurrence in viewOccurrences) {
        if (occurrence.completed) {
          (completedByEntry[occurrence.entryId] ??= {}).add(occurrence.date);
        }
      }
      final current = {for (final task in _tasks) task.id: task};
      _tasks
        ..clear()
        ..addAll(
          entries.map((task) {
            final old = current[task.id];
            final completed = completedByEntry[task.id] ?? {};
            return task.copyWith(
              completedDates: completed,
              isCompleted: task.isRoutine && !task.isRepeatingRoutine
                  ? completed.contains(Task.dateKey(task.dueDate))
                  : task.isCompleted,
              category: old?.category,
              priority: old?.priority,
            );
          }),
        );
      offlineMode = false;
      loadError = null;
      if (reminderRangeCovered) refreshReminders();
    } on EntryAttachmentException catch (error) {
      if (_disposed) return;
      offlineMode = true;
      loadError = error.message;
      if (error.status == 401 || error.status == 403) {
        _tasks.clear();
        _occurrences = [];
        try {
          await reminders?.cancelAllUserReminders();
        } catch (_) {
          loadError = 'Access denied. Device reminders could not be cleared.';
        }
      }
    } catch (_) {
      if (_disposed) return;
      offlineMode = true;
      loadError = 'Could not load tasks. Check your connection and retry.';
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<Task> persistTask(Task draft) async {
    if (offlineMode) throw StateError('Tasks are read only.');
    final remote = api;
    return remote == null ? draft : remote.save(draft);
  }

  Future<String?> acceptSavedTask(Task task) async {
    if (_disposed) return null;
    _revision++;
    final index = _tasks.indexWhere((current) => current.id == task.id);
    if (index == -1) {
      _tasks.insert(0, task);
    } else {
      _tasks[index] = task;
    }
    notifyListeners();
    if (api != null && task.isRoutine && reminders != null) {
      try {
        await _loadReminderOccurrences();
      } catch (_) {
        await reminders?.replaceForEntry(task.id!, []);
        return 'Task saved. Routine reminders will refresh after reconnecting.';
      }
    }
    return _syncReminders(task, requestPermission: true);
  }

  Future<void> _loadReminderOccurrences() async {
    final now = tz.TZDateTime.now(tz.getLocation('Asia/Kuala_Lumpur'));
    _occurrences = await api!.occurrences(
      now,
      DateTime(now.year, now.month, now.day + 7),
    );
  }

  Future<String?> deleteTask(String id) async {
    if (offlineMode) return 'Tasks are read only right now.';
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index == -1) return null;
    final task = _tasks[index];
    String? cleanupWarning;
    try {
      final remote = api;
      if (remote != null) {
        final result = await remote.attachments.savePhotoChange(
          previousPhotoId: task.photoId,
          removePhoto: true,
          persist: (_) => remote.delete(id),
        );
        cleanupWarning = result.warning;
      }
    } catch (_) {
      return 'Could not delete the task. Please try again.';
    }
    if (_disposed) return cleanupWarning;
    _revision++;
    _tasks.removeWhere((task) => task.id == id);
    _changedInPreview.remove(id);
    notifyListeners();
    return (await reminders?.replaceForEntry(id, [])) ?? cleanupWarning;
  }

  Future<String?> toggleComplete(String id, {DateTime? date}) async {
    if (offlineMode) return 'Tasks are read only right now.';
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index == -1) return null;
    final task = _tasks[index];
    final day = date ?? DateTime.now();
    try {
      final remote = api;
      if (remote != null) {
        if (task.isRoutine) {
          final from = DateTime(day.year, day.month, day.day);
          final to = DateTime(day.year, day.month, day.day + 1);
          final occurrences = await remote.occurrences(from, to);
          final occurrence = occurrences
              .where(
                (item) => item.entryId == id && item.date == Task.dateKey(day),
              )
              .firstOrNull;
          if (occurrence == null) {
            return 'There is no routine occurrence on that date.';
          }
          await remote.complete(
            occurrence.id,
            !occurrence.completed,
            routine: true,
          );
          _occurrences = [
            for (final item in _occurrences)
              if (item.id == occurrence.id)
                (
                  id: item.id,
                  entryId: item.entryId,
                  date: item.date,
                  start: item.start,
                  completed: !occurrence.completed,
                )
              else
                item,
          ];
        } else {
          await remote.complete(id, !task.isCompleted, routine: false);
        }
      }
    } catch (_) {
      return 'Could not update completion. Please try again.';
    }
    if (_disposed) return null;
    final currentIndex = _tasks.indexWhere((entry) => entry.id == id);
    if (currentIndex == -1) return null;
    final updated = task.toggleCompletedOn(day);
    _revision++;
    _tasks[currentIndex] = updated;
    notifyListeners();
    return _syncReminders(updated);
  }

  void refreshReminders() {
    for (final task in _tasks) {
      if (api != null || _changedInPreview.contains(task.id)) {
        unawaited(_syncReminders(task));
      }
    }
  }

  Future<String?> _syncReminders(
    Task task, {
    bool requestPermission = false,
  }) async {
    final id = task.id;
    final scheduler = reminders;
    if (id == null || scheduler == null || _disposed) {
      return requestPermission && task.reminderMinutes != null
          ? 'Task saved. Device reminders are unavailable.'
          : null;
    }
    _changedInPreview.add(id);
    final minutes = task.reminderMinutes;
    final schedule = <TaskReminder>[];
    if (minutes != null && !task.isCompleted && notificationsEnabled) {
      if (task.isDeadline && task.dueAt != null) {
        schedule.add(
          TaskReminder(
            entryId: id,
            occurrenceId: id,
            title: task.title,
            activityAt: task.dueAt!,
            minutes: minutes,
          ),
        );
      } else if (task.isRoutine) {
        for (final item in _reminderOccurrences(task)) {
          schedule.add(
            TaskReminder(
              entryId: id,
              occurrenceId: item.id,
              title: task.title,
              activityAt: item.start,
              minutes: minutes,
            ),
          );
        }
      }
    }
    return scheduler.replaceForEntry(
      id,
      schedule,
      requestPermission: requestPermission,
    );
  }

  Iterable<({String id, DateTime start})> _reminderOccurrences(
    Task task,
  ) sync* {
    final zone = tz.getLocation('Asia/Kuala_Lumpur');
    final now = tz.TZDateTime.now(zone);
    final today = tz.TZDateTime(zone, now.year, now.month, now.day);
    final horizon = tz.TZDateTime(zone, now.year, now.month, now.day + 7);
    if (api != null) {
      for (final occurrence in _occurrences) {
        if (occurrence.entryId == task.id &&
            !occurrence.completed &&
            !occurrence.start.isBefore(today) &&
            occurrence.start.isBefore(horizon)) {
          yield (id: occurrence.id, start: occurrence.start);
        }
      }
      return;
    }
    final time = task.startTime;
    if (time == null) return;
    for (var index = 0; index < 7; index++) {
      final day = tz.TZDateTime(
        zone,
        now.year,
        now.month,
        now.day + index,
        time.hour,
        time.minute,
      );
      final calendarDate = DateTime(day.year, day.month, day.day);
      if (task.occursOn(calendarDate) && !task.isCompletedOn(calendarDate)) {
        yield (id: Task.dateKey(day), start: day);
      }
    }
  }

  void updateProfile({
    required String name,
    required String email,
    required String phone,
  }) {
    userName = name;
    userEmail = email;
    userPhone = phone;
    notifyListeners();
  }

  void updatePreferences({
    bool? notificationsEnabled,
    int? defaultReminderMinutes,
    bool clearDefaultReminder = false,
    bool? weekStartsMonday,
    bool? offlineMode,
  }) {
    if (notificationsEnabled != null) {
      this.notificationsEnabled = notificationsEnabled;
    }
    if (clearDefaultReminder) {
      this.defaultReminderMinutes = null;
    } else if (defaultReminderMinutes != null) {
      this.defaultReminderMinutes = defaultReminderMinutes;
    }
    if (weekStartsMonday != null) {
      this.weekStartsMonday = weekStartsMonday;
    }
    if (offlineMode != null) {
      this.offlineMode = offlineMode;
    }
    notifyListeners();
  }
}
