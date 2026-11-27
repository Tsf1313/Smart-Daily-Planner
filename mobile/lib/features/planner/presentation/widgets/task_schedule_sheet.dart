import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/widgets/planner_primary_button.dart';

Future<DateTime?> pickTaskDate(BuildContext context, DateTime initial) {
  var selected = initial;
  return showModalBottomSheet<DateTime>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => _ScheduleSheet(
        title: 'Select Date',
        confirm: PlannerPrimaryButton(
          label: 'Confirm Date',
          onPressed: () => Navigator.pop(context, selected),
        ),
        children: [
          CalendarDatePicker(
            key: ValueKey(selected),
            initialDate: selected,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100, 12, 31),
            onDateChanged: (date) => setState(() => selected = date),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final (label, offset) in [
                ('Today', 0),
                ('Tomorrow', 1),
                ('Next Week', 7),
              ])
                ActionChip(
                  label: Text(label),
                  onPressed: () {
                    final today = DateTime.now();
                    setState(
                      () => selected = DateTime(
                        today.year,
                        today.month,
                        today.day + offset,
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<TimeOfDay?> pickTaskTime(BuildContext context, TimeOfDay initial) {
  var selected = initial;
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => _ScheduleSheet(
        title: 'Select Time',
        confirm: PlannerPrimaryButton(
          label: 'Confirm Time',
          onPressed: () => Navigator.pop(context, selected),
        ),
        children: [
          Container(
            height: 154,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: CupertinoDatePicker(
              key: ValueKey(initial),
              mode: CupertinoDatePickerMode.time,
              initialDateTime: DateTime(
                2000,
                1,
                1,
                initial.hour,
                initial.minute,
              ),
              onDateTimeChanged: (time) =>
                  selected = TimeOfDay.fromDateTime(time),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final hour in [8, 12, 15, 18])
                ActionChip(
                  label: Text(TimeOfDay(hour: hour, minute: 0).format(context)),
                  onPressed: () => setState(() {
                    selected = TimeOfDay(hour: hour, minute: 0);
                    initial = selected;
                  }),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ScheduleSheet extends StatelessWidget {
  const _ScheduleSheet({
    required this.title,
    required this.confirm,
    required this.children,
  });

  final String title;
  final Widget confirm;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            ...children,
            const SizedBox(height: 12),
            confirm,
          ],
        ),
      ),
    );
  }
}
