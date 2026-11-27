import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:image_picker/image_picker.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/services/task_photo_picker.dart';
import '../../../../core/widgets/planner_primary_button.dart';
import '../../../locations/data/repositories/campus_facilities.dart';
import '../../data/repositories/entry_attachments_api.dart';
import '../../data/repositories/task_store.dart';
import '../widgets/task_photo_preview.dart';
import '../widgets/task_schedule_sheet.dart';
import '../../data/models/task_model.dart' as model;
import '../../../locations/data/models/selected_facility.dart';
import '../../../locations/presentation/pages/location_picker_page.dart';

class AddTaskScreen extends StatefulWidget {
  final model.Task? task; // null = add, non-null with id = edit
  const AddTaskScreen({super.key, this.task, this.store});

  final TaskStore? store;

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

  String? _facilityId;
  String? _locationName;
  double? _latitude;
  double? _longitude;
  String? _photoPath;
  TimeOfDay? _dueTime;
  bool _pickingPhoto = false;
  bool _pickingLocation = false;
  bool _saving = false;
  bool _removeRemotePhoto = false;
  TaskStore get _store => widget.store ?? TaskStore.instance;

  final List<String> _categories = [
    'Study',
    'Assignment',
    'Health',
    'Personal',
  ];

  bool get isEditing => widget.task != null && widget.task!.id != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.task?.description ?? '',
    );

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
      final dueAt = existing.dueAt;
      if (dueAt != null) {
        _dueTime = TimeOfDay.fromDateTime(
          tz.TZDateTime.from(dueAt, tz.getLocation('Asia/Kuala_Lumpur')),
        );
      }
      _facilityId = existing.facilityId;
      _locationName = existing.locationName;
      _latitude = existing.latitude;
      _longitude = existing.longitude;
      _photoPath = _store.api == null ? existing.photoPath : null;
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
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: PlannerPrimaryButton(
            onPressed: _pickingPhoto || _pickingLocation || _saving
                ? null
                : _saveTask,
            label: _saving
                ? 'Saving…'
                : isEditing
                ? 'Update Task'
                : (_entryType == 'routine'
                      ? 'Save Routine Activity'
                      : 'Save Deadline Task'),
          ),
        ),
      ),
      body: PopScope(
        canPop: !_saving,
        child: AbsorbPointer(
          absorbing: _saving,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEntryTypeSwitcher(),
                  const SizedBox(height: 20),

                  _buildSectionLabel(
                    _entryType == 'routine' ? 'ROUTINE TITLE' : 'TASK TITLE',
                  ),
                  TextFormField(
                    controller: _titleController,
                    maxLength: 100,
                    decoration: InputDecoration(
                      hintText: _entryType == 'routine'
                          ? 'e.g. Monday study'
                          : 'e.g. Submit report',
                      prefixIcon: const Icon(
                        Icons.task_alt_outlined,
                        color: AppColors.textHint,
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                  ),
                  const SizedBox(height: 18),

                  _buildSectionLabel('DESCRIPTION'),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    maxLength: 2000,
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
                    _buildSectionLabel(
                      _repeatRule == 'never' ? 'DATE' : 'STARTS FROM',
                    ),
                    _buildDatePicker(),
                  ] else ...[
                    _buildSectionLabel('DUE DATE & TIME'),
                    Row(
                      children: [
                        Expanded(child: _buildDatePicker()),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTimeBox(
                            label: 'Due Time',
                            time: _dueTime,
                            onTap: _pickDueTime,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),

                  _buildLocationPicker(),
                  const SizedBox(height: 12),
                  _buildReminderSelector(),
                  const SizedBox(height: 12),
                  _buildPhotoPicker(),
                  const SizedBox(height: 28),

                  const SizedBox(height: 16),
                ],
              ),
            ),
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
              onTap: isEditing
                  ? null
                  : () => setState(() => _entryType = 'routine'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _entryType == 'routine'
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Routine Activity',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _entryType == 'routine'
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: isEditing
                  ? null
                  : () => setState(() => _entryType = 'deadline'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _entryType == 'deadline'
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Deadline Task',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _entryType == 'deadline'
                        ? Colors.white
                        : AppColors.textSecondary,
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
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textHint.withValues(alpha: 0.3),
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
                  color: isSelected
                      ? color.withValues(alpha: 0.15)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? color
                        : AppColors.textHint.withValues(alpha: 0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: isSelected ? color : AppColors.textHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      value[0].toUpperCase() + value.substring(1),
                      style: TextStyle(
                        color: isSelected ? color : AppColors.textHint,
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.normal,
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
    final options = [
      ('never', 'Never'),
      ('daily', 'Daily'),
      ('weekdays', 'Weekly'),
    ];
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
                  color: isSelected
                      ? AppColors.primaryLight
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0xFFE5E7EB),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
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
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0xFFE5E7EB),
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
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${_selectedDate.day} ${_monthName(_selectedDate.month)} ${_selectedDate.year}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBox({
    required String label,
    required TimeOfDay? time,
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
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    time?.format(context) ?? 'Select time',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<int>(
              isExpanded: true,
              value: _reminderMinutes ?? 0,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Reminder off')),
                DropdownMenuItem(value: 15, child: Text('15 min before')),
                DropdownMenuItem(value: 30, child: Text('30 min before')),
              ],
              onChanged: (value) {
                setState(() => _reminderMinutes = value == 0 ? null : value);
              },
            ),
          ),
          Switch(
            value: _reminderMinutes != null,
            onChanged: (enabled) =>
                setState(() => _reminderMinutes = enabled ? 15 : null),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPicker() {
    return GestureDetector(
      onTap: _pickingLocation ? null : _pickLocation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _pickingLocation
                    ? 'Loading locations…'
                    : _locationName ?? 'Attach Location',
                style: TextStyle(
                  fontSize: 14,
                  color: _locationName != null
                      ? AppColors.textPrimary
                      : AppColors.textHint,
                ),
              ),
            ),
            if (_locationName != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() {
                  _facilityId = null;
                  _locationName = null;
                  _latitude = null;
                  _longitude = null;
                }),
              )
            else
              Text(
                'Optional',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _pickingPhoto ? null : _pickPhoto,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child:
            _photoPath != null ||
                (_store.api != null &&
                    widget.task?.photoId != null &&
                    !_removeRemotePhoto)
            ? Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _photoPath == null
                        ? TaskPhotoPreview(
                            key: ValueKey(widget.task!.photoId),
                            photoId: widget.task!.photoId!,
                            api: _store.api!.attachments,
                            width: 48,
                            height: 48,
                          )
                        : Image.file(
                            File(_photoPath!),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.broken_image_outlined),
                          ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Photo attached',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Remove photo',
                    onPressed: () => setState(() {
                      _photoPath = null;
                      _removeRemotePhoto = true;
                    }),
                  ),
                ],
              )
            : Row(
                children: [
                  const Icon(
                    Icons.photo_camera_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Attach Photo',
                      style: TextStyle(fontSize: 14, color: AppColors.textHint),
                    ),
                  ),
                  Text(
                    'Optional',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await pickTaskDate(context, _selectedDate);
    if (mounted && picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickCustomTime({required bool isStart}) async {
    final picked = await pickTaskTime(context, isStart ? _startTime : _endTime);
    if (!mounted || picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _pickDueTime() async {
    final picked = await pickTaskTime(
      context,
      _dueTime ?? const TimeOfDay(hour: 15, minute: 0),
    );
    if (mounted && picked != null) setState(() => _dueTime = picked);
  }

  Future<void> _pickLocation() async {
    final api = _store.api?.attachments;
    final origin = _store.campusSearchOrigin;
    var facilities = sampleCampusFacilities;
    final distances = <String, double>{};
    if (api != null) {
      if (origin == null) {
        _showMessage('Campus location search is unavailable.');
        return;
      }
      setState(() => _pickingLocation = true);
      try {
        final nearby = await api.nearby(
          latitude: origin.latitude,
          longitude: origin.longitude,
        );
        facilities = [for (final result in nearby) result.facility];
        for (final result in nearby) {
          distances[result.facility.id] = result.distanceMeters;
        }
      } on EntryAttachmentException catch (error) {
        if (mounted) _showMessage(error.message);
        return;
      } catch (_) {
        if (mounted) _showMessage('Could not load locations. Try again.');
        return;
      } finally {
        if (mounted) setState(() => _pickingLocation = false);
      }
    }

    if (!mounted) return;
    final result = await Navigator.push<SelectedFacility>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          facilities: facilities,
          distancesInMeters: distances,
          initialFacilityId: _facilityId,
          sampleData: api == null,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _facilityId = result.id;
      _locationName = result.name;
      _latitude = result.latitude;
      _longitude = result.longitude;
    });
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppColors.primary,
              ),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (!mounted || source == null || _pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final photo = await ImagePicker().pickImage(source: source);
      if (photo == null) return;
      await taskPhotoMimeType(photo);
      if (mounted) setState(() => _photoPath = photo.path);
    } on TaskPhotoException catch (error) {
      if (mounted) _showMessage(error.message);
    } on PlatformException {
      if (mounted) {
        _showMessage(
          'Camera or gallery unavailable. Check permissions and try again.',
        );
      }
    } on FileSystemException {
      if (mounted) {
        _showMessage('Could not read this photo. Choose another one.');
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveTask() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final isRoutine = _entryType == 'routine';
    final date = _selectedDate;
    final dueTime = _dueTime;
    if (isRoutine &&
        (_startTime.hour * 60 + _startTime.minute >=
            _endTime.hour * 60 + _endTime.minute)) {
      _showMessage('End time must be after start time.');
      return;
    }
    if (isRoutine && _repeatRule == 'weekdays' && _selectedWeekdays.isEmpty) {
      _showMessage('Select at least one weekday.');
      return;
    }
    if (!isRoutine && _reminderMinutes != null && dueTime == null) {
      _showMessage('Choose a due time to turn on the reminder.');
      return;
    }
    final zone = tz.getLocation('Asia/Kuala_Lumpur');
    final dueAt = isRoutine || dueTime == null
        ? null
        : tz.TZDateTime(
            zone,
            date.year,
            date.month,
            date.day,
            dueTime.hour,
            dueTime.minute,
          );
    final api = _store.api?.attachments;
    model.Task buildDraft(String? photoId) => model.Task(
      id:
          widget.task?.id ??
          (api == null
              ? DateTime.now().microsecondsSinceEpoch.toString()
              : null),
      type: _entryType,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _selectedCategory,
      priority: _selectedPriority,
      dueDate: DateTime(date.year, date.month, date.day),
      dueAt: dueAt,
      startTime: isRoutine
          ? model.TimeOfDay(hour: _startTime.hour, minute: _startTime.minute)
          : null,
      endTime: isRoutine
          ? model.TimeOfDay(hour: _endTime.hour, minute: _endTime.minute)
          : null,
      repeatRule: isRoutine ? _repeatRule : null,
      repeatUntil: isRoutine && _repeatRule != 'never'
          ? widget.task?.repeatUntil
          : null,
      weekdays: isRoutine && _repeatRule == 'weekdays'
          ? (_selectedWeekdays.toList()..sort())
          : const [],
      isCompleted: widget.task?.isCompleted ?? false,
      completedDates: widget.task?.completedDates ?? const {},
      reminderEnabled: _reminderMinutes != null,
      reminderMinutes: _reminderMinutes,
      facilityId: _facilityId,
      locationName: _locationName,
      latitude: _latitude,
      longitude: _longitude,
      photoPath: api == null ? _photoPath : null,
      photoId: photoId,
      createdAt: widget.task?.createdAt,
    );

    setState(() => _saving = true);
    try {
      final model.Task saved;
      String? photoWarning;
      if (api == null) {
        saved = await _store.persistTask(buildDraft(null));
      } else {
        final path = _photoPath;
        final result = await api.savePhotoChange(
          previousPhotoId: widget.task?.photoId,
          newPhoto: path == null ? null : XFile(path),
          removePhoto: _removeRemotePhoto,
          persist: (photoId) => _store.persistTask(buildDraft(photoId)),
        );
        saved = result.value;
        photoWarning = result.warning;
      }
      final warning = await _store.acceptSavedTask(saved);
      if (!mounted) return;
      if (photoWarning != null) _showMessage(photoWarning);
      if (warning != null) _showMessage(warning);
      Navigator.pop(context);
    } on EntryAttachmentException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Could not save the task. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _monthName(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month];
  }
}
