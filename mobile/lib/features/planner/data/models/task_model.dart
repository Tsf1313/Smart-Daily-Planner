class TimeOfDay {
  final int hour;
  final int minute;
  const TimeOfDay({required this.hour, required this.minute});

  String format() {
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final period = hour < 12 ? 'AM' : 'PM';
    return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  String formatShort() {
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final period = hour < 12 ? 'AM' : 'PM';
    if (minute == 0) return '$h $period';
    return '$h:${minute.toString().padLeft(2, '0')} $period';
  }
}

class Task {
  final String? id;
  final String type; // 'routine' or 'deadline'
  final String title;
  final String? description;
  final String category;
  final String priority; // 'high', 'medium', 'low'
  final DateTime dueDate; // For deadline: due date only; for routine: start date
  final TimeOfDay? startTime; // Routine start time
  final TimeOfDay? endTime; // Routine end time
  final String? repeatRule; // 'never', 'daily', 'weekdays' (weekly)
  final List<int> weekdays; // Monday = 1 .. Sunday = 7
  final bool isCompleted; // For deadlines & non-repeating routines
  final Set<String> completedDates; // YYYY-MM-DD keys for repeating routine occurrences
  final bool reminderEnabled;
  final int? reminderMinutes; // null (Off), 15, or 30
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String? photoPath;
  final bool isSynced;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    this.id,
    this.type = 'deadline',
    required this.title,
    this.description,
    required this.category,
    required this.priority,
    required this.dueDate,
    this.startTime,
    this.endTime,
    this.repeatRule,
    this.weekdays = const [],
    this.isCompleted = false,
    this.completedDates = const {},
    this.reminderEnabled = false,
    this.reminderMinutes,
    this.locationName,
    this.latitude,
    this.longitude,
    this.photoPath,
    this.isSynced = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isRoutine => type == 'routine';
  bool get isDeadline => type == 'deadline';
  bool get isRepeatingRoutine =>
      isRoutine && (repeatRule == 'daily' || repeatRule == 'weekdays');

  static String dateKey(DateTime day) {
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '${day.year}-$m-$d';
  }

  /// Checks completion for a specific calendar date (per-occurrence for repeating routines).
  bool isCompletedOn(DateTime day) {
    if (isRepeatingRoutine) {
      return completedDates.contains(dateKey(day));
    }
    return isCompleted;
  }

  /// Toggles completion for a specific calendar date without affecting other occurrences.
  Task toggleCompletedOn(DateTime day) {
    if (isRepeatingRoutine) {
      final key = dateKey(day);
      final next = Set<String>.from(completedDates);
      if (next.contains(key)) {
        next.remove(key);
      } else {
        next.add(key);
      }
      return copyWith(completedDates: next);
    }
    return copyWith(isCompleted: !isCompleted);
  }

  Task copyWith({
    String? id,
    String? type,
    String? title,
    String? description,
    String? category,
    String? priority,
    DateTime? dueDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? repeatRule,
    List<int>? weekdays,
    bool? isCompleted,
    Set<String>? completedDates,
    bool? reminderEnabled,
    int? reminderMinutes,
    bool clearReminder = false,
    String? locationName,
    double? latitude,
    double? longitude,
    String? photoPath,
    bool? isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      repeatRule: repeatRule ?? this.repeatRule,
      weekdays: weekdays ?? this.weekdays,
      isCompleted: isCompleted ?? this.isCompleted,
      completedDates: completedDates ?? this.completedDates,
      reminderEnabled: clearReminder ? false : (reminderEnabled ?? this.reminderEnabled),
      reminderMinutes: clearReminder ? null : (reminderMinutes ?? this.reminderMinutes),
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      photoPath: photoPath ?? this.photoPath,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Returns true if this entry should appear on [day] in the calendar.
  bool occursOn(DateTime day) {
    final targetDay = DateTime(day.year, day.month, day.day);
    final baseDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (isDeadline) {
      return targetDay == baseDay;
    }

    if (targetDay.isBefore(baseDay)) return false;

    switch (repeatRule) {
      case 'daily':
        return true;
      case 'weekdays':
        return weekdays.contains(targetDay.weekday);
      case 'never':
      default:
        return targetDay == baseDay;
    }
  }
}
