import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/profile_model.dart';
import '../controllers/profile_controller.dart';
import '../controllers/voice_controller.dart';
import 'tts_service.dart';
import 'idle_poke_service_enhanced.dart';
import '../controllers/language_controller.dart';
import 'translation_service.dart';
import 'ruflo_service.dart';

class IdlePromptService extends GetxService {
  static IdlePromptService get to => Get.find();
  final _ruflo = RuFloService();

  Timer? _idleTimer;
  VoiceController? _voiceController;

  final RxBool isUserIdle = false.obs;
  final RxInt idleSeconds = 0.obs;
  final RxBool hasShownIdlePrompt = false.obs;

  static const int idleThresholdSeconds = 240;
  static const int cooldownMinutes = 10;
  static const int initialDelaySeconds = 30;

  DateTime? _lastIdlePromptTime;
  DateTime? _lastUserInteractionTime;

  // ── Screen-isolation guard ──────────────────────────────────────────────
  // When the game screen is active, all idle TTS pokes are suppressed.
  // The game screen owns the TTS channel and must not be interrupted.
  bool isGameScreenActive = false;

  @override
  void onInit() {
    super.onInit();
    _initializeInteractionTracking();
  }

  @override
  void onClose() {
    stopIdleTimer();
    super.onClose();
  }

  void startIdleTimer(VoiceController voiceController) {
    _voiceController = voiceController;
    _lastUserInteractionTime = DateTime.now();
    _setupIdleTimer();
  }

  void stopIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
    isUserIdle.value = false;
    idleSeconds.value = 0;
  }

  void resetIdleTimer() {
    _lastUserInteractionTime = DateTime.now();
    isUserIdle.value = false;
    idleSeconds.value = 0;
    hasShownIdlePrompt.value = false;

    _idleTimer?.cancel();
    _setupIdleTimer();
  }

  bool get userIsIdle => isUserIdle.value;

  int get currentIdleSeconds => idleSeconds.value;

  void _setupIdleTimer() {
    _idleTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      _updateIdleState();

      if (_shouldTriggerIdlePrompt()) {
        await _triggerIdlePrompt();
      }
    });
  }

  void _updateIdleState() {
    if (_lastUserInteractionTime == null) return;

    final secondsSinceLastInteraction =
        DateTime.now().difference(_lastUserInteractionTime!).inSeconds;

    idleSeconds.value = secondsSinceLastInteraction;

    if (secondsSinceLastInteraction >= idleThresholdSeconds) {
      isUserIdle.value = true;
    }
  }

  bool _shouldTriggerIdlePrompt() {
    if (!isUserIdle.value) return false;

    if (hasShownIdlePrompt.value) return false;

    if (_lastIdlePromptTime != null) {
      final timeSinceLastPrompt =
          DateTime.now().difference(_lastIdlePromptTime!).inMinutes;
      if (timeSinceLastPrompt < cooldownMinutes) {
        return false;
      }
    }

    if (_isConversationOngoing()) {
      return false;
    }

    return true;
  }

  Future<void> _triggerIdlePrompt() async {
    // ── Guard: never fire idle pokes into the game screen ──────────────────
    if (isGameScreenActive) {
      debugPrint('💤 Idle prompt suppressed (game screen is active)');
      return;
    }
    try {
      hasShownIdlePrompt.value = true;
      _lastIdlePromptTime = DateTime.now();

      final profileController = Get.find<ProfileController>();
      final userProfile = profileController.userProfile.value;

      final idlePrompt = _generateIdlePrompt(userProfile);

      debugPrint('💤 Idle Prompt Triggered: $idlePrompt');

      await _speakIdlePrompt(idlePrompt);
    } catch (e) {
      debugPrint('Error triggering idle prompt: $e');
    }
  }

  String _generateIdlePrompt(UserProfile profile) {
    // ── Phase 2: Prefer enhanced smart poke service ───────────────────────
    try {
      if (Get.isRegistered<IdlePokeServiceEnhanced>()) {
        final enhanced = Get.find<IdlePokeServiceEnhanced>();
        final prompt = enhanced.getNextPrompt();
        if (prompt != null && prompt.isNotEmpty) {
          return prompt;
        }
      }
    } catch (_) {}

    // Fallback to legacy interest-based prompting
    final interests = profile.fieldOfInterest
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (interests.isEmpty) {
      return _getGenericIdlePrompts().first;
    }

    return _getInterestSpecificPrompt(interests, profile);
  }

  String _getInterestSpecificPrompt(
      List<String> interests, UserProfile profile) {
    final promptTemplates = <String, List<String>>{
      'english': [
        'Would you like to improve your English skills? I can teach you a new word or phrase!',
        'Interested in learning some English idioms? I have some interesting ones to share!',
        'Want to practice English conversation? I can help you with that!',
      ],
      'ai': [
        'Do you want to learn something interesting about artificial intelligence? I can explain it simply!',
        'Curious about AI? I can walk you through how machine learning works!',
        'Want to explore AI concepts? I have some fascinating topics to discuss!',
      ],
      'cricket': [
        'Want to chat about the latest cricket match? I have some interesting stats!',
        'Interested in cricket news? I can share the latest updates!',
        'Should we discuss cricket? I know some fun facts about the game!',
      ],
      'science': [
        'Want to learn something interesting about science? I can explain complex concepts simply!',
        'Curious about scientific discoveries? I have fascinating updates!',
        'Ready to explore science? I can break down tricky topics for you!',
      ],
      'technology': [
        'Want to learn about the latest tech innovations? I can explain them in simple terms!',
        'Interested in tech trends? I have interesting updates!',
        'Should we discuss technology? I can simplify complex concepts!',
      ],
      'india': [
        'Want to know about Indian culture or news? I can share interesting facts!',
        'Curious about Indian history or geography? I have fascinating stories!',
        'Interested in Indian current events? I can keep you updated!',
      ],
    };

    final firstInterest = interests.first.toLowerCase();

    for (final template in promptTemplates.entries) {
      if (firstInterest.contains(template.key)) {
        return template.value[_random(template.value.length)];
      }
    }

    return _getGenericIdlePrompts()[_random(_getGenericIdlePrompts().length)];
  }

  List<String> _getGenericIdlePrompts() {
    return [
      'You\'ve been quiet. Is there anything I can help you with today?',
      'I\'m here if you need anything. Want to chat about something?',
      'Anything I can help you learn or explore right now?',
      'Got any questions for me? I\'m ready to help!',
    ];
  }

  Future<void> _speakIdlePrompt(String prompt) async {
    try {
      String finalPrompt = prompt;
      try {
        if (Get.isRegistered<LanguageController>()) {
          final langCode =
              Get.find<LanguageController>().selectedLanguage.value.code;
          final targetCode = langCode.split('-').first;
          final result = await TranslationService.translate(
            text: prompt,
            targetLanguage: targetCode,
            sourceLanguage: 'auto',
          );
          finalPrompt = result.translatedText;
        }
      } catch (e) {
        debugPrint('IdlePrompt translation error: $e');
      }

      if (Get.isRegistered<TTSService>()) {
        final ttsService = Get.find<TTSService>();

        await ttsService.speak(finalPrompt);
      }
    } catch (e) {
      debugPrint('Error speaking idle prompt: $e');
    }
  }

  bool _isConversationOngoing() {
    if (_voiceController == null) return false;

    if (_voiceController!.isTalking.value) return true;
    if (_voiceController!.isLoading.value) return true;

    if (_voiceController!.messages.isNotEmpty) {
      final lastMessage = _voiceController!.messages.last;
      final timeSinceLastMessage =
          DateTime.now().difference(lastMessage.timestamp).inSeconds;
      if (timeSinceLastMessage < 120) {
        return true;
      }
    }

    return false;
  }

  int _random(int max) => DateTime.now().millisecond % max;

  void _initializeInteractionTracking() {}

  Future<String> getContextualPrompt(String userId) async {
    try {
      final result = await _ruflo.swarmQuery(
        input: 'suggest_proactive_prompt',
        agents: ['engagement_optimizer', 'conversation_memory'],
        context: {
          'userId': userId,
          'timeOfDay': _getTimeOfDay(),
          'dayOfWeek': DateTime.now().weekday.toString(),
        },
      );
      return result['prompt'] as String? ?? _getGenericIdlePrompts().first;
    } catch (_) {
      return _getGenericIdlePrompts().first;
    }
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    if (hour < 21) return 'evening';
    return 'night';
  }

  Future<void> debugTriggerIdlePrompt() async {
    isUserIdle.value = true;
    await _triggerIdlePrompt();
  }
}
