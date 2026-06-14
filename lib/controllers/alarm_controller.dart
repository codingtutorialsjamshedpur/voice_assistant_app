import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import '../models/alarm_model.dart';
import '../routes/app_routes.dart';
import '../services/sound_service.dart';
import '../services/history_logger_service.dart';
import '../services/ruflo_service.dart';
import '../services/federation_service.dart';

class AlarmController extends GetxController {
  static AlarmController get to => Get.find<AlarmController>();
  final _ruflo = RuFloService();

  final _storage = GetStorage();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  final RxList<AlarmModel> alarms = <AlarmModel>[].obs;
  final RxList<VoiceRecording> voiceRecordings = <VoiceRecording>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  static const String _alarmsKey = 'alarms';
  static const String _voiceRecordingsKey = 'voice_recordings';
  static const int _maxVoiceRecordings = 5;

  @override
  void onInit() {
    super.onInit();
    _initNotifications();
    _loadAlarms();
    _loadVoiceRecordings();
  }

  Future<void> _initNotifications() async {
    tz.initializeTimeZones();
    // Set the local timezone based on device's UTC offset
    // DateTime.now().timeZoneName returns abbreviated names like 'IST'
    // which are NOT valid IANA timezone identifiers.
    // Instead, we find the matching timezone by UTC offset.
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      // Try to find timezone by name first
      try {
        tz.setLocalLocation(tz.getLocation(now.timeZoneName));
      } catch (_) {
        // timeZoneName wasn't a valid IANA name, find by offset
        final locations = tz.timeZoneDatabase.locations;
        String? bestMatch;
        for (final entry in locations.entries) {
          final tzNow = tz.TZDateTime.now(entry.value);
          if (tzNow.timeZoneOffset == offset) {
            bestMatch = entry.key;
            break;
          }
        }
        if (bestMatch != null) {
          tz.setLocalLocation(tz.getLocation(bestMatch));
        } else {
          // Fallback: use Asia/Kolkata for IST (+5:30)
          tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
        }
      }
    } catch (e) {
      print('Timezone initialization error: $e, falling back to Asia/Kolkata');
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  void _onNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;

    Map<String, dynamic> alarmData;
    try {
      alarmData = jsonDecode(payload);
    } catch (e) {
      alarmData = {'id': payload};
    }

    final alarmId = alarmData['id'];

    if (response.actionId == 'stop_action') {
      SoundService.to.stopAll();
      // Simply opening the app stops it as well, but we explicitly stop sound
    } else if (response.actionId == 'snooze_action') {
      SoundService.to.stopAll();
      AlarmModel? alarm = getAlarmById(alarmId);

      if (alarm == null && alarmData.containsKey('time')) {
        alarm = AlarmModel(
          id: alarmData['id'],
          time: alarmData['time'],
          label: alarmData['label'] ?? 'Alarm',
          isEnabled: true,
          repeatDays: [],
          sound: alarmData['sound'] ?? 'Bell Ring',
          customVoicePath: alarmData['customVoicePath'],
          createdAt: DateTime.now(),
        );
      }

      if (alarm != null) {
        final now = DateTime.now();
        final snoozeTime = now.add(const Duration(minutes: 5));
        final formattedTime =
            '${snoozeTime.hour > 12 ? snoozeTime.hour - 12 : (snoozeTime.hour == 0 ? 12 : snoozeTime.hour).toString().padLeft(2, '0')}:${snoozeTime.minute.toString().padLeft(2, '0')} ${snoozeTime.hour >= 12 ? 'PM' : 'AM'}';

        final snoozeAlarm = alarm.copyWith(
          id: '${alarm.id}_snooze',
          time: formattedTime,
          label: alarm.label.startsWith('Snooze:')
              ? alarm.label
              : 'Snooze: ${alarm.label}',
          repeatDays: [],
        );

        await scheduleAlarm(snoozeAlarm);
        print('Snoozed alarm via notification action');
      }
    } else {
      // Default tap action
      // AL-07 & AL-08: Prevent duplicate alarm UI or overlap crash
      if (Get.currentRoute == AppRoutes.alarmRinging) {
        // If it's already ringing, we just replace it or ignore it if same
        Get.offNamed(AppRoutes.alarmRinging,
            arguments: payload, preventDuplicates: false);
      } else {
        Get.toNamed(AppRoutes.alarmRinging,
            arguments: payload, preventDuplicates: true);
      }
    }
  }

  void _loadAlarms() {
    isLoading.value = true;
    try {
      final alarmsJson = _storage.read<List<dynamic>>(_alarmsKey);
      if (alarmsJson != null) {
        alarms.value = alarmsJson
            .map((json) => AlarmModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      errorMessage.value = 'Failed to load alarms: $e';
    } finally {
      isLoading.value = false;
    }
  }

  void _loadVoiceRecordings() {
    try {
      final recordingsJson = _storage.read<List<dynamic>>(_voiceRecordingsKey);
      if (recordingsJson != null) {
        voiceRecordings.value = recordingsJson
            .map(
                (json) => VoiceRecording.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Failed to load voice recordings: $e');
    }
  }

  Future<void> _saveAlarms() async {
    try {
      final alarmsJson = alarms.map((a) => a.toJson()).toList();
      await _storage.write(_alarmsKey, alarmsJson);
    } catch (e) {
      errorMessage.value = 'Failed to save alarms: $e';
    }
  }

  Future<void> _saveVoiceRecordings() async {
    try {
      final recordingsJson = voiceRecordings.map((r) => r.toJson()).toList();
      await _storage.write(_voiceRecordingsKey, recordingsJson);
    } catch (e) {
      print('Failed to save voice recordings: $e');
    }
  }

  Future<String> addVoiceRecording(
      String name, String path, int durationMs) async {
    if (voiceRecordings.length >= _maxVoiceRecordings) {
      // Remove oldest recording
      final oldest = voiceRecordings
          .reduce((a, b) => a.createdAt.isBefore(b.createdAt) ? a : b);
      await deleteVoiceRecording(oldest.id);
    }

    final recording = VoiceRecording(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      path: path,
      durationMs: durationMs,
      createdAt: DateTime.now(),
    );

    voiceRecordings.add(recording);
    await _saveVoiceRecordings();

    await SoundService.to.playSuccess();
    _showNotification(
      title: 'Voice Recording Saved',
      body: 'Your voice message "$name" has been saved.',
    );

    return recording.id;
  }

  Future<void> deleteVoiceRecording(String id) async {
    try {
      final recording = voiceRecordings.firstWhere((r) => r.id == id);
      final file = File(recording.path);
      if (await file.exists()) {
        await file.delete();
      }
      voiceRecordings.removeWhere((r) => r.id == id);
      await _saveVoiceRecordings();

      // Remove from any alarms using this recording
      for (var alarm in alarms) {
        if (alarm.customVoicePath == recording.path) {
          await updateAlarm(alarm.copyWith(
            customVoicePath: null,
            sound: 'Bell Ring',
          ));
        }
      }
    } catch (e) {
      print('Failed to delete voice recording: $e');
    }
  }

  Future<AlarmModel> createAlarm({
    required String time,
    required String label,
    List<String> repeatDays = const [],
    String sound = 'Bell Ring',
    String? customVoicePath,
  }) async {
    final alarm = AlarmModel(
      id: AlarmModel.generateId(),
      time: time,
      label: label,
      isEnabled: true,
      repeatDays: repeatDays,
      sound: sound,
      customVoicePath: customVoicePath,
      createdAt: DateTime.now(),
    );

    alarms.add(alarm);
    await _saveAlarms();

    await HistoryLoggerService().logAlarmActivity(
      action: 'created',
      alarmName: label,
    );

    final nextAlarm = alarm.getNextAlarmTime();
    if (nextAlarm != null) {
      unawaited(_ruflo.callTool('create_calendar_event', {
        'title': alarm.label,
        'datetime': nextAlarm.toIso8601String(),
        'duration': 5,
        'reminder': 10,
      }));
    }

    unawaited(Get.find<FederationService>().syncToFamily('alarm', {
      'id': alarm.id,
      'label': alarm.label,
      'time': alarm.time,
      'repeat_days': alarm.repeatDays,
    }));

    if (alarm.isEnabled) {
      try {
        await scheduleAlarm(alarm);
      } catch (e) {
        print('Warning: Failed to schedule alarm notification: $e');
        // Alarm is still saved, just notification scheduling failed
      }
    }

    await SoundService.to.playSuccess();
    _showNotification(
      title: 'Alarm Created',
      body: 'Alarm for $time - $label has been set.',
    );

    return alarm;
  }

  Future<void> updateAlarm(AlarmModel updatedAlarm) async {
    final index = alarms.indexWhere((a) => a.id == updatedAlarm.id);
    if (index >= 0) {
      alarms[index] = updatedAlarm.copyWith(updatedAt: DateTime.now());
      await _saveAlarms();

      await HistoryLoggerService().logAlarmActivity(
        action: 'edited',
        alarmName: updatedAlarm.label,
      );

      try {
        await cancelAlarm(updatedAlarm.id);
        if (updatedAlarm.isEnabled) {
          await scheduleAlarm(updatedAlarm);
        }
      } catch (e) {
        print('Warning: Failed to reschedule alarm notification: $e');
      }

      await SoundService.to.playSuccess();
    }
  }

  Future<void> deleteAlarm(String id) async {
    final alarm = alarms.firstWhereOrNull((a) => a.id == id);
    final alarmLabel = alarm?.label;
    try {
      await cancelAlarm(id);
    } catch (e) {
      print('Warning: Failed to cancel alarm notification: $e');
    }
    alarms.removeWhere((a) => a.id == id);
    await _saveAlarms();

    await HistoryLoggerService().logAlarmActivity(
      action: 'deleted',
      alarmName: alarmLabel,
    );

    await SoundService.to.playSuccess();
    _showNotification(
      title: 'Alarm Deleted',
      body: 'The alarm has been removed.',
    );
  }

  Future<void> toggleAlarm(String id) async {
    final index = alarms.indexWhere((a) => a.id == id);
    if (index >= 0) {
      final alarm = alarms[index];
      final updatedAlarm = alarm.copyWith(isEnabled: !alarm.isEnabled);
      alarms[index] = updatedAlarm;
      await _saveAlarms();

      await SoundService.to.playClick();

      try {
        if (updatedAlarm.isEnabled) {
          await scheduleAlarm(updatedAlarm);
          _showNotification(
            title: 'Alarm Enabled',
            body: 'Alarm for ${alarm.time} is now active.',
          );
        } else {
          await cancelAlarm(id);
          _showNotification(
            title: 'Alarm Disabled',
            body: 'Alarm for ${alarm.time} has been turned off.',
          );
        }
      } catch (e) {
        print('Warning: Failed to toggle alarm notification: $e');
        // State is already saved, just notification scheduling failed
        _showNotification(
          title: updatedAlarm.isEnabled ? 'Alarm Enabled' : 'Alarm Disabled',
          body: 'Alarm state updated. Notification scheduling may need retry.',
        );
      }
    }
  }

  Future<void> scheduleAlarm(AlarmModel alarm) async {
    final nextTime = alarm.getNextAlarmTime();
    if (nextTime == null) {
      print('Failed to get next alarm time for alarm: ${alarm.id}');
      return;
    }

    // Convert to TZDateTime properly using the local timezone
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      nextTime.year,
      nextTime.month,
      nextTime.day,
      nextTime.hour,
      nextTime.minute,
    );

    // If the scheduled time is in the past, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
      print(
          'Alarm time already passed, scheduling for tomorrow: $scheduledDate');
    }

    print('Scheduling alarm: ${alarm.id} at $scheduledDate (local time)');
    print(
        'Alarm details: Time=${alarm.time}, RepeatDays=${alarm.repeatDays}, Enabled=${alarm.isEnabled}');

    // Check if scheduled time is in the future
    if (scheduledDate.isBefore(now)) {
      print('ERROR: Scheduled time is in the past!');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'alarm_channel',
      'Spiritual Alarms',
      channelDescription: 'Daily spiritual practice reminders',
      importance: Importance.max,
      priority: Priority.high,
      enableLights: true,
      ledColor: Color(0xFFFFB2EE),
      ledOnMs: 1000,
      ledOffMs: 500,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('snooze_action', 'Snooze (5m)',
            showsUserInterface: true),
        AndroidNotificationAction('stop_action', 'Stop',
            showsUserInterface: true),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payloadJson = jsonEncode({
      'id': alarm.id,
      'time': alarm.time,
      'label': alarm.label,
      'sound': alarm.sound,
      'customVoicePath': alarm.customVoicePath,
    });

    try {
      // For non-repeating alarms, don't use matchDateTimeComponents
      if (alarm.repeatDays.isEmpty) {
        await _notifications.zonedSchedule(
          alarm.id.hashCode,
          'Spiritual Alarm',
          alarm.label.isNotEmpty
              ? alarm.label
              : 'Time for your spiritual practice',
          scheduledDate,
          details,
          payload: payloadJson,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        print('One-time alarm scheduled successfully');
      } else {
        // For repeating alarms, use matchDateTimeComponents
        await _notifications.zonedSchedule(
          alarm.id.hashCode,
          'Spiritual Alarm',
          alarm.label.isNotEmpty
              ? alarm.label
              : 'Time for your spiritual practice',
          scheduledDate,
          details,
          payload: payloadJson,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
        print('Repeating alarm scheduled successfully');
      }
    } on PlatformException catch (e) {
      // If exact alarms not permitted, fall back to inexact scheduling
      if (e.code == 'exact_alarms_not_permitted') {
        print('Exact alarms not permitted, using inexact scheduling');
        if (alarm.repeatDays.isEmpty) {
          await _notifications.zonedSchedule(
            alarm.id.hashCode,
            'Spiritual Alarm',
            alarm.label.isNotEmpty
                ? alarm.label
                : 'Time for your spiritual practice',
            scheduledDate,
            details,
            payload: payloadJson,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } else {
          await _notifications.zonedSchedule(
            alarm.id.hashCode,
            'Spiritual Alarm',
            alarm.label.isNotEmpty
                ? alarm.label
                : 'Time for your spiritual practice',
            scheduledDate,
            details,
            payload: payloadJson,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
        print('Inexact alarm scheduled successfully');
      } else {
        print('PlatformException while scheduling: $e');
        rethrow;
      }
    } catch (e) {
      print('Unexpected error while scheduling alarm: $e');
      rethrow;
    }
  }

  Future<void> cancelAlarm(String id) async {
    await _notifications.cancel(id.hashCode);
  }

  Future<void> cancelAllAlarms() async {
    await _notifications.cancelAll();
  }

  // Map sound names to actual asset file paths
  final Map<String, String> _soundAssetPaths = {
    'Bell Ring': 'assets/sounds/bell-ring.mp3',
    'Bird Chirping': 'assets/sounds/bird-sound.mp3',
    'Air Horn': 'assets/sounds/air-horn.mp3',
    'Dream Sound': 'assets/sounds/dream-sound.mp3',
  };

  String? getSoundFilePath(String soundName) {
    return _soundAssetPaths[soundName];
  }

  Future<void> _showNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'general_channel',
      'General Notifications',
      channelDescription: 'General app notifications',
      importance: Importance.low,
      priority: Priority.low,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
  }

  Future<String> getVoiceRecordingsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory('${appDir.path}/voice_recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    return recordingsDir.path;
  }

  AlarmModel? getAlarmById(String id) {
    try {
      return alarms.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  void refreshAlarms() {
    _loadAlarms();
  }

  /// Test if notifications are working by showing a test notification immediately
  Future<void> testNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Test notification channel',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999999,
      'Test Notification',
      'If you see this, notifications are working!',
      details,
    );
  }

  /// Schedule a test alarm 10 seconds from now
  Future<void> scheduleTestAlarm() async {
    final now = tz.TZDateTime.now(tz.local);
    final scheduledTime = now.add(const Duration(seconds: 10));

    print('Scheduling test alarm for: $scheduledTime');

    const androidDetails = AndroidNotificationDetails(
      'alarm_channel',
      'Spiritual Alarms',
      channelDescription: 'Daily spiritual practice reminders',
      importance: Importance.max,
      priority: Priority.high,
      enableLights: true,
      ledColor: Color(0xFFFFB2EE),
      ledOnMs: 1000,
      ledOffMs: 500,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('snooze_action', 'Snooze (5m)',
            showsUserInterface: true),
        AndroidNotificationAction('stop_action', 'Stop',
            showsUserInterface: true),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final timeStr =
        '${scheduledTime.hour > 12 ? scheduledTime.hour - 12 : (scheduledTime.hour == 0 ? 12 : scheduledTime.hour).toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')} ${scheduledTime.hour >= 12 ? 'PM' : 'AM'}';
    final payloadJson = jsonEncode({
      'id': 'test_alarm',
      'time': timeStr,
      'label': 'Test Alarm',
      'sound': 'Bell Ring',
      'customVoicePath': null,
    });

    try {
      await _notifications.zonedSchedule(
        888888,
        'Test Alarm',
        'This is a test alarm! It should appear in 10 seconds.',
        scheduledTime,
        details,
        payload: payloadJson,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('Test alarm scheduled successfully for 10 seconds from now');
    } catch (e) {
      print('Error scheduling test alarm: $e');
      rethrow;
    }
  }
}
