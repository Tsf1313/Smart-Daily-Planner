import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'app/app_theme.dart';
import 'core/services/task_reminders.dart';
import 'features/alerts/presentation/pages/task_notifications_page.dart';
import 'features/calendar/presentation/pages/calendar_screen.dart';
import 'features/planner/data/repositories/task_store.dart';
import 'features/planner/presentation/pages/task_detail_screen.dart';
import 'features/planner/presentation/pages/task_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  final navigatorKey = GlobalKey<NavigatorState>();
  final store = TaskStore.instance;
  String? launchEntryId;
  if (defaultTargetPlatform == TargetPlatform.android) {
    final plugin = FlutterLocalNotificationsPlugin();
    final scheduler = TaskReminderScheduler(plugin, ownerId: 'planner-preview');
    try {
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final entryId = scheduler.entryFromPayload(response.payload);
          if (entryId != null) {
            openPlannerTask(navigatorKey.currentState, entryId);
          }
        },
      );
      final launch = await plugin.getNotificationAppLaunchDetails();
      launchEntryId = scheduler.entryFromPayload(
        launch?.notificationResponse?.payload,
      );
      // The preview stores tasks in memory. Remove reminders from its previous run.
      await scheduler.cancelAllUserReminders();
      store.reminders = scheduler;
    } catch (_) {
      // The planner form remains available if device notifications cannot initialize.
    }
  }
  runApp(PlannerUiDemoApp(navigatorKey: navigatorKey));
  if (launchEntryId != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openPlannerTask(navigatorKey.currentState, launchEntryId!);
    });
  }
}

void openPlannerTask(NavigatorState? navigator, String entryId) {
  if (navigator == null) return;
  for (final task in TaskStore.instance.tasks) {
    if (task.id == entryId) {
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => TaskDetailScreen(task: task)),
      );
      return;
    }
  }
  ScaffoldMessenger.maybeOf(navigator.context)?.showSnackBar(
    const SnackBar(
      content: Text('This task is no longer available in the preview.'),
    ),
  );
}

class PlannerUiDemoApp extends StatelessWidget {
  const PlannerUiDemoApp({super.key, this.navigatorKey});

  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'SmartPlan Planner Integration Preview',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _PlannerPreviewShell(),
    );
  }
}

class _PlannerPreviewShell extends StatefulWidget {
  const _PlannerPreviewShell();

  @override
  State<_PlannerPreviewShell> createState() => _PlannerPreviewShellState();
}

class _PlannerPreviewShellState extends State<_PlannerPreviewShell> {
  int _index = 0;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: TaskStore.instance.refreshReminders,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const TaskListScreen(),
          const CalendarScreen(),
          TaskNotificationsPage(
            scheduler: TaskStore.instance.reminders,
            openTask: (id) => openPlannerTask(Navigator.of(context), id),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.check_box_outlined),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}
