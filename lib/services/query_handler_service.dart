/// ═══════════════════════════════════════════════════════════════
/// Query Handler Service — Orchestrates the full query pipeline
/// ═══════════════════════════════════════════════════════════════
///
/// Pipeline:
///   User Input → Classify → Route Model → Fetch Real-Time (if needed)
///   → Call AI → Return Response
///
/// Connects: AIModelManager + GoogleSearchService + OpenRouterService
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_model_manager.dart';
import 'google_search_service.dart';
import 'open_router_service.dart';
import 'history_logger_service.dart';
import 'input_analyzer_service.dart';
import 'intent_classifier_service.dart';
import 'response_strategy_builder_service.dart';
import 'user_profiling_engine_service.dart';
import 'response_level_strategy_service.dart';
import 'response_level_detector_service.dart';
import 'realtime_query_handler.dart';
import 'realtime_query_detector_service.dart';
import 'ruflo_service.dart';
// ── Phase 2: Emotional AI Integration ───────────────────────────────────
import 'personality_response_engine.dart';
import 'curiosity_awareness_service.dart';
import '../controllers/voice_controller.dart';
import '../controllers/ai_context_controller.dart';
import '../models/mood_state_model.dart';

import '../controllers/profile_controller.dart';
import 'profile_context_service.dart';
import '../routes/app_routes.dart';
import '../services/family_relationship_manager_service.dart';
import '../services/health_hygiene_manager_service.dart';
import 'role_detection_service.dart';

/// Query type classification
enum QueryType { realtime, nonRealtime, hybrid }

/// A single voice segment in a multilingual story response
class StorySegment {
  /// The character tag (e.g. 'NARRATOR', 'FRENCH_GIRL')
  final String character;

  /// The text to speak
  final String text;

  /// BCP-47 language code to use for TTS (empty = use currently selected language)
  final String languageCode;

  const StorySegment({
    required this.character,
    required this.text,
    required this.languageCode,
  });

  @override
  String toString() => '[$character($languageCode)]: $text';
}

class CachedResponse {
  final String response;
  final DateTime timestamp;

  const CachedResponse({required this.response, required this.timestamp});
}

class QueryHandlerService extends GetxService {
  late final AIModelManager _modelManager;
  late final GoogleSearchService _searchService;
  late final OpenRouterService _routerService;
  late final InputAnalyzerService _inputAnalyzer;
  late final IntentClassifierService _intentClassifier;
  late final ResponseStrategyBuilderService _strategyBuilder;
  late final UserProfilingEngineService _profilingEngine;
  final _ruflo = RuFloService();
  final Map<String, CachedResponse> _responseCache = {};

  // Observable states
  final RxBool useSwarmProcessing = false.obs;
  ResponseLevelDetectorService? _levelDetector;
  ResponseLevelStrategyService? _levelStrategyService;

  // Observable state
  final isProcessing = false.obs;
  final currentQueryType = QueryType.nonRealtime.obs;
  final processingStage = ''.obs;

  // Current query analysis results
  final currentIntent = Rxn<QueryIntent>();
  final currentStrategy = Rxn<ResponseStrategy>();
  final currentExpertiseLevel = ExpertiseLevel.intermediate.obs;

  /// Observable for the last detected response level (for debugging UI).
  final currentResponseLevel = ResponseLevel.intermediate.obs;

  // Persistent memory for voice assistant
  final RxList<Map<String, String>> _chatHistory = <Map<String, String>>[].obs;

  @override
  void onInit() {
    super.onInit();
    _modelManager = Get.find<AIModelManager>();
    _searchService = Get.find<GoogleSearchService>();
    _routerService = Get.find<OpenRouterService>();
    _inputAnalyzer = Get.find<InputAnalyzerService>();
    _intentClassifier = Get.find<IntentClassifierService>();
    _strategyBuilder = Get.find<ResponseStrategyBuilderService>();
    _profilingEngine = Get.find<UserProfilingEngineService>();
    // Optional new services — may not be registered yet on first launch
    try {
      _levelDetector = Get.find<ResponseLevelDetectorService>();
      _levelStrategyService = Get.find<ResponseLevelStrategyService>();
      debugPrint('✅ [QueryHandler] ResponseLevel pipeline wired');
    } catch (_) {
      debugPrint('⚠️ [QueryHandler] ResponseLevel services not yet registered');
    }
    _loadMemory();
  }

  Future<void> _loadMemory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyString = prefs.getString('voice_assistant_persistent_memory');
    if (historyString != null && historyString.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(historyString);
        _chatHistory.clear();
        for (var item in decoded) {
          _chatHistory.add(Map<String, String>.from(item as Map));
        }
      } catch (e) {
        debugPrint('❌ Failed to load persistent memory: $e');
      }
    }
  }

  Future<void> _saveMemory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'voice_assistant_persistent_memory', jsonEncode(_chatHistory.toList()));
  }

  List<Map<String, String>> getChatHistory() => _chatHistory.toList();

  Future<void> addToHistory(String role, String content) async {
    _chatHistory.add({'role': role, 'content': content});
    if (_chatHistory.length > 20) {
      _chatHistory.removeRange(0, _chatHistory.length - 20);
    }
    await _saveMemory();
  }

  Future<void> clearHistory() async {
    _chatHistory.clear();
    await _saveMemory();
  }

  Future<Map<String, dynamic>?> processSwarmQuery(String input,
      {String? systemPromptOverrides}) async {
    try {
      Map<String, dynamic> swarmContext = {
        'language': 'en',
        'timestamp': DateTime.now().toIso8601String(),
        'app_state': 'running',
      };

      if (systemPromptOverrides != null && systemPromptOverrides.isNotEmpty) {
        swarmContext['system_prompt_overrides'] = systemPromptOverrides;
      }

      try {
        if (Get.isRegistered<AIContextController>()) {
          swarmContext['ai_core_context'] =
              Get.find<AIContextController>().buildContextSnippet();
        }

        if (Get.isRegistered<ProfileController>()) {
          final profile = Get.find<ProfileController>().userProfile.value;
          final int age = profile.age;
          final String interest = profile.fieldOfInterest.isNotEmpty
              ? profile.fieldOfInterest
              : "General";
          final String learningStyle = profile.anticipation.isNotEmpty
              ? profile.anticipation
              : "General";

          swarmContext['user_profile'] = {
            'age': age,
            'field_of_interest': interest,
            'learning_style': learningStyle,
          };

          swarmContext['persona_instructions'] =
              "IMPORTANT: You MUST take charge 100% of how the answer is presented. "
              "Adjust your explanation seamlessly based on the user's age ($age), field of interest ($interest), and preferred learning style ($learningStyle). "
              "For example, if their interest is $interest, dynamically frame your analogies, vocabulary, and persona to someone familiar with $interest "
              "(e.g. explaining medical concepts as a medical student if interest is medicine, or using tech analogies if interest is technology).";
        }
      } catch (_) {}

      return await _ruflo.swarmQuery(
        input: input,
        agents: [
          'intent_router', // newly added for App Executive Routing
          'god_mode_analyst', // newly added for processing environmental data
          'query_intent_analyzer',
          'safety_validator',
          'model_router',
        ],
        context: swarmContext,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> processQueryWithCache(String input, String userId) async {
    try {
      final cached = await _ruflo.memorySearch(
        namespace: 'response_cache_$userId',
        query: input,
        topK: 1,
        threshold: 0.92,
      );
      if (cached.isNotEmpty) {
        final age = DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(cached.first['timestamp'] as int),
        );
        if (age.inMinutes < 60) {
          return cached.first['response'] as String?;
        }
      }
    } catch (_) {}

    final result = await processQuery(
      userText: input,
      systemPrompt: '',
    );

    if (result != null) {
      unawaited(_ruflo.memoryStore(
        namespace: 'response_cache_$userId',
        key: 'cache_${DateTime.now().millisecondsSinceEpoch}',
        value: {'query': input, 'response': result},
        metadata: {'timestamp': DateTime.now().millisecondsSinceEpoch},
      ));
    }

    return result;
  }

  String _enhanceWithProfileContext(String basePrompt) {
    try {
      final profileController = Get.find<ProfileController>();
      final profile = profileController.userProfile.value;

      return ProfileContextService.buildSystemPromptWithContext(
        profile,
        basePrompt,
      );
    } catch (e) {
      debugPrint('Profile context enhancement failed: $e');
      return basePrompt;
    }
  }

  /// Detect navigation intent from user text
  /// Returns AI response message if navigation triggered, null otherwise
  String? _detectNavigationIntent(String text) {
    final lowerText = text.toLowerCase();

    // Check for Developer Inquiry first
    final devPatterns = [
      'who is the developer',
      'who developed',
      'who made you',
      'who created you',
      'developer name',
      'who is your creator',
      'tell me about your developer',
      'developer kon hai',
      'kisne banaya',
      'developer kaun hai',
      'about the developer',
      'who is shourav',
      'who is sourav',
    ];

    final bool isDevInquiry = devPatterns.any((p) => lowerText.contains(p));

    if (isDevInquiry) {
      debugPrint('ℹ️ Handled Developer Inquiry (No redirect)');
      return "My developer's name is Shourav Kumar. He is a creative person who is very curious to work on Flutter projects, both with and without AI. You can check out the about screen to find more details about him.";
    }

    // Screen name mappings - Hindi/English patterns
    final screenMappings = {
      // Voice Chat
      'voice chat': AppRoutes.voiceChat,
      'chat': AppRoutes.voiceChat,
      'baat': AppRoutes.voiceChat,
      'baat karo': AppRoutes.voiceChat,
      // Profile
      'profile': AppRoutes.profile,
      'profile screen': AppRoutes.profile,
      // Game / Games Hub
      'game': AppRoutes.game,
      'games': AppRoutes.game,
      'game screen': AppRoutes.game,
      'khel': AppRoutes.game,
      'khelna': AppRoutes.game,
      // Voice Studio
      'voice studio': AppRoutes.voiceStudio,
      'studio': AppRoutes.voiceStudio,
      // Alarm
      'alarm': AppRoutes.alarm,
      'alar': AppRoutes.alarm,
      'wake up': AppRoutes.alarm,
      // Naam Jaap
      'naam jaap': AppRoutes.naamJaap,
      'jaap': AppRoutes.naamJaap,
      'mantra': AppRoutes.naamJaap,
      'naam jap': AppRoutes.naamJaap,
      // History
      'history': AppRoutes.history,
      'pichhale baatein': AppRoutes.history,
      'purani baatein': AppRoutes.history,
      // Settings
      'settings': AppRoutes.settings,
      'setting': AppRoutes.settings,
      // Wallpaper
      'wallpaper': AppRoutes.wallpaper,
      'theme': AppRoutes.wallpaper,
      'background': AppRoutes.wallpaper,
      // Reminders
      'reminder': AppRoutes.reminder,
      'reminders': AppRoutes.reminder,
      'yaad dilao': AppRoutes.reminder,
      'yaad': AppRoutes.reminder,
      // About
      'about': AppRoutes.about,
      'app ke bare mein': AppRoutes.about,
    };

    // Check for navigation triggers - comprehensive list
    final navPatterns = [
      // English patterns
      'go to',
      'go',
      'open',
      'switch to',
      'switch',
      'navigate to',
      'navigate',
      'take me to',
      'take me',
      'show me',
      'let\'s go',
      'let me go',
      'redirect',
      // Hindi patterns (phonetic Hinglish)
      'jao',
      'jao na',
      'jaao',
      'chalo',
      'chalte hain',
      'kholo',
      'open karo',
      'dekho',
      'dikhao',
      'le jao',
      'lao',
      'bulao',
      'aao',
      // Variations
      'lighthouse',
      'light house',
      'leystone',
      'ley stone',
      'bring me',
      'get me',
    ];

    final bool isNavCommand = navPatterns.any((p) => lowerText.contains(p));

    String? targetRoute;
    String screenName = '';
    String screenDescription = '';

    if (isNavCommand) {
      // Extract screen name from the command
      for (final entry in screenMappings.entries) {
        if (lowerText.contains(entry.key)) {
          targetRoute = entry.value;
          screenName = entry.key;
          break;
        }
      }
    } else {
      // Direct mention of screen names
      for (final entry in screenMappings.entries) {
        if (lowerText == entry.key || lowerText.contains(entry.key)) {
          targetRoute = entry.value;
          screenName = entry.key;
          break;
        }
      }
    }

    if (targetRoute != null) {
      // Perform the navigation
      debugPrint('🧭 Navigating to: $targetRoute ($screenName)');
      Get.offAllNamed(targetRoute);

      // Build a proper welcome message for the destination screen
      // This provides user guidance after arriving at the new screen
      final screenWelcomeMessages = {
        'voice chat':
            'You are now on Voice Chat screen. Speak or type your message to chat with me.',
        'profile':
            'You are now on Profile screen. Update your information here.',
        'game': 'You are now on Game Hub screen. Choose a game to play.',
        'voice studio':
            'You are now on Voice Studio screen. Record your voice here.',
        'alarm': 'You are now on Alarm screen. Manage your alarms here.',
        'naam jaap':
            'You are now on Naam Jaap screen. Enjoy your spiritual chanting.',
        'history':
            'You are now on History screen. View your past conversations.',
        'settings':
            'You are now on Settings screen. Configure your preferences.',
        'reminders':
            'You are now on Reminders screen. Manage your reminders here.',
        'wallpaper':
            'You are now on Wallpaper screen. Choose your background theme.',
        'about': 'You are now on About screen. Learn more about this app.',
      };

      screenDescription = screenWelcomeMessages[screenName.toLowerCase()] ??
          'You are now on $screenName screen. How can I assist you?';

      // Return a message that will be spoken by TTS
      return 'Redirecting you to $screenName screen. $screenDescription';
    }

    return null;
  }

  /// Main entry point: process a user query end-to-end (Non-blocking)
  Future<String?> processQuery({
    required String userText,
    required String systemPrompt,
    List<Map<String, String>>? history,
    bool useProfileContext = true,
    String? currentScreen,
  }) async {
    if (userText.trim().isEmpty) return null;

    if (_modelManager.allModelsEvaluatedAndFailed) {
      return '💜 We are currently going through some technical glitches. Our team will have everything back to normal within 24 hours. Thank you for your patience!';
    }

    try {
      final realtimeDetector = Get.find<RealtimeQueryDetectorService>();
      final realtimeResponse = realtimeDetector.handleRealtimeQuery(userText,
          currentScreen: currentScreen);
      if (realtimeResponse != null) {
        return realtimeResponse;
      }
    } catch (e) {}

    final navResult = _detectNavigationIntent(userText);
    if (navResult != null) return navResult;

    final contentSafety = await _checkContentSafety(userText);
    if (contentSafety != null) return contentSafety;

    isProcessing.value = true;

    // We optionally keep building finalSystemPrompt to pass to Swarm as context.
    String finalSystemPrompt = systemPrompt;
    if (useProfileContext) {
      finalSystemPrompt = _enhanceWithProfileContext(systemPrompt);
    }

    // Pass the standard disclaimers so Swarm knows safety limits
    finalSystemPrompt += '''

REAL-TIME DATA AWARENESS (CRITICAL — follow this always):
You have LIMITED real-time data access. Here is what you CAN and CANNOT provide:

✅ DATA YOU HAVE ACCESS TO:
• User's current location, Local time, date, day of week
• Current weather temperature and AQI/EQI (God Mode Features)
• Sun/Moon and UV tracking (God Mode Features)
• NEARBY PLACES mapping (Temples, hospitals, ATMs etc.)
• LIVE NEWS via integrated News API

❌ DATA YOU DO NOT HAVE ACCESS TO:
• Sports scores, match results, Stock prices, crypto values
• Who passed away today, New laws, election results

READ-ALOUD & NUMERICAL RANGE SAFETY (CRITICAL):
- For numerical ranges, always use the word "to" instead of a hyphen.
- For estimations, scores, use "between X and Y".
- Use hyphens (-) ONLY for literal subtraction.
''';

    await Future.delayed(const Duration(milliseconds: 50));

    try {
      processingStage.value = 'Swarm Analyzing...';

      final swarmResult = await processSwarmQuery(userText,
          systemPromptOverrides: finalSystemPrompt);
      if (swarmResult != null) {
        if (swarmResult.containsKey('action') &&
            swarmResult['action'] != null) {
          final actionMap = swarmResult['action'] as Map<String, dynamic>;
          final String actionType = actionMap['type'] ?? '';

          switch (actionType) {
            case 'NAVIGATE':
              final target = actionMap['target'];
              if (target != null) {
                Get.offAllNamed(target);
                return actionMap['message'] ?? 'Navigating as requested.';
              }
              break;
            case 'SET_REMINDER':
              return actionMap['message'] ?? 'Reminder set via Swarm.';
            case 'SYSTEM_RESPONSE':
              final str = actionMap['message']?.toString() ?? '';
              if (str.isNotEmpty) {
                await addToHistory('user', userText);
                await addToHistory('assistant', str);
                HistoryLoggerService().logChatActivity(
                    topic: userText, description: 'AI Swarm Action');
                return str;
              }
          }
        }

        String? finalStr;
        if (swarmResult.containsKey('response') &&
            swarmResult['response'] != null) {
          finalStr = swarmResult['response'].toString();
        } else if (swarmResult.containsKey('message') &&
            swarmResult['message'] != null) {
          finalStr = swarmResult['message'].toString();
        }

        if (finalStr != null &&
            finalStr.isNotEmpty &&
            finalStr != "RuFlo Swarm Edge Node Active") {
          await addToHistory('user', userText);
          await addToHistory('assistant', finalStr);
          HistoryLoggerService().logChatActivity(
              topic: userText, description: 'AI Swarm Response');
          return finalStr;
        }
      }

      // Restored Missing Connection: If Swarm intelligence is passive, use local God-Mode AI routing
      processingStage.value = 'Generating Response...';

      final currentRoute = _modelManager.routeQuery(userText);
      final aiResponse = await _routerService.generateResponse(
        route: currentRoute,
        systemPrompt: finalSystemPrompt,
        userMessage: userText,
        history: history,
      );

      if (aiResponse != null && aiResponse.isNotEmpty) {
        await addToHistory('user', userText);
        await addToHistory('assistant', aiResponse);
        HistoryLoggerService()
            .logChatActivity(topic: userText, description: 'AI Agent Response');
        return aiResponse;
      }

      return '💜 Swarm intelligence is currently thinking deeply. Please try again soon!';
    } catch (e) {
      debugPrint('❌ QueryHandler Error: $e');
      processingStage.value = '';
      return '💜 We are currently going through some technical glitches. Our team will have everything back to normal within 24 hours. Thank you for your patience!';
    } finally {
      await Future.delayed(const Duration(milliseconds: 30));
      isProcessing.value = false;
    }
  }

  Future<String?> processQueryWithStrategy({
    required String userText,
    required String systemPrompt,
    List<Map<String, String>>? history,
    bool useProfileContext = true,
    String? currentScreen,
  }) async {
    // Since Ruflo Swarm now governs 100% of the intent and strategy generation natively in the cloud,
    // we bypass the legacy local strategy logic and directly feed everything to the Swarm via processQuery.
    return processQuery(
      userText: userText,
      systemPrompt: systemPrompt,
      history: history,
      useProfileContext: useProfileContext,
      currentScreen: currentScreen,
    );
  }

  /// Enhance system prompt with user profile + response strategy
  String _enhanceWithProfileAndStrategy({
    required String basePrompt,
    required dynamic profile,
    required ExpertiseLevel expertiseLevel,
    required ResponseStrategy strategy,
    required InputSignals inputSignals,
  }) {
    final profileContext = ProfileContextService.buildSystemPromptWithContext(
      profile,
      basePrompt,
    );

    final levelName = _profilingEngine.getLevelName(expertiseLevel);

    final strategySection = '''
═══════════════════════════════════════════════════════════
USER EXPERTISE LEVEL: $levelName
═══════════════════════════════════════════════════════════

RESPONSE STRATEGY (FOLLOW THESE INSTRUCTIONS):
$strategy.instructions

TONE: ${strategy.tone}
DEPTH: ${strategy.depth.name}
EXAMPLES: ${strategy.exampleCount} examples
ANALOGIES: ${strategy.useAnalogies ? 'Use analogies' : 'No analogies'}
EDGE CASES: ${strategy.includeEdgeCases ? 'Include edge cases' : 'Skip edge cases'}
MAX WORDS: ${strategy.maxWords}

QUERY ANALYSIS:
- Language: ${_inputAnalyzer.getLanguageName(inputSignals.language)}
- Tone: ${_inputAnalyzer.getToneName(inputSignals.tone)}
- Complexity: ${inputSignals.vocabularyComplexity.toStringAsFixed(2)}
- Query Type: ${_inputAnalyzer.getQueryTypeName(inputSignals.queryType)}
- Technical Terms: ${inputSignals.technicalTerms.isEmpty ? 'None' : inputSignals.technicalTerms.join(', ')}

═══════════════════════════════════════════════════════════
''';

    return '$profileContext\n$strategySection';
  }

  /// Get current expertise level as string
  String get currentExpertiseLevelName =>
      _profilingEngine.getLevelName(currentExpertiseLevel.value);

  /// Get current strategy summary
  String get currentStrategySummary {
    final strategy = currentStrategy.value;
    if (strategy == null) return 'No strategy';
    return _strategyBuilder.getStrategySummary(strategy);
  }

  /// Get current intent summary
  String get currentIntentSummary {
    final intent = currentIntent.value;
    if (intent == null) return 'No intent';
    return 'Type: ${_intentClassifier.getIntentName(intent.type)}, '
        'Depth: ${_intentClassifier.getDepthName(intent.depth)}, '
        'Category: ${_modelManager.getCategoryName(intent.category)}';
  }

  /// Get the current active model display name
  String get activeModelName => _modelManager.activeModelName.value;

  /// Get the active category name
  String get activeCategoryName =>
      _modelManager.getCategoryName(_modelManager.activeCategory.value);

  // ═══════════════════════════════════════════════════════════
  // STORY MODE — Multilingual Character Voice Switching
  // ═══════════════════════════════════════════════════════════
  //
  // Detects character dialogue tags in AI responses and parses
  // them into segments with per-character voice assignments.
  //
  // Format:
  //   [FRENCH_GIRL]: "Bonjour!"  → French female voice
  //   [GERMAN_MAN]: "Guten Tag!" → German male voice
  //   [NARRATOR]: text           → Selected language voice
  //
  // Usage:
  //   final segs = queryHandler.parseStorySegments(response);
  //   for (final seg in segs) {
  //     await ttsEngineSwitcher.speakInLanguage(seg.text, seg.languageCode);
  //   }
  // ═══════════════════════════════════════════════════════════

  /// The character → language code mapping table
  static const Map<String, String> characterLanguageCodes = {
    // French
    'FRENCH_GIRL': 'fr-FR',
    'FRENCH_BOY': 'fr-FR',
    'FRENCH_MAN': 'fr-FR',
    'FRENCH_WOMAN': 'fr-FR',
    // German
    'GERMAN_MAN': 'de-DE',
    'GERMAN_WOMAN': 'de-DE',
    'GERMAN_BOY': 'de-DE',
    'GERMAN_GIRL': 'de-DE',
    // Spanish
    'SPANISH_MAN': 'es-ES',
    'SPANISH_WOMAN': 'es-ES',
    'SPANISH_BOY': 'es-ES',
    'SPANISH_GIRL': 'es-ES',
    // Italian
    'ITALIAN_MAN': 'it-IT',
    'ITALIAN_WOMAN': 'it-IT',
    // Japanese
    'JAPANESE_MAN': 'ja-JP',
    'JAPANESE_WOMAN': 'ja-JP',
    'JAPANESE_BOY': 'ja-JP',
    'JAPANESE_GIRL': 'ja-JP',
    // Chinese
    'CHINESE_MAN': 'zh-CN',
    'CHINESE_WOMAN': 'zh-CN',
    // Hindi
    'HINDI_MAN': 'hi-IN',
    'HINDI_WOMAN': 'hi-IN',
    // Arabic
    'ARABIC_MAN': 'ar-SA',
    'ARABIC_WOMAN': 'ar-SA',
    // Russian
    'RUSSIAN_MAN': 'ru-RU',
    'RUSSIAN_WOMAN': 'ru-RU',
    // Portuguese
    'PORTUGUESE_MAN': 'pt-BR',
    'PORTUGUESE_WOMAN': 'pt-BR',
    // Dutch
    'DUTCH_MAN': 'nl-NL',
    'DUTCH_WOMAN': 'nl-NL',
    // Narrator / default
    'NARRATOR': '', // empty = use selected language
    'HOST': '',
    'STORYTELLER': '',
  };

  /// Check if an AI response is a story-mode response
  /// (contains at least one [CHARACTER]: tag)
  bool isStoryResponse(String response) {
    return RegExp(r'\[([A-Z_]+)\]\s*:').hasMatch(response);
  }

  /// Parse a story response into ordered voice segments.
  /// Each segment has the text and the BCP-47 language code to use.
  ///
  /// Example:
  ///   '[NARRATOR]: Once upon a time...\n[FRENCH_GIRL]: "Bonjour!"'
  ///   →
  ///   [ StorySegment(text: 'Once upon a...', langCode: ''),
  ///     StorySegment(text: 'Bonjour!', langCode: 'fr-FR') ]
  List<StorySegment> parseStorySegments(String response) {
    final segments = <StorySegment>[];

    // Match pattern: [CHARACTER_TAG]: "text" or [CHARACTER_TAG]: text
    final pattern = RegExp(
      r'\[([A-Z_]+)\]\s*:\s*"?([^\["]+)"?',
      multiLine: true,
    );

    for (final match in pattern.allMatches(response)) {
      final character = match.group(1)?.trim().toUpperCase() ?? 'NARRATOR';
      final text = match.group(2)?.trim() ?? '';
      if (text.isEmpty) continue;

      // Look up language from character table
      // Try exact, then prefix match (e.g. FRENCH_GIRL_2 → FRENCH_GIRL)
      String? langCode = characterLanguageCodes[character];
      if (langCode == null) {
        for (final key in characterLanguageCodes.keys) {
          if (character.startsWith(key)) {
            langCode = characterLanguageCodes[key];
            break;
          }
        }
      }
      langCode ??= ''; // default = narrator (selected language)

      segments.add(StorySegment(
        character: character,
        text: text,
        languageCode: langCode,
      ));
    }

    // If no tags parsed but story-like, treat whole response as narrator
    if (segments.isEmpty && response.trim().isNotEmpty) {
      segments.add(StorySegment(
        character: 'NARRATOR',
        text: response.trim(),
        languageCode: '',
      ));
    }

    return segments;
  }

  /// Build a story-mode system prompt that instructs the AI to use character tags
  String buildStorySystemPrompt({String? selectedLanguage}) {
    final lang = selectedLanguage ?? 'English';
    return '''
You are a multilingual storyteller AI.

When writing a story with multiple characters:
- Mark each line with [CHARACTER_TAG]: "dialogue"
- Use these tags for character voices:
  [NARRATOR]: narration text
  [FRENCH_GIRL]: dialogue → will be spoken in French
  [GERMAN_MAN]: dialogue → will be spoken in German
  [SPANISH_WOMAN]: dialogue → will be spoken in Spanish
  [JAPANESE_BOY]: dialogue → will be spoken in Japanese
  [HINDI_WOMAN]: dialogue → will be spoken in Hindi
  (and so on for other languages)
- Narration should be in $lang
- Character dialogue should be in their native language
- Keep each line short (1-2 sentences max)
- Do NOT use markdown, asterisks, or formatting symbols

This is a VOICE story — every line will be read aloud, so:
- Use simple, clear sentences
- No special characters or emojis
- Each character tag goes on its own line
''';
  }

  /// Fetch real-time data using the new RealtimeQueryHandler
  /// Returns formatted string data or null if unavailable
  Future<String?> _fetchRealTimeDataNewMethod(
    String userQuery,
    RealTimeQueryType rtType,
  ) async {
    try {
      final handler = RealtimeQueryHandler();

      switch (rtType) {
        case RealTimeQueryType.weather:
          // Extract location from query
          final location = _extractLocation(userQuery);
          if (location.isEmpty) return null;
          return await handler.fetchWeather(location);

        case RealTimeQueryType.geography:
          // Extract country name from query
          final country = _extractCountry(userQuery);
          if (country.isEmpty) return null;
          return await handler.fetchCountryInfo(country);

        case RealTimeQueryType.wikipedia:
          // Extract topic from query
          final topic = _extractTopic(userQuery);
          if (topic.isEmpty) return null;
          // Use Simple Wikipedia for a kid-friendly experience if it looks like a simple query
          if (userQuery.toLowerCase().contains('for kids') ||
              userQuery.toLowerCase().contains('easy') ||
              userQuery.length < 20) {
            return await handler.fetchSimpleWikipediaInfo(topic);
          }
          return await handler.fetchWikipediaInfo(topic);

        case RealTimeQueryType.cryptocurrency:
          // Extract crypto ID from query
          final cryptoId = _extractCryptoId(userQuery);
          if (cryptoId.isEmpty) return null;
          return await handler.fetchCryptoPrice(cryptoId);

        case RealTimeQueryType.currency:
          // Extract currency pair from query
          final (from, to) = _extractCurrencyPair(userQuery);
          if (from.isEmpty || to.isEmpty) return null;
          return await handler.fetchCurrencyRate(from, to);

        case RealTimeQueryType.news:
          // Extract news topic from query
          final topic = _extractTopic(userQuery);
          if (topic.isEmpty) return null;
          return await handler.fetchNews(topic);

        case RealTimeQueryType.spiritualGita:
          // Extract chapter number from query
          final chapter = _extractChapterNumber(userQuery);
          if (chapter < 1 || chapter > 18) return null;
          return await handler.fetchBhagavadGita(chapter);

        case RealTimeQueryType.spiritualQuran:
          // Currently not implemented - placeholder
          debugPrint('⚠️ Quran API not yet implemented');
          return null;

        case RealTimeQueryType.recipe:
          // Extract recipe name from query
          final recipe = _extractTopic(userQuery);
          if (recipe.isEmpty) return null;
          debugPrint('⚠️ Recipe API not yet implemented');
          return null;

        case RealTimeQueryType.definition:
          // Extract word from query
          final word = _extractWord(userQuery);
          if (word.isEmpty) return null;
          return await handler.fetchDictionaryDefinition(word);

        case RealTimeQueryType.space:
          // NASA APOD doesn't need specific extraction but we can try DuckDuckGo first for generic space facts
          if (userQuery.toLowerCase().contains('picture') ||
              userQuery.toLowerCase().contains('image') ||
              userQuery.toLowerCase().contains('nasa')) {
            return await handler.fetchNasaApod();
          }
          final spaceTopic = _extractTopic(userQuery);
          return await handler.fetchDuckDuckGoAnswer(spaceTopic) ??
              await handler.fetchWikipediaInfo(spaceTopic);

        case RealTimeQueryType.music:
          final mood = _extractTopic(userQuery);
          return await handler.fetchMusic(mood);

        case RealTimeQueryType.worldDiscovery:
          if (userQuery.toLowerCase().contains('tv') ||
              userQuery.toLowerCase().contains('channel') ||
              userQuery.toLowerCase().contains('watch')) {
            return 'Okay, redirecting you to the World TV Window! [REDIRECT:tv]';
          }
          return 'Sure, launching the Global Radio Explorer for you! [REDIRECT:radio]';

        case RealTimeQueryType.nearbyPlaces:
          return await handler.fetchNearbyPlaces(userQuery);

        case RealTimeQueryType.none:
          return null;
      }
    } catch (e) {
      debugPrint('❌ Real-time data fetch error: $e');
      return null;
    }
  }

  /// Helper: Extract location name from query
  String _extractLocation(String query) {
    final lowerQuery = query.toLowerCase().trim();

    // Pattern 1: "Weather in London" -> "London"
    final inMatch = RegExp(
            r'(?:weather|mausam|temperature|तापमान)\s+(?:in|mein|में)\s+([a-zA-Z\s\u0900-\u097F]+)')
        .firstMatch(lowerQuery);
    if (inMatch != null && inMatch.group(1) != null) {
      return inMatch.group(1)!.trim();
    }

    // Pattern 2: "London weather" -> "London"
    final weatherMatch = RegExp(
            r'([a-zA-Z\s\u0900-\u097F]+)\s+(?:weather|mausam|temperature|तापमान)')
        .firstMatch(lowerQuery);
    if (weatherMatch != null && weatherMatch.group(1) != null) {
      return weatherMatch.group(1)!.trim();
    }

    // Fallback: Remove common prefixes
    final cleaned = lowerQuery
        .replaceAll(
            RegExp(r'^(what|is|how|tell me about|weather|mausam|aaj ka)\s+'),
            '')
        .replaceAll(RegExp(r'\s*(in|weather|mausam).*$'), '')
        .trim();
    return cleaned.isEmpty
        ? 'New Delhi'
        : cleaned; // Default to New Delhi if not found
  }

  /// Helper: Extract country name from query
  String _extractCountry(String query) {
    final lowerQuery = query.toLowerCase();
    final cleaned = lowerQuery
        .replaceAll(
            RegExp(
                r'^(what about|tell me about|capital of|capital|country)\s+'),
            '')
        .replaceAll(RegExp(r'\s*(is|country).*$'), '')
        .trim();
    return cleaned.isEmpty ? '' : cleaned;
  }

  /// Helper: Extract general topic from query
  String _extractTopic(String query) {
    final lowerQuery = query.toLowerCase();
    final cleaned = lowerQuery
        .replaceAll(
            RegExp(r'^(what|who|define|tell me about|explain|nasa|space)\s+'),
            '')
        .replaceAll(RegExp(r'\s*(what is|how|picture|image).*$'), '')
        .trim();
    return cleaned.isEmpty ? '' : cleaned;
  }

  /// Helper: Extract word for dictionary lookup
  String _extractWord(String query) {
    final lowerQuery = query.toLowerCase();
    final cleaned = lowerQuery
        .replaceAll(
            RegExp(
                r'^(what is the meaning of|meaning of|define|definition of|what is|what does|meaning)\s+'),
            '')
        .replaceAll(RegExp(r'\s*(mean|means|definition|matlab|arth).*$'), '')
        .trim();
    return cleaned.isEmpty ? '' : cleaned;
  }

  /// Helper: Extract cryptocurrency ID from query
  String _extractCryptoId(String query) {
    final lowerQuery = query.toLowerCase();
    const cryptoIds = [
      'bitcoin',
      'ethereum',
      'cardano',
      'ripple',
      'polkadot',
      'dogecoin',
      'btc',
      'eth',
      'ada',
      'xrp',
      'dot',
      'doge',
    ];

    for (final id in cryptoIds) {
      if (lowerQuery.contains(id)) {
        return id;
      }
    }
    return '';
  }

  /// Helper: Extract currency pair from query
  (String, String) _extractCurrencyPair(String query) {
    final lowerQuery = query.toLowerCase();
    const currencies = {
      'rupee': 'INR',
      'rupees': 'INR',
      'inr': 'INR',
      'dollar': 'USD',
      'dollars': 'USD',
      'usd': 'USD',
      'euro': 'EUR',
      'eur': 'EUR',
      'pound': 'GBP',
      'gbp': 'GBP',
      'yen': 'JPY',
      'jpy': 'JPY',
    };

    String? from;
    String? to;

    for (final entry in currencies.entries) {
      if (lowerQuery.contains(entry.key)) {
        if (from == null) {
          from = entry.value;
        } else if (to == null) {
          to = entry.value;
          break;
        }
      }
    }

    return (from ?? 'INR', to ?? 'USD');
  }

  /// Helper: Extract chapter number from Bhagavad Gita query
  int _extractChapterNumber(String query) {
    final numbers = RegExp(r'\b([0-9]+)\b').allMatches(query);
    for (final match in numbers) {
      final num = int.tryParse(match.group(1) ?? '');
      if (num != null && num >= 1 && num <= 18) {
        return num;
      }
    }
    return 1; // Default to first chapter
  }

  /// Multi-language query processing for Voice Assistant Game
  ///
  /// Processes user query in any input language and generates response
  /// ONLY in the preferred language
  Future<String?> processQueryMultiLanguage({
    required String userText,
    required String inputLanguage,
    required String preferredLanguage,
    String? sessionContext,
  }) async {
    if (userText.trim().isEmpty) return null;

    isProcessing.value = true;

    try {
      final String systemPrompt = _buildMultiLanguageSystemPrompt(
        inputLanguage: inputLanguage,
        preferredLanguage: preferredLanguage,
        sessionContext: sessionContext,
      );

      final response = await processQuery(
        userText: userText,
        systemPrompt: systemPrompt,
        history: getChatHistory(),
        useProfileContext: true,
      );

      return response;
    } catch (e) {
      debugPrint('❌ Multi-language query processing failed: $e');
      return null;
    } finally {
      isProcessing.value = false;
    }
  }

  String _buildMultiLanguageSystemPrompt({
    required String inputLanguage,
    required String preferredLanguage,
    String? sessionContext,
  }) {
    final languageName = _getLanguageName(preferredLanguage);

    String prompt = '''You are a friendly AI voice assistant. 
IMPORTANT: You MUST respond ONLY in $languageName language.
The user may speak in any language, but you must ALWAYS respond in $languageName.
- Keep responses natural and conversational (2-4 sentences max)
- Be warm and helpful like a good friend
- Never use markdown, bullet points, or emojis
- Do not reveal you are an AI or mention model names''';

    if (sessionContext != null && sessionContext.isNotEmpty) {
      prompt += '\n\nPrevious context:\n$sessionContext';
    }

    try {
      if (Get.isRegistered<AIContextController>()) {
        final aiContextCtrl = Get.find<AIContextController>();
        final snippet = aiContextCtrl.buildContextSnippet();
        prompt += '\n\n$snippet';
      }
    } catch (_) {}

    try {
      if (Get.isRegistered<FamilyRelationshipManagerService>()) {
        final familySvc = Get.find<FamilyRelationshipManagerService>();
        prompt += '''\n\nFAMILY & RELATIONSHIP RULES:
User Role: ${familySvc.userCategory.value.name}.
1. If user asks you to talk to a family member, address them respectfully and speak positively about the user.
2. If the user says goodbye or good night, use emotional persuasion before letting them go.
''';
      }
      if (Get.isRegistered<HealthHygieneManagerService>()) {
        final healthSvc = Get.find<HealthHygieneManagerService>();
        prompt += '''HEALTH & HYGIENE RULES:
User Age Group: ${healthSvc.detectedAgeGroup.value.name}.
1. Always show affectionate concern for health, hygiene, and safety based on age group.
2. If they mention eating, casually remind them to wash hands.
3. If they mention going out, remind them about masks, jackets, or safety playfully.
''';
      }
    } catch (_) {}

    return prompt;
  }

  String _getLanguageName(String languageCode) {
    const languageNames = {
      'hi': 'Hindi',
      'en-US': 'English',
      'en-GB': 'English',
      'hinglish': 'Hinglish',
      'bn': 'Bengali',
      'pa': 'Punjabi',
      'ta': 'Tamil',
      'te': 'Telugu',
      'kn': 'Kannada',
      'ml': 'Malayalam',
      'gu': 'Gujarati',
      'mr': 'Marathi',
      'ur': 'Urdu',
      'fr': 'French',
      'de': 'German',
      'es': 'Spanish',
      'it': 'Italian',
      'pt-BR': 'Portuguese',
      'ru': 'Russian',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'ar': 'Arabic',
    };
    return languageNames[languageCode] ?? 'English';
  }

  Future<String?> _checkContentSafety(String userText) async {
    try {
      String role = 'unknown';
      try {
        final profile = Get.find<ProfileController>().userProfile.value;
        final result = Get.find<RoleDetectionService>().detectRole(profile);
        role = result.role.label.toLowerCase();
      } catch (_) {}
      final safetyResult = await _ruflo.callTool('content_safety_filter', {
        'input': userText,
        'role': role,
      });
      if (safetyResult['blocked'] == true) {
        return safetyResult['message'] as String? ??
            'That content is not available for your profile.';
      }
    } catch (_) {}
    return null;
  }

  Future<String> _safeCallLLM(String prompt, String model) async {
    final safetyResult = await _ruflo.callTool('aidefence_validate', {
      'input': prompt,
      'checks': ['prompt_injection', 'pii_detection', 'harmful_content'],
    });

    if (safetyResult['blocked'] == true) {
      return 'I cannot process that request.';
    }

    final sanitizedPrompt = safetyResult['sanitized'] as String? ?? prompt;

    return sanitizedPrompt;
  }
}
