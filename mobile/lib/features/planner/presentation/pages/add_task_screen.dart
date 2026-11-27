import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/app_theme.dart';
import '../../data/models/task_model.dart' as model;
import '../../../locations/data/models/selected_facility.dart';
import '../../../locations/presentation/pages/location_picker_page.dart';

class AddTaskScreen extends StatefulWidget {
  final model.Task? task; // null = add, non-null with id = edit
  const AddTaskScreen({super.key, this.task});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  // 'routine' or 'deadline'
  String _entryType = 'deadline';
  String _selectedCategory = 'Study';
  String _selectedPriority = 'medium';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);

  // Repeat options for Routine: 'never', 'daily', 'weekdays' (weekly)
  String _repeatRule = 'never';
  Set<int> _selectedWeekdays = {1}; // Monday=1 .. Sunday=7

  // Reminder options: null (Off), 15, or 30
  int? _reminderMinutes;

  String? _locationName;
  double? _latitude;
  double? _longitude;
  String? _photoPath;

  final List<String> _categories = ['Study', 'Assignment', 'Health', 'Personal'];

  bool get isEditing => widget.task != null && widget.task!.id != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(text: widget.task?.description ?? '');

    final existing = widget.task;
    if (existing != null) {
      _entryType = existing.type;
      _selectedCategory = _categories.contains(existing.category)
          ? existing.category
          : 'Study';
      _selectedPriority = existing.priority;
      _selectedDate = DateTime(
        existing.dueDate.year,
        existing.dueDate.month,
        existing.dueDate.day,
      );

      if (existing.startTime != null) {
        _startTime = TimeOfDay(
          hour: existing.startTime!.hour,
          minute: existing.startTime!.minute,
        );
      }
      if (existing.endTime != null) {
        _endTime = TimeOfDay(
          hour: existing.endTime!.hour,
          minute: existing.endTime!.minute,
        );
      }

      _repeatRule = existing.repeatRule ?? 'never';
      if (existing.weekdays.isNotEmpty) {
        _selectedWeekdays = existing.weekdays.toSet();
      } else {
        _selectedWeekdays = {_selectedDate.weekday};
      }

      _reminderMinutes =
          existing.reminderMinutes ?? (existing.reminderEnabled ? 15 : null);
      _locationName = existing.locationName;
      _latitude = existing.latitude;
      _longitude = existing.longitude;
      _photoPath = existing.photoPath;
    } else {
      _selectedWeekdays = {_selectedDate.weekday};
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Task' : 'Add New Task'),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEntryTypeSwitcher(),
              const SizedBox(height: 20),

              _buildSectionLabel(_entryType == 'routine' ? 'ROUTINE TITLE' : 'TASK TITLE'),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: _entryType == 'routine'
                      ? 'e.g. Monday study'
                      : 'e.g. Submit report',
                  prefixIcon: const Icon(Icons.task_alt_outlined, color: AppColors.textHint),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 18),

              _buildSectionLabel('DESCRIPTION'),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Add notes or details about this task...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),

              _buildSectionLabel('CATEGORY'),
              _buildCategorySelector(),
              const SizedBox(height: 18),

              _buildSectionLabel('PRIORITY LEVEL'),
              _buildPrioritySelector(),
              const SizedBox(height: 18),

              if (_entryType == 'routine') ...[
                _buildSectionLabel('TIME'),
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeBox(
                        label: 'Start Time',
                        time: _startTime,
                        onTap: () => _pickCustomTime(isStart: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTimeBox(
                        label: 'End Time',
                        time: _endTime,
                        onTap: () => _pickCustomTime(isStart: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildSectionLabel('REPEAT'),
                _buildRepeatSelector(),
                if (_repeatRule == 'weekdays') ...[
                  const SizedBox(height: 14),
                  _buildSectionLabel('REPEAT DAYS'),
                  _buildWeekdaySelector(),
                ],
                const SizedBox(height: 14),
                _buildSectionLabel(_repeatRule == 'never' ? 'DATE' : 'STARTS FROM'),
                _buildDatePicker(),
              ] else ...[
                _buildSectionLabel('DUE DATE'),
                _buildDatePicker(),
              ],
              const SizedBox(height: 18),

              _buildSectionLabel('REMINDER'),
              _buildReminderSelector(),
              const SizedBox(height: 18),

              _buildLocationPicker(),
              const SizedBox(height: 12),

              _buildPhotoPicker(),
              const SizedBox(height: 28),

              ElevatedButton.icon(
                onPressed: _saveTask,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  isEditing
                      ? 'Update Task'
                      : (_entryType == 'routine'
                          ? 'Save Routine Activity'
                          : 'Save Deadline Task'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntryTypeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: isEditing ? null : () => setState(() => _entryType = 'routine'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _entryType == 'routine' ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Routine Activity',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _entryType == 'routine' ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: isEditing ? null : () => setState(() => _entryType = 'deadline'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _entryType == 'deadline' ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Deadline Task',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _entryType == 'deadline' ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((cat) {
        final isSelected = _selectedCategory == cat;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.textHint.withOpacity(0.3),
              ),
            ),
            child: Text(
              cat,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPrioritySelector() {
    final priorities = [
      ('high', AppColors.error, Icons.arrow_upward),
      ('medium', AppColors.warning, Icons.remove),
      ('low', AppColors.success, Icons.arrow_downward),
    ];

    return Row(
      children: priorities.map((p) {
        final (value, color, icon) = p;
        final isSelected = _selectedPriority == value;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedPriority = value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.15) : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : AppColors.textHint.withOpacity(0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 14, color: isSelected ? color : AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(
                      value[0].toUpperCase() + value.substring(1),
                      style: TextStyle(
                        color: isSelected ? color : AppColors.textHint,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRepeatSelector() {
    final options = [('never', 'Never'), ('daily', 'Daily'), ('weekdays', 'Weekly')];
    return Row(
      children: options.map((opt) {
        final (val, label) = opt;
        final isSelected = _repeatRule == val;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _repeatRule = val),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryLight : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeekdaySelector() {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = i + 1;
        final isSelected = _selectedWeekdays.contains(day);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected && _selectedWeekdays.length > 1) {
                    _selectedWeekdays.remove(day);
                  } else {
                    _selectedWeekdays.add(day);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              '${_selectedDate.day} ${_monthName(_selectedDate.month)} ${_selectedDate.year}',
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBox({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(time.format(context),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderSelector() {
    final options = <(int?, String)>[(null, 'Off'), (15, '15 min'), (30, '30 min')];
    return Row(
      children: options.map((opt) {
        final (val, label) = opt;
        final isSelected = _reminderMinutes == val;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _reminderMinutes = val),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryLight : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLocationPicker() {
    return GestureDetector(
      onTap: _pickLocation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _locationName ?? 'Attach Location',
                style: TextStyle(
                  fontSize: 14,
                  color: _locationName != null ? AppColors.textPrimary : AppColors.textHint,
                ),
              ),
            ),
            if (_locationName != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() {
                  _locationName = null;
                  _latitude = null;
                  _longitude = null;
                }),
              )
            else
              Text(
                'Optional',
                style: TextStyle(fontSize: 12, color: AppColors.textHint.withOpacity(0.7)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: _photoPath != null
            ? Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(_photoPath!), width: 48, height: 48, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Photo attached', style: TextStyle(fontSize: 14))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _photoPath = null),
                  ),
                ],
              )
            : Row(
                children: [
                  const Icon(Icons.photo_camera_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Attach Photo / Note',
                        style: TextStyle(fontSize: 14, color: AppColors.textHint)),
                  ),
                  Text(
                    'Optional',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint.withOpacity(0.7)),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickCustomTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<SelectedFacility>(
      context,
      MaterialPageRoute(
        builder: (_) => const LocationPickerPage(),
      ),
    );
    if (result != null) {
      setState(() {
        _locationName = result.name;
        
      });
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final img = await picker.pickImage(source: ImageSource.camera);
                if (img != null) setState(() => _photoPath = img.path);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final img = await picker.pickImage(source: ImageSource.gallery);
                if (img != null) setState(() => _photoPath = img.path);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _saveTask() {
    if (_formKey.currentState!.validate()) {
      final dateOnly = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );

      final isRoutine = _entryType == 'routine';
      if (isRoutine) {
        final startMins = _startTime.hour * 60 + _startTime.minute;
        final endMins = _endTime.hour * 60 + _endTime.minute;
        if (endMins <= startMins) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('End time must be after start time.')),
          );
          return;
        }
      }

      final sortedWeekdays = _selectedWeekdays.toList()..sort();

      final task = model.Task(
        id: widget.task?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        type: _entryType,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        priority: _selectedPriority,
        dueDate: dateOnly,
        startTime: isRoutine
            ? model.TimeOfDay(hour: _startTime.hour, minute: _startTime.minute)
            : null,
        endTime: isRoutine
            ? model.TimeOfDay(hour: _endTime.hour, minute: _endTime.minute)
            : null,
        repeatRule: isRoutine ? _repeatRule : null,
        weekdays: isRoutine && _repeatRule == 'weekdays' ? sortedWeekdays : const [],
        isCompleted: widget.task?.isCompleted ?? false,
        completedDates: widget.task?.completedDates ?? const {},
        reminderEnabled: _reminderMinutes != null,
        reminderMinutes: _reminderMinutes,
        locationName: _locationName,
        latitude: _latitude,
        longitude: _longitude,
        photoPath: _photoPath,
        isSynced: false,
      );

      Navigator.pop(context, task);
    }
  }

  String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }
}
