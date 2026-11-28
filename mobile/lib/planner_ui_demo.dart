import 'package:material_ui/material_ui.dart';
import 'app/app_theme.dart';
import 'features/planner/presentation/demo_shell/login_screen.dart';

/// SmartPlan prototype demo (sample data only).
/// Run with: flutter run -t lib/planner_ui_demo.dart
void main() {
  runApp(const PlannerUiDemoApp());
}

class PlannerUiDemoApp extends StatelessWidget {
  const PlannerUiDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartPlan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
