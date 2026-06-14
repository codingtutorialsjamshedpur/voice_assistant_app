import 'package:get/get.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../services/voice_memo_service.dart';
import '../services/naam_jaap_service.dart';
import '../services/ai_model_manager.dart';
import '../services/google_search_service.dart';
import '../services/open_router_service.dart';
import '../services/query_handler_service.dart';
import '../services/read_aloud_service.dart';
import '../services/reminder_service.dart';
import '../services/audio_recording_service.dart';
import '../services/audio_playback_service.dart';
import '../services/idle_prompt_service.dart';
import '../services/input_analyzer_service.dart';
import '../services/user_profiling_engine_service.dart';
import '../services/intent_classifier_service.dart';
import '../services/response_strategy_builder_service.dart';
// ── Task 1: Response Level pipeline ────────────────────────────────────────
import '../services/response_level_strategy_service.dart';
import '../services/response_level_detector_service.dart';
// ── Task 2: Curiosity Hook ─────────────────────────────────────────────────
import '../services/curiosity_hook_service.dart';
import '../services/curiosity_awareness_service.dart';
// ── Task 3: Child Context ──────────────────────────────────────────────────
import '../services/child_context_service.dart';
import '../services/grade_level_detector_service.dart';
import '../services/learning_style_detector_service.dart';
import '../services/vocabulary_tracker_service.dart';
// ── Task 4: Gesture + Audio Cue + Haptic ──────────────────────────────────
import '../services/gesture_recognizer_service.dart';
import '../services/audio_cue_service.dart';
import '../services/haptic_feedback_service.dart';
// ── Task 5: Natural Speech + Emotion + Continuity ─────────────────────────
import '../services/natural_speech_service.dart';
import '../services/emotion_adapter_service.dart';
import '../services/conversation_continuity_service.dart';
// ── Task 6: Quiz + Gamification ───────────────────────────────────────────
import '../services/quiz_mode_service.dart';
import '../services/gamification_service.dart';
// ── Screen Knowledge Base System ─────────────────────────────────────────
import '../services/language_service.dart';
import '../services/user_profile_service.dart';
import '../services/llm_service.dart';
import '../controllers/ai_context_controller.dart';
// ── Phase 2: Emotional AI Services ────────────────────────────────────────
import '../services/mood_detection_service.dart';
import '../services/role_detection_service.dart';
import '../services/personality_response_engine.dart';
import '../services/greeting_service.dart';
import '../services/enhanced_greeting_service.dart';
import '../services/smart_query_generator_service.dart';
import '../services/engagement_orchestrator_service.dart';
import '../services/family_relationship_manager_service.dart';
import '../services/health_hygiene_manager_service.dart';
import '../controllers/festival_theme_controller.dart';
import '../services/idle_poke_service_enhanced.dart';

import '../services/sherpa_tts_service.dart';
import '../services/tts_engine_switcher.dart';
import '../services/audio_export_service.dart';
import '../services/realtime_query_detector_service.dart';
import '../services/chunked_highlight_service.dart';
import '../services/music_stream_service.dart';
import '../controllers/voice_controller.dart';
import '../controllers/game_controller.dart';
import '../controllers/alarm_controller.dart';
import '../controllers/language_controller.dart';
import '../controllers/history_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/settings_controller.dart';
import '../shared/controllers/top_panel_controller.dart';
import '../features/orb_thinking/orb_thinking_controller.dart';
import '../services/god_mode_intelligence_service.dart';
import '../services/voice_state_snapshot_service.dart';
import '../services/universal_voice_pipeline.dart';
import '../services/voice_session_restoration_manager.dart';

/// Initial bindings for the app
///
/// This class initializes all services and controllers
/// that need to be available throughout the app lifecycle.
class InitialBindings extends Bindings {
  @override
  void dependencies() {
    // ── Core Voice Services (permanent) ───────────────────────────────────
    Get.put(TTSService(), permanent: true);
    Get.put(STTService(), permanent: true);
    Get.put(VoiceMemoService(), permanent: true);
    Get.put(NaamJaapService(), permanent: true);
    Get.put(ReadAloudService(), permanent: true);
    Get.put(UniversalVoicePipeline(),
        permanent: true); // Integrates standardized mic tap sequence
    Get.put(VoiceSessionRestorationManager(), permanent: true);

    // ── User Profiling Services - TIER 1 & 2 (order matters!) ────────────
    // 1. InputAnalyzer - analyzes language, tone, complexity
    Get.put(InputAnalyzerService(), permanent: true);
    // 2. UserProfilingEngine - detects expertise level (depends on InputAnalyzer)
    Get.put(UserProfilingEngineService(), permanent: true);
    // 3. IntentClassifier - classifies intent (depends on InputAnalyzer)
    Get.put(IntentClassifierService(), permanent: true);
    // 4. ResponseStrategyBuilder - builds response strategy
    Get.put(ResponseStrategyBuilderService(), permanent: true);

    // ── AI Services - TIER 3 (depends on profiling services) ──────────────
    Get.put(AIModelManager(), permanent: true);
    Get.put(GoogleSearchService(), permanent: true);
    Get.put(OpenRouterService(), permanent: true);

    // ── Task 1: Response Level pipeline (must be before QueryHandler) ─────
    Get.put(ResponseLevelStrategyService(), permanent: true);
    Get.put(ResponseLevelDetectorService(), permanent: true);

    // ── Task 3: Child Context services (must be before QueryHandler) ──────
    Get.put(VocabularyTrackerService(), permanent: true);
    Get.put(GradeLevelDetectorService(), permanent: true);
    Get.put(LearningStyleDetectorService(), permanent: true);
    Get.put(ChildContextService(), permanent: true);

    // ── Task 4: Gesture + Audio Cue + Haptic ──────────────────────────────
    Get.put(HapticFeedbackService(), permanent: true);
    Get.put(AudioCueService(), permanent: true);
    Get.put(GestureRecognizerService(), permanent: true);

    // ── Task 5: Natural Speech + Emotion + Continuity ─────────────────────
    Get.put(NaturalSpeechService(), permanent: true);
    Get.put(EmotionAdapterService(), permanent: true);
    Get.put(ConversationContinuityService(), permanent: true);

    // ── Task 6: Quiz + Gamification ───────────────────────────────────────
    Get.put(GamificationService(), permanent: true);
    Get.put(QuizModeService(), permanent: true);

    // ── Task 2: Curiosity Hook (after OpenRouter + InputAnalyzer) ─────────
    Get.put(CuriosityHookService(), permanent: true);
    Get.put(CuriosityAwarenessService(), permanent: true);

    // ── Real-time Query Detector (for CTJ privacy design) ─────────────────
    Get.put(RealtimeQueryDetectorService(), permanent: true);

    // QueryHandler must be after all services it depends on
    Get.put(QueryHandlerService(), permanent: true);

    // ── Reminder Service (permanent) ──────────────────────────────────────
    Get.put(ReminderService(), permanent: true);

    // ── Idle Prompt Service (permanent) ───────────────────────────────────
    Get.put(IdlePromptService(), permanent: true);

    // ── Alarm Controller (permanent) ──────────────────────────────────────
    Get.put(AlarmController(), permanent: true);

    // ── Voice Studio Services (permanent) ─────────────────────────────────
    Get.put(AudioRecordingService(), permanent: true);
    Get.put(AudioPlaybackService(), permanent: true);
    Get.put(MusicStreamService(), permanent: true);

    // ── Language Services (order matters!) ────────────────────────────────
    // LanguageModelService is pre-registered in main.dart via putAsync
    // 2. SherpaTtsService (depends on LanguageModelService)
    Get.put(SherpaTtsService(), permanent: true);
    // 3. TtsEngineSwitcher (routes between flutter_tts and sherpa)
    Get.put(TtsEngineSwitcher(), permanent: true);
    // 4. LanguageController (depends on all above and SttService)
    Get.put(LanguageController(), permanent: true);

    // ── Profile Controller (for AI personalization) ────────────────────────
    Get.put(ProfileController(), permanent: true);

    // ── Main Controller - TIER 4 (depends on all services) ───────────────
    Get.put(VoiceController(), permanent: true);

    // ── God Mode Intelligence ─────────────────────────────────────────────
    Get.put(GodModeIntelligenceService(), permanent: true);

    // ── Top Panel Controller for Screen Context Awareness ─────────────────
    Get.put(TopPanelController(), permanent: true);

    // ── Screen Knowledge Base System (after TopPanelController) ───────────
    // LanguageService: manages user preferred language
    Get.put(LanguageService(), permanent: true);
    // UserProfileService: age-based response adaptation
    Get.put(UserProfileService(), permanent: true);
    // AIContextController: real-time screen awareness + system prompt builder
    Get.put(AIContextController(), permanent: true);
    // LLMService: delegates to QueryHandlerService pipeline
    Get.put(GoogleLLMService(), permanent: true);

    // ── Game Controller (permanent — needed for voice routing check) ───────
    Get.put(GameController(), permanent: true);

    // ── History Controller (permanent — for activity tracking) ────────────
    Get.put(HistoryController(), permanent: true);

    // ── Phase 2: Emotional AI Services ────────────────────────────────────
    Get.put(MoodDetectionService(), permanent: true);
    Get.put(RoleDetectionService(), permanent: true);
    Get.put(PersonalityResponseEngine(), permanent: true);
    Get.put(FestivalThemeController(), permanent: true);
    Get.put(IdlePokeServiceEnhanced(), permanent: true);
    Get.put(GreetingService(), permanent: true);
    Get.put(EnhancedGreetingService(), permanent: true);

    // ── Family Relationship Manager (for emotionally intelligent family interactions) ──
    Get.put(FamilyRelationshipManagerService(), permanent: true);

    // ── Health & Hygiene Manager (for affectionate health & hygiene awareness) ──
    Get.put(HealthHygieneManagerService(), permanent: true);

    // ── Smart Query Generator Service (for intelligent user engagement) ────
    Get.put(SmartQueryGeneratorService(), permanent: true);

    // ── Engagement Orchestrator (central engagement loop controller) ───────
    Get.put(EngagementOrchestratorService(), permanent: true);

    // ── Settings Controller (for user preferences & app configuration) ────
    Get.put(SettingsController(), permanent: true);

    // ── Orb Thinking Controller (for thought bubble projections) ───────────
    Get.put(OrbThinkingController(), permanent: true);

    // ── Audio Export Service (for per-message TTS→file + share) ──────────
    Get.put(AudioExportService(), permanent: true);

    // ── Voice State Snapshot Service (portal-return recovery) ───────────
    // Must be after VoiceController & STTService are registered.
    Get.put(VoiceStateSnapshotService(), permanent: true);

    // ── Chunked Highlight Service (for 2000-word chunks with real-time highlighting) ──
    Get.put(ChunkedHighlightService(), permanent: true);
  }
}
