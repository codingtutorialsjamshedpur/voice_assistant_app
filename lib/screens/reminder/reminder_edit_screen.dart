import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/sound_service.dart';
import '../../services/reminder_service.dart';
import '../../models/reminder_model.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/glassmorphic_dialog.dart';

/// ═══════════════════════════════════════════════════════════════
/// Reminder Edit Screen - Add/Edit Reminder
/// ═══════════════════════════════════════════════════════════════
class ReminderEditScreen extends StatefulWidget {
  const ReminderEditScreen({super.key});

  @override
  State<ReminderEditScreen> createState() => _ReminderEditScreenState();
}

class _ReminderEditScreenState extends State<ReminderEditScreen> {
  final ReminderService _reminderService = Get.find<ReminderService>();

  // Controllers
  final TextEditingController _titleController = TextEditingController();

  // State
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  String _category = 'Spiritual';
  int _intervalMinutes = 30;
  Reminder? _existingReminder;
  bool _isEditing = false;

  final List<String> _categories = [
    'Spiritual',
    'Health',
    'Learning',
    'Work',
    'Personal',
  ];

  @override
  void initState() {
    super.initState();
    _checkForExistingReminder();
  }

  void _checkForExistingReminder() {
    final args = Get.arguments;
    if (args != null && args is Reminder) {
      _existingReminder = args;
      _isEditing = true;

      // Populate fields with existing data
      _titleController.text = _existingReminder!.title;
      _selectedTime = _existingReminder!.time;
      _category = _existingReminder!.category;
      _intervalMinutes = _existingReminder!.intervalMinutes;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _saveReminder() async {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter a reminder title',
        backgroundColor: Colors.red.withAlpha(230),
        colorText: Colors.white,
      );
      await SoundService.to.playWrong();
      return;
    }

    final reminder = Reminder(
      id: _existingReminder?.id,
      title: title,
      time: _selectedTime,
      category: _category,
      intervalMinutes: _intervalMinutes,
      isEnabled: true,
    );

    try {
      if (_isEditing && _existingReminder != null) {
        await _reminderService.updateReminder(_existingReminder!.id, reminder);
        Get.snackbar(
          'Success',
          'Reminder updated successfully',
          backgroundColor: Colors.green.withAlpha(230),
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      } else {
        await _reminderService.addReminder(reminder);
        Get.snackbar(
          'Success',
          '"$title" reminder set successfully',
          backgroundColor: Colors.green.withAlpha(230),
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }

      Get.back(result: true);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save reminder: $e',
        backgroundColor: Colors.red.withAlpha(230),
        colorText: Colors.white,
      );
      await SoundService.to.playWrong();
    }
  }

  void _deleteReminder() async {
    if (_existingReminder == null) return;

    await SoundService.to.playClick();

    final confirmed = await GlassmorphicDialogHelper.showDeleteConfirmation(
      title: 'Delete Reminder?',
      message: 'Are you sure you want to delete "${_existingReminder!.title}"?',
      subtitle: 'This action cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      onConfirm: () async {
        await _reminderService.deleteReminder(_existingReminder!.id);
      },
    );

    if (confirmed == true) {
      Get.back(result: true);
      Get.snackbar(
        'Deleted',
        'Reminder deleted successfully',
        backgroundColor: Colors.red.withAlpha(230),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _isEditing ? 'Edit Reminder' : 'Add Reminder',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    if (_isEditing) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: _deleteReminder,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(26),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 32),

                // Title Input
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reminder Title',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: 'e.g., Drink Water',
                          border: InputBorder.none,
                          prefixIcon: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB2EE).withAlpha(51),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.title,
                              color: Color(0xFFFF69B4),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Time Picker
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Start Time',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  timePickerTheme: TimePickerThemeData(
                                    backgroundColor:
                                        Colors.white.withAlpha(230),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (time != null) {
                            setState(() {
                              _selectedTime = time;
                            });
                            await SoundService.to.playClick();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.access_time,
                                color: AppColors.textPrimary(context),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedTime.format(context),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Interval Selection (Repeating)
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Repeat Every',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'In every $_intervalMinutes minutes',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: _intervalMinutes.toDouble(),
                        min: 15,
                        max: 120,
                        divisions: 7,
                        activeColor: const Color(0xFFFFB2EE),
                        inactiveColor: Colors.white.withValues(alpha: 0.3),
                        label: '$_intervalMinutes min',
                        onChanged: (value) {
                          setState(() {
                            _intervalMinutes = value.round();
                          });
                        },
                        onChangeEnd: (_) async {
                          await SoundService.to.playClick();
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '15m',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          Text(
                            '60m',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          Text(
                            '120m',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Category Selection
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Category',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((cat) {
                          final isSelected = _category == cat;
                          Color categoryColor;

                          switch (cat.toLowerCase()) {
                            case 'spiritual':
                              categoryColor = Colors.purple;
                              break;
                            case 'health':
                              categoryColor = Colors.green;
                              break;
                            case 'learning':
                              categoryColor = Colors.blue;
                              break;
                            case 'work':
                              categoryColor = Colors.orange;
                              break;
                            case 'personal':
                              categoryColor = Colors.pink;
                              break;
                            default:
                              categoryColor = Colors.grey;
                          }

                          return GestureDetector(
                            onTap: () async {
                              setState(() {
                                _category = cat;
                              });
                              await SoundService.to.playClick();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? categoryColor
                                    : categoryColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? categoryColor
                                      : categoryColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color:
                                      isSelected ? Colors.white : categoryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Save Button
                GestureDetector(
                  onTap: _saveReminder,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB2EE), Color(0xFFFF69B4)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB2EE).withAlpha(77),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isEditing ? Icons.save : Icons.add,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isEditing ? 'Save Changes' : 'Save Reminder',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
