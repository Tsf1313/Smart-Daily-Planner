import 'package:flutter/foundation.dart';
import '../models/task_model.dart';

class TaskStore extends ChangeNotifier {
  TaskStore._();
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
        final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        final d = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
        return d.isBefore(today);
      }).length;

  void addTask(Task task) {
    _tasks.insert(0, task);
    notifyListeners();
  }

  void updateTask(Task updated) {
    final index = _tasks.indexWhere((t) => t.id == updated.id);
    if (index != -1) {
      _tasks[index] = updated;
      notifyListeners();
    }
  }

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void toggleComplete(String id, {DateTime? date}) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tasks[index] = _tasks[index].toggleCompletedOn(date ?? DateTime.now());
      notifyListeners();
    }
  }

  void updateProfile({required String name, required String email, required String phone}) {
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
