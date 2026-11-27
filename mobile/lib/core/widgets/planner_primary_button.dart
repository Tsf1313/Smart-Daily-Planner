import 'package:material_ui/material_ui.dart';

import '../../app/app_theme.dart';

class PlannerPrimaryButton extends StatelessWidget {
  const PlannerPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: onPressed == null
            ? null
            : const LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
              ),
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: const Color(0xFFE2E5F1),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}
