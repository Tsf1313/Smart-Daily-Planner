import 'package:material_ui/material_ui.dart';

import '../../app/app_theme.dart';

class PriorityBadge extends StatelessWidget {
  final String priority;
  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      'high' => AppColors.error,
      'low' => AppColors.success,
      _ => AppColors.warning,
    };

    final icon = switch (priority) {
      'high' => Icons.arrow_upward,
      'low' => Icons.arrow_downward,
      _ => Icons.remove,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            priority[0].toUpperCase() + priority.substring(1),
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
