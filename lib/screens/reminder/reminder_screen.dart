import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';
import '../../services/sound_service.dart';
import '../../services/reminder_service.dart';
import '../../models/reminder_model.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/glassmorphic_dialog.dart';

/// ═══════════════════════════════════════════════════════════════
/// Reminder Screen - Displays list of reminders with progress
/// ═══════════════════════════════════════════════════════════════
class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen>
    with SingleTickerProviderStateMixin {
  final ReminderService _reminderService = Get.find<ReminderService>();
  late AnimationController _progressAnimController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _progressAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _progressAnimController.forward();
    });
  }

  @override
  void dispose() {
    _progressAnimController.dispose();
    super.dispose();
  }

  void _addReminder() async {
    await SoundService.to.playClick();
    final result = await Get.toNamed(AppRoutes.reminderEdit);
    if (result == true) {
      // Refresh will happen automatically via Obx
    }
  }

  void _editReminder(Reminder reminder) async {
    await SoundService.to.playClick();
    final result = await Get.toNamed(
      AppRoutes.reminderEdit,
      arguments: reminder,
    );
    if (result == true) {
      // Refresh will happen automatically via Obx
    }
  }

  void _toggleComplete(Reminder reminder) async {
    await _reminderService.toggleComplete(reminder.id);
  }

  void _deleteReminder(Reminder reminder) async {
    await SoundService.to.playClick();

    final confirmed = await GlassmorphicDialogHelper.showDeleteConfirmation(
      title: 'Delete Reminder?',
      message: 'Are you sure you want to delete "${reminder.title}"?',
      subtitle: 'This action cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      onConfirm: () async {
        await _reminderService.deleteReminder(reminder.id);
      },
    );

    if (confirmed == true) {
      Get.snackbar(
        'Deleted',
        '"${reminder.title}" has been deleted',
        backgroundColor: Colors.red.withAlpha(230),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      currentRoute: AppRoutes.reminder,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Header with Title and Add Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reminders',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              Semantics(
                label: 'Add reminder',
                button: true,
                child: GestureDetector(
                  onTap: _addReminder,
                  child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB2EE), Color(0xFFFF69B4)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFB2EE).withAlpha(77),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                  ),
                ),
              ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress Card
          Obx(() {
            final progress = _reminderService.progressPercentage;
            final progressText = _reminderService.progressText;

            return GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today\'s Progress',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Builder(
                          builder: (ctx) => Text(
                            progressText,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(ctx),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          value: progress * _progressAnimation.value,
                          strokeWidth: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFFFB2EE),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),

          // Reminders List
          Expanded(
            child: Obx(() {
              final reminders = _reminderService.reminders;

              if (reminders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No reminders yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add your first reminder',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: reminders.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final reminder = reminders[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildReminderCard(reminder),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    final isCompleted = reminder.isCompleted;
    final categoryColor = reminder.categoryColor;

    return Dismissible(
      key: Key(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(77),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(
          Icons.delete,
          color: Colors.red[700],
        ),
      ),
      onDismissed: (_) => _deleteReminder(reminder),
      child: Semantics(
        label: reminder.title,
        child: GestureDetector(
          onTap: () => _editReminder(reminder),
          child: GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Checkbox
              Semantics(
                label: isCompleted ? 'Mark incomplete' : 'Mark complete',
                button: true,
                child: GestureDetector(
                  onTap: () => _toggleComplete(reminder),
                  child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFFFFB2EE)
                        : Colors.white.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFFFFB2EE)
                          : Colors.grey[400]!,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (ctx) => Text(
                        reminder.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? Colors.grey
                              : AppColors.textPrimary(ctx),
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Category pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            reminder.category,
                            style: TextStyle(
                              fontSize: 10,
                              color: categoryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Time
                        Text(
                          reminder.formattedTime,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (reminder.intervalMinutes > 0) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.repeat,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Every ${reminder.intervalMinutes}m',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Delete button (visible on tap)
              Semantics(
                label: 'Delete reminder',
                button: true,
                child: GestureDetector(
                  onTap: () => _deleteReminder(reminder),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red[400],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
