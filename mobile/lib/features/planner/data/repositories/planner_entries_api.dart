import 'package:timezone/timezone.dart' as tz;

import '../models/task_model.dart';
import 'entry_attachments_api.dart';

typedef RoutineOccurrence = ({
  String id,
  String entryId,
  String date,
  DateTime start,
  bool completed,
});

class PlannerEntriesApi {
  const PlannerEntriesApi(this.attachments);

  final EntryAttachmentsApi attachments;

  Future<List<Task>> list(DateTime from, DateTime to) async {
    final entries = <Task>[];
    for (var page = 1; ; page++) {
      final result = await attachments.requestJson(
        'GET',
        'entries',
        query: {..._range(from, to), 'page': '$page', 'pageSize': '100'},
      );
      final items = (result['items'] as List).cast<Map<String, dynamic>>();
      entries.addAll(items.map(_task));
      if (items.isEmpty || entries.length >= (result['total'] as int)) {
        return entries;
      }
    }
  }

  Future<List<RoutineOccurrence>> occurrences(
    DateTime from,
    DateTime to,
  ) async {
    final result = await attachments.requestJson(
      'GET',
      'routine-occurrences',
      query: _range(from, to),
    );
    return [
      for (final item in (result['items'] as List).cast<Map<String, dynamic>>())
        (
          id: item['id'] as String,
          entryId: item['entryId'] as String,
          date: item['date'] as String,
          start: DateTime.parse(item['startAt'] as String),
          completed: item['isCompleted'] == true,
        ),
    ];
  }

  Map<String, String> _range(DateTime from, DateTime to) => {
    'from': Task.dateKey(from),
    'to': Task.dateKey(to),
  };

  Future<Task> save(Task task) async {
    final id = task.id;
    final place = task.locationName;
    final result = await attachments.requestJson(
      id == null ? 'POST' : 'PATCH',
      id == null ? 'entries' : 'entries/${Uri.encodeComponent(id)}',
      body: {
        if (id == null) 'kind': task.type,
        'title': task.title,
        'description': task.description,
        'timeZone': 'Asia/Kuala_Lumpur',
        'reminderMinutes': task.reminderMinutes,
        'photoId': task.photoId,
        'location': place == null
            ? null
            : {
                'facilityId': task.facilityId,
                'name': place,
                'latitude': task.latitude,
                'longitude': task.longitude,
              },
        if (task.isDeadline)
          if (task.dueAt case final DateTime due)
            'dueAt': due.toUtc().toIso8601String()
          else
            'dueDate': Task.dateKey(task.dueDate),
        if (task.isRoutine) ...{
          'startDate': Task.dateKey(task.dueDate),
          'startTime': _clockText(task.startTime!),
          'endTime': _clockText(task.endTime!),
          'repeat': switch (task.repeatRule) {
            'weekdays' => 'weekly',
            'daily' => 'daily',
            _ => 'none',
          },
          'weekdays': task.weekdays,
          'repeatUntil': task.repeatRule == 'never' ? null : task.repeatUntil,
        },
      },
    );
    // Category and priority are UI fields and are absent from the current API.
    return _task(result)
        .copyWith(category: task.category, priority: task.priority);
  }

  Future<void> delete(String id) async {
    await attachments.requestJson(
      'DELETE',
      'entries/${Uri.encodeComponent(id)}',
    );
  }

  Future<void> complete(
    String id,
    bool completed, {
    required bool routine,
  }) async {
    final path = routine ? 'routine-occurrences' : 'entries';
    await attachments.requestJson(
      'PUT',
      '$path/${Uri.encodeComponent(id)}/completion',
      body: {'isCompleted': completed},
    );
  }

  Task _task(Map<String, dynamic> json) {
    final type = json['kind'] as String;
    final dueAt = json['dueDate'] != null
        ? null
        : DateTime.tryParse(json['dueAt'] as String? ?? '');
    final dayText = json['startDate'] as String? ?? json['dueDate'] as String?;
    final day = dayText == null
        ? tz.TZDateTime.from(dueAt!, tz.getLocation('Asia/Kuala_Lumpur'))
        : DateTime.parse(dayText);
    final location = json['location'] as Map<String, dynamic>?;
    return Task(
      id: json['id'] as String,
      type: type,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: 'Personal',
      priority: 'medium',
      dueDate: DateTime(day.year, day.month, day.day),
      dueAt: dueAt,
      startTime: _clock(json['startTime'] as String?),
      endTime: _clock(json['endTime'] as String?),
      repeatRule: switch (json['repeat']) {
        'weekly' => 'weekdays',
        'daily' => 'daily',
        _ => 'never',
      },
      weekdays: (json['weekdays'] as List? ?? const []).cast<int>(),
      repeatUntil: json['repeatUntil'] as String?,
      isCompleted: json['isCompleted'] == true,
      reminderEnabled: json['reminderMinutes'] != null,
      reminderMinutes: json['reminderMinutes'] as int?,
      facilityId: location?['facilityId'] as String?,
      locationName: location?['name'] as String?,
      latitude: (location?['latitude'] as num?)?.toDouble(),
      longitude: (location?['longitude'] as num?)?.toDouble(),
      photoId: json['photoId'] as String?,
      isSynced: true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }

  TimeOfDay? _clock(String? time) {
    if (time == null) return null;
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _clockText(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}
