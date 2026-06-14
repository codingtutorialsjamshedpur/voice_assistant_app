/// ═══════════════════════════════════════════════════════════════════════════
/// Engagement Orchestrator Service
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Central state machine for intelligent user engagement.
///
/// SEQUENCE (with 20-second intervals):
///   0s  → Message 1: Welcome greeting
///   20s → Message 2: Personal greeting + time-based context
///   40s → Message 3: Location + Weather + AQI (if data available)
///   60s → IDLE LOOP (repeats every 20s):
///         • Message 1: Random idle poke
///         • Message 2: Random idle poke (different)
///         • Message 3: SMART QUERY (based on detected interests)
///         • Repeat pattern
///
/// KEY FEATURES:
/// ✅ Doesn't start until screen is visible
/// ✅ Proper 20-second interval timing
/// ✅ Fetches real-time data before injecting messages
/// ✅ Smart query generation after every 2 idle pokes
/// ✅ Non-repetitive random message selection
/// ✅ User activity detection to pause/resume
///
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/voice_controller.dart';
import '../controllers/profile_controller.dart';
import '../shared/controllers/top_panel_controller.dart';
import 'smart_query_generator_service.dart';
import 'idle_poke_service_enhanced.dart';
import '../controllers/language_controller.dart';
import 'translation_service.dart';
import 'ruflo_service.dart';

/// Engagement message types
enum EngagementMessageType {
  greeting1, // Initial welcome
  greeting2, // Personal greeting
  envData, // Location + Weather + AQI
  idlePoke, // Random engagement
  smartQuery, // AI-generated interest question
}

/// Message waiting to be injected
class PendingMessage {
  final String content;
  final EngagementMessageType type;
  final Duration delay;
  final DateTime scheduledTime;

  PendingMessage({
    required this.content,
    required this.type,
    required this.delay,
    required this.scheduledTime,
  });
}

/// ═══════════════════════════════════════════════════════════════════════════
/// ENGAGEMENT ORCHESTRATOR SERVICE
/// ═══════════════════════════════════════════════════════════════════════════
class EngagementOrchestratorService extends GetxService {
  static EngagementOrchestratorService get to => Get.find();

  final _ruflo = RuFloService();

  // State observables
  final isEngagementActive = false.obs;
  final currentEngagementPhase = 'idle'.obs;
  final messagesInjected = 0.obs;
  final idlePokeCount = 0.obs;

  // Services
  late VoiceController _vc;
  late ProfileController _pc;
  late TopPanelController _tpc;
  late SmartQueryGeneratorService _sqgs;
  late IdlePokeServiceEnhanced _ipes;

  // Timers
  Timer? _engagementTimer;
  Timer? _userActivityTimer;

  // State tracking
  final List<String> _sentMessages = [];
  bool _screenReady = false;

  // Configuration
  static const Duration greetingInterval = Duration(seconds: 20);
  static const Duration idleLoopInterval = Duration(seconds: 90);
  static const int idlePokesBeforeSmartQuery = 2;
  static const Duration userActivityCooldown = Duration(seconds: 30);

  @override
  void onInit() {
    super.onInit();
    debugPrint(
        '🎭 [EngagementOrchestrator] Service initialized (waiting for screen ready)');
  }

  @override
  void onClose() {
    _engagementTimer?.cancel();
    _userActivityTimer?.cancel();
    super.onClose();
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// PUBLIC API
  /// ═══════════════════════════════════════════════════════════════════════

  /// Signal that screen is ready and engagement can begin
  void markScreenAsReady() {
    if (_screenReady) {
      debugPrint('⚠️ [EngagementOrchestrator] Screen already marked as ready');
      return;
    }

    _screenReady = true;
    debugPrint(
        '✅ [EngagementOrchestrator] Screen marked as ready - starting engagement');

    _initializeServices();
    _startEngagementSequence();
  }

  /// User became active (typing, tapping) - pause engagement
  void onUserActivity() {
    if (!isEngagementActive.value) return;

    debugPrint(
        '👤 [EngagementOrchestrator] User activity detected - pausing engagement');
    _engagementTimer?.cancel();

    // Schedule auto-resume after cooldown if no more activity
    _userActivityTimer?.cancel();
    _userActivityTimer = Timer(userActivityCooldown, () {
      if (isEngagementActive.value) {
        debugPrint(
            '⏰ [EngagementOrchestrator] Resuming engagement after user cooldown');
        _resumeEngagement();
      }
    });
  }

  /// Resume engagement where it left off
  void _resumeEngagement() {
    if (!isEngagementActive.value) return;

    if (currentEngagementPhase.value == 'idle_loop' ||
        currentEngagementPhase.value == 'idle') {
      _startIdleEngagementLoop();
    } else {
      // Just re-initiate idle loop, skip the greetings as they already played
      _startIdleEngagementLoop();
    }
  }

  /// Stop engagement loop (e.g., when leaving chat screen)
  void stopEngagement() {
    isEngagementActive.value = false;
    currentEngagementPhase.value = 'stopped';
    _engagementTimer?.cancel();
    _userActivityTimer?.cancel();
    _screenReady = false;
    debugPrint('🛑 [EngagementOrchestrator] Engagement stopped');
  }

  /// Reset for new session
  void reset() {
    stopEngagement();
    _sentMessages.clear();
    messagesInjected.value = 0;
    idlePokeCount.value = 0;
    debugPrint('🔄 [EngagementOrchestrator] Reset for new session');
  }

  Future<Map<String, dynamic>> getStrategy(String userId) async {
    try {
      final swarmResult = await _ruflo.swarmQuery(
        input: 'get_engagement_strategy',
        agents: ['engagement_optimizer'],
        context: {
          'userId': userId,
          'sessionCount': messagesInjected.value,
        },
      );
      return swarmResult;
    } catch (_) {
      return {};
    }
  }

  Future<void> logInteraction({
    required String userId,
    required String interactionType,
    required bool satisfied,
    Map<String, dynamic>? metadata,
  }) async {
    unawaited(_ruflo.memoryStore(
      namespace: 'engagement_trajectory_$userId',
      key: 'interaction_${DateTime.now().millisecondsSinceEpoch}',
      value: {
        'type': interactionType,
        'satisfied': satisfied,
        'timestamp': DateTime.now().toIso8601String(),
        ...?metadata,
      },
    ));
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// PRIVATE IMPLEMENTATION
  /// ═══════════════════════════════════════════════════════════════════════

  void _initializeServices() {
    try {
      _vc = Get.find<VoiceController>();
      _pc = Get.find<ProfileController>();
      _tpc = Get.find<TopPanelController>();
      _sqgs = Get.find<SmartQueryGeneratorService>();
      _ipes = Get.find<IdlePokeServiceEnhanced>();
      debugPrint('✅ [EngagementOrchestrator] All services initialized');
    } catch (e) {
      debugPrint('❌ [EngagementOrchestrator] Service initialization error: $e');
    }
  }

  void _startEngagementSequence() {
    if (!_screenReady || isEngagementActive.value) return;

    isEngagementActive.value = true;
    currentEngagementPhase.value = 'greetings';

    debugPrint('🎬 [EngagementOrchestrator] Starting engagement sequence');

    // Greeting Phase (0-40 seconds)
    _scheduleGreetingPhase();
  }

  /// Phase 1 & 2: Greeting messages (0s, 20s)
  void _scheduleGreetingPhase() {
    // Message 1: Immediate welcome
    _scheduleMessage(
        content: _getGreeting1Message(),
        type: EngagementMessageType.greeting1,
        delay: const Duration(seconds: 1), // slight buffer
        onAfterDelay: () {
          // Schedule Message 2 after Message 1 is spoken
          _scheduleMessage(
              content: _getGreeting2Message(),
              type: EngagementMessageType.greeting2,
              delay: greetingInterval,
              onAfterDelay: () {
                // Schedule Message 3 after Message 2
                _scheduleEnvironmentalDataPhase();
              });
        });
  }

  /// Phase 3: Environmental data message (40s)
  void _scheduleEnvironmentalDataPhase() {
    _scheduleMessage(
      content: _getEnvironmentalDataMessage(),
      type: EngagementMessageType.envData,
      delay: greetingInterval,
      onAfterDelay: () {
        // Disabled idle loop to prevent unprompted "unprofessional" chatter.
        // _startIdleEngagementLoop();
      },
    );
  }

  /// Phase 4: Repeating idle loop (every 20s, starting at 60s)
  void _startIdleEngagementLoop() {
    currentEngagementPhase.value = 'idle_loop';
    debugPrint('🔄 [EngagementOrchestrator] Starting idle engagement loop');

    _scheduleIdleMessage();
  }

  /// Schedule next idle poke or smart query
  void _scheduleIdleMessage() {
    if (!isEngagementActive.value) return;

    // After every 2 idle pokes, inject smart query
    if (idlePokeCount.value % idlePokesBeforeSmartQuery == 0 &&
        idlePokeCount.value > 0) {
      debugPrint(
          '✨ [EngagementOrchestrator] Smart query scheduled (after ${idlePokeCount.value} idle pokes)');
      _scheduleMessage(
        content: _getSmartQueryMessage(),
        type: EngagementMessageType.smartQuery,
        delay: idleLoopInterval,
        onAfterDelay: () {
          _scheduleIdleMessage(); // Continue loop
        },
      );
    } else {
      // Random idle poke
      _scheduleMessage(
        content: _getIdlePokeMessage(),
        type: EngagementMessageType.idlePoke,
        delay: idleLoopInterval,
        onAfterDelay: () {
          idlePokeCount.value++;
          _scheduleIdleMessage(); // Continue loop
        },
      );
    }
  }

  /// Schedule a message to be injected after delay
  void _scheduleMessage({
    required String content,
    required EngagementMessageType type,
    required Duration delay,
    VoidCallback? onAfterDelay,
  }) {
    _engagementTimer?.cancel();
    _engagementTimer = Timer(delay, () async {
      if (isEngagementActive.value && _screenReady) {
        // Do not inject idle or smart pokes if AI is busy
        if (type == EngagementMessageType.idlePoke ||
            type == EngagementMessageType.smartQuery) {
          try {
            // Let's assume voice controller is available
            if (_vc.isLoading.value ||
                _vc.isTalking.value ||
                _vc.sttService.isListening.value) {
              debugPrint(
                  '⏳ [EngagementOrchestrator] System busy, rescheduling $type');
              _scheduleIdleMessage(); // try again later
              return;
            }
          } catch (_) {}
        }

        String finalContent = content;
        try {
          if (Get.isRegistered<LanguageController>()) {
            final langCode =
                Get.find<LanguageController>().selectedLanguage.value.code;
            final targetCode = langCode.split('-').first;
            final result = await TranslationService.translate(
              text: content,
              targetLanguage: targetCode,
              sourceLanguage: 'auto',
            );
            finalContent = result.translatedText;
          }
        } catch (e) {
          debugPrint('Engagement translation error: $e');
        }

        if (isEngagementActive.value && _screenReady) {
          _injectMessage(
            content: finalContent,
            type: type,
            delay: delay,
          );
          onAfterDelay?.call();
        }
      }
    });
  }

  /// Inject message immediately (add to chat + TTS)
  void _injectMessage({
    required String content,
    required EngagementMessageType type,
    required Duration delay,
  }) {
    if (content.isEmpty) {
      debugPrint('⚠️ [EngagementOrchestrator] Empty message for type: $type');
      return;
    }

    try {
      // Avoid immediate duplicates (check last 5 messages)
      final recentMessages = _sentMessages.length > 5
          ? _sentMessages.sublist(_sentMessages.length - 5)
          : _sentMessages;
      if (recentMessages.contains(content)) {
        debugPrint(
            '🔁 [EngagementOrchestrator] Skipping immediate duplicate message');
        return;
      }

      // Skip engagement messages if user has very recently interacted (within 15 seconds)
      // This prevents engagement messages from appearing right after user query
      if (type == EngagementMessageType.idlePoke ||
          type == EngagementMessageType.smartQuery) {
        // Check if last message is from user (recent interaction)
        if (_vc.messages.isNotEmpty) {
          final lastMsg = _vc.messages.last;
          if (lastMsg.role == 'user') {
            final timeDiff = DateTime.now().difference(lastMsg.timestamp);
            if (timeDiff.inSeconds < 15) {
              debugPrint(
                  '⏸️ [EngagementOrchestrator] Skipping ${type.name} - user recently interacted (${timeDiff.inSeconds}s ago)');
              return;
            }
          }
        }
      }

      _sentMessages.add(content);

      // Create chat message
      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'assistant',
        content: content,
        timestamp: DateTime.now(),
        modelName: 'CTJ Voice - ${type.name}',
      );

      // Add to chat
      _vc.messages.add(message);
      messagesInjected.value++;

      // Speak message
      _vc.speakMessage(message);

      debugPrint('💬 [EngagementOrchestrator] ${type.name}: $content');
    } catch (e) {
      debugPrint('❌ [EngagementOrchestrator] Message injection error: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// MESSAGE CONTENT GENERATION
  /// ═══════════════════════════════════════════════════════════════════════

  String _getGreeting1Message() {
    return '''Welcome to Voice Assistant! 
    I'm your AI companion. Let's have an amazing conversation today! 🎉''';
  }

  String _getGreeting2Message() {
    try {
      final userName = _pc.userProfile.value.name;
      final hour = DateTime.now().hour;
      final timeGreeting = _getTimeBasedGreeting(hour);

      return 'Hello $userName! $timeGreeting How are you doing today? 😊';
    } catch (e) {
      debugPrint('Error building greeting 2: $e');
      return 'Hello there! How are you doing today? 😊';
    }
  }

  String _getTimeBasedGreeting(int hour) {
    if (hour >= 5 && hour < 12) {
      return 'Good morning! ☀️ ';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon! 🌤️ ';
    } else if (hour >= 17 && hour < 21) {
      return 'Good evening! 🌅 ';
    } else {
      return 'Good night! 🌙 ';
    }
  }

  String _getEnvironmentalDataMessage() {
    try {
      final userName = _pc.userProfile.value.name;
      final location = _tpc.placeName.value;
      final temperature = _tpc.temperatureNum.value;
      final aqi = _tpc.aqiNum.value;

      if (location.isEmpty ||
          location == 'Detecting...' ||
          temperature == 0 ||
          aqi == 0) {
        debugPrint(
            '⚠️ [EngagementOrchestrator] Location data not ready (L:$location, T:$temperature, A:$aqi)');
        return ''; // Skip if data not available
      }

      final weatherAdvice = _getWeatherAdvice(temperature, aqi);
      return '''$userName, I notice your city is $location.
      The temperature is ${temperature.toStringAsFixed(1)}°C and AQI is $aqi.
      $weatherAdvice 🌍''';
    } catch (e) {
      debugPrint('Error building env data message: $e');
      return '';
    }
  }

  String _getWeatherAdvice(double temp, int aqi) {
    String tempAdvice = '';
    if (temp < 10) {
      tempAdvice = 'It\'s quite cold! Wear warm clothes.';
    } else if (temp > 30) {
      tempAdvice = 'It\'s hot outside! Stay hydrated.';
    } else {
      tempAdvice = 'Perfect weather for a nice walk!';
    }

    String aqiAdvice = '';
    if (aqi > 200) {
      aqiAdvice = ' Air quality is poor - consider wearing a mask.';
    } else if (aqi > 100) {
      aqiAdvice = ' Air quality is moderate - be mindful if outdoors.';
    } else {
      aqiAdvice = ' Air quality is great!';
    }

    return tempAdvice + aqiAdvice;
  }

  String _getIdlePokeMessage() {
    try {
      final poke = _ipes.getNextPrompt();
      if (poke != null && poke.isNotEmpty) {
        return poke;
      }
    } catch (e) {
      debugPrint('Error getting idle poke: $e');
    }

    // Fallback
    final fallbacks = [
      'Still there? I\'m here whenever you need! 👂',
      'What\'s on your mind? 💭',
      'Share your thoughts with me! 🗣️',
      'I\'m listening... Tell me something! 👂',
      'What would you like to talk about? 🤔',
    ];
    return fallbacks[DateTime.now().millisecond % fallbacks.length];
  }

  String _getSmartQueryMessage() {
    try {
      final interests = _sqgs.detectedInterests;
      if (interests.isNotEmpty) {
        // Get smart query from SmartQueryGeneratorService
        final smartQuery = _sqgs.lastGeneratedQuery.value;
        if (smartQuery.isNotEmpty) {
          return smartQuery;
        }
      }
    } catch (e) {
      debugPrint('Error getting smart query: $e');
    }

    // Fallback smart query
    return '''I noticed you're interested in something fascinating! 
    Have you ever explored that further? I'd love to help! 🚀''';
  }
}
