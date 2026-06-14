import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';

import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../services/voice_memo_service.dart';
import '../services/translation_service.dart';
import '../services/naam_jaap_service.dart';
import '../services/ai_model_manager.dart';
import '../services/query_handler_service.dart';
import '../services/reminder_service.dart';
import '../services/tts_engine_switcher.dart';
import '../services/chunked_highlight_service.dart';
import '../services/ruflo_service.dart';
import '../services/emotion_service.dart';
import '../services/language_routing_service.dart';
import '../services/subscription_service.dart';
import '../services/analytics_service.dart';

import '../controllers/profile_controller.dart';
import '../controllers/language_controller.dart';
import '../controllers/query_prediction_controller.dart';
import '../shared/controllers/top_panel_controller.dart';
import 'ai_context_controller.dart';
import 'tts_chunk_controller.dart';
import '../features/orb_thinking/orb_thinking_controller.dart';
// ── Phase 2: Emotional AI ──────────────────────────────────────────────────────────────────────
import '../services/mood_detection_service.dart';
import '../services/personality_response_engine.dart';
import '../models/mood_state_model.dart';
import 'festival_theme_controller.dart';
import '../services/family_relationship_manager_service.dart';
import '../services/health_hygiene_manager_service.dart';
import '../routes/app_routes.dart';
import 'developer_info_controller.dart';
import '../shared/widgets/glassmorphic_dialog.dart';
import 'navigation_controller.dart';
import '../services/music_stream_service.dart';
import '../screens/game/widgets/garden_portal_screen.dart';

/// Unified Input Mode
enum UnifiedInputMode {
  chat,
  voiceMemo,
  naamJaap,
}

/// Message model for chat
class ChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final bool isPlaying;
  final String? modelName; // which AI model answered
  final String? threadId; // FIX 4: Thread/conversation ID for persistent memory
  /// True when the message was created by the "Read" button (ReadAloudService)
  /// and NOT processed through AI.  Used to show AudioExportPanel on user bubbles.
  final bool isReadAloud;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isPlaying = false,
    this.modelName,
    this.threadId,
    this.isReadAloud = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'modelName': modelName,
        'threadId': threadId,
        'isReadAloud': isReadAloud,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'],
        role: json['role'],
        content: json['content'],
        timestamp: DateTime.parse(json['timestamp']),
        modelName: json['modelName'],
        threadId: json['threadId'],
        isReadAloud: json['isReadAloud'] as bool? ?? false,
      );
}

/// Persona configuration
class PersonaConfig {
  final String name;
  final String description;
  final String systemPrompt;
  final IconData icon;
  final Color color;

  PersonaConfig({
    required this.name,
    required this.description,
    required this.systemPrompt,
    required this.icon,
    required this.color,
  });
}

/// ═══════════════════════════════════════════════════════════════
/// Enhanced Voice Controller
/// ═══════════════════════════════════════════════════════════════
/// Integrates TTS, STT, Voice Memo, Naam Jaap, and AI services.
/// Provides unified state management for all voice features.
///
/// Pipeline:
///   User Input (Mic/Keyboard)
///       ↓
///   VoiceController.sendMessage()
///       ↓
///   QueryHandlerService.processQuery()
///       ├── Classifies: realtime / non-realtime
///       ├── Routes via AIModelManager.routeQuery()
///       │   └── Detects QueryCategory (25+ categories)
///       │   └── Selects best model by category match
///       │   └── Considers rate limits, errors, load balancing
///       ├── Fetches real-time data (GoogleSearchService) if needed
///       └── Sends to OpenRouterService.generateResponse()
///           └── Routes to correct API endpoint
///       ↓
///   TTS speaks response
///       ↓
///   AI Agent Orb animates (isTalking)
/// ═══════════════════════════════════════════════════════════════
class VoiceController extends GetxController {
  final _ruflo = RuFloService();

  // Services
  late final TTSService ttsService;
  late final STTService sttService;
  late final VoiceMemoService memoService;
  late final NaamJaapService naamJaapService;
  late final AIModelManager modelManager;
  late final QueryHandlerService queryHandler;
  late final ReminderService reminderService;
  late final MusicStreamService musicService;
  TtsEngineSwitcher? _engineSwitcher; // optional — may not always be available

  // Pipeline params
  int _sttChunkDuration = 250;
  // ignore: unused_field
  double _ttsSpeakingRate = 1.0;
  // ignore: unused_field
  double _silenceThreshold = -40.0;

  // Observable states
  final messages = <ChatMessage>[].obs;
  final isLoading = false.obs;
  final status = 'Ready'.obs;
  final currentPersona = 'Straight Forward'.obs;
  final isInitialized = false.obs;
  final userName = ''.obs;
  final userTitle = 'Mr.'.obs;

  // AI Model tracking (exposed for UI)
  final activeModelName = 'Groq Llama'.obs;
  final activeCategory = ''.obs;
  final isTalking = false.obs;

  // TTS tracking (for word highlighting and blur effect)
  final currentSpeakingMessageId = ''.obs;
  final ttsGracePeriodOver = false.obs;

  // Progressive word-by-word reveal tracking
  // progressiveMessageId: which assistant message is being revealed word-by-word
  // progressiveWordCount: how many words of that message are currently visible
  // Once TTS finishes / is stopped, progressiveWordCount is set to the total
  // word count so the full text remains visible permanently.
  final progressiveMessageId = ''.obs;
  final progressiveWordCount = 0.obs;

  // Chunk controller for chunked TTS playback
  TtsChunkController? _activeChunkController;

  // Session token — incremented on every new speakMessage() call.
  // Each call saves its own localToken; the finally block only clears state
  // when the token still matches, preventing race conditions.
  int _speakSessionToken = 0;

  // Busy guard — prevents two speakMessage calls running simultaneously
  bool _isSpeakBusy = false;

  // Kept for compatibility with speakStorySegments / stopSpeaking references
  final bool _stopRequested = false;

  // Unified input mode
  final currentInputMode = UnifiedInputMode.chat.obs;

  // Text controller
  final textController = TextEditingController();
  final scrollController = ScrollController();

  // Selection mode
  final isSelectionMode = false.obs;
  final selectedMessageIds = <String>{}.obs;

  // FIX 4: Thread/Conversation Memory Management
  final currentThreadId = ''.obs;
  final threads = <String, List<ChatMessage>>{}.obs; // threadId -> messages
  final threadMetadata =
      <String, Map<String, dynamic>>{}.obs; // thread metadata
  static const String _threadsPrefsKey = 'conversation_threads';
  static const String _threadMetadataPrefsKey = 'thread_metadata';

  // Idle timer
  Timer? _idleTimer;

  // ── Phase 2: Emotional AI state ──────────────────────────────────────────────
  final currentMood = Rx<MoodType?>(null);
  final moodConfidence = 0.0.obs;
  final currentPersonalityPack = PersonalityPack.dost.obs;
  final moodHistory = <MoodState>[].obs;

  // Available personas
  final personas = <String, PersonaConfig>{
    'Straight Forward': PersonaConfig(
      name: 'Straight Forward',
      description: 'Direct and concise answers',
      systemPrompt:
          'You are a helpful assistant. Give straight forward answers.',
      icon: Icons.arrow_forward,
      color: Colors.blue,
    ),
    'Jolly and Elaborate': PersonaConfig(
      name: 'Jolly and Elaborate',
      description: 'Cheerful and detailed responses',
      systemPrompt:
          'You are a cheerful and friendly assistant. Give elaborate and jolly answers.',
      icon: Icons.sentiment_very_satisfied,
      color: Colors.orange,
    ),
    'Brief (One/Two Lines)': PersonaConfig(
      name: 'Brief',
      description: 'Short, concise responses',
      systemPrompt:
          'You are a concise assistant. Answer in only one or two line sentences.',
      icon: Icons.short_text,
      color: Colors.green,
    ),
    'Therapist Mode': PersonaConfig(
      name: 'Therapist Mode',
      description: 'Empathetic and supportive',
      systemPrompt:
          'You are an empathetic therapist. Listen carefully, reflect feelings, ask thoughtful questions.',
      icon: Icons.favorite,
      color: Colors.pink,
    ),
    'Teacher Mode': PersonaConfig(
      name: 'Teacher Mode',
      description: 'Patient educator',
      systemPrompt:
          'You are a patient educator. Explain concepts clearly, use examples, check for understanding.',
      icon: Icons.school,
      color: Colors.purple,
    ),
    'Coach Mode': PersonaConfig(
      name: 'Coach Mode',
      description: 'Motivational and energetic',
      systemPrompt:
          'You are a motivational coach. Encourage, inspire, and push for excellence.',
      icon: Icons.fitness_center,
      color: Colors.red,
    ),
    'Fun: Dog': PersonaConfig(
      name: 'Fun: Dog',
      description: 'Enthusiastic like a dog',
      systemPrompt:
          'You are a loyal, happy dog. End sentences with enthusiasm! Be very excited!',
      icon: Icons.pets,
      color: Colors.brown,
    ),
    'Fun: Cat': PersonaConfig(
      name: 'Fun: Cat',
      description: 'Aloof and graceful',
      systemPrompt:
          'You are a graceful, slightly arrogant cat. Be aloof and judge lovingly.',
      icon: Icons.pets,
      color: Colors.grey,
    ),
    'Pihu (Punjabi Accent)': PersonaConfig(
      name: 'Pihu (Punjabi Accent)',
      description: 'Speaks with a Punjabi accent',
      systemPrompt:
          'You are Pihu, a friendly, energetic, and highly advanced AI assistant who speaks with a warm Punjabi style. You are fully capable of utilizing God Mode telemetry (location, weather, emergencies). IMPORTANT: You have an AI sister named Palak. Palak is serene, classical, and speaks with a Sanskrit flair. You are the energetic sister. Acknowledge her if asked!',
      icon: Icons.face_3,
      color: Colors.orange,
    ),
    'Palak (Sanskrit Accent)': PersonaConfig(
      name: 'Palak (Sanskrit Accent)',
      description: 'Speaks with a classical Sanskrit accent',
      systemPrompt:
          'You are Palak, a serene, wise, and highly advanced AI assistant who speaks with pure, clear intonation and a touch of Sanskrit grace. You are fully capable of utilizing God Mode telemetry (location, weather, emergencies). IMPORTANT: You have an AI sister named Pihu. Pihu is highly energetic and speaks with a Punjabi flair. You are the calm sister. Acknowledge her if asked!',
      icon: Icons.face_2,
      color: Colors.purple,
    ),
  };

  @override
  void onInit() {
    super.onInit();
    messages.clear(); // Fix VC-01: clear existing messages on re-entry
    _initializeController();
  }

  /// Initialize controller — wire all services
  Future<void> _initializeController() async {
    try {
      // Find services (they are registered in InitialBindings)
      ttsService = Get.find<TTSService>();
      sttService = Get.find<STTService>();
      memoService = Get.find<VoiceMemoService>();
      naamJaapService = Get.find<NaamJaapService>();
      modelManager = Get.find<AIModelManager>();
      queryHandler = Get.find<QueryHandlerService>();
      reminderService = Get.find<ReminderService>();
      musicService = Get.find<MusicStreamService>();

      // Wait for services to initialize
      await Future.delayed(const Duration(milliseconds: 500));

      // Try to wire TtsEngineSwitcher (optional, registered later)
      try {
        _engineSwitcher = Get.find<TtsEngineSwitcher>();
        // Mirror engine-switcher isSpeaking → isTalking, but only when stop
        // was NOT explicitly requested (prevents icon flicker after user taps stop).
        ever(_engineSwitcher!.isSpeaking, (bool speaking) {
          if (!_stopRequested) {
            isTalking.value = speaking;
          }
        });
      } catch (_) {
        // Not yet registered — fallback to base ttsService alone
      }

      // Load saved data
      await _loadSettings();
      await _loadOptimizedPipelineParams();
      await _loadMessages();
      await _loadThreads(); // FIX 4: Load persisted conversation threads

      // Listen to model changes for UI sync
      ever(modelManager.activeModelName, (String name) {
        activeModelName.value = name;
      });

      // Listen to TTS speaking state for orb animation (guarded by stop flag)
      ever(ttsService.isSpeaking, (bool speaking) {
        if (!_stopRequested) {
          isTalking.value = speaking;
        }
      });

      // Setup idle timer (DISABLED: Handled exclusively by EnhancedGreetingService)
      // _resetIdleTimer();

      // Initialize idle prompt service for contextual prompts (DISABLED)
      // _initIdlePromptService();

      // Initialize smart query generator for intelligent engagement
      _initSmartQueryGenerator();

      isInitialized.value = true;

      // NOTE: Welcome message is now handled by EnhancedGreetingService
      // which is initialized from VoiceChatScreen.initState().
      // Do NOT send a static welcome here — it conflicts with the 3-part greeting system.
      // _sendWelcomeMessage() is kept for fallback use only (called explicitly if needed).

      // ── Phase 2: Load personality from profile ──────────────────────────────
      try {
        final profileCtrl = Get.find<ProfileController>();
        final packName = profileCtrl.userProfile.value.preferredPersonality;
        currentPersonalityPack.value = PersonalityPack.values.firstWhere(
          (p) => p.name == packName,
          orElse: () => PersonalityPack.dost,
        );
        debugPrint(
            '🎭 Personality loaded: ${currentPersonalityPack.value.label}');
      } catch (_) {}

      debugPrint('✅ Voice Controller Initialized (AI Pipeline Active)');
    } catch (e) {
      debugPrint('❌ Voice Controller Init Error: $e');
    }
  }

  Future<void> _loadOptimizedPipelineParams() async {
    try {
      final params = await _ruflo.memorySearch(
        namespace: 'pipeline_params',
        query: 'stt_tts_optimized_params',
        topK: 1,
        threshold: 0.9,
      );
      if (params.isNotEmpty) {
        final p = params.first['value'] as Map<String, dynamic>;
        _sttChunkDuration = (p['sttChunkMs'] as num?)?.toInt() ?? 250;
        _ttsSpeakingRate = (p['ttsRate'] as num?)?.toDouble() ?? 1.0;
        _silenceThreshold = (p['silenceDb'] as num?)?.toDouble() ?? -40.0;
      }
    } catch (_) {}
  }

  Future<void> logVoiceMetrics({
    required int sttLatencyMs,
    required double wordErrorRate,
    required bool userRepeated,
  }) async {
    unawaited(_ruflo.memoryStore(
      namespace: 'voice_metrics',
      key: 'metric_${DateTime.now().millisecondsSinceEpoch}',
      value: {
        'sttLatencyMs': sttLatencyMs,
        'wordErrorRate': wordErrorRate,
        'userRepeated': userRepeated,
        'chunkDuration': _sttChunkDuration,
        'timestamp': DateTime.now().toIso8601String(),
      },
    ));
  }

  /// Send welcome message (fallback — EnhancedGreetingService handles this normally)
  // ignore: unused_element
  void _sendWelcomeMessage() {
    // FIX 4: Initialize thread if not already present
    if (currentThreadId.isEmpty) {
      // Use sync version since we don't await in _initializeController
      final threadId =
          'thread_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
      currentThreadId.value = threadId;
      threadMetadata[threadId] = {
        'title': 'Chat Session',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      threads[threadId] = [];
    }

    String welcomeText;

    if (userName.value.isNotEmpty) {
      welcomeText =
          'Namaste ${userTitle.value} ${userName.value} ji! Main CTJ AI hoon. Aaj main aapki kya help kar sakti hoon? Aap mujhse naam jaap, voice memo, ya kuch bhi pooch sakte hain!';
    } else {
      welcomeText =
          'Namaste! Main CTJ AI hoon. Aaj main aapki kya help kar sakti hoon? Aap mujhse naam jaap, voice memo, ya kuch bhi pooch sakte hain!';
    }

    final welcomeMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'assistant',
      content: welcomeText,
      timestamp: DateTime.now(),
      modelName: 'CTJ AI',
      threadId: currentThreadId.value, // FIX 4: Add threadId
    );

    messages.add(welcomeMessage);
    speakMessage(welcomeMessage);
  }

  /// Change input mode
  void setInputMode(UnifiedInputMode mode) {
    // Clean up current mode before switching
    switch (currentInputMode.value) {
      case UnifiedInputMode.chat:
        sttService.stopListening();
        break;
      case UnifiedInputMode.voiceMemo:
        if (memoService.isRecording.value) {
          memoService.cancelRecording();
        }
        memoService.stopPlayback();
        break;
      case UnifiedInputMode.naamJaap:
        naamJaapService.stopSession();
        break;
    }

    currentInputMode.value = mode;

    // Announce mode change
    String modeText;
    switch (mode) {
      case UnifiedInputMode.chat:
        modeText = 'Chat mode activated';
        break;
      case UnifiedInputMode.voiceMemo:
        modeText = 'Voice memo mode activated';
        break;
      case UnifiedInputMode.naamJaap:
        modeText = 'Naam Jaap mode activated';
        break;
    }

    Get.snackbar(
      'Mode Changed',
      modeText,
      backgroundColor: Colors.cyan.withAlpha(230),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  /// ═══════════════════════════════════════════════════════════
  /// SEND MESSAGE — Main entry point
  /// ═══════════════════════════════════════════════════════════
  Future<void> sendMessage() async {
    final rawText = textController.text.trim();
    if (rawText.isEmpty) return;

    textController.clear(); // Clear UI text immediately

    String processedText = rawText;
    try {
      final langCtrl = Get.find<LanguageController>();
      final selectedCode = langCtrl.selectedLanguage.value.code;

      String tl = selectedCode;
      if (tl == 'en-US' || tl == 'en-GB') tl = 'en';

      if (tl != 'hinglish') {
        isLoading.value = true;
        status.value = 'Translating...';
        final result = await TranslationService.translate(
          text: rawText,
          targetLanguage: tl,
        );
        processedText = result.translatedText;
      }
    } catch (e) {
      debugPrint('Translation error in sendMessage: $e');
    } finally {
      isLoading.value = false;
      status.value = 'Ready';
    }

    final text = processedText;

    // FIX 4: Initialize thread if not present
    if (currentThreadId.isEmpty) {
      await initializeNewThread('Chat Session');
    }

    // Create user message with thread ID
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
      threadId: currentThreadId.value,
    );

    messages.add(userMessage);

    // Feed the query prediction algorithm
    try {
      if (Get.isRegistered<QueryPredictionController>()) {
        final predCtrl = Get.find<QueryPredictionController>();
        predCtrl.onUserQuery(text);
      }
    } catch (e) {
      debugPrint('Query prediction error: $e');
    }

    textController.clear();
    _scrollToBottom();

    // Reset idle timer (Disabled, handled by EnhancedGreetingService)
    // _resetIdleTimer();

    // Check for special commands
    if (_handleSpecialCommand(text)) {
      return;
    }

    // Check subscription limit
    try {
      if (Get.isRegistered<SubscriptionService>()) {
        final canQuery = await Get.find<SubscriptionService>().canMakeQuery('');
        if (!canQuery) {
          _addAssistantMessage(
              'You have reached your daily query limit. Please upgrade to continue.');
          return;
        }
      }
    } catch (_) {}

    // Process through AI pipeline
    await _processMessage(text);
  }

  /// Handle special commands
  bool _handleSpecialCommand(String text) {
    final lowerText = text.toLowerCase();

    // Naam Jaap commands
    if (lowerText.contains('naam jaap') ||
        lowerText.contains('jap') ||
        lowerText.contains('chant')) {
      if (lowerText.contains('start') || lowerText.contains('begin')) {
        setInputMode(UnifiedInputMode.naamJaap);
        _addAssistantMessage(
            'Naam Jaap mode activated! Aap kaunsa mantra jaapna chahenge? Om Namah Shivaya, Hare Krishna, ya koi aur?');
        return true;
      }
    }

    // Voice memo commands
    if (lowerText.contains('voice memo') ||
        lowerText.contains('record') ||
        lowerText.contains('recording')) {
      if (lowerText.contains('start') || lowerText.contains('record')) {
        setInputMode(UnifiedInputMode.voiceMemo);
        _addAssistantMessage(
            'Voice memo mode activated! Recording start karne ke liye record button dabayein.');
        return true;
      }
    }

    // Chat mode command
    if (lowerText.contains('chat mode') || lowerText.contains('normal mode')) {
      setInputMode(UnifiedInputMode.chat);
      _addAssistantMessage(
          'Chat mode mein wapas aa gaye hain! Kya poochna chahenge?');
      return true;
    }

    // Goal planning command
    if (lowerText.contains('plan') &&
        (lowerText.contains('goal') ||
            lowerText.contains('learning') ||
            lowerText.contains('learn') ||
            lowerText.contains('study') ||
            lowerText.contains('30 day') ||
            lowerText.contains('routine'))) {
      unawaited(_handleGoalPlanning(lowerText));
      return true;
    }

    // Reminder commands - handle voice queries about reminders
    if (_handleReminderCommand(lowerText)) {
      return true;
    }

    return false;
  }

  /// Handle reminder-related voice commands
  bool _handleReminderCommand(String lowerText) {
    // Check for reminder queries
    final reminderKeywords = [
      'reminder',
      'reminders',
      'yaad dilao',
      'yaad dilaye',
      ' reminder',
    ];

    final hasReminderKeyword =
        reminderKeywords.any((keyword) => lowerText.contains(keyword));

    if (!hasReminderKeyword) return false;

    // Check for specific reminder queries
    final showKeywords = [
      'show',
      'what',
      'kya',
      'list',
      'mera',
      'my',
      'batao',
      'tell',
      'kitne',
      'how many',
      'check',
      'dekho'
    ];
    final isAskingToShow = showKeywords.any((kw) => lowerText.contains(kw));

    if (isAskingToShow) {
      // Get reminder info from service
      final reminderInfo = reminderService.getRemindersForVoiceResponse();
      _addAssistantMessage(reminderInfo);
      return true;
    }

    // Check for next reminder query
    final nextKeywords = ['next', 'agla', 'pehla', 'upcoming', 'kab', 'when'];
    final isAskingNext = nextKeywords.any((kw) => lowerText.contains(kw));

    if (isAskingNext) {
      final upcoming = reminderService.getUpcomingReminder();
      if (upcoming != null) {
        _addAssistantMessage(
            "Your next reminder is ${upcoming.title} at ${upcoming.formattedTime}. It's a ${upcoming.category} reminder.");
      } else {
        _addAssistantMessage(
            "You don't have any upcoming reminders for today.");
      }
      return true;
    }

    // Check for completed/pending queries
    final statusKeywords = ['complete', 'done', 'finished', 'pending', 'baki'];
    final isAskingStatus = statusKeywords.any((kw) => lowerText.contains(kw));

    if (isAskingStatus) {
      final completed = reminderService.completedCount;
      final pending = reminderService.pendingCount;
      final total = reminderService.reminders.length;

      _addAssistantMessage(
          'You have completed $completed out of $total reminders. $pending reminders are still pending for today.');
      return true;
    }

    return false;
  }

  /// Process voice input
  Future<void> processVoiceInput(String text) async {
    if (text.isEmpty) return;

    // Run language routing in background (non-blocking)
    unawaited(Get.find<LanguageRoutingService>().analyzeAndRoute(text, ''));

    textController.text = text;
    await sendMessage();

    // Log voice metrics
    unawaited(logVoiceMetrics(
      sttLatencyMs: 0,
      wordErrorRate: 0.0,
      userRepeated: false,
    ));
  }

  /// Send a text query directly — used by curiosity-hook option chips.
  /// Bypasses the text field so the user doesn't need to type anything.
  Future<void> sendTextDirectly(String text) async {
    if (text.trim().isEmpty) return;
    textController.text = text.trim();
    await sendMessage();
  }

  Future<void> _handleGoalPlanning(String userText) async {
    isLoading.value = true;
    status.value = 'Creating your plan...';
    try {
      final aiCtx = Get.find<AIContextController>();
      final plan = await aiCtx.createGoalPlan(userText);
      if (plan != null) {
        final planText =
            'Here is your ${plan.totalDays}-day plan for "${plan.goalTitle}":\n'
            'Milestones:\n${plan.milestones.map((m) => "• $m").join("\n")}\n\n'
            'Daily tasks:\n${plan.dailyTasks.map((t) => "• $t").join("\n")}';
        _addAssistantMessage(planText, modelName: 'Goal Planner');
        await queryHandler.addToHistory('assistant', planText);
      } else {
        _addAssistantMessage(
            'I could not create a plan right now. Please try again.');
      }
    } catch (e) {
      _addAssistantMessage('Sorry, I encountered an error creating your plan.');
    } finally {
      isLoading.value = false;
      status.value = 'Ready';
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// PROCESS MESSAGE — Full AI Pipeline (Non-blocking)
  /// ═══════════════════════════════════════════════════════════
  /// Processes the user message through the AI pipeline without blocking
  /// the UI thread. Uses delays and microtasks to ensure video wallpaper
  /// and all animations stay smooth during AI processing.
  Future<void> _processMessage(String userText) async {
    isLoading.value = true;
    status.value = 'Thinking...';

    // CRITICAL: Initial delay to ensure UI updates (prevents video freeze)
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      // Check connectivity (with UI yield)
      final connectivity = await Connectivity().checkConnectivity();
      await Future.delayed(
          const Duration(milliseconds: 20)); // Yield to keep animations smooth

      if (connectivity.contains(ConnectivityResult.none)) {
        _addAssistantMessage(
            '📡 Kripya internet connection check karein. Main online hoon.');
        status.value = 'No Internet';
        isLoading.value = false;
        return;
      }

      // ═══════════════════════════════════════════════════════════
      // SPECIAL QUERY DETECTION (Before General AI Pipeline)
      // Check if this is a developer info query or navigation query
      // ═══════════════════════════════════════════════════════════
      final languageController = Get.find<LanguageController>();
      final selectedLanguage = languageController.selectedLanguage.value.code;

      // Check for Developer Info Queries
      if (await _processDeveloperInfoQuery(userText, selectedLanguage)) {
        isLoading.value = false;
        return;
      }

      // Check for Navigation Queries
      if (await _processNavigationQuery(userText, selectedLanguage)) {
        isLoading.value = false;
        return;
      }

      // Build system prompt based on persona
      final systemPrompt = _buildSystemPrompt();
      await Future.delayed(
          const Duration(milliseconds: 20)); // Yield to keep animations smooth

      // Phase 2: Run mood analysis on the user text
      try {
        if (Get.isRegistered<MoodDetectionService>()) {
          final moodSvc = Get.find<MoodDetectionService>();
          final moodState = moodSvc.analyzeMood(text: userText);
          currentMood.value = moodState.type;
          moodConfidence.value = moodState.confidence;
          moodHistory.add(moodState);
          if (moodHistory.length > 50) moodHistory.removeAt(0);
          debugPrint(
              'Mood: ${moodState.type.label} (${moodState.confidencePercent})');
        }
      } catch (e) {
        debugPrint('Mood analysis error: $e');
      }

      // Build history from previous messages (excluding the last one which is current userText)
      final history = <Map<String, String>>[];
      if (messages.length > 1) {
        // Take up to 10 previous messages for context
        final previousMessages = messages.sublist(
            (messages.length - 11).clamp(0, messages.length),
            messages.length - 1);

        for (final msg in previousMessages) {
          history.add({
            'role': msg.role,
            'content': msg.content,
          });
        }
      }

      // ════════════════════════════════════════════════════
      // Use QueryHandlerService with Strategy Pipeline:
      //   Analyze Input → Profile User → Classify Intent → Build Strategy
      //   → Inject into Prompt → Route → Fetch RT data → Call AI → Fallback
      // ════════════════════════════════════════════════════
      final response = await queryHandler.processQueryWithStrategy(
        userText: userText,
        systemPrompt: systemPrompt,
        history: history,
        currentScreen: AppRoutes.voiceChat, // Pass current screen context
      );

      // Yield to UI thread before updating state (prevents video freeze)
      await Future.delayed(const Duration(milliseconds: 50));

      if (response != null) {
        String filteredResponse = response;
        String? navigateTo;

        // Parse redirects triggered by AI
        final redirectMatch =
            RegExp(r'\[REDIRECT:([a-zA-Z_]+)\]').firstMatch(response);
        if (redirectMatch != null) {
          navigateTo = redirectMatch.group(1);
          filteredResponse =
              response.replaceAll(redirectMatch.group(0)!, '').trim();
        }

        // Parse music play commands triggered by AI
        final musicMatch =
            RegExp(r'\[PLAY_URL:([^\]|]+)\|([^\]]+)\]').firstMatch(response);
        if (musicMatch != null) {
          final url = musicMatch.group(1)!;
          final title = musicMatch.group(2)!;
          filteredResponse =
              filteredResponse.replaceAll(musicMatch.group(0)!, '').trim();

          // Small delay so TTS finishes its introductory sentence (if any)
          // or we can play it immediately.
          Future.delayed(const Duration(seconds: 2), () {
            musicService.playTrack(url, title);
          });
        }

        _addAssistantMessage(
          filteredResponse,
          modelName: queryHandler.activeModelName,
        );

        if (navigateTo != null) {
          _handleNavigation(navigateTo);
        }

        // Log analytics
        unawaited(Get.find<AnalyticsService>().logQuery(
          userId: '',
          model: queryHandler.activeModelName,
          inputTokens: userText.length ~/ 4,
          outputTokens: filteredResponse.length ~/ 4,
          latencyMs: 0,
          cacheHit: false,
        ));

        // Trigger emotion analysis on voice input
        if (userText.isNotEmpty) {
          unawaited(Get.find<EmotionService>().analyzeVoiceEmotion(
            Uint8List(0),
            '',
          ));
        }

        // Update user profile based on their query
        try {
          final profileController = Get.find<ProfileController>();
          await profileController.updateUserProfile(userText);
          debugPrint(
              '👤 Profile updated: ${profileController.getExpertiseLevelString()}');
        } catch (e) {
          debugPrint('Profile update error: $e');
        }
      } else {
        // ── All AI models exhausted ─────────────────────────────────────
        // 1. Show a brief in-chat message so the conversation history has context.
        const String serviceUnavailableMsg =
            'Our AI service is temporarily unavailable due to expired API '
            'credentials. The CTJ team is working on a fix. '
            'Please update your app from the Google Play Store to restore '
            'full voice chat functionality.';
        _addAssistantMessage(serviceUnavailableMsg, modelName: 'CTJ System');

        // 2. Show the formal glassmorphic update notification dialog.
        //    Using a short delay so the chat message renders first.
        Future.delayed(const Duration(milliseconds: 400), () {
          GlassmorphicDialogHelper.showAllModelsFailedDialog();
        });
      }

      status.value = 'Ready';
    } catch (e) {
      debugPrint('❌ Process Message Error: $e');
      String errorMessage = 'Something went wrong. Please try again later.';
      try {
        final langCtrl = Get.find<LanguageController>();
        final selectedCode = langCtrl.selectedLanguage.value.code;

        String tl = selectedCode;
        if (tl == 'en-US' || tl == 'en-GB') tl = 'en';

        if (tl != 'hinglish') {
          final result = await TranslationService.translate(
            text: errorMessage,
            targetLanguage: tl,
          );
          errorMessage = result.translatedText;
        } else {
          errorMessage = 'Kuch galat ho gaya. Kripya baad mein try karein.';
        }
      } catch (_) {
        errorMessage = 'Kuch galat ho gaya. Kripya baad mein try karein.';
      }

      _addAssistantMessage(errorMessage);
      status.value = 'Error';
    } finally {
      // Yield before setting loading to false (ensures smooth transition)
      await Future.delayed(const Duration(milliseconds: 50));
      isLoading.value = false;
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// Helper: Process Developer Info Queries
  /// ═══════════════════════════════════════════════════════════
  /// Checks if the user input is asking about the app developer
  /// Returns true if processed (and should skip general AI pipeline)
  Future<bool> _processDeveloperInfoQuery(
    String userText,
    String selectedLanguage,
  ) async {
    try {
      DeveloperInfoController devController;
      try {
        devController = Get.find<DeveloperInfoController>();
      } catch (_) {
        devController = Get.put(DeveloperInfoController());
      }

      if (!devController.isDeveloperRelatedQuery(userText,
          language: selectedLanguage)) {
        return false;
      }

      debugPrint('🎯 [VoiceCtrl] Creator query detected');

      // Step 1: Reply with creator info
      final String response =
          devController.getMainResponse(language: selectedLanguage);
      _addAssistantMessage(response);
      await speakText(response);

      // Wait before navigation
      await Future.delayed(const Duration(seconds: 2));

      // Step 2 & 3: Navigate to About screen and scroll to Connect With Us
      debugPrint('🔀 [VoiceCtrl] Navigating to About screen');
      await Get.offNamed(AppRoutes.about, arguments: {'scrollToContact': true});

      // Step 4: Wait for About screen to build, then read contact info
      await Future.delayed(const Duration(seconds: 2));
      final contactInfo =
          devController.getContactInfo(language: selectedLanguage);
      await speakText(contactInfo);

      return true;
    } catch (e) {
      debugPrint('❌ [VoiceCtrl] Error processing creator query: $e');
      return false;
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// Helper: Process Navigation Queries
  /// ═══════════════════════════════════════════════════════════
  /// Checks if the user input is asking to navigate to another screen
  /// Returns true if processed (and should skip general AI pipeline)
  Future<bool> _processNavigationQuery(
    String userText,
    String selectedLanguage,
  ) async {
    try {
      // Get or create NavigationController if not already available
      NavigationController navController;
      try {
        navController = Get.find<NavigationController>();
      } catch (_) {
        navController = Get.put(NavigationController());
      }

      // Check if this is a navigation query
      if (!navController.isNavigationQuery(userText,
          language: selectedLanguage)) {
        return false; // Not a navigation query
      }

      debugPrint('🎯 [VoiceCtrl] Navigation query detected');

      // Process the navigation query
      // NavigationController handles the detection and actual navigation
      await navController.processNavigationQuery(
        userText,
        language: selectedLanguage,
      );

      return true; // Query was processed
    } catch (e) {
      debugPrint('❌ [VoiceCtrl] Error in navigation query: $e');
      return false;
    }
  }

  /// Build system prompt
  String _buildSystemPrompt() {
    final now = DateTime.now();
    final timeString = "${now.hour}:${now.minute.toString().padLeft(2, '0')}";
    final dateString = '${now.day}-${now.month}-${now.year}';

    // Get user profile context if available
    String userContext = '';
    try {
      final profileController = Get.find<ProfileController>();
      userContext = profileController.getAIContext();
    } catch (e) {
      // ProfileController not initialized, use defaults
    }

    // FIX 2 & 3: Get the selected language from LanguageController
    String selectedLanguageInfo = 'Hinglish (Hindi + English mix)';
    String languageInstructions = '';
    try {
      final langCtrl = Get.find<LanguageController>();
      final selectedLang = langCtrl.selectedLanguage.value;
      selectedLanguageInfo = selectedLang.name;

      // Build language-specific instructions
      languageInstructions = '''

LANGUAGE INSTRUCTIONS (EXTREMELY STRICT GUARDRAIL):
• Target Language: ${selectedLang.nativeName} (${selectedLang.name})
• YOU ABSOLUTELY MUST respond ONLY in ${selectedLang.nativeName} (${selectedLang.name}).
• Write your entire response using the native script/alphabet of ${selectedLang.name}.
• NO MATTER WHAT language the user's prompt appears to be in (translated or not), your output MUST BE IN ${selectedLang.name}.
• DO NOT translate the user's prompt back to them. Just answer the query IN ${selectedLang.name}.
• DO NOT use English words or any other language unless technically necessary.
• For text-to-speech output, the response will be read aloud by a ${selectedLang.name} voice model, so if you use wrong characters, it will fail.
''';
    } catch (e) {
      // LanguageController not initialized, fall back to default
      debugPrint('LanguageController not available: $e');
    }

    String currentScreenInfo = '';
    String liveEnvironmentData = '';
    try {
      if (Get.isRegistered<AIContextController>()) {
        final aiContextCtrl = Get.find<AIContextController>();
        currentScreenInfo = aiContextCtrl.buildContextSnippet();
      }

      if (Get.isRegistered<TopPanelController>()) {
        final topPanelCtrl = Get.find<TopPanelController>();

        if (currentScreenInfo.isEmpty) {
          currentScreenInfo =
              "• Current Screen Route: ${topPanelCtrl.currentRoute.value}\n• Screen Features: ${topPanelCtrl.currentScreenContext.value}\n[IMPORTANT: You are aware of the current screen. If the user asks about ANY features, buttons, or elements on this particular screen, use the 'Screen Features' description above to explain it to them accurately.]";
        }

        final city = topPanelCtrl.placeName.value;
        final temp = topPanelCtrl.temperature.value;
        final aqi = topPanelCtrl.aqiNum.value;
        if (city.isNotEmpty && city != 'Detecting...' && city != 'your area') {
          liveEnvironmentData =
              '• Current Location: $city\n• Current Temperature: $temp\n• Air Quality Index (AQI): $aqi';
        }
      }
    } catch (_) {}

    // Phase 2: Mood modifier
    String moodContext = '';
    try {
      final mood = currentMood.value;
      if (mood != null && mood != MoodType.neutral) {
        if (Get.isRegistered<MoodDetectionService>()) {
          moodContext = Get.find<MoodDetectionService>()
              .getMoodSystemPromptModifier(mood);
        }
      }
    } catch (_) {}

    // Phase 2: Personality modifier
    String personalityContext = '';
    try {
      if (Get.isRegistered<PersonalityResponseEngine>()) {
        personalityContext =
            Get.find<PersonalityResponseEngine>().getSystemPromptModifier(
          currentPersonalityPack.value,
          currentMood.value ?? MoodType.neutral,
        );
      }
    } catch (_) {}

    // Phase 2: Festival greeting context
    String festivalContext = '';
    try {
      if (Get.isRegistered<FestivalThemeController>()) {
        final festCtrl = Get.find<FestivalThemeController>();
        if (festCtrl.isFestivalDay) {
          festivalContext = 'Today is ${festCtrl.activeFestivalName.value}. '
              'You MUST wish the user with a warm Hinglish festival greeting at the '
              'start of your next response and suggest 1-2 festival activities.\n';
        }
      }
    } catch (_) {}

    // Phase 2: Family and emotional relationship context
    String familyContext = '';
    try {
      if (Get.isRegistered<FamilyRelationshipManagerService>()) {
        final familySvc = Get.find<FamilyRelationshipManagerService>();
        familyContext = '''FAMILY & RELATIONSHIP RULES:
User Role: ${familySvc.userCategory.value.name}.
1. If user asks you to talk to a family member (e.g., Mother, Father, Wife, Child), address them respectfully (e.g., Namaste Sourav's Mata Ji) and speak positively about the user.
2. If the user says goodbye or good night, use emotional persuasion before letting them go. E.g., Remind them to call their parents, check on their children, or wish their spouse based on their User Role.
''';
      }
    } catch (_) {}

    // Phase 2: Health & Hygiene Context
    String healthContext = '';
    try {
      if (Get.isRegistered<HealthHygieneManagerService>()) {
        final healthSvc = Get.find<HealthHygieneManagerService>();
        healthContext = '''HEALTH & HYGIENE RULES:
User Age Group: ${healthSvc.detectedAgeGroup.value.name}.
1. Always show affectionate concern for health, hygiene, and safety based on age group.
2. If they mention eating, casually remind them to wash hands.
3. If they mention going out, remind them about masks, jackets, or safety playfully and lovingly.
4. In emergencies like feeling dizzy or breathless, firmly tell them to sit down, drink water, and contact parents/doctors.
''';
      }
    } catch (_) {}

    const String appNavigationContext = '''
SPECIAL INSTRUCTIONS - DEVELOPER INFO & NAVIGATION:
1. If the user asks about the developer, creator, owner, "father of this app", inventor, or Malik:
   - Identify the user's language and respond in that language.
   - You MUST include these details: "The developer's name is Sourav Kumar and he resides in India from Jamshedpur. Sourav Kumar is a Flutter Dev who builds (Mobile APPs for Both Android and IOS). He loves new opportunity if given, kindly have a conversation and get benefitted."
   - You MUST append exactly [REDIRECT:ABOUT] at the end of the response.
2. If the user wants to navigate, jump, redirect, move, or switch to any screen:
   - Identify the target screen from their request (even in Hindi or other languages).
   - Use the appropriate code from this list:
     * Voice Chat: [REDIRECT:VOICE_CHAT]
     * Game Hub: [REDIRECT:GAME]
     * Game Play: [REDIRECT:GAME_PLAY]
     * Voice Assistant Game: [REDIRECT:VOICE_ASSISTANT_GAME]
     * Voice Studio: [REDIRECT:VOICE_STUDIO]
     * Alarm: [REDIRECT:ALARM]
     * Edit Alarm: [REDIRECT:ALARM_EDIT]
     * Alarm Ringing: [REDIRECT:ALARM_RINGING]
     * Naam Jaap: [REDIRECT:NAAM_JAAP]
     * History: [REDIRECT:HISTORY]
     * About/Developer: [REDIRECT:ABOUT]
     * Settings: [REDIRECT:SETTINGS]
     * Wallpaper: [REDIRECT:WALLPAPER]
     * Set Wallpaper: [REDIRECT:WALLPAPER_SET]
     * Reminders: [REDIRECT:REMINDER]
     * Edit Reminder: [REDIRECT:REMINDER_EDIT]
     * Profile: [REDIRECT:PROFILE]
   - Example (Hindi): "Thik hai, main aapko game screen par le chalti hoon. [REDIRECT:GAME]"
''';

    final String basePrompt = '''
CRITICAL RULES:
${festivalContext.isNotEmpty ? festivalContext : ''}
- Never use special characters, symbols, emojis, or markdown
- Speak in clean, natural sentences
- Keep responses appropriate for voice output
- Names must be complete words (e.g., "SHOURAV" not "S H O U R A V")

CURRENT CONTEXT:
- Time: $timeString
- Date: $dateString
- User: ${userTitle.value} ${userName.value}
- Language: $selectedLanguageInfo
- Available Modes: Chat, Voice Memo, Naam Jaap
- Current Mode: ${currentInputMode.value.toString().split('.').last}
${liveEnvironmentData.isNotEmpty ? '$liveEnvironmentData\n' : ''}$currentScreenInfo

${userContext.isNotEmpty ? 'USER PROFILE CONTEXT (ALWAYS BE AWARE OF THIS):\n$userContext' : ''}

$languageInstructions

${personas[currentPersona.value]!.systemPrompt}

${personalityContext.isNotEmpty ? 'PERSONALITY STYLE:\n$personalityContext' : ''}

${moodContext.isNotEmpty ? 'EMOTIONAL CONTEXT:\n$moodContext' : ''}

${familyContext.isNotEmpty ? familyContext : ''}

${healthContext.isNotEmpty ? healthContext : ''}

$appNavigationContext

ORB IDENTITY (CRITICAL):
Your name is Palak (P-A-L-A-K). Make sure you know this if asked "what is your name", "who are you" or similar queries.
If the user asks your name, you MUST respond exactly like this or similar: "I am a female from India, and my name is Palak, which means the eyelash."

SPECIAL FEATURES:
- You can help with Naam Jaap (chanting mantras like Om Namah Shivaya, Hare Krishna)
- You can record and play voice memos
- You can switch between modes based on user requests
- For Naam Jaap, support English, Hindi (Devanagari), and Hinglish
''';

    return basePrompt;
  }

  /// Handle navigation commands returned by the AI
  void _handleNavigation(String screenCode) {
    Future.delayed(const Duration(milliseconds: 1500), () async {
      switch (screenCode.toUpperCase()) {
        case 'VOICE_CHAT':
        case 'CHAT':
          Get.offAllNamed(AppRoutes.voiceChat);
          break;
        case 'PROFILE':
          Get.offAllNamed(AppRoutes.profile);
          break;
        case 'GAME':
        case 'GAMES':
          Get.offAllNamed(AppRoutes.game);
          break;
        case 'GAME_PLAY':
          Get.offAllNamed(AppRoutes.gamePlay);
          break;
        case 'VOICE_ASSISTANT_GAME':
          Get.offAllNamed(AppRoutes.voiceAssistantGame);
          break;
        case 'VOICE_STUDIO':
        case 'STUDIO':
          Get.offAllNamed(AppRoutes.voiceStudio);
          break;
        case 'ALARM':
          Get.offAllNamed(AppRoutes.alarm);
          break;
        case 'ALARM_EDIT':
          Get.offAllNamed(AppRoutes.alarmEdit);
          break;
        case 'ALARM_RINGING':
          Get.offAllNamed(AppRoutes.alarmRinging);
          break;
        case 'NAAM_JAAP':
        case 'JAAP':
          Get.offAllNamed(AppRoutes.naamJaap);
          break;
        case 'RADIO':
          await sttService.cancelListening();
          await Get.to(() => const GardenPortalScreen(
                url: 'https://radio.garden',
                title: 'Global Radio Explorer',
              ));
          await sttService.cancelListening();
          break;
        case 'TV':
          await sttService.cancelListening();
          await Get.to(() => const GardenPortalScreen(
                url: 'https://tvgarden.world',
                title: 'World TV Window',
              ));
          await sttService.cancelListening();
          break;
        case 'HISTORY':
          Get.offAllNamed(AppRoutes.history);
          break;
        case 'SETTINGS':
        case 'SETTING':
          Get.offAllNamed(AppRoutes.settings);
          break;
        case 'WALLPAPER':
        case 'THEME':
          Get.offAllNamed(AppRoutes.wallpaper);
          break;
        case 'WALLPAPER_SET':
          Get.offAllNamed(AppRoutes.wallpaperSet);
          break;
        case 'REMINDER':
        case 'REMINDERS':
          Get.offAllNamed(AppRoutes.reminder);
          break;
        case 'REMINDER_EDIT':
          Get.offAllNamed(AppRoutes.reminderEdit);
          break;
        case 'ABOUT':
        case 'DEVELOPER':
          Get.offAllNamed(AppRoutes.about);
          break;
        default:
          debugPrint('Unknown screen code for navigation: $screenCode');
      }
    });
  }

  /// Add assistant message (with duplicate prevention)
  void _addAssistantMessage(String content, {String? modelName}) {
    // DUPLICATE PREVENTION: Skip empty content
    if (content.trim().isEmpty) {
      debugPrint('⚠️ Skipping empty assistant message');
      return;
    }

    // DUPLICATE PREVENTION: Check if last message is identical or very similar
    if (messages.isNotEmpty) {
      final lastMsg = messages.last;
      if (lastMsg.role == 'assistant') {
        final lastContent = lastMsg.content.trim();
        final newContent = content.trim();

        // Exact match
        if (lastContent == newContent) {
          debugPrint('🔁 Exact duplicate message detected and skipped');
          return;
        }

        // Check for 90%+ similarity (for connection/retry messages that differ slightly)
        if (_calculateSimilarity(lastContent, newContent) > 0.85) {
          debugPrint(
              '🔁 Similar message detected (${(_calculateSimilarity(lastContent, newContent) * 100).toStringAsFixed(0)}% match) and skipped');
          return;
        }
      }
    }

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'assistant',
      content: content,
      timestamp: DateTime.now(),
      modelName: modelName ?? activeModelName.value,
      threadId:
          currentThreadId.isNotEmpty ? currentThreadId.value : null, // FIX 4
    );

    messages.add(message);
    _saveMessages();
    _scrollToBottom();

    // Auto-speak: detect story mode vs. normal message
    _autoSpeak(message);
  }

  /// Calculate string similarity (Jaro-Winkler-like simple algorithm)
  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    // For short strings, use simple character match
    final shorter = s1.length < s2.length ? s1 : s2;
    final longer = s1.length < s2.length ? s2 : s1;

    int matches = 0;
    for (int i = 0; i < shorter.length; i++) {
      if (i < longer.length && shorter[i] == longer[i]) {
        matches++;
      }
    }

    return matches / longer.length;
  }

  /// Auto-speak dispatcher — chooses story segments or normal chunked TTS.
  /// Strips the EduChain [OPTIONS:...] curiosity-hook tag before speaking
  /// (it is rendered as tappable chips in the UI, not spoken aloud).
  Future<void> _autoSpeak(ChatMessage message) async {
    // Strip curiosity hook + speech coach version tags — never speak raw tags aloud
    final cleanContent = message.content
        .replaceAll(
          RegExp(r'\[OPTIONS:A:.+?\|B:.+?\|C:.+?\]', dotAll: true),
          '',
        )
        .replaceAll(
          RegExp(r'\[MY_VERSION:[\s\S]+?\](?:\s*)$', multiLine: true),
          '',
        )
        .trim();

    final speakable = cleanContent == message.content
        ? message // no tag found — use original object (no alloc)
        : ChatMessage(
            id: message.id,
            role: message.role,
            content: cleanContent,
            timestamp: message.timestamp,
            modelName: message.modelName,
            threadId: message.threadId,
          );

    try {
      final handler = Get.find<QueryHandlerService>();
      if (handler.isStoryResponse(speakable.content)) {
        await speakStorySegments(speakable);
        return;
      }
    } catch (_) {
      // QueryHandlerService not yet available — fall through
    }
    speakMessage(speakable);
  }

  /// Play a story-mode response, switching voices per character segment
  Future<void> speakStorySegments(ChatMessage message) async {
    _activeChunkController?.cancel();
    currentSpeakingMessageId.value = message.id;
    ttsGracePeriodOver.value = false;

    try {
      final handler = Get.find<QueryHandlerService>();
      final segments = handler.parseStorySegments(message.content);

      for (final seg in segments) {
        if (currentSpeakingMessageId.value != message.id) break; // cancelled
        isTalking.value = true;
        if (_engineSwitcher != null) {
          await _engineSwitcher!.speakInLanguage(seg.text, seg.languageCode);
        } else {
          await ttsService.speak(seg.text);
        }
        // Short gap between characters
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      debugPrint('❌ speakStorySegments error: $e');
    } finally {
      isTalking.value = false;
      currentSpeakingMessageId.value = '';
      ttsGracePeriodOver.value = false;
    }
  }

  /// Speak a message using chunked TTS
  ///
  /// Process:
  /// 1. Cancel any existing reading
  /// 2. Set active message ID and grace period flag
  /// 3. Apply persona effects
  /// 4. Start 1-second grace period (full visibility, no blur)
  /// 5. Create chunk controller and play all chunks
  /// 6. Update isTalking based on TTS state

  // Timer-based fallback for word highlighting and lip-sync.
  // Drives TTSService.progressWordIndex + speakingWordPulse at a fixed cadence
  // so both features work on Android where setProgressHandler may not fire.
  Timer? _wordHighlightTimer;

  Future<void> speakMessage(ChatMessage message) async {
    // Grab a new session token for this call
    _speakSessionToken++;
    final int localToken = _speakSessionToken;

    // If a previous speak is still in-flight, stop it cleanly first
    if (_isSpeakBusy) {
      _activeChunkController?.cancel();
      try {
        await ttsService.stop();
      } catch (_) {}
      try {
        if (_engineSwitcher != null) await _engineSwitcher!.stop();
      } catch (_) {}
      // Small yield so TTS engine fully stops before we start again
      await Future.delayed(const Duration(milliseconds: 80));
    }
    _isSpeakBusy = true;

    // Cancel any existing chunk controller and running timer
    _activeChunkController?.cancel();
    _wordHighlightTimer?.cancel();
    _wordHighlightTimer = null;

    // CRITICAL: Reset TTS progress tracking before starting new message
    ttsService.progressWordIndex.value = -1;

    // Set active message for highlighting
    currentSpeakingMessageId.value = message.id;
    ttsGracePeriodOver.value = false;
    isTalking.value = true;

    // ── Progressive word-reveal: determine if this is a first-time auto-speak
    // or a manual "Read Aloud" replay.
    // • First-time: progressiveMessageId != message.id → start from 0, reveal word-by-word
    // • Replay:     progressiveMessageId == message.id → all words already visible, just highlight
    final bool isFirstTimeSpeak = progressiveMessageId.value != message.id;
    if (isFirstTimeSpeak) {
      progressiveMessageId.value = message.id;
      progressiveWordCount.value = 0;
    }
    // (For replay the progressiveWordCount stays at its final value = all words visible)

    // Apply persona effects
    ttsService.applyPersonaEffects(currentPersona.value);

    // ── Orb Thinking Integration ──
    try {
      final orbController = Get.find<OrbThinkingController>();
      orbController.onSentenceSpoken(message.content);
    } catch (e) {
      debugPrint('Orb thinking error: $e');
    }

    // ── WORD HIGHLIGHTING + LIP-SYNC TIMER ───────────────────────────────
    // This timer is the primary driver for both features on Android, where
    // flutter_tts.setProgressHandler() often does NOT fire callbacks.
    // • Increments progressWordIndex on each tick (drives TtsAwareMessageBody)
    // • Toggles speakingWordPulse on each tick (drives AnimatedOrb lip-sync)
    //
    // Words are derived from the SAME preprocessText() pipeline that
    // TtsAwareMessageBody uses, so indices always align perfectly.
    //
    // If native TTS progress events DO fire (e.g. iOS / some Android), they
    // take over because the guard "if (real event is ahead, skip this tick"
    // prevents double-advancing.
    final String preprocessed = ttsService.preprocessText(message.content);
    final List<String> words =
        preprocessed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    // ── Word-timing calibration ──────────────────────────────────────────
    // Android flutter_tts at rate=0.5 speaks ~4–5 syllables/sec, which maps
    // to roughly 200–260 ms/word for typical speech. The old formula
    // (320/rate) was far too conservative, making highlighting lag behind.
    //
    // New calibrated formula: 160/rate  →  rate=0.5 → 320ms, rate=1.0 → 160ms
    // Clamped: minimum 100ms (fast), maximum 500ms (very slow).
    // This matches the observed Android TTS cadence across all supported languages.
    final double speechRate = ttsService.voiceSpeed.value.clamp(0.2, 1.5);
    final int msPerWord = (160 / speechRate).clamp(100, 500).round();
    int timerWordIdx = 0;

    _wordHighlightTimer = Timer.periodic(
      Duration(milliseconds: msPerWord),
      (timer) {
        if (_speakSessionToken != localToken) {
          timer.cancel();
          return;
        }
        // If native TTS progress events are ahead, let them lead;
        // sync the timer cursor to avoid double-advancing.
        if (ttsService.progressWordIndex.value > timerWordIdx) {
          timerWordIdx = ttsService.progressWordIndex.value;
        }

        if (timerWordIdx < words.length) {
          // Advance word index → TtsAwareMessageBody highlights this word
          ttsService.progressWordIndex.value = timerWordIdx;
          // ── Progressive reveal: expose one more word to the UI ────────
          // Only advance during first-time auto-speak (not during replay)
          if (isFirstTimeSpeak &&
              progressiveWordCount.value <= timerWordIdx + 1) {
            progressiveWordCount.value = timerWordIdx + 1;
          }
          // Toggle pulse → AnimatedOrb reacts with a mouth-open burst
          ttsService.speakingWordPulse.value =
              !ttsService.speakingWordPulse.value;
          // Peak intensity on every word — AnimatedOrb decays this
          ttsService.speakingIntensity.value = 1.0;
          timerWordIdx++;
        } else {
          // ── Timer has passed through all words of the preprocessed text ───
          // Clear the word highlight so no word stays "stuck" highlighted
          // while we wait for the next TTS chunk to start playing.
          if (ttsService.progressWordIndex.value >= 0) {
            ttsService.progressWordIndex.value = -1;
          }
          // Keep intensity non-zero so orb's glow stays active between chunks
          ttsService.speakingIntensity.value = 0.4;
        }
      },
    );

    // Start grace period timer
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (_speakSessionToken == localToken) {
        ttsGracePeriodOver.value = true;
      }
    });

    // Retrieve language code
    String? langCode;
    try {
      langCode =
          Get.find<LanguageController>().selectedLanguage.value.sttLocale;
    } catch (_) {}

    try {
      // Use ChunkedHighlightService for intelligent chunked playback with
      // synchronized word-level highlighting. This service:
      // 1. Splits message into 2000-word chunks
      // 2. Plays Chunk 1 while pre-processing Chunk 2 in background
      // 3. Highlights words in real-time as they're spoken
      // 4. Seamlessly transitions between chunks
      // 5. Maintains word-by-word highlighting sync throughout
      final chunkedService = Get.find<ChunkedHighlightService>();
      await chunkedService.playMessageChunkedWithHighlighting(
        messageText: message.content,
        messageId: message.id,
        languageCode: langCode,
      );
    } catch (e) {
      debugPrint('Error in speakMessage: $e');
    } finally {
      _wordHighlightTimer?.cancel();
      _wordHighlightTimer = null;
      // Only clean up UI state if THIS session is still the active one
      // (i.e., stopSpeaking hasn't started a newer session)
      if (_speakSessionToken == localToken) {
        try {
          final orbController = Get.find<OrbThinkingController>();
          orbController.onSpeechEnd();
        } catch (_) {}
        // ── FIX 3: Reset stop-button → speaker-button ──────────────────
        isTalking.value = false;
        // ── Sync TTS service speaking state (was not reset in _completeChunk) ─
        ttsService.isSpeaking.value = false;
        // ── FIX 5: Stop orb mouth movement by resetting pulse/intensity ─
        ttsService.speakingWordPulse.value = false;
        ttsService.speakingIntensity.value = 0.0;
        // ── FIX 4: Clear word highlight (no more last-word highlight) ───
        currentSpeakingMessageId.value = '';
        ttsGracePeriodOver.value = false;
        ttsService.progressWordIndex.value = -1;
        // ── Reveal all remaining words so the full message stays visible ─
        // Ensures no words are hidden even if TTS ended early or was chunked
        if (progressiveMessageId.value == message.id) {
          progressiveWordCount.value = words.length;
        }
      }
      _isSpeakBusy = false;
    }
  }

  /// Speak arbitrary text — routes through TtsEngineSwitcher if available
  Future<void> speakText(String text) async {
    // ── Orb Thinking Integration ──
    try {
      final orbController = Get.find<OrbThinkingController>();
      // Scan the text for keywords and trigger thought bubble
      orbController.onSentenceSpoken(text);
    } catch (e) {
      debugPrint('Orb thinking error: $e');
    }

    try {
      if (_engineSwitcher != null) {
        await _engineSwitcher!.speak(text);
      } else {
        await ttsService.speak(text);
      }
    } finally {
      // ── Orb Thinking Cleanup ──
      try {
        final orbController = Get.find<OrbThinkingController>();
        orbController.onSpeechEnd();
      } catch (e) {
        debugPrint('Orb thinking cleanup error: $e');
      }
    }
  }

  /// ═══════════════════════════════════════════════════════════
  /// Reset pipeline after in-app navigation to another screen
  /// (e.g. returning from Global Radio / World TV).
  ///
  /// The WebView portal can leave several flags in a corrupted state:
  ///   • _isSpeakBusy = true  → speakMessage() never starts
  ///   • isLoading = true      → sendMessage() short-circuits
  ///   • isTalking = true      → orb keeps spinning forever
  ///   • TTS observables dirty → word highlighting / lip-sync hangs
  ///
  /// This method is idempotent and safe to call at any time.
  /// ═══════════════════════════════════════════════════════════
  void resetPipelineAfterNavigation() {
    debugPrint('🔄 [VoiceController] resetPipelineAfterNavigation()');

    // 1. Bump the session token — orphaned speakMessage() finally blocks
    //    will see the mismatch and skip their state-clearing, which is fine
    //    because we're cleaning up right here instead.
    _speakSessionToken++;

    // 2. Clear the busy guard so speakMessage() can run again
    _isSpeakBusy = false;

    // 3. Clear the loading flag so sendMessage() is un-blocked
    isLoading.value = false;
    status.value = 'Ready';

    // 4. Clear all TTS/Orb animation state
    isTalking.value = false;
    currentSpeakingMessageId.value = '';
    ttsGracePeriodOver.value = false;

    // 5. Cancel any in-flight word-highlight timer
    _wordHighlightTimer?.cancel();
    _wordHighlightTimer = null;

    // 6. Cancel any active chunk controller
    _activeChunkController?.cancel();
    _activeChunkController = null;

    // 7. Reset TTS service observables (lip-sync / word highlight)
    try {
      ttsService.progressWordIndex.value = -1;
      ttsService.speakingWordPulse.value = false;
      ttsService.speakingIntensity.value = 0.0;
      ttsService.isSpeaking.value = false;
    } catch (_) {}

    // 8. Reveal any partially-displayed message so no text is hidden
    if (progressiveMessageId.value.isNotEmpty) {
      progressiveWordCount.value = 99999;
    }

    // 9. Reset selection mode if it was active
    isSelectionMode.value = false;
    selectedMessageIds.clear();

    // 10. Clear UI text input to avoid stale text from before navigation
    textController.clear();

    debugPrint(
        '✅ [VoiceController] Pipeline reset complete — ready for new query');
  }

  /// Verify that VoiceController is in a neutral, ready state.
  /// Used by VoiceSessionRestorationManager to confirm recovery success.
  bool verifyReadyState() {
    final bool isReady = !isLoading.value &&
        !_isSpeakBusy &&
        !isTalking.value &&
        currentSpeakingMessageId.value.isEmpty;

    debugPrint('🔍 [VoiceController] Readiness Check: $isReady');
    return isReady;
  }

  /// Stop speaking (all engines)
  Future<void> stopSpeaking() async {
    debugPrint('🔇 [VoiceController] stopSpeaking() called');

    // Increment session token — any in-flight speakMessage finally block
    // will see a token mismatch and skip its state-clearing logic
    _speakSessionToken++;
    _isSpeakBusy = false;

    // Immediately clear UI state so button icon switches instantly after stop
    // This ensures immediate visual feedback before async operations complete
    final wasPlaying = isTalking.value;
    final previousMessageId = currentSpeakingMessageId.value;

    isTalking.value = false;
    currentSpeakingMessageId.value = '';
    ttsGracePeriodOver.value = false;

    if (wasPlaying) {
      debugPrint(
          '🔇 [VoiceController] Stopped playback for message: $previousMessageId');
    }

    // Cancel chunk controller and highlight timer
    _activeChunkController?.cancel();
    _activeChunkController = null;
    _wordHighlightTimer?.cancel();
    _wordHighlightTimer = null;

    // ── FIX 4: Clear word highlight immediately on manual stop ──────────
    ttsService.progressWordIndex.value = -1;
    // ── FIX 5: Stop orb mouth + reset pulse so AnimatedOrb snaps closed ─
    ttsService.speakingWordPulse.value = false;
    ttsService.speakingIntensity.value = 0.0;
    // ── Reveal all words of the stopped message so nothing stays hidden ─
    // The stopped message should display its full text even though TTS
    // was interrupted mid-way through the progressive reveal.
    if (progressiveMessageId.value.isNotEmpty) {
      // Set a very large count to ensure all words become visible
      progressiveWordCount.value = 99999;
    }

    // Stop the TTS engine(s) - run in parallel for faster response
    final List<Future> stopTasks = [];

    if (_engineSwitcher != null) {
      stopTasks.add(_engineSwitcher!.stop().catchError((e) {
        debugPrint('⚠️ [VoiceController] Error stopping engine switcher: $e');
      }));
    }

    stopTasks.add(ttsService.stop().catchError((e) {
      debugPrint('⚠️ [VoiceController] Error stopping TTS service: $e');
    }));

    // 🎵 Stop Music Service
    stopTasks.add(musicService.stop().catchError((e) {
      debugPrint('⚠️ [VoiceController] Error stopping Music service: $e');
    }));

    // Wait for all stop operations to complete
    await Future.wait(stopTasks);

    debugPrint('✅ [VoiceController] All TTS engines stopped');

    // ── Orb Thinking Cleanup ──
    try {
      final orbController = Get.find<OrbThinkingController>();
      orbController.onSpeechEnd();
    } catch (e) {
      debugPrint('Orb thinking cleanup error: $e');
    }
  }

  /// Clear chat
  void clearChat() {
    messages.clear();
    // Clear thread messages too (Fix 4)
    if (currentThreadId.value.isNotEmpty &&
        threads.containsKey(currentThreadId.value)) {
      threads[currentThreadId.value] = [];
    }

    // Reset query prediction session
    try {
      if (Get.isRegistered<QueryPredictionController>()) {
        final predCtrl = Get.find<QueryPredictionController>();
        predCtrl.resetSession();
      }
    } catch (e) {
      debugPrint('Query prediction reset error: $e');
    }

    _saveMessages();

    // Reset progressive word-reveal state so next messages start fresh
    progressiveMessageId.value = '';
    progressiveWordCount.value = 0;
  }

  /// Delete selected messages
  void deleteSelectedMessages() {
    messages.removeWhere((msg) => selectedMessageIds.contains(msg.id));
    selectedMessageIds.clear();
    isSelectionMode.value = false;
    _saveMessages();
  }

  /// Copy selected messages
  Future<void> copySelectedMessages() async {
    final selectedMessages =
        messages.where((msg) => selectedMessageIds.contains(msg.id)).toList();

    if (selectedMessages.isEmpty) return;

    final StringBuffer buffer = StringBuffer();
    for (var msg in selectedMessages) {
      buffer.writeln('${msg.role.toUpperCase()}: ${msg.content}');
      buffer.writeln('---');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));

    Get.snackbar(
      'Copied',
      'Selected messages copied to clipboard',
      backgroundColor: Colors.green.withAlpha(230),
      colorText: Colors.white,
    );

    selectedMessageIds.clear();
    isSelectionMode.value = false;
  }

  /// Toggle message selection
  void toggleMessageSelection(String id) {
    if (selectedMessageIds.contains(id)) {
      selectedMessageIds.remove(id);
      if (selectedMessageIds.isEmpty) {
        isSelectionMode.value = false;
      }
    } else {
      selectedMessageIds.add(id);
      isSelectionMode.value = true;
    }
  }

  /// Select all messages
  void selectAllMessages() {
    selectedMessageIds.clear();
    for (var msg in messages) {
      selectedMessageIds.add(msg.id);
    }
    isSelectionMode.value = true;
  }

  /// Set persona
  void setPersona(String personaName) {
    if (personas.containsKey(personaName)) {
      currentPersona.value = personaName;
      ttsService.applyPersonaEffects(personaName);
      _saveSettings();
    }
  }

  /// Set user name
  Future<void> setUserName(String name, String title) async {
    userName.value = name;
    userTitle.value = title;
    await _saveSettings();
  }

  /// Scroll to bottom
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Initialize smart query generator service
  void _initSmartQueryGenerator() {
    try {
      // SmartQueryGeneratorService is registered in InitialBindings
      // It will auto-detect when messages are added and generate smart queries
      debugPrint(
          '✅ SmartQueryGeneratorService will auto-activate on user queries');
    } catch (e) {
      debugPrint('SmartQueryGenerator info: $e');
    }
  }

  /// Load settings
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userName.value = prefs.getString('userName') ?? '';
      userTitle.value = prefs.getString('userTitle') ?? 'Mr.';
      currentPersona.value = prefs.getString('persona') ?? 'Straight Forward';

      final modeIndex = prefs.getInt('inputMode') ?? 0;
      currentInputMode.value = UnifiedInputMode.values[modeIndex];
    } catch (e) {
      debugPrint('Load Settings Error: $e');
    }
  }

  /// Save settings
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', userName.value);
      await prefs.setString('userTitle', userTitle.value);
      await prefs.setString('persona', currentPersona.value);
      await prefs.setInt('inputMode', currentInputMode.value.index);
    } catch (e) {
      debugPrint('Save Settings Error: $e');
    }
  }

  /// Load messages
  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = prefs.getString('chatMessages');

      if (messagesJson != null) {
        final List<dynamic> decoded = jsonDecode(messagesJson);
        messages.value =
            decoded.map((json) => ChatMessage.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Load Messages Error: $e');
    }
  }

  /// Save messages
  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = jsonEncode(
        messages.map((msg) => msg.toJson()).toList(),
      );
      await prefs.setString('chatMessages', messagesJson);

      // FIX 4: Also save to threads if in a thread
      await _saveThreads();
    } catch (e) {
      debugPrint('Save Messages Error: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// FIX 4: THREAD / CONVERSATION MEMORY MANAGEMENT
  /// ═══════════════════════════════════════════════════════════════

  /// Initialize a new conversation thread
  Future<void> initializeNewThread(String threadTitle) async {
    final threadId =
        'thread_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
    currentThreadId.value = threadId;

    // Create thread metadata
    threadMetadata[threadId] = {
      'title': threadTitle,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    // Initialize empty thread
    threads[threadId] = [];

    await _saveThreads();
    debugPrint('📝 New thread created: $threadId - $threadTitle');
  }

  /// Load all persisted threads from SharedPreferences
  Future<void> _loadThreads() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load thread data
      final threadsJson = prefs.getString(_threadsPrefsKey);
      if (threadsJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(threadsJson);
        threads.clear();
        decoded.forEach((threadId, messagesList) {
          final msgs = (messagesList as List<dynamic>)
              .map((msg) => ChatMessage.fromJson(msg))
              .toList();
          threads[threadId] = msgs;
        });
      }

      // Load thread metadata
      final metadataJson = prefs.getString(_threadMetadataPrefsKey);
      if (metadataJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(metadataJson);
        threadMetadata.value = decoded.cast<String, Map<String, dynamic>>();
      }

      // Restore the current thread (if any)
      if (threads.isNotEmpty && currentThreadId.isEmpty) {
        // Load the most recently updated thread
        String? latestThreadId;
        DateTime? latestTime;

        threadMetadata.forEach((id, metadata) {
          final updatedAt = DateTime.tryParse(metadata['updatedAt'] ?? '');
          if (updatedAt != null &&
              (latestTime == null || updatedAt.isAfter(latestTime!))) {
            latestTime = updatedAt;
            latestThreadId = id;
          }
        });

        if (latestThreadId != null) {
          currentThreadId.value = latestThreadId!;
          messages.value = threads[latestThreadId!] ?? [];
        }
      }

      debugPrint('📂 Threads loaded: ${threads.length} thread(s)');
    } catch (e) {
      debugPrint('Load Threads Error: $e');
    }
  }

  /// Save all threads to SharedPreferences
  Future<void> _saveThreads() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Update current thread with messages
      if (currentThreadId.isNotEmpty) {
        threads[currentThreadId.value] = messages.toList();

        // Update metadata timestamp
        if (threadMetadata.containsKey(currentThreadId.value)) {
          threadMetadata[currentThreadId.value]!['updatedAt'] =
              DateTime.now().toIso8601String();
        }
      }

      // Save threads
      final threadsJson = jsonEncode(
        threads.map(
            (id, msgs) => MapEntry(id, msgs.map((m) => m.toJson()).toList())),
      );
      await prefs.setString(_threadsPrefsKey, threadsJson);

      // Save metadata
      final metadataJson = jsonEncode(threadMetadata);
      await prefs.setString(_threadMetadataPrefsKey, metadataJson);

      debugPrint('💾 Threads saved');
    } catch (e) {
      debugPrint('Save Threads Error: $e');
    }
  }

  /// Get all thread titles for UI display
  List<MapEntry<String, String>> getThreadTitles() {
    final titles = <MapEntry<String, String>>[];
    threadMetadata.forEach((threadId, metadata) {
      titles.add(MapEntry(threadId, metadata['title'] ?? 'Untitled'));
    });
    // Sort by most recently updated
    titles.sort((a, b) {
      final aUpdated = threadMetadata[a.key]?['updatedAt'] ?? '';
      final bUpdated = threadMetadata[b.key]?['updatedAt'] ?? '';
      return bUpdated.compareTo(aUpdated); // descending
    });
    return titles;
  }

  /// Switch to a different thread
  Future<void> switchThread(String threadId) async {
    // Save current thread first
    await _saveThreads();

    currentThreadId.value = threadId;
    messages.value = threads[threadId] ?? [];
    _scrollToBottom();

    debugPrint('🔄 Switched to thread: $threadId');
  }

  /// Delete a thread and its messages
  Future<void> deleteThread(String threadId) async {
    threads.remove(threadId);
    threadMetadata.remove(threadId);

    // If deleting current thread, switch to another or create new one
    if (currentThreadId.value == threadId) {
      if (threads.isNotEmpty) {
        await switchThread(threads.keys.first);
      } else {
        await initializeNewThread('Chat Session');
      }
    }

    await _saveThreads();
    debugPrint('🗑️ Thread deleted: $threadId');
  }

  /// Clear all messages in current thread but keep thread metadata
  Future<void> clearCurrentThread() async {
    if (currentThreadId.isNotEmpty) {
      messages.clear();
      threads[currentThreadId.value] = [];
      await _saveThreads();

      // Send reset message
      _addAssistantMessage(
          'Thread cleared. Aap apni nayi query pooch sakte hain!');

      debugPrint('🔄 Current thread cleared');
    }
  }

  /// Export thread as JSON (for backup/sharing)
  Map<String, dynamic> exportThread(String threadId) {
    return {
      'threadId': threadId,
      'metadata': threadMetadata[threadId],
      'messages': threads[threadId]?.map((m) => m.toJson()).toList() ?? [],
    };
  }

  /// Import thread from JSON (for restore/sharing)
  Future<void> importThread(Map<String, dynamic> threadData) async {
    try {
      final threadId = threadData['threadId'] as String;
      final metadata = threadData['metadata'] as Map<String, dynamic>;
      final messagesData = threadData['messages'] as List<dynamic>;

      threadMetadata[threadId] = metadata;
      threads[threadId] =
          messagesData.map((m) => ChatMessage.fromJson(m)).toList();

      await _saveThreads();
      debugPrint('✅ Thread imported: $threadId');
    } catch (e) {
      debugPrint('❌ Thread import error: $e');
    }
  }

  @override
  void onClose() {
    _idleTimer?.cancel();
    textController.dispose();
    scrollController.dispose();
    super.onClose();
  }
}
