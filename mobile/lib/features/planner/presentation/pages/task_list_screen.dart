import 'package:flutter/material.dart';
import '../../../../app/app_theme.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/task_store.dart';
import '../../../../core/widgets/priority_badge.dart';
import '../../../../core/widgets/empty_state.dart';
import 'add_task_screen.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  String _selectedFilter = 'all';
  String _selectedCategory = 'All';
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Task> _filterTasks(List<Task> all) {
    return all.where((t) {
      final matchesStatus = switch (_selectedFilter) {
        'pending' => !t.isCompleted,
        'done' => t.isCompleted,
        'overdue' => !t.isCompleted && t.dueDate.isBefore(DateTime.now()),
        _ => true,
      };
      final matchesCategory =
          _selectedCategory == 'All' || t.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesStatus && matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final filtered = _filterTasks(store.tasks);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search tasks...',
                      border: InputBorder.none,
                      filled: false,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  )
                : const Text('My Tasks'),
            backgroundColor: AppColors.surface,
            actions: [
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showCategoryFilterSheet,
              ),
            ],
          ),
          body: Column(
            children: [
              if (store.offlineMode) _buildOfflineBanner(),
              _buildFilterChips(),
              _buildStatsRow(store),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.check_circle_outline,
                        title: 'No tasks here!',
                        subtitle: 'Tap the + button to add a new task.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final task = filtered[index];
                          return _TaskCard(
                            task: task,
                            offlineMode: store.offlineMode,
                            onToggle: (_) {
                              if (store.offlineMode) {
                                _showOfflineToast();
                                return;
                              }
                              if (task.id != null) store.toggleComplete(task.id!);
                            },
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TaskDetailScreen(task: task),
                                ),
                              );
                            },
                            onDelete: () {
                              if (task.id != null) store.deleteTask(task.id!);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: store.offlineMode
                ? _showOfflineToast
                : () async {
                    final newTask = await Navigator.push<Task>(
                      context,
                      MaterialPageRoute(builder: (_) => const AddTaskScreen()),
                    );
                    if (newTask != null) {
                      store.addTask(newTask);
                    }
                  },
            backgroundColor: store.offlineMode ? Colors.grey : AppColors.primary,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.warning.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: AppColors.warning),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline Read-Only Mode: Viewing cached tasks. Editing disabled.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  void _showOfflineToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Offline mode: connect to internet to edit tasks.')),
    );
  }

  void _showCategoryFilterSheet() {
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
              child: Text('Filter by Category',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...categories.map((cat) => ListTile(
                  title: Text(cat),
                  trailing: _selectedCategory == cat
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['all', 'pending', 'done', 'overdue'];
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  filter[0].toUpperCase() + filter.substring(1),
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedFilter = filter),
                backgroundColor: AppColors.primaryLight,
                selectedColor: AppColors.primary,
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatsRow(TaskStore store) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _StatChip(label: 'Pending', count: store.pendingCount, color: AppColors.warning),
          const SizedBox(width: 8),
          _StatChip(label: 'Done', count: store.completedCount, color: AppColors.success),
          const SizedBox(width: 8),
          _StatChip(label: 'Overdue', count: store.overdueCount, color: AppColors.error),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('$count $label',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Task task;
  final bool offlineMode;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    required this.offlineMode,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(task.id ?? task.title),
      direction: offlineMode ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => onToggle(!task.isCompleted),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.isCompleted ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: task.isCompleted ? AppColors.primary : AppColors.textHint,
                      width: 2,
                    ),
                  ),
                  child: task.isCompleted
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: task.isCompleted ? AppColors.textHint : AppColors.textPrimary,
                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        PriorityBadge(priority: task.priority),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(task.category,
                              style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.access_time, size: 12, color: AppColors.textHint),
                        const SizedBox(width: 2),
                        Text(
                          _formatDate(task.dueDate),
                          style: TextStyle(
                            fontSize: 11,
                            color: _isOverdue(task) ? AppColors.error : AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }

  bool _isOverdue(Task task) =>
      !task.isCompleted && task.dueDate.isBefore(DateTime.now());

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = DateTime(date.year, date.month, date.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return '${date.day}/${date.month}';
  }
}
