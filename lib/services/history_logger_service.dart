import 'package:get/get.dart';

import '../controllers/history_controller.dart';
import '../models/history_model.dart';

class HistoryLoggerService {
  static final HistoryLoggerService _instance =
      HistoryLoggerService._internal();
  factory HistoryLoggerService() => _instance;
  HistoryLoggerService._internal();

  HistoryController get _ctrl => Get.find<HistoryController>();

  Future<void> logChatActivity({
    String topic = 'Voice Chat',
    String? description,
  }) async {
    await _ctrl.logActivity(
      type: ActivityType.chat,
      title: topic,
      description: description,
      screenRoute: '/voice-chat',
    );
  }

  Future<void> logGameActivity({
    required String gameName,
    int? score,
    int? durationSeconds,
  }) async {
    await _ctrl.logActivity(
      type: ActivityType.game,
      title: 'Game: $gameName',
      description: score != null ? 'Score: $score' : null,
      screenRoute: '/game-play',
      durationSeconds: durationSeconds,
      metadata: {'gameName': gameName, 'score': score},
    );
  }

  Future<void> logAlarmActivity({
    required String action,
    String? alarmName,
  }) async {
    await _ctrl.logActivity(
      type: ActivityType.alarm,
      title: 'Alarm ${action.capitalizeFirst}: ${alarmName ?? "Untitled"}',
      screenRoute: '/alarm',
      metadata: {'action': action, 'alarmName': alarmName},
    );
  }

  Future<void> logNaamJaapActivity({
    int chantCount = 108,
    int? durationSeconds,
  }) async {
    await _ctrl.logActivity(
      type: ActivityType.naamJaap,
      title: 'Chanting: $chantCount Chants',
      description: durationSeconds != null
          ? 'Duration: ${_formatDuration(durationSeconds)}'
          : null,
      screenRoute: '/naam-jaap',
      durationSeconds: durationSeconds,
      metadata: {'chantCount': chantCount},
    );
  }

  Future<void> logVoiceStudioActivity({
    String? recordingName,
    int? durationSeconds,
  }) async {
    await _ctrl.logActivity(
      type: ActivityType.voiceStudio,
      title: 'Voice Recording: ${recordingName ?? "New Recording"}',
      screenRoute: '/voice-studio',
      durationSeconds: durationSeconds,
      metadata: {'recordingName': recordingName},
    );
  }

  Future<void> logReminderActivity({
    required String action,
    String? reminderName,
  }) async {
    await _ctrl.logActivity(
      type: ActivityType.reminder,
      title:
          'Reminder ${action.capitalizeFirst}: ${reminderName ?? "Untitled"}',
      screenRoute: '/reminder',
      metadata: {'action': action, 'reminderName': reminderName},
    );
  }

  Future<void> logWallpaperActivity({String? wallpaperName}) async {
    await _ctrl.logActivity(
      type: ActivityType.wallpaper,
      title: 'Wallpaper Changed: ${wallpaperName ?? "New Wallpaper"}',
      screenRoute: '/wallpaper',
      metadata: {'wallpaperName': wallpaperName},
    );
  }

  Future<void> logLanguageCoachActivity({
    String language = 'Unknown',
    int? durationSeconds,
  }) async {
    await _ctrl.logActivity(
      type: ActivityType.languageCoach,
      title: 'Language Practice: $language',
      screenRoute: '/language-coach',
      durationSeconds: durationSeconds,
      metadata: {'language': language},
    );
  }

  Future<void> logSettingsActivity({String? setting}) async {
    await _ctrl.logActivity(
      type: ActivityType.settings,
      title: 'Settings Modified: ${setting ?? "General Settings"}',
      screenRoute: '/settings',
      metadata: {'setting': setting},
    );
  }

  Future<void> logCustomActivity({
    required ActivityType type,
    required String title,
    String? description,
    String screenRoute = 'unknown',
    int? durationSeconds,
    Map<String, dynamic>? metadata,
  }) async {
    await _ctrl.logActivity(
      type: type,
      title: title,
      description: description,
      screenRoute: screenRoute,
      durationSeconds: durationSeconds,
      metadata: metadata,
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }
}
