import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/alarm_controller.dart';
import '../../models/alarm_model.dart';
import '../../routes/app_routes.dart';
import '../../services/sound_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/responsive.dart';
import '../../shared/theme/responsive_widgets.dart';
import '../../shared/widgets/glassmorphic_dialog.dart';

class AlarmScreen extends StatelessWidget {
  const AlarmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AlarmController());

    return DefaultLayout(
      currentRoute: AppRoutes.alarm,
      content: TabletConstrained(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RSizedBox(h: 16),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spiritual Alarms',
                style: TextStyle(
                  fontSize: context.r.sp(24),
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              Semantics(
                label: 'Add new alarm',
                button: true,
                child: GestureDetector(
                  onTap: () async {
                    await SoundService.to.playClick();
                    final result = await Get.toNamed(AppRoutes.alarmEdit);
                    if (result == true) {
                      controller.refreshAlarms();
                    }
                  },
                  child: Container(
                    padding: context.r.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB2EE), Color(0xFFFF69B4)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB2EE).withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: context.r.scale(24),
                    ),
                  ),
                ),
              ),
            ],
          ),
          RSizedBox(h: 8),
          // Subtitle
          Text(
            'Manage your daily spiritual practice reminders',
            style: TextStyle(
              fontSize: context.r.sp(14),
              color: AppColors.textSecondary(context),
            ),
          ),
          RSizedBox(h: 24),
          // Alarms List
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFFFB2EE)),
                  ),
                );
              }

              if (controller.alarms.isEmpty) {
                return _buildEmptyState(context);
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: controller.alarms.length,
                itemBuilder: (context, index) {
                  final alarm = controller.alarms[index];
                  return Padding(
                    padding: EdgeInsets.only(bottom: context.r.scale(12)),
                    child: _buildAlarmCard(context, alarm, controller),
                  );
                },
              );
            }),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: context.r.scale(120),
            height: context.r.scale(120),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB2EE), Color(0xFFFF69B4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB2EE).withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.alarm_off,
              size: context.r.scale(50),
              color: Colors.white,
            ),
          ),
          RSizedBox(h: 24),
          Builder(
            builder: (ctx) => Text(
              'No Alarms Set',
              style: TextStyle(
                fontSize: context.r.sp(22),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(ctx),
              ),
            ),
          ),
          RSizedBox(h: 12),
          Builder(
            builder: (ctx) => Text(
              'Tap the + button to create your first\nspiritual practice reminder',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: context.r.sp(14),
                color: AppColors.textSecondary(ctx),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmCard(BuildContext context, AlarmModel alarm, AlarmController controller) {
    final timeParts = alarm.time.split(' ');
    final time = timeParts[0];
    final amPm = timeParts[1];

    return Dismissible(
      key: Key(alarm.id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.3,
      },
      movementDuration: const Duration(milliseconds: 200),
      background: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFF4444)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: context.r.scale(24)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: context.r.sp(16),
              ),
            ),
            RSizedBox(w: 8),
            Icon(
              Icons.delete,
              color: Colors.white,
              size: context.r.scale(24),
            ),
          ],
        ),
      ),
      onDismissed: (_) async {
        await controller.deleteAlarm(alarm.id);
      },
      confirmDismiss: (direction) async {
        final confirmed = await GlassmorphicDialogHelper.showDeleteConfirmation(
          title: 'Delete Alarm?',
          message:
              'Are you sure you want to delete the alarm for ${alarm.time}?',
          subtitle: 'This action cannot be undone.',
          confirmLabel: 'Delete',
          cancelLabel: 'Cancel',
        );
        return confirmed ?? false;
      },
      child: Semantics(
        label: 'Alarm for ${alarm.time}${alarm.label.isNotEmpty ? ": ${alarm.label}" : ""}',
        button: true,
        child: GestureDetector(
          onTap: () async {
            await SoundService.to.playClick();
            final result = await Get.toNamed(
              AppRoutes.alarmEdit,
              arguments: alarm,
            );
            if (result == true) {
              controller.refreshAlarms();
            }
          },
          child: GlassContainer(
            padding: context.r.all(20),
            child: Row(
              children: [
                Container(
                  width: context.r.scale(56),
                  height: context.r.scale(56),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: alarm.isEnabled
                          ? [const Color(0xFFFFB2EE), const Color(0xFFFF69B4)]
                          : [Colors.grey[300]!, Colors.grey[400]!],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: alarm.isEnabled
                        ? [
                            BoxShadow(
                              color:
                                  const Color(0xFFFFB2EE).withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.alarm,
                    color: Colors.white,
                    size: context.r.scale(28),
                  ),
                ),
                RSizedBox(w: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Builder(
                            builder: (ctx) => Text(
                              time,
                              style: TextStyle(
                                fontSize: context.r.sp(36),
                                fontWeight: FontWeight.w300,
                                color: alarm.isEnabled
                                    ? AppColors.textPrimary(ctx)
                                    : Colors.grey,
                              ),
                            ),
                          ),
                          RSizedBox(w: 4),
                          Builder(
                            builder: (ctx) => Text(
                              amPm,
                              style: TextStyle(
                                fontSize: context.r.sp(16),
                                fontWeight: FontWeight.w500,
                                color: alarm.isEnabled
                                    ? AppColors.textSecondary(ctx)
                                    : Colors.grey[500],
                              ),
                            ),
                          ),
                        ],
                      ),
                      RSizedBox(h: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              alarm.label,
                              style: TextStyle(
                                fontSize: context.r.sp(14),
                                fontWeight: FontWeight.w500,
                                color: alarm.isEnabled
                                    ? const Color(0xFF5A3E54)
                                    : Colors.grey[500],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (alarm.repeatDays.isNotEmpty) ...[
                            RSizedBox(w: 8),
                            Icon(
                              Icons.repeat,
                              size: context.r.scale(14),
                              color: alarm.isEnabled
                                  ? const Color(0xFFFFB2EE)
                                  : Colors.grey[400],
                            ),
                            RSizedBox(w: 2),
                            Text(
                              _formatRepeatDays(alarm.repeatDays),
                              style: TextStyle(
                                fontSize: context.r.sp(12),
                                color: alarm.isEnabled
                                    ? const Color(0xFFFFB2EE)
                                    : Colors.grey[400],
                              ),
                            ),
                          ],
                          if (alarm.customVoicePath != null) ...[
                            RSizedBox(w: 8),
                            Icon(
                              Icons.mic,
                              size: context.r.scale(14),
                              color: alarm.isEnabled
                                  ? const Color(0xFFFFB2EE)
                                  : Colors.grey[400],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                RSizedBox(w: 8),
                Semantics(
                  label: '${alarm.isEnabled ? "Disable" : "Enable"} alarm',
                  child: Switch.adaptive(
                    value: alarm.isEnabled,
                    onChanged: (_) => controller.toggleAlarm(alarm.id),
                    activeThumbColor: const Color(0xFFFFB2EE),
                    activeTrackColor:
                        const Color(0xFFFFB2EE).withValues(alpha: 0.5),
                    inactiveThumbColor: Colors.grey[400],
                    inactiveTrackColor: Colors.grey[300],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatRepeatDays(List<String> days) {
    if (days.isEmpty) return '';
    if (days.length == 7) return 'Everyday';
    if (days.length == 5 &&
        days.contains('Mon') &&
        days.contains('Tue') &&
        days.contains('Wed') &&
        days.contains('Thu') &&
        days.contains('Fri')) {
      return 'Weekdays';
    }
    if (days.length == 2 && days.contains('Sat') && days.contains('Sun')) {
      return 'Weekends';
    }
    return days.map((d) => d.substring(0, 1)).join(', ');
  }
}
