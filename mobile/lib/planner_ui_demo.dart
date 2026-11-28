import 'package:flutter_localizations/flutter_localizations.dart';
import 'app/app_theme.dart';
import 'features/planner/presentation/pages/task_list_screen.dart';
import 'features/calendar/presentation/pages/calendar_screen.dart';

void main() {
  runApp(const PlannerUiDemoApp());
}

class PlannerUiDemoApp extends StatelessWidget {
  const PlannerUiDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartPlan Planner UI Demo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Add localization delegates to provide MaterialLocalizations.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
      ],
      home: const _PlannerDemoShell(),
    );
  }
}

// Removed the previous build method that returned a MaterialApp without delegates.



class _PlannerDemoShell extends StatefulWidget {
  const _PlannerDemoShell();

  @override
  State<_PlannerDemoShell> createState() => _PlannerDemoShellState();
}

class _PlannerDemoShellState extends State<_PlannerDemoShell> {
  int _index = 0;

  final _pages = const [
    TaskListScreen(),
    CalendarScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.check_box_outlined),
            activeIcon: Icon(Icons.check_box),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }
}
