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
      title: 'Submit Assignment Report',
      description: 'Upload final PDF for CSS3344 Mobile App Development.',
      category: 'Assignment',
      priority: 'high',
      dueDate: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        14,
        0,
      ),
      isCompleted: false,
      reminderEnabled: true,
      locationName: 'UTS Library',
    ),
    Task(
      id: '2',
      title: 'Library Book Return',
      description: 'Return Flutter & Dart reference books at counter.',
      category: 'Personal',
      priority: 'medium',
      dueDate: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        11,
        0,
      ),
      isCompleted: false,
      reminderEnabled: true,
      locationName: 'UTS Library',
    ),
    Task(
      id: '3',
      title: 'Morning Lecture – CSC301',
      description: 'Software Engineering lecture at Chancellor Hall.',
      category: 'Study',
      priority: 'medium',
      dueDate: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        9,
        0,
      ),
      isCompleted: true,
      reminderEnabled: true,
      locationName: 'Chancellor Hall',
    ),
    Task(
      id: '4',
      title: 'Study for Midterm',
      description: 'Chapter 1–5 revision and past year questions.',
      category: 'Study',
      priority: 'low',
      dueDate: DateTime.now().add(const Duration(days: 2)),
      isCompleted: false,
      reminderEnabled: false,
    ),
    Task(
      id: '5',
      title: 'Overdue Lab Report',
      description: 'Submit lab sheet 4 to lecturer.',
      category: 'Assignment',
      priority: 'high',
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
      isCompleted: false,
      reminderEnabled: true,
    ),
  ];

  List<Task> get tasks => List.unmodifiable(_tasks);

  int get totalCount => _tasks.length;
  int get completedCount => _tasks.where((t) => t.isCompleted).length;
  int get pendingCount => _tasks.where((t) => !t.isCompleted).length;
  int get overdueCount => _tasks
      .where((t) => !t.isCompleted && t.dueDate.isBefore(DateTime.now()))
      .length;

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

  void toggleComplete(String id) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final current = _tasks[index];
      _tasks[index] = current.copyWith(isCompleted: !current.isCompleted);
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
