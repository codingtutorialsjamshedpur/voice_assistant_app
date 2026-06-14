import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/alarm_controller.dart';
import '../../models/alarm_model.dart';
import '../../services/sound_service.dart';
import 'dart:convert';
import 'dart:async';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/theme/app_colors.dart';

class AlarmRingingScreen extends StatefulWidget {
  const AlarmRingingScreen({super.key});

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen>
    with SingleTickerProviderStateMixin {
  late AlarmModel? _alarm;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _autoStopTimer;

  @override
  void initState() {
    super.initState();
    _loadAlarm();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-stop alarm after 30 seconds to reduce ringtone loop time
    _autoStopTimer = Timer(const Duration(seconds: 30), () {
      _stopAlarm();
    });
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _loadAlarm() {
    final args = Get.arguments as String?;
    if (args != null) {
      try {
        final Map<String, dynamic> alarmData = jsonDecode(args);
        final alarmId = alarmData['id'];
        _alarm = AlarmController.to.getAlarmById(alarmId);

        if (_alarm == null && alarmData.containsKey('time')) {
          _alarm = AlarmModel(
            id: alarmId,
            time: alarmData['time'],
            label: alarmData['label'] ?? 'Alarm',
            isEnabled: true,
            repeatDays: [],
            sound: alarmData['sound'] ?? 'Bell Ring',
            customVoicePath: alarmData['customVoicePath'],
            createdAt: DateTime.now(),
          );
        }
      } catch (e) {
        _alarm = AlarmController.to.getAlarmById(args);
      }
    } else {
      _alarm = null;
    }
    _playAlarmSound();
  }

  void _playAlarmSound() {
    if (_alarm != null) {
      SoundService.to.playAlarmWithSound(
        _alarm!.sound,
        customVoicePath: _alarm!.customVoicePath,
      );
    } else {
      SoundService.to.playAlarm();
    }
  }

  void _stopAlarm() {
    SoundService.to.stopAll();
    Get.back();
  }

  void _snoozeAlarm() {
    SoundService.to.stopAll();

    if (_alarm != null) {
      // Create a temporary snooze alarm 5 minutes from now
      final now = DateTime.now();
      final snoozeTime = now.add(const Duration(minutes: 5));
      final formattedTime =
          '${snoozeTime.hour > 12 ? snoozeTime.hour - 12 : (snoozeTime.hour == 0 ? 12 : snoozeTime.hour).toString().padLeft(2, '0')}:${snoozeTime.minute.toString().padLeft(2, '0')} ${snoozeTime.hour >= 12 ? 'PM' : 'AM'}';

      final snoozeAlarm = _alarm!.copyWith(
        id: '${_alarm!.id}_snooze', // temporary id
        time: formattedTime,
        label: 'Snooze: ${_alarm!.label}',
        repeatDays: [], // Snooze doesn't repeat
      );

      AlarmController.to.scheduleAlarm(snoozeAlarm);
    }

    Get.back();
    Get.snackbar(
      'Alarm Snoozed',
      'Alarm will ring again in 5 minutes',
      backgroundColor: const Color(0xFFFFB2EE).withValues(alpha: 0.9),
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      borderRadius: 12,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final time = _alarm?.time ?? '06:00 AM';
    final label = _alarm?.label ?? 'Morning Meditation';

    return AppBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Alarm Icon with pulse
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB2EE), Color(0xFFFF69B4)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFB2EE).withValues(alpha: 0.5),
                        blurRadius: 40,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.alarm,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              // Time
              Text(
                time,
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 16),
              // Label
              Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 64),
              // Stop Button
              GestureDetector(
                onTap: _stopAlarm,
                child: Container(
                  width: double.infinity,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF4D4D),
                        Color(0xFFCC0000)
                      ], // Prominent Red
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4D4D).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Stop',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Snooze Button
              GestureDetector(
                onTap: _snoozeAlarm,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Center(
                    child: Builder(
                      builder: (ctx) => Text(
                        'Snooze (5 min)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(ctx),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
