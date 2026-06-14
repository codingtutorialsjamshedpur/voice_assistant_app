import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';
import '../services/sound_service.dart';
import '../services/history_logger_service.dart';
import '../models/reminder_model.dart';

/// ═══════════════════════════════════════════════════════════════
/// Reminder Service - Full Business Logic
/// ═══════════════════════════════════════════════════════════════
///
/// Handles:
/// - CRUD operations for reminders
/// - Persistence via StorageService
/// - Real-time reminder checking
/// - Voice announcements via TTS
/// - Progress tracking
///
class ReminderService extends GetxService {
  static ReminderService get to => Get.find();

  // Observable reminders list
  final reminders = <Reminder>[].obs;

  // Today's progress
  final todayCompleted = 0.obs;
  final todayTotal = 0.obs;

  // Timer for checking reminders
  Timer? _reminderCheckTimer;

  // Services
  late final TTSService _ttsService;

  // Track which reminders have been announced today
  final Set<String> _announcedToday = {};

  @override
  void onInit() {
    super.onInit();
    _initializeService();
  }

  /// Initialize the service
  Future<void> _initializeService() async {
    try {
      _ttsService = Get.find<TTSService>();
    } catch (_) {
      debugPrint('⚠️ TTS Service not available for reminders');
    }

    // Load reminders from storage
    await loadReminders();

    // Start reminder checker
    _startReminderChecker();

    // Calculate initial progress
    _updateProgress();

    // Reset announced set at midnight
    _scheduleMidnightReset();

    debugPrint('✅ Reminder Service Initialized');
  }

  /// Load reminders from storage
  Future<void> loadReminders() async {
    try {
      final data = StorageService.to.read(StorageService.reminders);
      if (data != null) {
        final List<dynamic> list = data;
        reminders.value = list.map((json) => Reminder.fromJson(json)).toList();
        _updateProgress();
        debugPrint('📋 Loaded ${reminders.length} reminders');
      }
    } catch (e) {
      debugPrint('❌ Error loading reminders: $e');
    }
  }

  /// Save reminders to storage
  Future<void> _saveReminders() async {
    try {
      final list = reminders.map((r) => r.toJson()).toList();
      await StorageService.to.write(StorageService.reminders, list);
      _updateProgress();
      debugPrint('💾 Saved ${reminders.length} reminders');
    } catch (e) {
      debugPrint('❌ Error saving reminders: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// CRUD OPERATIONS
  /// ═══════════════════════════════════════════════════════════

  /// Add a new reminder
  Future<void> addReminder(Reminder reminder) async {
    reminders.add(reminder);
    await _saveReminders();

    await HistoryLoggerService().logReminderActivity(
      action: 'created',
      reminderName: reminder.title,
    );

    await SoundService.to.playSuccess();
    debugPrint('➕ Added reminder: ${reminder.title}');
  }

  /// Update an existing reminder
  Future<void> updateReminder(String id, Reminder updatedReminder) async {
    final index = reminders.indexWhere((r) => r.id == id);
    if (index != -1) {
      reminders[index] = updatedReminder;
      await _saveReminders();

      await HistoryLoggerService().logReminderActivity(
        action: 'edited',
        reminderName: updatedReminder.title,
      );

      await SoundService.to.playSuccess();
      debugPrint('✏️ Updated reminder: ${updatedReminder.title}');
    }
  }

  /// Delete a reminder
  Future<void> deleteReminder(String id) async {
    final reminder = reminders.firstWhereOrNull((r) => r.id == id);
    final reminderTitle = reminder?.title;
    reminders.removeWhere((r) => r.id == id);
    await _saveReminders();

    await HistoryLoggerService().logReminderActivity(
      action: 'deleted',
      reminderName: reminderTitle,
    );

    await SoundService.to.playClick();
    debugPrint('🗑️ Deleted reminder: $id');
  }

  /// Toggle reminder completion status
  Future<void> toggleComplete(String id) async {
    final index = reminders.indexWhere((r) => r.id == id);
    if (index != -1) {
      final reminder = reminders[index];
      final isNowCompleted = !reminder.isCompleted;

      reminders[index] = reminder.copyWith(
        isCompleted: isNowCompleted,
        completedAt: isNowCompleted ? DateTime.now() : null,
      );

      await _saveReminders();

      if (isNowCompleted) {
        await SoundService.to.playSuccess();
      } else {
        await SoundService.to.playClick();
      }

      debugPrint(
          '${isNowCompleted ? "✅" : "⬜"} Toggled reminder: ${reminder.title}');
    }
  }

  /// Toggle reminder enabled status
  Future<void> toggleEnabled(String id) async {
    final index = reminders.indexWhere((r) => r.id == id);
    if (index != -1) {
      final reminder = reminders[index];
      reminders[index] = reminder.copyWith(isEnabled: !reminder.isEnabled);
      await _saveReminders();
      await SoundService.to.playClick();
    }
  }

  /// Get a reminder by ID
  Reminder? getReminderById(String id) {
    try {
      return reminders.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// PROGRESS TRACKING
  /// ═══════════════════════════════════════════════════════════

  /// Update today's progress
  void _updateProgress() {
    final todayReminders = reminders.where((r) {
      // Count all active reminders for today
      return r.isEnabled;
    }).toList();

    todayTotal.value = todayReminders.length;
    todayCompleted.value = todayReminders.where((r) => r.isCompleted).length;
  }

  /// Get progress percentage (0.0 to 1.0)
  double get progressPercentage {
    if (todayTotal.value == 0) return 0.0;
    return todayCompleted.value / todayTotal.value;
  }

  /// Get progress text (e.g., "1/4 Completed")
  String get progressText {
    return '$todayCompleted/$todayTotal Completed';
  }

  /// ═══════════════════════════════════════════════════════════
  /// VOICE ANNOUNCEMENTS
  /// ═══════════════════════════════════════════════════════════

  /// Announce a reminder using TTS
  Future<void> announceReminder(Reminder reminder) async {
    if (_announcedToday.contains(reminder.id)) {
      debugPrint('🔇 Already announced today: ${reminder.title}');
      return;
    }

    try {
      // Play notification sound
      await SoundService.to.playEffect('sounds/notification.mp3');

      // Speak the announcement
      await _ttsService.speak(reminder.voiceAnnouncement);

      // Mark as announced
      _announcedToday.add(reminder.id);

      debugPrint('🔊 Announced: ${reminder.title}');
    } catch (e) {
      debugPrint('❌ Error announcing reminder: $e');
    }
  }

  /// Check and announce due reminders (called periodically)
  Future<void> checkAndAnnounceReminders() async {
    for (final reminder in reminders) {
      if (reminder.shouldTriggerNow()) {
        // Check if not already announced in the last minute
        if (!_announcedToday.contains(reminder.id)) {
          await announceReminder(reminder);
        }
      }
    }
  }

  /// Get all active reminders for today (for voice queries)
  List<Reminder> getTodaysActiveReminders() {
    return reminders.where((r) => r.isActiveToday).toList()
      ..sort((a, b) => a.nextOccurrence.compareTo(b.nextOccurrence));
  }

  /// Get upcoming reminder (next one to trigger)
  Reminder? getUpcomingReminder() {
    final active = getTodaysActiveReminders();
    if (active.isEmpty) return null;
    return active.first;
  }

  /// Get reminders formatted for voice response
  String getRemindersForVoiceResponse() {
    final active = getTodaysActiveReminders();

    if (active.isEmpty) {
      return 'You have no active reminders for today.';
    }

    if (active.length == 1) {
      final r = active.first;
      return 'You have one reminder: ${r.title} at ${r.formattedTime}.';
    }

    final buffer = StringBuffer('You have ${active.length} reminders today: ');
    for (int i = 0; i < active.length; i++) {
      final r = active[i];
      if (i == active.length - 1) {
        buffer.write('and ${r.title} at ${r.formattedTime}.');
      } else {
        buffer.write('${r.title} at ${r.formattedTime}, ');
      }
    }

    return buffer.toString();
  }

  /// ═══════════════════════════════════════════════════════════
  /// BACKGROUND CHECKING
  /// ═══════════════════════════════════════════════════════════

  /// Start the periodic reminder checker
  void _startReminderChecker() {
    // Check every 30 seconds
    _reminderCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => checkAndAnnounceReminders(),
    );

    debugPrint('⏰ Reminder checker started (30s interval)');
  }

  /// Schedule reset of announced set at midnight
  void _scheduleMidnightReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final durationUntilMidnight = tomorrow.difference(now);

    Timer(durationUntilMidnight, () {
      _announcedToday.clear();
      _resetAllDailyCompletions();
      _scheduleMidnightReset(); // Reschedule for next day
    });
  }

  /// Reset all completions at midnight for daily reminders
  Future<void> _resetAllDailyCompletions() async {
    bool hasChanges = false;

    for (int i = 0; i < reminders.length; i++) {
      if (reminders[i].isCompleted) {
        reminders[i] = reminders[i].copyWith(
          isCompleted: false,
          completedAt: null,
        );
        hasChanges = true;
      }
    }

    if (hasChanges) {
      await _saveReminders();
      debugPrint('🌅 Reset all daily completions');
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// UTILITY
  /// ═══════════════════════════════════════════════════════════

  /// Get reminders by category
  List<Reminder> getRemindersByCategory(String category) {
    return reminders.where((r) => r.category == category).toList();
  }

  /// Get completed reminders count
  int get completedCount => reminders.where((r) => r.isCompleted).length;

  /// Get pending reminders count
  int get pendingCount =>
      reminders.where((r) => !r.isCompleted && r.isEnabled).length;

  @override
  void onClose() {
    _reminderCheckTimer?.cancel();
    super.onClose();
  }
}
