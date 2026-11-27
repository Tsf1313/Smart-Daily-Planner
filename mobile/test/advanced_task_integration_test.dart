import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smart_daily_planner/core/services/task_reminders.dart';
import 'package:smart_daily_planner/features/locations/data/models/selected_facility.dart';
import 'package:smart_daily_planner/features/locations/presentation/pages/location_picker_page.dart';
import 'package:smart_daily_planner/features/planner/data/models/task_model.dart'
    as model;
import 'package:smart_daily_planner/features/planner/data/repositories/entry_attachments_api.dart';
import 'package:smart_daily_planner/features/planner/data/repositories/planner_entries_api.dart';
import 'package:smart_daily_planner/features/planner/data/repositories/task_store.dart';
import 'package:smart_daily_planner/features/planner/presentation/pages/task_list_screen.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  EntryAttachmentsApi attachments(http.Client client) => EntryAttachmentsApi(
    baseUrl: Uri.parse('https://planner.example.test/api/v1/'),
    client: client,
    idToken: () async => 'test-token',
  );

  testWidgets('location search highlights a choice before returning it', (
    tester,
  ) async {
    SelectedFacility? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await Navigator.push<SelectedFacility>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LocationPickerPage(
                      facilities: [
                        SelectedFacility(id: 'library', name: 'Library'),
                        SelectedFacility(id: 'hall', name: 'Lecture Hall'),
                      ],
                    ),
                  ),
                );
              },
              child: const Text('Choose'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirm Location'),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), '  LIBRARY ');
    await tester.pumpAndSettle();
    expect(find.text('Lecture Hall'), findsNothing);
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await tester.tap(find.text('Confirm Location'));
    await tester.pumpAndSettle();
    expect(selected?.id, 'library');
  });

  test(
    'photo replacement uploads first and only deletes the old photo after save',
    () async {
      final directory = await Directory.systemTemp.createTemp();
      addTearDown(() => directory.delete(recursive: true));
      final photo = File('${directory.path}/sample.png');
      await photo.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10, 0]);

      final events = <String>[];
      final api = attachments(
        MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test-token');
          events.add('${request.method} ${request.url.path}');
          if (request.method == 'POST') {
            expect(
              request.headers['Content-Type'],
              contains('multipart/form-data'),
            );
            expect(latin1.decode(request.bodyBytes), contains('name="file"'));
            expect(latin1.decode(request.bodyBytes), contains('image/png'));
            return http.Response('{"data":{"id":"new-photo"}}', 201);
          }
          return http.Response('{"data":{"deleted":true}}', 200);
        }),
      );
      final changed = await api.savePhotoChange(
        previousPhotoId: 'old-photo',
        newPhoto: XFile(photo.path),
        persist: (id) async {
          expect(id, 'new-photo');
          events.add('Save entry');
          return 'task';
        },
      );
      expect(changed.value, 'task');
      expect(events, [
        'POST /api/v1/photos',
        'Save entry',
        'DELETE /api/v1/photos/old-photo',
      ]);

      events.clear();
      final failed = api.savePhotoChange<void>(
        previousPhotoId: 'old-photo',
        newPhoto: XFile(photo.path),
        persist: (_) async => throw StateError('Rejected by planner API'),
      );
      await expectLater(failed, throwsStateError);
      expect(events, [
        'POST /api/v1/photos',
        'DELETE /api/v1/photos/new-photo',
      ]);
    },
  );

  testWidgets(
    'real form loads API tasks and persists a 30-minute reminder with due time',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final events = <String>[];
      Map<String, dynamic>? saved;
      final api = PlannerEntriesApi(
        attachments(
          MockClient((request) async {
            expect(request.headers['Authorization'], 'Bearer test-token');
            events.add('${request.method} ${request.url.path}');
            if (request.method == 'POST') {
              final requestBody =
                  jsonDecode(request.body) as Map<String, dynamic>;
              expect(requestBody['reminderMinutes'], 30);
              expect(requestBody['dueAt'], isA<String>());
              expect(requestBody.containsKey('id'), false);
              saved = {'id': 'new-task', ...requestBody};
              return http.Response(jsonEncode({'data': saved}), 201);
            }
            return http.Response(
              jsonEncode({
                'data': {'items': [], 'total': 0},
              }),
              200,
            );
          }),
        ),
      );
      final scheduler = _RecordingScheduler();
      final store = TaskStore.authenticated(api, scheduler);
      addTearDown(store.dispose);
      await tester.runAsync(store.load);
      await tester.pumpWidget(MaterialApp(home: TaskListScreen(store: store)));
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Physics report',
      );
      final time = find.text('Select time');
      await tester.ensureVisible(time);
      await tester.tap(time);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Time'));
      await tester.pumpAndSettle();

      final reminder = find.byType(DropdownButton<int>);
      await tester.ensureVisible(reminder);
      await tester.tap(reminder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 min before').last);
      await tester.pumpAndSettle();

      final save = find.text('Save Deadline Task');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saved?['title'], 'Physics report');
      expect(store.tasks.single.reminderMinutes, 30);
      expect(scheduler.plans.last.single.minutes, 30);
      expect(events, contains('POST /api/v1/entries'));
      expect(find.text('Physics report'), findsOneWidget);
    },
  );

  test(
    'saving and editing replaces reminder; completing and deleting cancel it',
    () async {
      final methods = <String>[];
      final api = PlannerEntriesApi(
        attachments(
          MockClient((request) async {
            methods.add(request.method);
            final body = request.body.isEmpty
                ? <String, dynamic>{}
                : jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'data': {'id': 'task-1', 'kind': 'deadline', ...body},
              }),
              200,
            );
          }),
        ),
      );
      final scheduler = _RecordingScheduler();
      final store = TaskStore.authenticated(api, scheduler);
      addTearDown(store.dispose);
      final draft = model.Task(
        title: 'Report',
        category: 'Study',
        priority: 'medium',
        dueDate: DateTime(2099),
        dueAt: DateTime.utc(2099, 1, 1, 7),
        reminderMinutes: 30,
      );
      final saved = await store.persistTask(draft);
      await store.acceptSavedTask(saved);
      final edited = await store.persistTask(
        saved.copyWith(reminderMinutes: 15),
      );
      await store.acceptSavedTask(edited);
      await store.toggleComplete('task-1');
      await store.deleteTask('task-1');
      expect(methods, ['POST', 'PATCH', 'PUT', 'DELETE']);
      expect(scheduler.plans.map((plan) => plan.firstOrNull?.minutes), [
        30,
        15,
        null,
        null,
      ]);
    },
  );
}

class _RecordingScheduler extends TaskReminderScheduler {
  _RecordingScheduler()
    : super(FlutterLocalNotificationsPlugin(), ownerId: 'student-1');

  final plans = <List<TaskReminder>>[];

  @override
  Future<String?> replaceForEntry(
    String entryId,
    List<TaskReminder> reminders, {
    bool requestPermission = false,
  }) async {
    plans.add(reminders);
    return null;
  }
}
