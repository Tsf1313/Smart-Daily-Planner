// Task model
class Task {
  final String? id;
  final String title;
  final String? description;
  final String category;
  final String priority; // 'high', 'medium', 'low'
  final DateTime dueDate;
  final TimeOfDay? dueTime;
  final bool isCompleted;
  final bool reminderEnabled;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String? photoPath;
  final bool isSynced; // for offline support
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    this.id,
    required this.title,
    this.description,
    required this.category,
    required this.priority,
    required this.dueDate,
    this.dueTime,
    this.isCompleted = false,
    this.reminderEnabled = false,
    this.locationName,
    this.latitude,
    this.longitude,
    this.photoPath,
    this.isSynced = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? priority,
    DateTime? dueDate,
    TimeOfDay? dueTime,
    bool? isCompleted,
    bool? reminderEnabled,
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
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      isCompleted: isCompleted ?? this.isCompleted,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      photoPath: photoPath ?? this.photoPath,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'due_date': dueDate.toIso8601String(),
      'due_time_hour': dueTime?.hour,
      'due_time_minute': dueTime?.minute,
      'is_completed': isCompleted ? 1 : 0,
      'reminder_enabled': reminderEnabled ? 1 : 0,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'photo_path': photoPath,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id']?.toString(),
      title: map['title'] ?? '',
      description: map['description'],
      category: map['category'] ?? 'Personal',
      priority: map['priority'] ?? 'medium',
      dueDate: DateTime.parse(map['due_date']),
      dueTime: (map['due_time_hour'] != null && map['due_time_minute'] != null)
          ? TimeOfDay(hour: map['due_time_hour'], minute: map['due_time_minute'])
          : null,
      isCompleted: map['is_completed'] == 1,
      reminderEnabled: map['reminder_enabled'] == 1,
      locationName: map['location_name'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      photoPath: map['photo_path'],
      isSynced: map['is_synced'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id']?.toString(),
      title: json['title'] ?? '',
      description: json['description'],
      category: json['category'] ?? 'Personal',
      priority: json['priority'] ?? 'medium',
      dueDate: DateTime.parse(json['due_date']),
      isCompleted: json['is_completed'] ?? false,
      reminderEnabled: json['reminder_enabled'] ?? false,
      locationName: json['location_name'],
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      photoPath: json['photo_path'],
      isSynced: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'due_date': dueDate.toIso8601String(),
      'is_completed': isCompleted,
      'reminder_enabled': reminderEnabled,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

// TimeOfDay is from Flutter - import needed in actual file
class TimeOfDay {
  final int hour;
  final int minute;
  const TimeOfDay({required this.hour, required this.minute});
  String format() {
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final period = hour < 12 ? 'AM' : 'PM';
    return '${h.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
}
