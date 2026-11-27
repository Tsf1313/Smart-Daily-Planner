import 'package:flutter/material.dart';
import '../../../../app/app_theme.dart';
import '../../../planner/data/models/task_model.dart';
import '../../../planner/data/repositories/task_store.dart';
import '../../../planner/presentation/pages/add_task_screen.dart';
import '../../../planner/presentation/pages/task_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  String _categoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final tasks = _categoryFilter == 'All'
            ? store.tasks
            : store.tasks.where((t) => t.category == _categoryFilter).toList();
        final isWeekly = _tabController.index == 1;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Calendar'),
            backgroundColor: AppColors.surface,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: _showFilterSheet,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _categoryFilter == 'All'
                          ? AppColors.primaryLight.withOpacity(0.6)
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.filter_list,
                      size: 20,
                      color: _categoryFilter == 'All'
                          ? AppColors.textPrimary
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              tabs: const [
                Tab(text: 'Daily'),
                Tab(text: 'Weekly'),
              ],
            ),
          ),
          body: Column(
            children: [
              _buildWeekHeader(tasks, store.weekStartsMonday, isWeekly),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDayView(tasks),
                    _buildWeekGridView(tasks, store.weekStartsMonday),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: store.offlineMode ? Colors.grey : AppColors.primary,
            onPressed: () async {
              if (store.offlineMode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Offline mode: cannot add tasks.')),
                );
                return;
              }
              final newTask = await Navigator.push<Task>(
                context,
                MaterialPageRoute(
                  builder: (_) => AddTaskScreen(
                    task: Task(
                      title: '',
                      type: 'deadline',
                      category: 'Study',
                      priority: 'medium',
                      dueDate: _selectedDate,
                    ),
                  ),
                ),
              );
              if (newTask != null) {
                store.addTask(newTask);
              }
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  DateTime _startOfWeek(DateTime date, bool mondayStart) {
    if (mondayStart) {
      return date.subtract(Duration(days: date.weekday - 1));
    }
    return date.subtract(Duration(days: date.weekday % 7));
  }

  Widget _buildWeekHeader(List<Task> tasks, bool mondayStart, bool isWeekly) {
    final startOfWeek = _startOfWeek(_selectedDate, mondayStart);

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => setState(() {
                  _selectedDate = _selectedDate.subtract(const Duration(days: 7));
                }),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.chevron_left,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedDate = DateTime.now()),
                child: Text(
                  _monthYearLabel(_selectedDate),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              InkWell(
                onTap: () => setState(() {
                  _selectedDate = _selectedDate.add(const Duration(days: 7));
                }),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              if (isWeekly) const SizedBox(width: 32),
              Expanded(
                child: Row(
                  children: List.generate(7, (i) {
                    final day = startOfWeek.add(Duration(days: i));
                    final isSelected = _isSameDay(day, _selectedDate);
                    final isToday = _isSameDay(day, DateTime.now());
                    final hasTask = tasks.any((t) => t.occursOn(day));

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedDate = day),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isToday && !isSelected
                                ? Border.all(color: AppColors.primary, width: 1.5)
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _dayLabel(day.weekday).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white70
                                      : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : (isToday
                                          ? AppColors.primary
                                          : AppColors.textPrimary),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasTask
                                      ? (isSelected
                                          ? Colors.white.withOpacity(0.85)
                                          : AppColors.primary)
                                      : Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayView(List<Task> tasks) {
    final dayEntries = tasks.where((t) => t.occursOn(_selectedDate)).toList();
    final dayDeadlines = dayEntries.where((t) => t.isDeadline).toList();
    final dayRoutines = dayEntries.where((t) => t.isRoutine).toList();

    return Column(
      children: [
        if (dayDeadlines.isNotEmpty)
          Container(
            width: double.infinity,
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DEADLINES DUE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                ...dayDeadlines.map((task) => _buildDeadlineBanner(task)),
              ],
            ),
          ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 24,
            itemBuilder: (context, hour) {
              final hourRoutines = dayRoutines
                  .where((t) => (t.startTime?.hour ?? 9) == hour)
                  .toList();
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 50,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _formatHour(hour),
                        style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(height: 1, color: const Color(0xFFE5E7EB)),
                        ...hourRoutines.map((task) => _buildTimelineEvent(task)),
                        if (hourRoutines.isEmpty) const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeadlineBanner(Task task) {
    final color = _eventAccentColor(task);
    final isDone = task.isCompletedOn(_selectedDate);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TaskDetailScreen(task: task, occurrenceDate: _selectedDate),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _eventBgColor(task),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          children: [
            Icon(Icons.flag_outlined, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Text(
              'Due',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekGridView(List<Task> tasks, bool mondayStart) {
    final startOfWeek = _startOfWeek(_selectedDate, mondayStart);
    const int startHour = 7;
    const int endHour = 21;
    const int totalHours = endHour - startHour + 1;
    const double hourHeight = 62.0;
    const double gutterWidth = 48.0;

    final hasAnyDeadlinesThisWeek = List.generate(7, (i) {
      final day = startOfWeek.add(Duration(days: i));
      return tasks.any((t) => t.isDeadline && t.occursOn(day));
    }).any((has) => has);

    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          if (hasAnyDeadlinesThisWeek)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: gutterWidth,
                    child: Padding(
                      padding: EdgeInsets.only(top: 4, right: 8),
                      child: Text(
                        'DUE',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(7, (dayIndex) {
                        final day = startOfWeek.add(Duration(days: dayIndex));
                        final dayDeadlines = tasks
                            .where((t) => t.isDeadline && t.occursOn(day))
                            .toList();

                        return Expanded(
                          child: Column(
                            children: dayDeadlines.map((task) {
                              final color = _eventAccentColor(task);
                              final isDone = task.isCompletedOn(day);
                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TaskDetailScreen(
                                      task: task,
                                      occurrenceDate: day,
                                    ),
                                  ),
                                ),
                                child: Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 2, vertical: 2),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _eventBgColor(task),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border(
                                      left: BorderSide(color: color, width: 2.5),
                                    ),
                                  ),
                                  child: Text(
                                    task.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                      decoration: isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              child: SizedBox(
                height: totalHours * hourHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: gutterWidth,
                      child: Column(
                        children: List.generate(totalHours, (idx) {
                          final hour = startHour + idx;
                          return SizedBox(
                            height: hourHeight,
                            child: Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4, right: 8),
                                child: Text(
                                  _formatHour(hour),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textHint,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final colWidth = constraints.maxWidth / 7;

                          return Stack(
                            children: [
                              Column(
                                children: List.generate(totalHours, (_) {
                                  return Container(
                                    height: hourHeight,
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                            color: Color(0xFFF0F0F5), width: 1),
                                      ),
                                    ),
                                    child: Row(
                                      children: List.generate(7, (col) {
                                        return Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border(
                                                left: BorderSide(
                                                  color: const Color(0xFFF0F0F5),
                                                  width: col == 0 ? 1 : 0.8,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  );
                                }),
                              ),
                              ...List.generate(7, (dayIndex) {
                                final day = startOfWeek.add(Duration(days: dayIndex));
                                final dayRoutines = tasks
                                    .where((t) => t.isRoutine && t.occursOn(day))
                                    .toList();

                                return dayRoutines.map((task) {
                                  final startH = task.startTime?.hour ?? 9;
                                  final startM = task.startTime?.minute ?? 0;
                                  final endH = task.endTime?.hour ?? (startH + 1);
                                  final endM = task.endTime?.minute ?? startM;

                                  final clampedStart = startH.clamp(startHour, endHour);
                                  final top = (clampedStart - startHour) * hourHeight +
                                      (startM / 60.0) * hourHeight +
                                      2;
                                  final durationHours =
                                      ((endH * 60 + endM) - (startH * 60 + startM)) /
                                          60.0;
                                  final blockHeight =
                                      (durationHours.clamp(0.75, 6.0) * hourHeight) - 4;

                                  final accentColor = _eventAccentColor(task);
                                  final bgColor = _eventBgColor(task);
                                  final isDone = task.isCompletedOn(day);

                                  return Positioned(
                                    left: dayIndex * colWidth + 2,
                                    top: top,
                                    width: colWidth - 4,
                                    height: blockHeight,
                                    child: GestureDetector(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => TaskDetailScreen(
                                            task: task,
                                            occurrenceDate: day,
                                          ),
                                        ),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: bgColor,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border(
                                            left: BorderSide(
                                                color: accentColor, width: 3),
                                          ),
                                        ),
                                        child: Text(
                                          task.title,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: accentColor,
                                            height: 1.2,
                                            decoration: isDone
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  );
                                });
                              }).expand((widgets) => widgets),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineEvent(Task task) {
    final color = _eventAccentColor(task);
    final isDone = task.isCompletedOn(_selectedDate);
    final timeRange =
        '${task.startTime?.formatShort() ?? '9 AM'} – ${task.endTime?.formatShort() ?? '10 AM'}';
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TaskDetailScreen(task: task, occurrenceDate: _selectedDate),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _eventBgColor(task),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
            ),
            Text('$timeRange · ${task.category}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    const categories = ['All', 'Study', 'Assignment', 'Health', 'Personal'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Filter Calendar by Category',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...categories.map((cat) => ListTile(
                  title: Text(cat),
                  trailing: _categoryFilter == cat
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() => _categoryFilter = cat);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Color _eventAccentColor(Task task) {
    if (task.priority == 'high') return AppColors.error;
    if (task.category == 'Health' || task.priority == 'low') {
      return AppColors.secondary;
    }
    if (task.category == 'Study') return AppColors.primary;
    return AppColors.warning;
  }

  Color _eventBgColor(Task task) {
    if (task.priority == 'high') return const Color(0xFFFFE4E6);
    if (task.category == 'Health' || task.priority == 'low') {
      return const Color(0xFFE0FBF4);
    }
    if (task.category == 'Study') return AppColors.primaryLight;
    return const Color(0xFFFEF3C7);
  }

  String _dayLabel(int weekday) {
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday];
  }

  String _monthYearLabel(DateTime date) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month]} ${date.year}';
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }
}
