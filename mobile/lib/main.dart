import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import 'app/app_theme.dart';
import 'core/network/planner_client.dart';
import 'core/services/task_reminders.dart';
import 'features/alerts/presentation/pages/task_notifications_page.dart';
import 'features/calendar/presentation/pages/calendar_screen.dart';
import 'features/planner/data/repositories/entry_attachments_api.dart';
import 'features/planner/data/repositories/planner_entries_api.dart';
import 'features/planner/data/repositories/task_store.dart';
import 'features/planner/presentation/pages/task_detail_screen.dart';
import 'features/planner/presentation/pages/task_list_screen.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'core/storage/deadline_cache.dart';
import 'features/auth/presentation/pages/sign_in_page.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const key = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const sender = String.fromEnvironment('FIREBASE_SENDER_ID');
  String? setupMessage;
  if ([project, key, appId, sender].any((v) => v.isEmpty)) {
    setupMessage =
        'Add the Firebase Android app settings to your launch configuration.';
  } else {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          projectId: project,
          apiKey: key,
          appId: appId,
          messagingSenderId: sender,
        ),
      );
    } on FirebaseException {
      setupMessage =
          'Could not initialize Firebase. Check the Android app settings.';
    }
  }
  runApp(PlannerApp(setupMessage: setupMessage));
}

class PlannerApp extends StatelessWidget {
  const PlannerApp({super.key, this.setupMessage});
  final String? setupMessage;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Smart Daily Planner',
    theme: AppTheme.lightTheme,
    home: setupMessage != null
        ? Scaffold(
            appBar: AppBar(title: const Text('Smart Daily Planner')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(setupMessage!),
            ),
          )
        : StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Scaffold(
                  body: Center(child: Text('Could not open your session.')),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final user = snapshot.data;
              return user == null
                  ? const SignInPage()
                  : StudentHome(key: ValueKey(user.uid), user: user);
            },
          ),
  );
}

class StudentHome extends StatefulWidget {
  const StudentHome({super.key, required this.user});
  final User user;

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  final transport = http.Client();
  late final cache = DeadlineCache(
    widget.user.uid,
    directory: getApplicationSupportDirectory,
  );
  late final api = PlannerClient(
    Uri.parse(
      const String.fromEnvironment(
        'PLANNER_API_URL',
        defaultValue: 'http://10.0.2.2:3000/api/v1/',
      ),
    ),
    transport,
    () => widget.user.getIdToken(),
  );
  late final attachments = EntryAttachmentsApi(
    baseUrl: api.baseUrl,
    client: transport,
    idToken: api.idToken,
  );
  late final store = TaskStore.authenticated(
    PlannerEntriesApi(attachments),
    null,
    campusSearchOrigin: _campusSearchOrigin(),
  );
  late final AppLifecycleListener _lifecycle;
  int page = 0;
  bool _signedOut = false;

  ({double latitude, double longitude})? _campusSearchOrigin() {
    final latitude = double.tryParse(
      const String.fromEnvironment('CAMPUS_LATITUDE'),
    );
    final longitude = double.tryParse(
      const String.fromEnvironment('CAMPUS_LONGITUDE'),
    );
    if (latitude == null || longitude == null) return null;
    return (latitude: latitude, longitude: longitude);
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (!_signedOut) unawaited(store.load());
      },
    );
    unawaited(_initializePlanner());
  }

  Future<void> _initializePlanner() async {
    String? launchPayload;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final notifications = FlutterLocalNotificationsPlugin();
      final scheduler = TaskReminderScheduler(
        notifications,
        ownerId: widget.user.uid,
      );
      try {
        await notifications.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          ),
          onDidReceiveNotificationResponse: (response) {
            final entryId = scheduler.entryFromPayload(response.payload);
            if (mounted && !_signedOut && entryId != null) _openTask(entryId);
          },
        );
        final launch = await notifications.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp == true) {
          launchPayload = launch?.notificationResponse?.payload;
        }
        if (!mounted || _signedOut) return;
        setState(() => store.reminders = scheduler);
      } catch (_) {
        // The form stays available if device notifications cannot initialize.
      }
    }
    if (!mounted || _signedOut) return;
    await store.load();
    final launchId = store.reminders?.entryFromPayload(launchPayload);
    if (mounted && !_signedOut && launchId != null) _openTask(launchId);
  }

  void _openTask(String id) {
    for (final task in store.tasks) {
      if (task.id == id) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TaskDetailScreen(task: task, store: store),
          ),
        );
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This task is outside the loaded planner dates.'),
      ),
    );
  }

  Future<void> _beforeSignOut() async {
    _signedOut = true;
    try {
      await cache.clear();
      await store.reminders?.closeSession();
    } catch (_) {
      _signedOut = false;
      rethrow;
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    store.dispose();
    transport.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: switch (page) {
      0 => AppBar(title: const Text('Dashboard')),
      4 => AppBar(title: const Text('Profile')),
      _ => null,
    },
    body: IndexedStack(
      index: page,
      children: [
        DashboardPage(
          api: api,
          cache: cache,
          store: store,
          displayName: widget.user.displayName,
        ),
        TaskListScreen(store: store),
        CalendarScreen(store: store),
        TaskNotificationsPage(scheduler: store.reminders, openTask: _openTask),
        ProfilePage(user: widget.user, beforeSignOut: _beforeSignOut),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: page,
      onDestinationSelected: (value) {
        setState(() => page = value);
        if (value == 1) unawaited(store.load(around: DateTime.now()));
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.check_box_outlined),
          label: 'Tasks',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          label: 'Calendar',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_none),
          label: 'Alerts',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    ),
  );
}
