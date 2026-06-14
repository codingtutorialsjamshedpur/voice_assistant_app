// Enhanced Greeting & Idle Engagement Service - PHASE 1, 2, 3
// Ensures proper message flow with user on chat screen
// Greets user with 3 main messages, then idle pokes with unpredictability
// PHASE 1: Gender-aware, Day-of-week, Enhanced time-of-day greetings
// PHASE 2: Activity-based, Weather-based, Personality-matched, Last visit tracking
// PHASE 3: AI-generated, Mood-detection, Achievement tracking

import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/voice_controller.dart';
import '../controllers/profile_controller.dart';
import '../models/profile_model.dart';
import '../shared/controllers/top_panel_controller.dart';
import '../controllers/language_controller.dart';
import 'translation_service.dart';
import 'ruflo_service.dart';
import 'storage_service.dart';
import 'idle_prompt_service.dart';
import '../controllers/alarm_controller.dart';
import 'festival_service.dart';

// ════════════════════════════════════════════════════════════════════════════════
// MESSAGE QUEUE ITEM - For sequential, non-overlapping message delivery
// ════════════════════════════════════════════════════════════════════════════════
class MessageQueueItem {
  final String text;
  final String source;
  final bool isBadgeMessage;
  final int? badgeCount;

  MessageQueueItem({
    required this.text,
    required this.source,
    this.isBadgeMessage = false,
    this.badgeCount,
  });
}

class EnhancedGreetingService extends GetxService {
  static EnhancedGreetingService get to => Get.find();
  final _ruflo = RuFloService();

  // State
  final RxBool hasStartedGreeting = false.obs;
  final RxInt messageCount = 0.obs;
  final RxInt idlePokeCount = 0.obs;
  final RxBool isWaitingForTopPanelData = false.obs;
  final RxInt unreadMessageBadge = 0.obs;
  final RxBool showFirstMessage = false.obs;
  final RxBool isProcessingMessageQueue = false.obs;

  // NEW: Track if system messages have been shown in this session
  static bool _hasShownSystemMessagesThisSession = false;

  /// Reset session flag for testing purposes only
  static void resetSessionFlag() {
    _hasShownSystemMessagesThisSession = false;
    debugPrint('🔄 [EnhancedGreeting] Session flag reset for testing');
  }

  Timer? _message2Timer;
  Timer? _message3Timer;
  Timer? _idlePokeTimer;
  Timer? _topPanelWaitTimer;

  VoiceController? _voiceController;
  ProfileController? _profileController;
  TopPanelController? _topPanelController;

  // Idle poke state
  DateTime _lastUserInteractionTime = DateTime.now();
  int _consecutiveIdlePokeCount = 0;
  int _userQueryCount = 0; // Track how many times the user has queried

  // Message queue system for sequential, non-overlapping delivery
  final Queue<MessageQueueItem> _messageQueue = Queue();
  bool _isProcessingQueue = false;

  // Phase 4 & 5: State-based Intelligence Layer
  final List<String> _userQueriesHistory = [];
  final List<String> _derivedMessagesHistory = [];
  final Set<String> _usedDerivedPairs = {}; // hash memory
  int _lastProcessedUserQueryIndex = 0;
  DateTime? _lastDerivedMessageTime;

  final Set<String> _recentPrompts = {}; // Prevent repetition within 2 hours
  final Set<String> _usedProbeIndices =
      {}; // Track used curiosity probe indices
  final Set<String> _usedIdleIndices = {}; // Track used idle poke indices

  // PHASE 2: Tracking variables for Visit Frequency & Activity
  late SharedPreferences _prefs;
  int _visitCountToday = 0;

  // PHASE 3: Achievement tracking
  int _sessionCount = 0;
  int _daysActiveStreak = 0;

  @override
  void onClose() {
    _cancelAllTimers();
    super.onClose();
  }

  /// Call this when user navigates back to chat screen to re-run greetings
  /// NOTE: Does NOT reset session flag to prevent repetitive system messages
  void resetForReentry() {
    _cancelAllTimers();
    hasStartedGreeting.value = false;
    messageCount.value = 0;
    idlePokeCount.value = 0;
    isWaitingForTopPanelData.value = false;
    _consecutiveIdlePokeCount = 0;
    _userQueryCount = 0;
    _userQueriesHistory.clear();
    _derivedMessagesHistory.clear();
    _usedDerivedPairs.clear();
    _lastProcessedUserQueryIndex = 0;
    _lastDerivedMessageTime = null;
    _recentPrompts.clear();
    _usedProbeIndices.clear();
    _usedIdleIndices.clear();
    _lastUserInteractionTime = DateTime.now();

    // IMPORTANT: Do NOT reset _hasShownSystemMessagesThisSession here
    // This prevents system messages from repeating when navigating between screens

    debugPrint(
        '🔄 [EnhancedGreeting] Reset for re-entry (session flag preserved)');
  }

  /// Pause the service (e.g. when entering a game screen)
  void pauseService() {
    _cancelAllTimers();
    if (_isProcessingQueue) {
      _messageQueue.clear();
      _isProcessingQueue = false;
      isProcessingMessageQueue.value = false;
    }
    debugPrint('⏸️ [EnhancedGreeting] Service paused');
  }

  /// Resume the service
  void resumeService() {
    debugPrint('▶️ [EnhancedGreeting] Service resumed');
    _lastUserInteractionTime = DateTime.now();
    if (hasStartedGreeting.value) {
      _startIdlePoking();
    }
  }

  void _cancelAllTimers() {
    _message2Timer?.cancel();
    _message3Timer?.cancel();
    _idlePokeTimer?.cancel();
    _topPanelWaitTimer?.cancel();
  }

  /// Wait until the currently speaking message (TTS) finishes.
  ///
  /// Prevents Message 3 from starting early when Message 2 TTS takes longer
  /// than the estimated timer-based delay.
  Future<void> _waitUntilTtsFinished({
    required String sourceGuard,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final vc = _voiceController;
    if (vc == null) return;

    final startedAt = DateTime.now();

    // Give TTS a short moment to flip isTalking/isLoading if it was queued.
    if (!vc.isTalking.value && !vc.isLoading.value) {
      await Future.delayed(const Duration(milliseconds: 150));
    }

    while (vc.isTalking.value || vc.isLoading.value) {
      if (DateTime.now().difference(startedAt) > timeout) {
        debugPrint(
            '⚠️ [EnhancedGreeting] _waitUntilTtsFinished timeout after ${timeout.inSeconds}s (guard=$sourceGuard)');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  /// Initialize greeter when user enters chat screen
  /// This must be called AFTER the chat screen is fully visible
  Future<void> initializeGreetings() async {
    if (hasStartedGreeting.value) {
      debugPrint(
          '⚠️ [EnhancedGreeting] Already started, skipping reinitialize');
      return;
    }

    try {
      _voiceController = Get.find<VoiceController>();
      _profileController = Get.find<ProfileController>();
      _topPanelController = Get.find<TopPanelController>();

      // PHASE 2: Initialize SharedPreferences for tracking
      _prefs = await SharedPreferences.getInstance();
      await _loadTrackingData();

      hasStartedGreeting.value = true;
      debugPrint(
          '✅ [EnhancedGreeting] Service initialized (PHASE 1-3 enabled)');

      // Start greeting flow
      await _startGreetingFlow();
    } catch (e) {
      debugPrint('❌ [EnhancedGreeting] Initialization error: $e');
    }
  }

  /// PHASE 2: Load tracking data from SharedPreferences
  Future<void> _loadTrackingData() async {
    try {
      final today = DateTime.now().toString().split(' ')[0]; // YYYY-MM-DD
      final lastVisitDateStr = _prefs.getString('lastVisitDate');

      // Check if today is a new day
      if (lastVisitDateStr != today) {
        _visitCountToday = 0; // Reset counter for new day
        await _prefs.setString('lastVisitDate', today);
      } else {
        _visitCountToday = _prefs.getInt('visitCountToday') ?? 0;
      }

      _sessionCount = _prefs.getInt('sessionCount') ?? 0;
      _daysActiveStreak = _prefs.getInt('daysActiveStreak') ?? 1;

      debugPrint(
          '📊 [EnhancedGreeting] Loaded: visits=$_visitCountToday, sessions=$_sessionCount, streak=$_daysActiveStreak');
    } catch (e) {
      debugPrint('⚠️ [EnhancedGreeting] Could not load tracking data: $e');
    }
  }

  /// PHASE 2: Save tracking data to SharedPreferences
  Future<void> _saveTrackingData() async {
    try {
      _visitCountToday++;
      await _prefs.setInt('visitCountToday', _visitCountToday);
      await _prefs.setString('lastVisitTime', DateTime.now().toIso8601String());
      await _prefs.setInt('sessionCount', _sessionCount + 1);
      await _prefs.setInt('daysActiveStreak', _daysActiveStreak);
    } catch (e) {
      debugPrint('⚠️ [EnhancedGreeting] Could not save tracking data: $e');
    }
  }

  /// CRITICAL FIX: Setup interaction tracking for idle detection
  /// Listens to user messages and updates last interaction time
  void _setupInteractionTracking() {
    try {
      if (_voiceController == null) {
        debugPrint(
            '⚠️ [EnhancedGreeting] VoiceController unavailable for tracking');
        return;
      }

      // Listen to messages and track when user interacts
      ever(_voiceController!.messages, (messages) {
        if (messages.isNotEmpty) {
          final lastMsg = messages.last;
          if (lastMsg.role == 'user') {
            _lastUserInteractionTime = lastMsg.timestamp;
            _userQueryCount++;
            _userQueriesHistory.add(lastMsg.content);
            debugPrint(
                '📍 [EnhancedGreeting] Query added to history: ${lastMsg.content}. Total: $_userQueryCount');
          }
        }
      });

      debugPrint('✅ [EnhancedGreeting] Interaction tracking initialized');
    } catch (e) {
      debugPrint('❌ [EnhancedGreeting] Interaction tracking setup failed: $e');
    }
  }

  /// ════════════════════════════════════════════════════════════════════════════════
  /// SMART GREETING FLOW - Prevents repetitive system messages
  /// NEW USER: Shows system messages (once only)
  /// RETURNING USER: Shows only personalized welcome (name, weather, etc.)
  /// Calculate speech duration based on word count
  /// Formula: 35 words ≈ 20 seconds → 1 word ≈ 0.57 seconds (20/35)
  /// ════════════════════════════════════════════════════════════════════════════════
  int _calculateSpeechDurationSeconds(String message) {
    // Count words (split by whitespace and remove emojis/symbols)
    final cleanMessage = message.replaceAll(RegExp(r'[^\w\s]'), ' ');
    final wordCount = cleanMessage
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;

    // Formula: 35 words = 20 seconds → duration = (wordCount / 35) * 20
    final durationSeconds = ((wordCount / 35) * 20).ceil();

    debugPrint(
        '📊 [EnhancedGreeting] Message: $wordCount words ≈ ${durationSeconds}s to read');
    return durationSeconds;
  }

  /// SAME SESSION: No system messages when returning from other screens
  /// ════════════════════════════════════════════════════════════════════════════════
  Future<void> _startGreetingFlow() async {
    try {
      final profile = _profileController?.userProfile.value;
      if (profile == null) {
        debugPrint('⚠️ [EnhancedGreeting] Profile not loaded');
        return;
      }

      _setupInteractionTracking();

      late bool isFirstTimeVoiceChatUser;
      try {
        final storageService = Get.find<StorageService>();
        isFirstTimeVoiceChatUser = !storageService.hasVisitedVoiceChat;
        debugPrint(
            '🔍 [EnhancedGreeting] isFirstTimeVoiceChatUser: $isFirstTimeVoiceChatUser');
      } catch (e) {
        isFirstTimeVoiceChatUser = _sessionCount <= 1;
        debugPrint(
            '⚠️ [EnhancedGreeting] StorageService error, fallback isFirstTimeVoiceChatUser: $isFirstTimeVoiceChatUser');
      }

      final bool sessionAlreadyShown = _hasShownSystemMessagesThisSession;
      debugPrint(
          '🔍 [EnhancedGreeting] sessionAlreadyShown: $sessionAlreadyShown');

      if (sessionAlreadyShown) {
        // Re-entry: skip all 3 messages, go directly to idle poke loop
        debugPrint(
            '🔄 [EnhancedGreeting] Session already shown, skipping to idle pokes');
        _startIdlePoking();
        return;
      }

      _hasShownSystemMessagesThisSession = true;
      debugPrint(
          '✅ [EnhancedGreeting] Starting greeting flow - isFirstTimeVoiceChat: $isFirstTimeVoiceChatUser');

      // ═══════════════════════════════════════════════════════════════════════════════
      // MESSAGE 1: Always show (new + returning)
      // ═══════════════════════════════════════════════════════════════════════════════
      final message1 = _buildMessage1PersonalizedWelcome(profile);
      await _sendMessage1PersonalizedWelcome(profile);
      messageCount.value = 1;
      final message1Duration = _calculateSpeechDurationSeconds(message1);
      final message1TotalDelay = message1Duration + 20;
      debugPrint(
          '✅ [EnhancedGreeting] Message 1 sent (${message1Duration}s read + 20s gap = ${message1TotalDelay}s total)');

      if (isFirstTimeVoiceChatUser) {
        // ═════════════════════════════════════════════════════════════════════════════
        // NEW USER: Message 2 after Message 1 completes
        // (Do not rely on estimated duration; wait for real TTS end)
        // ═════════════════════════════════════════════════════════════════════════════
        debugPrint(
            '🎯 [EnhancedGreeting] NEW USER - waiting for Message 1 TTS to finish before Message 2');
        await _waitUntilTtsFinished(sourceGuard: 'Welcome1');

        // Send Message 2
        final message2 = _buildMessage2FeaturesOverview();
        await _sendMessage2FeaturesOverview();
        messageCount.value = 2;
        debugPrint('✅ [EnhancedGreeting] Message 2 sent');

        // Mark user as having visited voice chat
        try {
          final storageService = Get.find<StorageService>();
          await storageService.setHasVisitedVoiceChat(true);
          debugPrint(
              '✅ [EnhancedGreeting] User marked as having visited voice chat');
        } catch (e) {
          debugPrint(
              '⚠️ [EnhancedGreeting] Error marking voice chat visit: $e');
        }

        // ═══════════════════════════════════════════════════════════════════════════
        // NEW USER: Message 3 after Message 2 completes (wait for real TTS end)
        // ═══════════════════════════════════════════════════════════════════════════
        debugPrint(
            '⏰ [EnhancedGreeting] NEW USER - waiting for Message 2 TTS to finish before Message 3');
        await _waitUntilTtsFinished(sourceGuard: 'Features Overview');
        await _trySendMessage3EnvironmentalData();
      } else {
        // ═════════════════════════════════════════════════════════════════════════════
        // RETURNING USER: Skip Message 2, go directly to Message 3
        // ═════════════════════════════════════════════════════════════════════════════
        debugPrint('👤 [EnhancedGreeting] RETURNING USER - skipping Message 2');
        debugPrint(
            '⏰ [EnhancedGreeting] RETURNING USER - scheduling Message 3 after ${message1TotalDelay}s');
        await Future.delayed(Duration(seconds: message1TotalDelay));
        await _trySendMessage3EnvironmentalData();
      }

      // ── Morning Briefing (6am-10am only) ─────────────────────────
      try {
        final briefing = await getMorningBriefing(profile.id);
        if (briefing != null) {
          await Future.delayed(const Duration(seconds: 3));
          _addAndSpeakMessage(briefing, 'Morning Briefing');
        }
      } catch (_) {}

      // Start idle poking after messages
      Timer(const Duration(seconds: 5), () {
        _startIdlePoking();
      });

      await _saveTrackingData();
    } catch (e) {
      debugPrint('❌ [EnhancedGreeting] Flow error: $e');
    }
  }

  /// Build Message 1 text (without sending it)
  String _buildMessage1PersonalizedWelcome(UserProfile profile) {
    final String name = profile.name.isNotEmpty ? profile.name : 'User';
    final String timeGreeting = _getTimeOfDay();
    final String partOfDay = _getPartOfDay();

    // Check for festivals
    final festival = FestivalService.getFestivalForDate(DateTime.now());

    if (festival != null) {
      final random = Random();
      final greeting = festival.greetingVariations[
          random.nextInt(festival.greetingVariations.length)];
      final question = FestivalService.getQuestion(festival, partOfDay);

      return '''$greeting $name!
$timeGreeting — have a wonderful $partOfDay!

$question''';
    }

    return '''Welcome to CTJ Voice Chat, $name!
$timeGreeting — have a wonderful $partOfDay!''';
  }

  /// Build Message 2 text (without sending it)
  String _buildMessage2FeaturesOverview() {
    return '''🎙️ **CTJ Voice Assistant**

Explore powerful AI, productivity, entertainment, and spiritual tools in one app:

• 🎙️ **Voice Chat** – Talk with AI using voice or text
• 🎮 **Games Hub** – Play 5 voice-enabled games including Tic-Tac-Toe, Ball Sort, Radio & TV World
• 🎵 **Voice Studio** – Record and customize your voice with effects
• 🙏 **Naam Jaap** – Track mantra chanting milestones
• ⏰ **Alarms & Reminders** – Set voice-based reminders and spiritual alarms
• 📜 **History** – View conversations, activities, and progress
• 🖼️ **Wallpapers** – Personalize your app with images and videos
• 🌍 **Language Coach** – Improve pronunciation with AI feedback
• 👤 **Profile** – Manage goals, interests, and learning preferences
• ⚙️ **Settings** – Customize AI, audio, notifications, privacy, and more

💡 **Quick Tips**
• Double-tap AI orb → Expand chat
• Single-tap AI orb → Clear chat
• Use voice input for the best experience
• Explore games, voice tools, and spiritual features

🚀 Learn, play, create, and grow with CTJ Voice Assistant.''';
  }

  Future<void> _sendMessage1PersonalizedWelcome(UserProfile profile) async {
    try {
      final String message = _buildMessage1PersonalizedWelcome(profile);
      await _addAndSpeakMessage(message, 'Welcome1');
      debugPrint('✅ [EnhancedGreeting] Welcome Message 1 sent');
    } catch (e) {
      debugPrint('❌ [EnhancedGreeting] Welcome Message 1 error: $e');
    }
  }

  Future<void> _sendMessage2FeaturesOverview() async {
    try {
      debugPrint(
          '🎯 [EnhancedGreeting] Starting Message 2 (Features Overview)');

      final String message = _buildMessage2FeaturesOverview();

      debugPrint(
          '📝 [EnhancedGreeting] Message 2 content prepared, length: ${message.length}');

      // Check if voice controller is available
      if (_voiceController == null) {
        debugPrint(
            '❌ [EnhancedGreeting] Message 2 failed - VoiceController is null');
        return;
      }

      // Check if TTS is busy
      if (_voiceController!.isTalking.value ||
          _voiceController!.isLoading.value) {
        debugPrint('⚠️ [EnhancedGreeting] Message 2 deferred - TTS is busy');
        // Wait a bit and try again
        await Future.delayed(const Duration(seconds: 3));
        if (_voiceController!.isTalking.value ||
            _voiceController!.isLoading.value) {
          debugPrint(
              '⚠️ [EnhancedGreeting] Message 2 skipped - TTS still busy after wait');
          return;
        }
      }

      await _addAndSpeakMessage(message, 'Features Overview');
      debugPrint(
          '✅ [EnhancedGreeting] Features Overview Message 2 sent successfully');
    } catch (e) {
      debugPrint('❌ [EnhancedGreeting] Features Overview Message 2 error: $e');
      debugPrint('❌ [EnhancedGreeting] Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _trySendMessage3EnvironmentalData() async {
    try {
      final profile = _profileController?.userProfile.value;
      if (profile == null) return;

      final topPanel = _topPanelController;
      if (topPanel == null) return;

      int retries = 0;
      bool isValid = false;

      while (retries <= 3) {
        final String location = topPanel.placeName.value;
        final String temp = topPanel.temperature.value;
        final double tempNum =
            double.tryParse(temp) ?? topPanel.temperatureNum.value;
        final int aqi = topPanel.aqiNum.value;

        if (location.isNotEmpty &&
            location != 'Detecting...' &&
            location != 'your area' &&
            tempNum != 0.0 &&
            aqi != 0) {
          isValid = true;
          break;
        }

        if (retries < 3) {
          await Future.delayed(const Duration(seconds: 5));
        }
        retries++;
      }

      if (!isValid) {
        debugPrint('⚠️ Env data unavailable, Message 3 skipped');
        return;
      }

      final String location = topPanel.placeName.value;
      final double tempNum = topPanel.temperatureNum.value;
      final int aqi = topPanel.aqiNum.value;

      String weatherAdvice = '';
      if (tempNum < 10) {
        weatherAdvice = "It's quite cold outside! Please dress warmly. 🧥";
      } else if (tempNum > 35) {
        weatherAdvice = "It's very hot! Stay hydrated and avoid direct sun. 💧";
      } else {
        weatherAdvice = 'The weather looks pleasant for a walk! 🌿';
      }

      if (aqi > 200) {
        weatherAdvice +=
            ' Air quality is poor — please wear a mask if going outside. 😷';
      } else if (aqi > 100) {
        weatherAdvice += ' Air quality is moderate — be cautious outdoors. 🌫️';
      } else {
        weatherAdvice += ' Air quality is great today! 🌬️';
      }

      final String name = profile.name.isNotEmpty ? profile.name : 'User';
      final String message = '''$name, I can see you're in $location right now.
The temperature is ${tempNum.toInt()}°C and the AQI is $aqi.
$weatherAdvice''';

      await _addAndSpeakMessage(message, 'Environmental Data');
      debugPrint('✅ [EnhancedGreeting] Environmental Data Message 3 sent');
    } catch (e) {
      debugPrint('❌ [EnhancedGreeting] Environmental Data Message 3 error: $e');
    }
  }

  void _startIdlePoking() {
    // Disabled to stop unprompted "unprofessional" queries.
    return;
  }

  void _scheduleNextIdlePoke() {
    _idlePokeTimer?.cancel();
    // Random delay between 70–140 seconds
    final delaySeconds = 70 + Random().nextInt(71);

    _idlePokeTimer = Timer(Duration(seconds: delaySeconds), () async {
      try {
        final voiceCtrl = _voiceController;
        if (voiceCtrl == null) {
          debugPrint(
              '⚠️ [EnhancedGreeting] VoiceController null, stopping idle pokes');
          return;
        }

        // Calculate time since last user interaction
        final secondsSinceInteraction =
            DateTime.now().difference(_lastUserInteractionTime).inSeconds;
        debugPrint(
            '⏱️ [EnhancedGreeting] Idle check: ${secondsSinceInteraction}s since last interaction');

        // Check if user is actually idle (no recent interaction in last 30s as a cooldown)
        if (secondsSinceInteraction < 30) {
          debugPrint('✋ [EnhancedGreeting] User not idle yet, deferring poke');
          // Try again later instead of stopping
          _idlePokeTimer =
              Timer(const Duration(seconds: 30), _scheduleNextIdlePoke);
          return;
        }

        // TTS busy check — Before injecting any derived or idle message, verify !_vc.isTalking.value && !_vc.isLoading.value
        if (voiceCtrl.isTalking.value || voiceCtrl.isLoading.value) {
          debugPrint('✋ [EnhancedGreeting] TTS is busy, deferring poke');
          _idlePokeTimer =
              Timer(const Duration(seconds: 30), _scheduleNextIdlePoke);
          return;
        }

        idlePokeCount.value++;

        const bool derivedMessageSent = false;

        // Cooldown mechanism = 30 seconds minimum between derived messages
        bool cooldownPassed = true;
        if (_lastDerivedMessageTime != null) {
          cooldownPassed =
              DateTime.now().difference(_lastDerivedMessageTime!).inSeconds >=
                  30;
        }

        if (cooldownPassed) {
          // Trigger derivation check removed from here and placed in tracker directly
          // Chain Progression removed as per Feature 3 rules
        }

        if (!derivedMessageSent) {
          // NORMAL IDLE LOOP
          // Smart Query/Random Poke cycle: 0 -> Poke, 1 -> Poke, 2 -> Smart Query, 3 -> Poke, 4 -> Poke, 5 -> Derived...
          // We vary this to make it feel less like a fixed loop
          final int cycle = _consecutiveIdlePokeCount % 4;
          if (cycle == 3) {
            debugPrint(
                '⭐ [EnhancedGreeting] Sending Smart Query (poke #${idlePokeCount.value})');
            await _sendSmartQuery();
          } else {
            debugPrint(
                '💭 [EnhancedGreeting] Sending random poke (poke #${idlePokeCount.value})');
            await _sendRandomIdlePoke();
          }
        }

        _consecutiveIdlePokeCount++;
      } catch (e) {
        debugPrint('❌ [EnhancedGreeting] Idle poke error: $e');
      } finally {
        // Schedule the next one recursively
        _scheduleNextIdlePoke();
      }
    });
  }

  /// Send Smart Query
  Future<void> _sendSmartQuery() async {
    try {
      const String message =
          '''I feel like there’s something interesting on your mind 🤔  
Want to explore it together?''';
      await _addAndSpeakMessage(message, 'Smart Query');
    } catch (e) {
      debugPrint('❌ [EnhancedGreeting] Smart Query error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SEMANTIC CURIOSITY BRIDGE ENGINE
  // ═══════════════════════════════════════════════════════════════════════
  //
  // Analyzes the last two user queries and generates a human-intuition-like
  // bridging question, making the AI feel like it's genuinely thinking.
  //
  // Rules:
  //  - Same semantic domain → ask a depth-probing follow-up
  //  - Different domains    → weave an unexpected but plausible connection
  //  - Always phrase as natural curiosity, NOT as a label or category badge

  /// Called after every 2 new user queries
  Future<void> _processQueryPairDerivedMessage() async {
    if (_userQueriesHistory.length - _lastProcessedUserQueryIndex < 2) return;

    if (_voiceController != null &&
        (_voiceController!.isTalking.value ||
            _voiceController!.isLoading.value)) {
      Timer(const Duration(seconds: 3), _processQueryPairDerivedMessage);
      return;
    }

    final queryA = _userQueriesHistory[_lastProcessedUserQueryIndex];
    final queryB = _userQueriesHistory[_lastProcessedUserQueryIndex + 1];
    _lastProcessedUserQueryIndex += 2;

    final String derivedMessage = _buildSemanticCuriosityBridge(queryA, queryB);

    if (derivedMessage.isNotEmpty && !_recentPrompts.contains(derivedMessage)) {
      await _addAndSpeakMessage(derivedMessage, 'Curiosity');
      _recentPrompts.add(derivedMessage);
    }
  }

  /// Core algorithm: Generate a contextual curiosity bridge between queryA and queryB
  String _buildSemanticCuriosityBridge(String queryA, String queryB) {
    final domainA = _extractSemanticDomain(queryA);
    final domainB = _extractSemanticDomain(queryB);

    // Pick opening phrase for natural variety
    final openers = [
      'That got me thinking —',
      'Interesting! And now I\'m curious —',
      'You know what\'s fascinating?',
      'This made me wonder —',
      'Something just connected in my mind!',
    ];
    final rand = Random();
    final opener = openers[rand.nextInt(openers.length)];

    if (domainA.key == domainB.key) {
      // ── SAME DOMAIN: depth probe ───────────────────────────────────────
      return _buildDepthProbe(queryA, queryB, domainA, opener);
    } else {
      // ── DIFFERENT DOMAINS: semantic intersection ───────────────────────
      return _buildCrossTopicBridge(queryA, queryB, domainA, domainB, opener);
    }
  }

  /// Same-domain depth probe — feel like the AI noticed a pattern
  String _buildDepthProbe(
      String qA, String qB, _SemanticDomain domain, String opener) {
    final topicA = _extractKeyTopic(qA);
    final topicB = _extractKeyTopic(qB);

    final probes = [
      'You asked about "$topicA" and then "$topicB" — are you exploring ${domain.label} in depth? I\'d love to take you deeper! 🔍',
      'I noticed both your questions touched on ${domain.label}. Is there a specific angle — like the history or the science behind it — you\'d like to unpack? 🧠',
      'You\'re on a ${domain.label} trail! What aspect do you find most surprising or puzzling? Let\'s dig in! ✨',
      'It seems ${domain.label} is your focus lately. Between "$topicA" and "$topicB", which one sparked more curiosity? 💡',
      'Your interest in ${domain.label} is clear! If we were to dive into the core of "$topicB", where should we start? 🧪',
      'I see a pattern! "$topicA" and "$topicB" both lead back to ${domain.label}. Are you working on a project or just curious? 🏗️',
      'Connecting "$topicA" and "$topicB"... it seems ${domain.label} is the bridge. What\'s the most fascinating thing you\'ve found so far? 🌈',
    ];

    // Select index, avoiding recently used templates
    int index;
    int retries = 0;
    do {
      index = Random().nextInt(probes.length);
      retries++;
    } while (_usedProbeIndices.contains('depth_$index') && retries < 10);

    _usedProbeIndices.add('depth_$index');
    if (_usedProbeIndices.length > 5) {
      _usedProbeIndices.remove(_usedProbeIndices.first);
    }

    final selectedProbe = probes[index];

    // Some probes already have openers or are standalone, others need one
    if (index < 3) {
      return '$opener $selectedProbe';
    } else {
      return selectedProbe;
    }
  }

  /// Cross-domain bridge — find an unexpected but organic connection
  String _buildCrossTopicBridge(String qA, String qB, _SemanticDomain dA,
      _SemanticDomain dB, String opener) {
    final topicA = _extractKeyTopic(qA);
    final topicB = _extractKeyTopic(qB);

    // Look up pre-defined bridge insight for this pair of domains
    final bridgeInsight = _getDomainBridgeInsight(dA.key, dB.key);

    if (bridgeInsight.isNotEmpty) {
      return '$opener You explored "$topicA" and then "$topicB" — $bridgeInsight 🌐';
    }

    // Generic fallback bridge
    final fallbacks = [
      'From "$topicA" to "$topicB" — did you know these two worlds often intersect in surprising ways? Want to explore the connection? 🔗',
      'You went from ${dA.label} to ${dB.label}! The link between these is more fascinating than most people realise. Shall I connect the dots? 🤔',
      'Your curiosity is jumping across domains — from ${dA.label} to ${dB.label}. That\'s a powerful mindset! What drew you to "$topicB" after "$topicA"? 💡',
      'I see you\'ve shifted from ${dA.label} to ${dB.label}. Usually, there\'s a hidden reason for such a jump! Is "$topicB" a new interest? 🧩',
      'Bridging "$topicA" and "$topicB"... it feels like you\'re painting a bigger picture between ${dA.label} and ${dB.label}. What\'s the common thread? 🕸️',
      'Interesting transition! Topic A: ${dA.label}, Topic B: ${dB.label}. How do you see these two fitting together in your curiosity? 🔭',
    ];

    // Select index, avoiding recently used templates
    int index;
    int retries = 0;
    do {
      index = Random().nextInt(fallbacks.length);
      retries++;
    } while (_usedProbeIndices.contains('cross_$index') && retries < 10);

    _usedProbeIndices.add('cross_$index');
    if (_usedProbeIndices.length > 5) {
      _usedProbeIndices.remove(_usedProbeIndices.first);
    }

    final selectedFallback = fallbacks[index];

    if (index < 3) {
      return '$opener $selectedFallback';
    } else {
      return selectedFallback;
    }
  }

  /// Get a curated bridge insight for a specific pair of domains
  String _getDomainBridgeInsight(String keyA, String keyB) {
    // Normalise order so (a,b) == (b,a)
    final pair = [keyA, keyB]..sort();
    final k = '${pair[0]}|${pair[1]}';

    const insights = {
      'animal|food':
          'some of the world\'s most beloved street foods were born from watching how animals forage for nutrition. Curious coincidence?',
      'animal|science':
          'biology and animal behaviour actually inspired some of the biggest scientific breakthroughs. Want to hear one?',
      'food|science':
          'the science of fermentation links traditional cooking to cutting-edge biology in mind-blowing ways!',
      'food|history':
          'food has shaped the course of human civilisation more than most wars. Which dish would you say changed history?',
      'food|technology':
          'food technology is one of the fastest evolving fields — from lab-grown meat to AI-designed recipes!',
      'animal|history':
          'animals were at the heart of almost every major historical turning point — from war elephants to carrier pigeons.',
      'science|sports':
          'sports science is quietly revolutionising how athletes train. Did you know the marginal gains model came from cycling?',
      'history|technology':
          'every major technological era was shaped by a historical crisis. Which era do you think was the most pivotal?',
      'health|food':
          'the line between food and medicine was blurred for most of human history — and modern nutritionists are rediscovering why.',
      'health|science':
          'some of the most shocking medical discoveries came from completely unrelated fields of research!',
      'geography|history':
          'almost every empire in history was shaped entirely by the geography it was born into. Want to explore one?',
      'geography|food':
          'a region\'s unique geography is usually the real reason it developed its most iconic dishes. Which cuisine intrigues you most?',
      'entertainment|technology':
          'entertainment is one of the biggest drivers of tech innovation — streaming, gaming, VR — they all push the boundaries!',
      'entertainment|history':
          'storytelling and entertainment have documented history more honestly than official records. Want an example?',
      'politics|history':
          'history often feels like politics in slow motion. Which political pattern do you think keeps repeating?',
      'sports|history':
          'sport has always been a mirror of the political and cultural tensions of its era. Think about it!',
    };

    return insights[k] ?? '';
  }

  /// Extract the single most important keyword/topic from a query
  String _extractKeyTopic(String query) {
    // Strip filler words and return the prominent noun/phrase
    final stopWords = {
      'what',
      'is',
      'are',
      'the',
      'a',
      'an',
      'of',
      'in',
      'on',
      'at',
      'to',
      'for',
      'with',
      'how',
      'why',
      'when',
      'where',
      'who',
      'do',
      'does',
      'did',
      'can',
      'me',
      'tell',
      'about',
      'give',
      'i',
      'my',
      'you',
      'your',
      'and',
      'or',
      'that',
      'this',
    };
    final words = query
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(' ')
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toList();
    if (words.isEmpty) {
      return query.length > 30 ? '${query.substring(0, 28)}...' : query;
    }
    // Return the first 1-3 meaningful words as the topic
    return words.take(3).join(' ');
  }

  /// Classify query into a named semantic domain
  _SemanticDomain _extractSemanticDomain(String query) {
    final q = query.toLowerCase();
    final domains = [
      const _SemanticDomain('sports', 'Sports & Games', [
        'cricket',
        'bat',
        'hockey',
        'football',
        'sport',
        'tennis',
        'ipl',
        'match',
        'player',
        'goal',
        'athlete',
        'game',
        'score'
      ]),
      const _SemanticDomain('politics', 'Politics & Governance', [
        'modi',
        'minister',
        'government',
        'election',
        'party',
        'parliament',
        'politics',
        'policy',
        'law',
        'president',
        'vote'
      ]),
      const _SemanticDomain('technology', 'Technology & AI', [
        'ai',
        'robot',
        'computer',
        'software',
        'app',
        'phone',
        'internet',
        'technology',
        'digital',
        'code',
        'programming',
        'machine'
      ]),
      const _SemanticDomain('science', 'Science & Nature', [
        'science',
        'physics',
        'chemistry',
        'atom',
        'space',
        'planet',
        'gravity',
        'biology',
        'nature',
        'experiment',
        'quantum'
      ]),
      const _SemanticDomain('history', 'History & Culture', [
        'history',
        'war',
        'king',
        'dynasty',
        'ancient',
        'century',
        'emperor',
        'civilisation',
        'culture',
        'heritage',
        'empire'
      ]),
      const _SemanticDomain('geography', 'Geography & Travel', [
        'city',
        'country',
        'river',
        'mountain',
        'capital',
        'geography',
        'map',
        'climate',
        'travel',
        'place',
        'region'
      ]),
      const _SemanticDomain('entertainment', 'Entertainment & Arts', [
        'movie',
        'song',
        'actor',
        'film',
        'music',
        'bollywood',
        'entertainment',
        'art',
        'dance',
        'celebrity',
        'series'
      ]),
      const _SemanticDomain('health', 'Health & Wellness', [
        'health',
        'disease',
        'doctor',
        'medicine',
        'diet',
        'exercise',
        'body',
        'mental',
        'yoga',
        'nutrition',
        'fitness'
      ]),
      const _SemanticDomain('food', 'Food & Cuisine', [
        'food',
        'eat',
        'recipe',
        'cook',
        'restaurant',
        'street food',
        'dish',
        'cuisine',
        'taste',
        'meal',
        'drink',
        'snack'
      ]),
      const _SemanticDomain('animal', 'Animals & Nature', [
        'dog',
        'cat',
        'bird',
        'animal',
        'pet',
        'wild',
        'fish',
        'insect',
        'lion',
        'tiger',
        'elephant',
        'snake',
        'horse'
      ]),
    ];

    for (final domain in domains) {
      if (domain.keywords.any((k) => q.contains(k))) return domain;
    }
    return const _SemanticDomain('general', 'General Knowledge', []);
  }

  bool _containsAny(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  /// Send random idle poke message
  Future<void> _sendRandomIdlePoke() async {
    try {
      final profile = _profileController?.userProfile.value;
      if (profile == null) return;

      final prompt = _selectRandomIdlePrompt(profile);
      if (prompt.isEmpty) return;

      String message = prompt;

      // Auto Inject Festival Layer randomly (10% chance)
      final festival = _getCurrentFestival();
      if (festival.isNotEmpty && Random().nextInt(100) < 10) {
        message = 'Aapko $festival ki hardik shubhkamnayein 🎉\n\n$message';
      }

      // Check if prompt was recent to avoid repetition
      if (_recentPrompts.contains(message)) {
        // Try again with different prompt
        final alternatePrompt = _selectRandomIdlePrompt(profile);
        if (alternatePrompt.isNotEmpty &&
            !_recentPrompts.contains(alternatePrompt)) {
          await _addAndSpeakMessage(alternatePrompt, 'Idle Poke');
          _recentPrompts.add(alternatePrompt);
        }
      } else {
        await _addAndSpeakMessage(message, 'Idle Poke');
        _recentPrompts.add(message);
      }

      debugPrint(
          '💭 [EnhancedGreeting] Idle poke sent (#${idlePokeCount.value})');

      // Clean up old prompts after 2 hours
      _cleanupOldPrompts();
    } catch (e) {
      debugPrint('❌ [EnhancedGreeting] Idle poke error: $e');
    }
  }

  /// Unpredictability Engine for Idle Prompts
  String _selectRandomIdlePrompt(UserProfile profile) {
    final rand = Random().nextInt(100);
    String poolType; // 40% emotional, 20% health, 20% curiosity, 20% time-based
    if (rand < 40) {
      poolType = 'emotional';
    } else if (rand < 60) {
      poolType = 'health';
    } else if (rand < 80) {
      poolType = 'curiosity';
    } else {
      poolType = 'time-based';
    }

    final familyEmotionalPrompts = [
      'Aaj ghar pe sab kaise hain? Ek call kar lo, accha lagega 😊',
      'Dosto se baat ki aaj? Connect karo, mood acha hoga!',
      'Kuch acha yaad aa raha hai? Khush raho! ✨',
      'Family time nikal liya aaj? Bahut zaroori hai! 🥰',
      'Smile karo! Aaj badiya day ayega! 😊'
    ];

    final healthPrompts = [
      'Paani piya kya? Thoda hydration ho jaye 💧',
      'Baithe baithe thak gaye? Thoda stretch kar lo! 🤸',
      'Aankhon ko rest do thodi der, screen se break lo! 👀',
      'Health is wealth! Aaj workout kiya? 💪',
      'Deep breaths... 4-7-8 breathing exercise try karo! 🌬️'
    ];

    final curiosityPrompts = [
      'I was just thinking... kya aaj tumne kuch naya seekha? 🧠',
      'Do you know the best way to solve a tough problem is to take a walk? 🚶',
      'Kya chal raha hai dimaag mein? Let me know! 💡',
      'Koi naya idea aaya? We can brainstorm! 🚀'
    ];

    final timeBasedPrompts = [
      '(Subah) Good morning! Chai ya coffee ho jaye? ☀️',
      '(Dupahar) Lunch skip mat karna, energy chahiye! 🍽️',
      '(Sham) Thoda relax kar lo — kaafi productive din tha 🌇',
      '(Raat) Jaldi so jao, kal fresh start milega 🌙'
    ];

    List<String> selectedPool;
    if (poolType == 'emotional') {
      selectedPool = familyEmotionalPrompts;
    } else if (poolType == 'health') {
      selectedPool = healthPrompts;
    } else if (poolType == 'curiosity') {
      selectedPool = curiosityPrompts;
    } else {
      selectedPool = timeBasedPrompts;
    }

    if (poolType == 'time-based') {
      final hour = DateTime.now().hour;
      if (hour >= 5 && hour < 12) {
        selectedPool = [timeBasedPrompts[0]];
      } else if (hour >= 12 && hour < 17) {
        selectedPool = [timeBasedPrompts[1]];
      } else if (hour >= 17 && hour < 21) {
        selectedPool = [timeBasedPrompts[2]];
      } else {
        selectedPool = [timeBasedPrompts[3]];
      }
    }

    // Return random from pool, avoiding recent
    var available =
        selectedPool.where((p) => !_recentPrompts.contains(p)).toList();

    if (available.isEmpty) {
      // If pool-specific prompts are exhausted, clear just those and try again
      _recentPrompts.removeWhere((p) => selectedPool.contains(p));
      available = selectedPool;
    }

    // Secondary layer: Track index to avoid immediate repetition even if string differs slightly
    int index;
    int retries = 0;
    do {
      index = Random().nextInt(available.length);
      retries++;
    } while (_usedIdleIndices.contains('${poolType}_$index') && retries < 5);

    _usedIdleIndices.add('${poolType}_$index');
    if (_usedIdleIndices.length > 5) {
      _usedIdleIndices.remove(_usedIdleIndices.first);
    }

    return available[index];
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Good Morning ☀️';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon 🌤️';
    } else if (hour >= 17 && hour < 21) {
      return 'Good Evening 🌅';
    } else {
      return 'Good Night 🌙';
    }
  }

  String _getPartOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'morning';
    } else if (hour >= 12 && hour < 17) {
      return 'afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'evening';
    } else {
      return 'night';
    }
  }

  /// Helper: Get current festival
  String _getCurrentFestival() {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;

    final festivals = {
      (1, 26): 'Republic Day',
      (3, 8): 'Maha Shivaratri',
      (3, 25): 'Holi',
      (4, 14): 'Baisakhi',
      (8, 15): 'Independence Day',
      (8, 26): 'Janmashtami',
      (9, 16): 'Milad-un-Nabi',
      (10, 2): 'Gandhi Jayanti',
      (10, 12): 'Dussehra',
      (10, 31): 'Diwali',
      (11, 1): 'Diwali',
      (12, 25): 'Christmas',
    };

    return festivals[(month, day)] ?? '';
  }

  /// Add message to chat and speak it
  Future<void> _addAndSpeakMessage(String text, String source) async {
    if (_voiceController == null) {
      debugPrint('❌ [EnhancedGreeting] VoiceController is null!');
      return;
    }

    // FINAL GUARD: Prevent exact or semantic repetition within the last 5 messages
    if (_isVerbatimRepetition(text)) {
      debugPrint(
          '🛡️ [EnhancedGreeting] Suppressing verbatim repetition of: "${text.substring(0, min(text.length, 30))}..."');
      return;
    }

    // Game screen isolation — isGameScreenActive guard must remain in place. No messages during game screen.
    try {
      if (Get.isRegistered<IdlePromptService>()) {
        final idlePromptService = Get.find<IdlePromptService>();
        if (idlePromptService.isGameScreenActive) {
          debugPrint(
              '💤 [EnhancedGreeting] Message suppressed (game screen is active)');
          return;
        }
      }
    } catch (_) {}

    try {
      String finalContent = text;
      try {
        if (Get.isRegistered<LanguageController>()) {
          final langCode =
              Get.find<LanguageController>().selectedLanguage.value.code;
          final targetCode = langCode.split('-').first;
          final result = await TranslationService.translate(
            text: text,
            targetLanguage: targetCode,
            sourceLanguage: 'auto',
          );
          finalContent = result.translatedText;
        }
      } catch (e) {
        debugPrint('EnhancedGreeting translation error: $e');
      }

      // Create message object
      final message = _createChatMessage(finalContent, source);

      debugPrint(
          '📝 [EnhancedGreeting] Adding message ($source): $finalContent');

      // Add to messages list
      _voiceController!.messages.add(message);
      debugPrint('✅ [EnhancedGreeting] Message added to list');

      // CRITICAL FIX: Force UI update so message appears on screen
      _voiceController!.update();
      debugPrint('✅ [EnhancedGreeting] UI update triggered');

      // Speak the message with error handling
      try {
        _voiceController!.speakMessage(message);
        debugPrint('🔊 [EnhancedGreeting] TTS started for: $source');
      } catch (ttsError) {
        debugPrint(
            '⚠️ [EnhancedGreeting] TTS error (message still visible): $ttsError');
        // Don't fail - message is still visible even if TTS fails
      }

      debugPrint('✅ [EnhancedGreeting] Message complete: $source');
    } catch (e) {
      debugPrint('❌ [EnhancedGreeting] Fatal add/speak error: $e');
    }
  }

  /// Create a proper ChatMessage object (FIXED: was returning Map which broke messages list)
  ChatMessage _createChatMessage(String text, String source) {
    return ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}',
      role: 'assistant',
      content: text,
      timestamp: DateTime.now(),
      modelName: 'CTJ Voice - $source',
    );
  }

  /// Cleanup old prompts from tracking set (older than 2 hours)
  void _cleanupOldPrompts() {
    // Simple cleanup - in production, track timestamps
    if (_recentPrompts.length > 100) {
      _recentPrompts.clear();
    }
  }

  Future<String?> getMorningBriefing(String userId) async {
    final hour = DateTime.now().hour;
    if (hour < 6 || hour > 10) return null;

    final now = DateTime.now();

    // Gather upcoming events from today
    final upcomingEvents = <String>[];
    try {
      if (Get.isRegistered<AlarmController>()) {
        final alarmCtrl = Get.find<AlarmController>();
        for (final alarm in alarmCtrl.alarms) {
          final nextTime = alarm.getNextAlarmTime();
          if (nextTime != null &&
              nextTime.day == now.day &&
              nextTime.month == now.month) {
            upcomingEvents.add('${alarm.label} at ${alarm.time}');
          }
        }
      }
    } catch (_) {}

    try {
      final result = await _ruflo.swarmQuery(
        input: 'generate_morning_briefing',
        agents: ['morning_briefing'],
        context: {
          'userId': userId,
          'language':
              Get.find<LanguageController>().selectedLanguage.value.code,
          'upcoming_events': upcomingEvents.join('; '),
          'current_time': now.toIso8601String(),
        },
      );
      return result['briefing'] as String?;
    } catch (_) {
      if (upcomingEvents.isNotEmpty) {
        return 'Good morning! Here is your schedule today: ${upcomingEvents.join(", ")}. Have a great day!';
      }
      return null;
    }
  }

  /// Reset greeting (for testing)
  void resetGreeting() {
    _cancelAllTimers();
    hasStartedGreeting.value = false;
    messageCount.value = 0;
    idlePokeCount.value = 0;
    _consecutiveIdlePokeCount = 0;
    _recentPrompts.clear();
    // ALSO reset session flag for testing
    _hasShownSystemMessagesThisSession = false;
    debugPrint(
        '🔄 [EnhancedGreeting] Service reset for testing (including session flag)');
  }

  /// Check if the exact same content already exists in the recent chat history
  bool _isVerbatimRepetition(String text) {
    if (_voiceController == null) return false;
    final messages = _voiceController!.messages;
    if (messages.isEmpty) return false;

    // Check last 5 messages
    final startIndex = max(0, messages.length - 5);
    for (int i = messages.length - 1; i >= startIndex; i--) {
      // Compare content, normalized for comparison
      final existingContent = messages[i].content.trim().toLowerCase();
      final newContent = text.trim().toLowerCase();

      if (existingContent == newContent) return true;

      // Also check if one is a subset of the other (for translated/untranslated mismatches)
      if (existingContent.contains(newContent) ||
          newContent.contains(existingContent)) {
        if (newContent.length > 20) return true; // Only for significant strings
      }
    }
    return false;
  }

  /// Get current session status (for debugging)
  static bool get hasShownSystemMessagesThisSession =>
      _hasShownSystemMessagesThisSession;
}

// ═════════════════════════════════════════════════════════════════════════════
// SEMANTIC DOMAIN VALUE TYPE
// ═════════════════════════════════════════════════════════════════════════════

/// Represents a named semantic domain with a unique key, display label,
/// and a list of trigger keywords for classification.
class _SemanticDomain {
  final String key;
  final String label;
  final List<String> keywords;

  const _SemanticDomain(this.key, this.label, this.keywords);
}
