import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../controllers/alarm_controller.dart';
import '../../models/alarm_model.dart';
import '../../services/sound_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/responsive.dart';
import '../../shared/theme/responsive_widgets.dart';
import '../../shared/widgets/glassmorphic_dialog.dart';

class AlarmEditScreen extends StatefulWidget {
  const AlarmEditScreen({super.key});

  @override
  State<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends State<AlarmEditScreen>
    with SingleTickerProviderStateMixin {
  final AlarmController _alarmController = Get.find<AlarmController>();
  final AudioPlayer _audioPlayer = AudioPlayer();

  late TimeOfDay _selectedTime;
  late TextEditingController _labelController;
  late List<String> _selectedDays;
  late String _sound;
  String? _customVoicePath;
  String? _editingAlarmId;

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  // Available alarm sounds with their display names and file paths
  final Map<String, String> _soundOptions = {
    'Bell Ring': 'assets/sounds/bell-ring.mp3',
    'Bird Chirping': 'assets/sounds/bird-sound.mp3',
    'Air Horn': 'assets/sounds/air-horn.mp3',
    'Dream Sound': 'assets/sounds/dream-sound.mp3',
  };

  // Recording state
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  String? _currentRecordingPath;

  // Playing state
  String? _currentlyPlayingId;
  bool _isPlaying = false;

  late AnimationController _recordingAnimController;
  late Animation<double> _recordingAnimation;

  @override
  void initState() {
    super.initState();
    _initFromArguments();
    _recordingAnimController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _recordingAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _recordingAnimController,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _initFromArguments() {
    final alarm = Get.arguments as AlarmModel?;
    if (alarm != null) {
      // Editing existing alarm
      _editingAlarmId = alarm.id;
      _selectedTime = _parseTimeString(alarm.time);
      _labelController = TextEditingController(text: alarm.label);
      _selectedDays = List<String>.from(alarm.repeatDays);
      _sound = alarm.sound;
      _customVoicePath = alarm.customVoicePath;
    } else {
      // Creating new alarm
      _selectedTime = const TimeOfDay(hour: 6, minute: 0);
      _labelController = TextEditingController();
      _selectedDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
      _sound = 'Bell Ring';
    }
  }

  TimeOfDay _parseTimeString(String timeStr) {
    final parts = timeStr.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    final int minute = int.parse(timeParts[1]);
    if (parts[1] == 'PM' && hour != 12) hour += 12;
    if (parts[1] == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  void dispose() {
    _labelController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordingAnimController.dispose();
    super.dispose();
  }

  Future<void> _checkAndRequestPermissions() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _showNotification(
        'Permission Required',
        'Microphone permission is needed to record voice messages.',
        isError: true,
      );
      throw Exception('Microphone permission denied');
    }
  }

  Future<void> _startRecording() async {
    try {
      await _checkAndRequestPermissions();

      final dir = await _alarmController.getVoiceRecordingsDirectory();
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.mp3';
      _currentRecordingPath = '$dir/$fileName';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordingDuration = 0;
      });

      _recordingAnimController.repeat(reverse: true);

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration++;
        });
      });

      _showNotification(
        'Recording Started',
        'Recording your voice message...',
      );
    } catch (e) {
      _showNotification(
        'Recording Error',
        'Failed to start recording: $e',
        isError: true,
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      _recordingAnimController.stop();

      final path = await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
        _isPaused = false;
      });

      if (path != null) {
        _showSaveRecordingDialog(path);
      }
    } catch (e) {
      _showNotification(
        'Recording Error',
        'Failed to stop recording: $e',
        isError: true,
      );
    }
  }

  Future<void> _pauseRecording() async {
    try {
      await _audioRecorder.pause();
      _recordingTimer?.cancel();
      _recordingAnimController.stop();
      setState(() {
        _isPaused = true;
      });
    } catch (e) {
      print('Failed to pause recording: $e');
    }
  }

  Future<void> _resumeRecording() async {
    try {
      await _audioRecorder.resume();
      _recordingAnimController.repeat(reverse: true);
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration++;
        });
      });
      setState(() {
        _isPaused = false;
      });
    } catch (e) {
      print('Failed to resume recording: $e');
    }
  }

  void _showSaveRecordingDialog(String path) {
    final nameController = TextEditingController(
      text: 'Voice Message ${_alarmController.voiceRecordings.length + 1}',
    );

    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Save Recording',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Builder(
              builder: (ctx) => Text(
                'Duration: ${_formatDuration(_recordingDuration)}',
                style: TextStyle(
                  color: AppColors.textSecondary(ctx),
                ),
              ),
            ),
            RSizedBox(h: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Recording Name',
                hintText: 'Enter a name for this voice message',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFFFFB2EE), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Get.back();
              // Delete the temp file
              final file = File(path);
              if (await file.exists()) {
                await file.delete();
              }
              _showNotification(
                'Recording Discarded',
                'The voice message was not saved.',
              );
            },
            child: const Text(
              'Discard',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Get.back();
                await _alarmController.addVoiceRecording(
                  name,
                  path,
                  _recordingDuration * 1000,
                );
                setState(() {
                  _customVoicePath = path;
                  _sound = 'Custom Voice';
                });
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(
                color: Color(0xFFFFB2EE),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _playRecording(VoiceRecording recording) async {
    try {
      if (_isPlaying && _currentlyPlayingId == recording.id) {
        await _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
          _currentlyPlayingId = null;
        });
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(recording.path));
        setState(() {
          _isPlaying = true;
          _currentlyPlayingId = recording.id;
        });

        _audioPlayer.onPlayerComplete.listen((_) {
          setState(() {
            _isPlaying = false;
            _currentlyPlayingId = null;
          });
        });
      }
    } catch (e) {
      _showNotification(
        'Playback Error',
        'Failed to play recording: $e',
        isError: true,
      );
    }
  }

  Future<void> _deleteRecording(String id) async {
    final confirmed = await GlassmorphicDialogHelper.showDeleteConfirmation(
      title: 'Delete Recording?',
      message: 'This voice message will be permanently deleted.',
      subtitle: 'This action cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
    );

    if (confirmed == true) {
      await _alarmController.deleteVoiceRecording(id);
      if (_customVoicePath != null) {
        final recording = _alarmController.voiceRecordings
            .firstWhereOrNull((r) => r.path == _customVoicePath);
        if (recording == null) {
          setState(() {
            _customVoicePath = null;
            _sound = 'Bell Ring';
          });
        }
      }
    }
  }

  Future<void> _saveAlarm() async {
    if (_labelController.text.trim().isEmpty) {
      _showNotification(
        'Label Required',
        'Please enter a label for this alarm.',
        isError: true,
      );
      return;
    }

    final timeString = _formatTimeString(_selectedTime);

    try {
      if (_editingAlarmId != null) {
        // Update existing alarm
        final existingAlarm = _alarmController.getAlarmById(_editingAlarmId!);
        if (existingAlarm != null) {
          await _alarmController.updateAlarm(existingAlarm.copyWith(
            time: timeString,
            label: _labelController.text.trim(),
            repeatDays: _selectedDays,
            sound: _sound,
            customVoicePath: _customVoicePath,
          ));
          _showNotification(
            'Alarm Updated',
            'Your alarm has been updated successfully.',
          );
        }
      } else {
        // Create new alarm
        await _alarmController.createAlarm(
          time: timeString,
          label: _labelController.text.trim(),
          repeatDays: _selectedDays,
          sound: _sound,
          customVoicePath: _customVoicePath,
        );
        _showNotification(
          'Alarm Created',
          'Your new alarm has been set successfully.',
        );
      }
      Get.back(result: true);
    } catch (e) {
      _showNotification(
        'Error',
        'Failed to save alarm: $e',
        isError: true,
      );
    }
  }

  String _formatTimeString(TimeOfDay time) {
    final hour = time.hourOfPeriod.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  void _showNotification(String title, String body, {bool isError = false}) {
    Get.snackbar(
      title,
      body,
      backgroundColor: isError
          ? Colors.red.withValues(alpha: 0.9)
          : const Color(0xFFFFB2EE).withValues(alpha: 0.9),
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      borderRadius: 12,
      margin: context.r.all(16),
      duration: const Duration(seconds: 3),
      icon: Icon(
        isError ? Icons.error_outline : Icons.check_circle_outline,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        child: Padding(
          padding: context.r.all(24),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        await SoundService.to.playClick();
                        Get.back();
                      },
                      child: Container(
                        padding: context.r.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back),
                      ),
                    ),
                    RSizedBox(w: 16),
                    Text(
                      _editingAlarmId != null ? 'Edit Alarm' : 'Add Alarm',
                      style: TextStyle(
                        fontSize: context.r.sp(24),
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    if (_editingAlarmId != null) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: () async {
                          await SoundService.to.playClick();
                          final confirmed = await GlassmorphicDialogHelper
                              .showDeleteConfirmation(
                            title: 'Delete Alarm?',
                            message:
                                'Are you sure you want to delete this alarm?',
                            subtitle: 'This action cannot be undone.',
                            confirmLabel: 'Delete',
                            cancelLabel: 'Cancel',
                          );
                          if (confirmed == true) {
                            await _alarmController
                                .deleteAlarm(_editingAlarmId!);
                            Get.back(result: true);
                          }
                        },
                        child: Container(
                          padding: context.r.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFFF4444),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                RSizedBox(h: 32),
                // Time Picker Display
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      await SoundService.to.playClick();
                      if (!context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              timePickerTheme: TimePickerThemeData(
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.95),
                                hourMinuteShape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
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
                      }
                    },
                    child: GlassContainer(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.r.scale(48),
                        vertical: context.r.scale(32),
                      ),
                      child: Text(
                        _selectedTime.format(context),
                        style: TextStyle(
                          fontSize: context.r.sp(56),
                          fontWeight: FontWeight.w300,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ),
                ),
                RSizedBox(h: 32),
                // Label Input
                GlassContainer(
                  padding: context.r.all(16),
                  child: TextField(
                    controller: _labelController,
                    decoration: const InputDecoration(
                      labelText: 'Alarm Label',
                      hintText: 'e.g., Morning Meditation',
                      border: InputBorder.none,
                      prefixIcon:
                          Icon(Icons.label_outline, color: Color(0xFFFFB2EE)),
                      labelStyle: TextStyle(color: Color(0xFF5A3E54)),
                    ),
                  ),
                ),
                RSizedBox(h: 16),
                // Days Selection
                GlassContainer(
                  padding: context.r.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Repeat',
                            style: TextStyle(
                              fontSize: context.r.sp(16),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          if (_selectedDays.length < 7)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDays = List<String>.from(_days);
                                });
                                SoundService.to.playClick();
                              },
                              child: Text(
                                'Select All',
                                style: TextStyle(
                                  fontSize: context.r.sp(12),
                                  color: Color(0xFFFFB2EE),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      RSizedBox(h: 12),
                      Wrap(
                        spacing: context.r.scale(8),
                        runSpacing: context.r.scale(8),
                        children: _days.map((day) {
                          final isSelected = _selectedDays.contains(day);
                          return GestureDetector(
                            onTap: () async {
                              await SoundService.to.playClick();
                              setState(() {
                                if (isSelected) {
                                  _selectedDays.remove(day);
                                } else {
                                  _selectedDays.add(day);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(
                                horizontal: context.r.scale(14),
                                vertical: context.r.scale(10),
                              ),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xFFFFB2EE),
                                          Color(0xFFFF69B4)
                                        ],
                                      )
                                    : null,
                                color: isSelected
                                    ? null
                                    : Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFFFB2EE)
                                              .withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                day,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: context.r.sp(13),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                RSizedBox(h: 16),
                // Sound Selection
                GlassContainer(
                  padding: context.r.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Alarm Sound',
                            style: TextStyle(
                              fontSize: context.r.sp(16),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          if (_isPlaying)
                            GestureDetector(
                              onTap: () async {
                                await _audioPlayer.stop();
                                setState(() {
                                  _isPlaying = false;
                                });
                              },
                              child: Container(
                                padding: context.r.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB2EE),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.stop,
                                  color: Colors.white,
                                  size: context.r.scale(16),
                                ),
                              ),
                            ),
                        ],
                      ),
                      RSizedBox(h: 8),
                      Text(
                        'Tap a sound to preview, select to use it',
                        style: TextStyle(
                          fontSize: context.r.sp(12),
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      RSizedBox(h: 12),
                      RadioGroup<String>(
                        groupValue: _sound,
                        onChanged: (value) async {
                          if (value != null) {
                            await SoundService.to.playClick();
                            setState(() {
                              _sound = value;
                              _customVoicePath = null;
                            });
                          }
                        },
                        child: Column(
                          children: [
                            ..._soundOptions.keys.map((soundName) {
                              final isSelected = _sound == soundName;
                              return Container(
                                margin: EdgeInsets.only(bottom: context.r.scale(8)),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFFB2EE)
                                          .withValues(alpha: 0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isSelected
                                      ? Border.all(
                                          color: const Color(0xFFFFB2EE),
                                          width: 1.5,
                                        )
                                      : null,
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: context.r.scale(12)),
                                  leading: GestureDetector(
                                    onTap: () async {
                                      await SoundService.to.playClick();
                                      // Play preview of sound
                                      final soundPath =
                                          _soundOptions[soundName];
                                      if (soundPath != null) {
                                        await _audioPlayer.stop();
                                        await _audioPlayer.play(AssetSource(
                                            soundPath.replaceFirst(
                                                'assets/', '')));
                                        setState(() {
                                          _isPlaying = true;
                                        });
                                        _audioPlayer.onPlayerComplete
                                            .listen((_) {
                                          setState(() {
                                            _isPlaying = false;
                                          });
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: context.r.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFB2EE)
                                            .withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.play_arrow,
                                        color: Color(0xFFFFB2EE),
                                        size: context.r.scale(20),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    soundName,
                                    style: TextStyle(
                                      fontSize: context.r.sp(14),
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: AppColors.textPrimary(context),
                                    ),
                                  ),
                                  trailing: Radio<String>(
                                    value: soundName,
                                    activeColor: const Color(0xFFFFB2EE),
                                  ),
                                  onTap: () async {
                                    await SoundService.to.playClick();
                                    setState(() {
                                      _sound = soundName;
                                      _customVoicePath = null;
                                    });
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                RSizedBox(h: 16),
                // Voice Recording Section
                GlassContainer(
                  padding: context.r.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Or Use Your Voice',
                            style: TextStyle(
                              fontSize: context.r.sp(16),
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          if (_alarmController.voiceRecordings.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.r.scale(8),
                                vertical: context.r.scale(4),
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB2EE)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_alarmController.voiceRecordings.length}/5',
                                style: TextStyle(
                                  fontSize: context.r.sp(12),
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFFB2EE),
                                ),
                              ),
                            ),
                        ],
                      ),
                      RSizedBox(h: 8),
                      Text(
                        'Record a custom message like "Time to wake up!" instead of preset sounds. Max 5 recordings.',
                        style: TextStyle(
                          fontSize: context.r.sp(12),
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      RSizedBox(h: 16),
                      // Recording Controls
                      Center(
                        child: AnimatedBuilder(
                          animation: _recordingAnimation,
                          builder: (context, child) {
                            return GestureDetector(
                              onTap: () async {
                                if (_isRecording) {
                                  await _stopRecording();
                                } else {
                                  await _startRecording();
                                }
                              },
                              child: Transform.scale(
                                scale: _isRecording
                                    ? _recordingAnimation.value
                                    : 1.0,
                                child: Container(
                                  width: context.r.scale(100),
                                  height: context.r.scale(100),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: _isRecording
                                        ? const LinearGradient(
                                            colors: [
                                              Color(0xFFFF4444),
                                              Color(0xFFFF6B6B)
                                            ],
                                          )
                                        : const LinearGradient(
                                            colors: [
                                              Color(0xFFFFB2EE),
                                              Color(0xFFFF69B4)
                                            ],
                                          ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isRecording
                                                ? const Color(0xFFFF4444)
                                                : const Color(0xFFFFB2EE))
                                            .withValues(alpha: 0.5),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      _isRecording ? Icons.stop : Icons.mic,
                                      color: Colors.white,
                                      size: context.r.scale(40),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_isRecording) ...[
                        RSizedBox(h: 16),
                        Center(
                          child: Text(
                            _isPaused
                                ? 'Paused'
                                : 'Recording... ${_formatDuration(_recordingDuration)}',
                            style: TextStyle(
                              fontSize: context.r.sp(18),
                              fontWeight: FontWeight.w600,
                              color: _isPaused
                                  ? Colors.orange
                                  : const Color(0xFFFF4444),
                            ),
                          ),
                        ),
                        RSizedBox(h: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () async {
                                await SoundService.to.playClick();
                                if (_isPaused) {
                                  await _resumeRecording();
                                } else {
                                  await _pauseRecording();
                                }
                              },
                              child: Container(
                                padding: context.r.all(12),
                                decoration: BoxDecoration(
                                  color: _isPaused
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.orange.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isPaused ? Icons.play_arrow : Icons.pause,
                                  color:
                                      _isPaused ? Colors.green : Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      RSizedBox(h: 24),
                      // Saved Recordings List
                      Obx(() {
                        if (_alarmController.voiceRecordings.isEmpty) {
                          return Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.mic_none,
                                  size: context.r.scale(48),
                                  color: Colors.grey[400],
                                ),
                                RSizedBox(h: 8),
                                Text(
                                  'No voice recordings yet',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: context.r.sp(14),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children:
                              _alarmController.voiceRecordings.map((recording) {
                            final isSelected =
                                _customVoicePath == recording.path;
                            final isPlaying =
                                _currentlyPlayingId == recording.id &&
                                    _isPlaying;

                            return Container(
                              margin: EdgeInsets.only(bottom: context.r.scale(8)),
                              padding: context.r.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFFB2EE)
                                        .withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(
                                        color: const Color(0xFFFFB2EE),
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _playRecording(recording),
                                    child: Container(
                                      padding: context.r.all(8),
                                      decoration: BoxDecoration(
                                        color: isPlaying
                                            ? const Color(0xFFFFB2EE)
                                            : Colors.white
                                                .withValues(alpha: 0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Builder(
                                        builder: (ctx) => Icon(
                                          isPlaying
                                              ? Icons.stop
                                              : Icons.play_arrow,
                                          color: isPlaying
                                              ? Colors.white
                                              : AppColors.textPrimary(ctx),
                                          size: context.r.scale(20),
                                        ),
                                      ),
                                    ),
                                  ),
                                  RSizedBox(w: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Builder(
                                          builder: (ctx) => Text(
                                            recording.name,
                                            style: TextStyle(
                                              fontSize: ctx.r.sp(14),
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary(ctx),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        RSizedBox(h: 2),
                                        Text(
                                          '${recording.durationFormatted} • ${_formatDate(recording.createdAt)}',
                                          style: TextStyle(
                                            fontSize: context.r.sp(12),
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: context.r.scale(8),
                                        vertical: context.r.scale(4),
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFB2EE),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Active',
                                        style: TextStyle(
                                          fontSize: context.r.sp(10),
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  if (!isSelected)
                                    GestureDetector(
                                      onTap: () async {
                                        await SoundService.to.playClick();
                                        setState(() {
                                          _customVoicePath = recording.path;
                                          _sound = 'Custom Voice';
                                        });
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: context.r.scale(12),
                                          vertical: context.r.scale(6),
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFB2EE)
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Use',
                                          style: TextStyle(
                                            fontSize: context.r.sp(12),
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFFFB2EE),
                                          ),
                                        ),
                                      ),
                                    ),
                                  RSizedBox(w: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      await SoundService.to.playClick();
                                      await _deleteRecording(recording.id);
                                    },
                                    child: Container(
                                      padding: context.r.all(8),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.red.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.delete_outline,
                                        color: Color(0xFFFF4444),
                                        size: context.r.scale(18),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      }),
                    ],
                  ),
                ),
                RSizedBox(h: 24),
                // Save Button
                GestureDetector(
                  onTap: _saveAlarm,
                  child: Container(
                    width: double.infinity,
                    height: context.r.buttonHeight,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB2EE), Color(0xFFFF69B4)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB2EE).withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Save Alarm',
                        style: TextStyle(
                          fontSize: context.r.sp(18),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                RSizedBox(h: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
