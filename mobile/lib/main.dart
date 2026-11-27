import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import 'core/network/planner_client.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'core/storage/deadline_cache.dart';
import 'features/auth/presentation/pages/sign_in_page.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  int page = 0;

  @override
  void dispose() {
    transport.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(page == 0 ? 'Dashboard' : 'Profile')),
    body: IndexedStack(
      index: page,
      children: [
        DashboardPage(api: api, cache: cache),
        ProfilePage(user: widget.user),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: page,
      onDestinationSelected: (value) => setState(() => page = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
    ),
  );
}
