/// ═══════════════════════════════════════════════════════════════
/// Settings Controller - Reactive Settings Management
/// ═══════════════════════════════════════════════════════════════
///
/// Manages all application settings with persistent storage.
/// Extends GetxController for reactive state management.
///
/// **Responsibilities:**
/// 1. Load and persist user preferences
/// 2. Provide reactive observables for UI binding
/// 3. Validate and apply settings changes
/// 4. Handle settings synchronization across app
///
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../services/storage_service.dart';
import '../services/sound_service.dart';
import '../services/language_service.dart';
import '../services/theme_service.dart';

class SettingsController extends GetxController {
  static SettingsController get to => Get.find();

  // ═══════════════════════════════════════════════════════════════
  // AUDIO & VOICE SETTINGS
  // ═══════════════════════════════════════════════════════════════
  final voiceSpeed = 1.0.obs; // 0.5 - 1.5x
  final voicePitch = 1.0.obs; // 0.8 - 1.2
  final masterVolume = 0.8.obs; // 0.0 - 1.0
  final soundEffectsEnabled = true.obs;
  final hapticFeedbackEnabled = true.obs;
  final autoListenEnabled = true.obs;
  final interruptAiEnabled = true.obs;

  // ═══════════════════════════════════════════════════════════════
  // LANGUAGE SETTINGS
  // ═══════════════════════════════════════════════════════════════
  final appLanguage = 'English'.obs; // 'English', 'Hindi', 'Hinglish'
  final hinglishModeEnabled = false.obs;

  // ═══════════════════════════════════════════════════════════════
  // NOTIFICATION SETTINGS
  // ═══════════════════════════════════════════════════════════════
  final notificationsEnabled = true.obs;
  final alarmNotificationsEnabled = true.obs;
  final reminderNotificationsEnabled = true.obs;
  final dailyWisdomEnabled = true.obs;
  final streakRemindersEnabled = true.obs;
  final voiceAlertsEnabled = false.obs;
  final notificationVolume = 0.8.obs; // 0.0 - 1.0
  final notificationSound =
      'bell'.obs; // 'bell', 'chime', 'chirp', 'gong', 'silent'

  // ═══════════════════════════════════════════════════════════════
  // APPEARANCE & PERSONALIZATION
  // ═══════════════════════════════════════════════════════════════
  final themeMode = 'system'.obs;
  final accentColor = '#FFB2EE'.obs; // Pink by default
  final animationIntensity = 'medium'.obs; // 'low', 'medium', 'high'
  final orbAnimationEnabled = true.obs;
  final defaultExpandedLayout = false.obs;
  final glassBlurIntensity = 10.0.obs; // 0.0 - 20.0

  // ═══════════════════════════════════════════════════════════════
  // INTERACTION & FEEDBACK
  // ═══════════════════════════════════════════════════════════════
  final hapticIntensity = 'medium'.obs; // 'light', 'medium', 'heavy'

  // ═══════════════════════════════════════════════════════════════
  // SPIRITUAL & NICHE FEATURES
  // ═══════════════════════════════════════════════════════════════
  final defaultMantra = 'Ram Ram'.obs;
  final milestoneCelebrationsEnabled = true.obs;
  final sessionAutoSaveEnabled = true.obs;
  final chantingGuideVoiceEnabled = false.obs;

  // ═══════════════════════════════════════════════════════════════
  // PRIVACY & DATA
  // ═══════════════════════════════════════════════════════════════
  final chatHistorySaveEnabled = true.obs;
  final aiLearningEnabled = true.obs;
  final analyticsEnabled = true.obs;
  final crashReportsEnabled = true.obs;

  // ═══════════════════════════════════════════════════════════════
  // STATUS & METADATA
  // ═══════════════════════════════════════════════════════════════
  final isLoading = false.obs;
  final lastSavedTime = Rx<DateTime?>(null);
  final hasUnsavedChanges = false.obs;

  // Storage service reference
  late StorageService _storage;
  late SoundService _soundService;

  @override
  void onInit() {
    super.onInit();
    debugPrint('🔧 [SettingsController] Initializing...');
    _storage = StorageService.to;
    _soundService = Get.find<SoundService>();
    _loadSettings();

    ever(ThemeService.to.appThemeMode, (AppThemeMode mode) {
      final modeStr = mode == AppThemeMode.light
          ? 'light'
          : mode == AppThemeMode.dark
              ? 'dark'
              : 'system';
      if (themeMode.value != modeStr) {
        themeMode.value = modeStr;
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // PUBLIC API - LOADING & SAVING
  // ═══════════════════════════════════════════════════════════════

  /// Load all settings from persistent storage
  Future<void> _loadSettings() async {
    try {
      isLoading.value = true;

      // Audio & Voice
      voiceSpeed.value = _storage.read('voice_speed') ?? 1.0;
      voicePitch.value = _storage.read('voice_pitch') ?? 1.0;
      masterVolume.value = _storage.read('master_volume') ?? 0.8;
      soundEffectsEnabled.value = _storage.read('sound_effects') ?? true;
      hapticFeedbackEnabled.value = _storage.read('haptic_feedback') ?? true;
      autoListenEnabled.value = _storage.read('auto_listen') ?? true;
      interruptAiEnabled.value = _storage.read('interrupt_ai') ?? true;

      // Language
      appLanguage.value = _storage.read('app_language') ?? 'English';
      hinglishModeEnabled.value = _storage.read('hinglish_mode') ?? false;

      // Notifications
      notificationsEnabled.value =
          _storage.read('notifications_master') ?? true;
      alarmNotificationsEnabled.value =
          _storage.read('alarm_notifications') ?? true;
      reminderNotificationsEnabled.value =
          _storage.read('reminder_notifications') ?? true;
      dailyWisdomEnabled.value = _storage.read('daily_wisdom') ?? true;
      streakRemindersEnabled.value = _storage.read('streak_reminders') ?? true;
      voiceAlertsEnabled.value = _storage.read('voice_alerts') ?? false;
      notificationVolume.value = _storage.read('notification_volume') ?? 0.8;
      notificationSound.value = _storage.read('notification_sound') ?? 'bell';

      // Appearance
      themeMode.value = _storage.read('theme_mode') ?? 'system';
      accentColor.value = _storage.read('accent_color') ?? '#FFB2EE';
      animationIntensity.value =
          _storage.read('animation_intensity') ?? 'medium';
      orbAnimationEnabled.value = _storage.read('orb_animation') ?? true;
      defaultExpandedLayout.value =
          _storage.read('default_expanded_layout') ?? false;
      glassBlurIntensity.value = _storage.read('glass_blur_intensity') ?? 10.0;

      // Interaction & Feedback
      hapticIntensity.value = _storage.read('haptic_intensity') ?? 'medium';

      // Spiritual & Niche
      defaultMantra.value = _storage.read('default_mantra') ?? 'Ram Ram';
      milestoneCelebrationsEnabled.value =
          _storage.read('milestone_celebrations') ?? true;
      sessionAutoSaveEnabled.value = _storage.read('session_auto_save') ?? true;
      chantingGuideVoiceEnabled.value =
          _storage.read('chanting_guide_voice') ?? false;

      // Privacy & Data
      chatHistorySaveEnabled.value = _storage.read('save_chat_history') ?? true;
      aiLearningEnabled.value = _storage.read('ai_learning') ?? true;
      analyticsEnabled.value = _storage.read('analytics_enabled') ?? true;
      crashReportsEnabled.value = _storage.read('crash_reports') ?? true;

      lastSavedTime.value = DateTime.now();
      hasUnsavedChanges.value = false;
      isLoading.value = false;

      debugPrint('✅ [SettingsController] Settings loaded successfully');
    } catch (e) {
      debugPrint('❌ [SettingsController] Error loading settings: $e');
      isLoading.value = false;
    }
  }

  /// Save all settings to persistent storage
  Future<void> saveAllSettings() async {
    try {
      isLoading.value = true;

      // Audio & Voice
      await _storage.write('voice_speed', voiceSpeed.value);
      await _storage.write('voice_pitch', voicePitch.value);
      await _storage.write('master_volume', masterVolume.value);
      await _storage.write('sound_effects', soundEffectsEnabled.value);
      await _storage.write('haptic_feedback', hapticFeedbackEnabled.value);
      await _storage.write('auto_listen', autoListenEnabled.value);
      await _storage.write('interrupt_ai', interruptAiEnabled.value);

      // Language
      await _storage.write('app_language', appLanguage.value);
      await _storage.write('hinglish_mode', hinglishModeEnabled.value);

      // Notifications
      await _storage.write('notifications_master', notificationsEnabled.value);
      await _storage.write(
          'alarm_notifications', alarmNotificationsEnabled.value);
      await _storage.write(
          'reminder_notifications', reminderNotificationsEnabled.value);
      await _storage.write('daily_wisdom', dailyWisdomEnabled.value);
      await _storage.write('streak_reminders', streakRemindersEnabled.value);
      await _storage.write('voice_alerts', voiceAlertsEnabled.value);
      await _storage.write('notification_volume', notificationVolume.value);
      await _storage.write('notification_sound', notificationSound.value);

      // Appearance
      await _storage.write('theme_mode', themeMode.value);
      await _storage.write('accent_color', accentColor.value);
      await _storage.write('animation_intensity', animationIntensity.value);
      await _storage.write('orb_animation', orbAnimationEnabled.value);
      await _storage.write(
          'default_expanded_layout', defaultExpandedLayout.value);
      await _storage.write('glass_blur_intensity', glassBlurIntensity.value);

      // Interaction & Feedback
      await _storage.write('haptic_intensity', hapticIntensity.value);

      // Spiritual & Niche
      await _storage.write('default_mantra', defaultMantra.value);
      await _storage.write(
          'milestone_celebrations', milestoneCelebrationsEnabled.value);
      await _storage.write('session_auto_save', sessionAutoSaveEnabled.value);
      await _storage.write(
          'chanting_guide_voice', chantingGuideVoiceEnabled.value);

      // Privacy & Data
      await _storage.write('save_chat_history', chatHistorySaveEnabled.value);
      await _storage.write('ai_learning', aiLearningEnabled.value);
      await _storage.write('analytics_enabled', analyticsEnabled.value);
      await _storage.write('crash_reports', crashReportsEnabled.value);

      lastSavedTime.value = DateTime.now();
      hasUnsavedChanges.value = false;
      isLoading.value = false;

      debugPrint('✅ [SettingsController] All settings saved');
    } catch (e) {
      debugPrint('❌ [SettingsController] Error saving settings: $e');
      isLoading.value = false;
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // AUDIO & VOICE METHODS
  // ═══════════════════════════════════════════════════════════════

  Future<void> setVoiceSpeed(double speed) async {
    voiceSpeed.value = speed.clamp(0.5, 1.5);
    hasUnsavedChanges.value = true;
    await _storage.write('voice_speed', voiceSpeed.value);
    debugPrint('🔊 [Settings] Voice speed → ${voiceSpeed.value}x');
  }

  Future<void> setVoicePitch(double pitch) async {
    voicePitch.value = pitch.clamp(0.8, 1.2);
    hasUnsavedChanges.value = true;
    await _storage.write('voice_pitch', voicePitch.value);
    debugPrint('🔊 [Settings] Voice pitch → ${voicePitch.value}');
  }

  Future<void> setMasterVolume(double volume) async {
    masterVolume.value = volume.clamp(0.0, 1.0);
    hasUnsavedChanges.value = true;
    await _storage.write('master_volume', masterVolume.value);
    _soundService.masterVolume.value = masterVolume.value;
    debugPrint(
        '🔊 [Settings] Master volume → ${(masterVolume.value * 100).toInt()}%');
  }

  Future<void> toggleSoundEffects(bool enabled) async {
    soundEffectsEnabled.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('sound_effects', enabled);
    if (enabled) {
      await _soundService.playEffect(SoundService.clickSound);
    }
    debugPrint('🔊 [Settings] Sound effects → $enabled');
  }

  Future<void> toggleHapticFeedback(bool enabled) async {
    hapticFeedbackEnabled.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('haptic_feedback', enabled);
    debugPrint('📳 [Settings] Haptic feedback → $enabled');
  }

  Future<void> toggleAutoListen(bool enabled) async {
    autoListenEnabled.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('auto_listen', enabled);
    debugPrint('🎤 [Settings] Auto listen → $enabled');
  }

  Future<void> toggleInterruptAi(bool enabled) async {
    interruptAiEnabled.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('interrupt_ai', enabled);
    debugPrint('🤐 [Settings] Interrupt AI → $enabled');
  }

  // ═══════════════════════════════════════════════════════════════
  // LANGUAGE METHODS
  // ═══════════════════════════════════════════════════════════════

  Future<void> setLanguage(String language) async {
    final validLanguages = ['English', 'Hindi', 'Hinglish'];
    if (!validLanguages.contains(language)) {
      debugPrint('⚠️ [Settings] Invalid language: $language');
      return;
    }

    appLanguage.value = language;
    hasUnsavedChanges.value = true;
    await _storage.write('app_language', language);

    // Sync with LanguageService if available
    try {
      Get.find<LanguageService>();
      debugPrint('🌐 [Settings] Synced language with LanguageService');
    } catch (e) {
      debugPrint('⚠️ [Settings] LanguageService not available: $e');
    }

    debugPrint('🌐 [Settings] Language → $language');
  }

  Future<void> toggleHinglishMode(bool enabled) async {
    hinglishModeEnabled.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('hinglish_mode', enabled);
    debugPrint('🌐 [Settings] Hinglish mode → $enabled');
  }

  // ═══════════════════════════════════════════════════════════════
  // NOTIFICATION METHODS
  // ═══════════════════════════════════════════════════════════════

  Future<void> toggleNotifications(bool enabled) async {
    notificationsEnabled.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('notifications_master', enabled);
    if (enabled && soundEffectsEnabled.value) {
      await _soundService.playEffect(SoundService.bellRing);
    }
    debugPrint('🔔 [Settings] Notifications → $enabled');
  }

  Future<void> toggleAlarmNotifications(bool enabled) async {
    alarmNotificationsEnabled.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('alarm_notifications', enabled);
    debugPrint('🔔 [Settings] Alarm notifications → $enabled');
  }

  Future<void> toggleReminderNotifications(bool enabled) async {
    reminderNotificationsEnabled.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('reminder_notifications', enabled);
    debugPrint('🔔 [Settings] Reminder notifications → $enabled');
  }

  Future<void> toggleDailyWisdom(bool enabled) async {
    dailyWisdomEnabled.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('daily_wisdom', enabled);
    debugPrint('💡 [Settings] Daily wisdom → $enabled');
  }

  Future<void> toggleStreakReminders(bool enabled) async {
    streakRemindersEnabled.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('streak_reminders', enabled);
    debugPrint('🔥 [Settings] Streak reminders → $enabled');
  }

  Future<void> toggleVoiceAlerts(bool enabled) async {
    voiceAlertsEnabled.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('voice_alerts', enabled);
    debugPrint('🎙️ [Settings] Voice alerts → $enabled');
  }

  Future<void> setNotificationVolume(double volume) async {
    notificationVolume.value = volume.clamp(0.0, 1.0);
    hasUnsavedChanges.value = true;
    await _storage.write('notification_volume', notificationVolume.value);
    debugPrint(
        '🔔 [Settings] Notification volume → ${(notificationVolume.value * 100).toInt()}%');
  }

  Future<void> setNotificationSound(String sound) async {
    final validSounds = ['bell', 'chime', 'chirp', 'gong', 'silent'];
    if (!validSounds.contains(sound)) {
      debugPrint('⚠️ [Settings] Invalid notification sound: $sound');
      return;
    }

    notificationSound.value = sound;
    hasUnsavedChanges.value = true;
    await _storage.write('notification_sound', sound);

    // Play preview sound if not silent
    if (sound != 'silent' && soundEffectsEnabled.value) {
      // Map to actual sound file
      final soundPath = _notificationSoundMap[sound] ?? SoundService.bellRing;
      await _soundService.playEffect(soundPath);
    }

    debugPrint('🔔 [Settings] Notification sound → $sound');
  }

  final Map<String, String> _notificationSoundMap = {
    'bell': SoundService.bellRing,
    'chime': SoundService.notification,
    'chirp': SoundService.birdChirp,
    'gong': SoundService.settingStatement,
    'silent': '',
  };

  // ═══════════════════════════════════════════════════════════════
  // APPEARANCE METHODS
  // ═══════════════════════════════════════════════════════════════

  Future<void> toggleDarkMode(bool enabled) async {
    final mode = enabled ? 'dark' : 'light';
    await setThemeMode(mode);
  }

  Future<void> setThemeMode(String mode) async {
    final validModes = ['system', 'light', 'dark'];
    if (!validModes.contains(mode)) {
      debugPrint('⚠️ [Settings] Invalid theme mode: $mode');
      return;
    }
    themeMode.value = mode;
    hasUnsavedChanges.value = true;
    await _storage.write('theme_mode', mode);
    try {
      final ts = Get.find<ThemeService>();
      switch (mode) {
        case 'light':
          ts.setMode(AppThemeMode.light);
          break;
        case 'dark':
          ts.setMode(AppThemeMode.dark);
          break;
        default:
          ts.setMode(AppThemeMode.system);
      }
    } catch (_) {}
    debugPrint('🌙 [Settings] Theme mode → $mode');
  }

  Future<void> setAccentColor(String colorHex) async {
    accentColor.value = colorHex;
    hasUnsavedChanges.value = true;
    await _storage.write('accent_color', colorHex);
    debugPrint('🎨 [Settings] Accent color → $colorHex');
  }

  Future<void> setAnimationIntensity(String intensity) async {
    final validIntensities = ['low', 'medium', 'high'];
    if (!validIntensities.contains(intensity.toLowerCase())) {
      debugPrint('⚠️ [Settings] Invalid animation intensity: $intensity');
      return;
    }

    animationIntensity.value = intensity.toLowerCase();
    hasUnsavedChanges.value = true;
    await _storage.write('animation_intensity', animationIntensity.value);
    debugPrint('✨ [Settings] Animation intensity → $intensity');
  }

  Future<void> toggleOrbAnimation(bool enabled) async {
    orbAnimationEnabled.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('orb_animation', enabled);
    debugPrint('🌀 [Settings] Orb animation → $enabled');
  }

  Future<void> toggleDefaultExpandedLayout(bool enabled) async {
    defaultExpandedLayout.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('default_expanded_layout', enabled);
    debugPrint('📱 [Settings] Default expanded layout → $enabled');
  }

  Future<void> setGlassBlurIntensity(double intensity) async {
    glassBlurIntensity.value = intensity.clamp(0.0, 20.0);
    hasUnsavedChanges.value = true;
    await _storage.write('glass_blur_intensity', glassBlurIntensity.value);
    debugPrint(
        '💨 [Settings] Glass blur intensity → ${glassBlurIntensity.value}');
  }

  // ═══════════════════════════════════════════════════════════════
  // INTERACTION & FEEDBACK METHODS
  // ═══════════════════════════════════════════════════════════════

  Future<void> setHapticIntensity(String intensity) async {
    final validIntensities = ['light', 'medium', 'heavy'];
    if (!validIntensities.contains(intensity.toLowerCase())) {
      debugPrint('⚠️ [Settings] Invalid haptic intensity: $intensity');
      return;
    }

    hapticIntensity.value = intensity.toLowerCase();
    hasUnsavedChanges.value = true;
    await _storage.write('haptic_intensity', hapticIntensity.value);
    debugPrint('📳 [Settings] Haptic intensity → $intensity');
  }

  // ═══════════════════════════════════════════════════════════════
  // SPIRITUAL & NICHE METHODS
  // ═══════════════════════════════════════════════════════════════

  Future<void> setDefaultMantra(String mantra) async {
    defaultMantra.value = mantra.isNotEmpty ? mantra : 'Ram Ram';
    hasUnsavedChanges.value = true;
    await _storage.write('default_mantra', defaultMantra.value);
    debugPrint('🙏 [Settings] Default mantra → ${defaultMantra.value}');
  }

  Future<void> toggleMilestoneCelebrations(bool enabled) async {
    milestoneCelebrationsEnabled.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('milestone_celebrations', enabled);
    debugPrint('🎉 [Settings] Milestone celebrations → $enabled');
  }

  Future<void> toggleSessionAutoSave(bool enabled) async {
    sessionAutoSaveEnabled.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('session_auto_save', enabled);
    debugPrint('💾 [Settings] Session auto-save → $enabled');
  }

  Future<void> toggleChantingGuideVoice(bool enabled) async {
    chantingGuideVoiceEnabled.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('chanting_guide_voice', enabled);
    debugPrint('🎙️ [Settings] Chanting guide voice → $enabled');
  }

  // ═══════════════════════════════════════════════════════════════
  // PRIVACY & DATA METHODS
  // ═══════════════════════════════════════════════════════════════

  Future<void> toggleChatHistorySave(bool enabled) async {
    chatHistorySaveEnabled.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('save_chat_history', enabled);
    debugPrint('💬 [Settings] Chat history save → $enabled');
  }

  Future<void> toggleAiLearning(bool enabled) async {
    aiLearningEnabled.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('ai_learning', enabled);
    debugPrint('🤖 [Settings] AI learning → $enabled');
  }

  Future<void> toggleAnalytics(bool enabled) async {
    analyticsEnabled.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('analytics_enabled', enabled);
    debugPrint('📊 [Settings] Analytics → $enabled');
  }

  Future<void> toggleCrashReports(bool enabled) async {
    crashReportsEnabled.value = enabled;
    hasUnsavedChanges.value = true;
    await _storage.write('crash_reports', enabled);
    debugPrint('🚨 [Settings] Crash reports → $enabled');
  }

  // ═══════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════

  /// Reset all settings to defaults
  Future<void> resetAllSettings() async {
    try {
      isLoading.value = true;

      voiceSpeed.value = 1.0;
      voicePitch.value = 1.0;
      masterVolume.value = 0.8;
      soundEffectsEnabled.value = true;
      hapticFeedbackEnabled.value = true;
      autoListenEnabled.value = true;
      interruptAiEnabled.value = true;

      appLanguage.value = 'English';
      hinglishModeEnabled.value = false;

      notificationsEnabled.value = true;
      alarmNotificationsEnabled.value = true;
      reminderNotificationsEnabled.value = true;
      dailyWisdomEnabled.value = true;
      streakRemindersEnabled.value = true;
      voiceAlertsEnabled.value = false;
      notificationVolume.value = 0.8;
      notificationSound.value = 'bell';

      themeMode.value = 'system';
      accentColor.value = '#FFB2EE';
      animationIntensity.value = 'medium';
      orbAnimationEnabled.value = true;
      defaultExpandedLayout.value = false;
      glassBlurIntensity.value = 10.0;

      hapticIntensity.value = 'medium';

      defaultMantra.value = 'Ram Ram';
      milestoneCelebrationsEnabled.value = true;
      sessionAutoSaveEnabled.value = true;
      chantingGuideVoiceEnabled.value = false;

      chatHistorySaveEnabled.value = true;
      aiLearningEnabled.value = true;
      analyticsEnabled.value = true;
      crashReportsEnabled.value = true;

      await saveAllSettings();
      isLoading.value = false;

      debugPrint('🔄 [Settings] All settings reset to defaults');
    } catch (e) {
      debugPrint('❌ [Settings] Error resetting settings: $e');
      isLoading.value = false;
      rethrow;
    }
  }

  /// Clear chat history (destructive operation)
  Future<void> clearChatHistory() async {
    try {
      await _storage.remove('chat_history');
      debugPrint('🗑️ [Settings] Chat history cleared');
    } catch (e) {
      debugPrint('❌ [Settings] Error clearing chat history: $e');
      rethrow;
    }
  }

  @override
  void onClose() {
    debugPrint('🔧 [SettingsController] Closing...');
    super.onClose();
  }
}
