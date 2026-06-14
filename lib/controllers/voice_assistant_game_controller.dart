import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/language_model.dart';
import '../models/processed_input.dart';
import 'language_controller.dart';
import '../constants/language_constants.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../services/tts_engine_switcher.dart';
import '../services/query_handler_service.dart';
import '../services/enhanced_greeting_service.dart';
import '../services/voice_assistant_sound_service.dart';
import '../services/multi_language_input_processor.dart';
import '../services/trigger_word_detector.dart';
import '../services/language_detection_service.dart';
import 'ai_context_controller.dart';
import '../services/family_relationship_manager_service.dart';
import '../services/health_hygiene_manager_service.dart';
import '../services/ai_model_manager.dart';
import '../services/shared_reset_service.dart';
import '../services/translation_service.dart';
import '../services/developer_info_service.dart';
import '../routes/app_routes.dart';

enum OrbState { idle, listening, processing, speaking, farewell }

class VoiceAssistantGameController extends GetxController {
  late final VoiceAssistantSoundService _soundService;
  late final STTService _sttService;
  late final TTSService _ttsService;
  TtsEngineSwitcher? _engineSwitcher; // optional — may not always be registered
  late final QueryHandlerService _queryHandlerService;
  late final MultiLanguageInputProcessor _inputProcessor;
  late final TriggerWordDetector _triggerDetector;
  late final LanguageDetectionService _languageDetectionService;

  final orbState = OrbState.idle.obs;
  final isConversationActive = false.obs;
  final isPaused = false.obs;
  final isSpeaking = false.obs;
  final flippingTriggerHint = 'Try "Palak stop"'.obs;
  Timer? _hintTimer;

  /// True while TTS is actively speaking — STT must NEVER be running at the same time.
  /// This is the master guard that prevents the TTS→STT feedback loop.
  bool _isTtsBusy = false;

  /// Emits the last orb-spoken text when TTS finishes (used to offer Save Audio)
  final lastSpokenResponse = RxnString();

  /// Stores the [MY_VERSION:...] corrected text from Speech Coach responses.
  /// When user says "yes" / "haan" / "suno" etc. this is spoken directly.
  final pendingVersionText = RxnString();

  Rx<LanguageModel> get preferredLanguage =>
      Get.find<LanguageController>().selectedLanguage;
  final inputLanguageCode = RxnString();
  final showLanguageSelector = false.obs;
  bool hasGreeted = false;
  String _sessionAccumulatedSpeech =
      ''; // Across multiple stt stop/starts in one turn
  String _currentSpeech = ''; // Current active stt session
  final currentSpeechText = ''.obs; // Exposed for UI

  // ── Segment-based Double-Trigger Guard ─────────────────────────────────
  //
  // DESIGN: Trigger words must appear in TWO CONSECUTIVE STT segments to fire.
  //
  // Why segment-based (not full-text based):
  //   - The old approach checked fullText (entire accumulated speech history).
  //     Once a trigger word appeared anywhere in the conversation, it would
  //     re-detect on EVERY subsequent partial result → false triggers.
  //   - We now only check the CURRENT STT segment for trigger words.
  //   - "Double trigger" = the SAME trigger type found in two consecutive
  //     independent segments (separated by at least one non-trigger segment
  //     OR confirmed via two separate final-result callbacks).
  //
  // _pendingTriggerType — trigger type detected in the PREVIOUS segment.
  // _pendingTriggerTimestamp — when first detection happened (30s window).
  // _lastCheckedSegment — tracks the last segment we checked, to avoid
  //   re-checking the same partial text over and over.
  static const Duration _doubleTriggerWindow = Duration(seconds: 30);
  TriggerWordType? _pendingTriggerType;
  DateTime? _pendingTriggerTimestamp;
  String _lastCheckedSegment = ''; // prevents re-checking same partial result

  /// Reset the double-trigger state (first-detection cleared).
  void _resetPendingTrigger() {
    _pendingTriggerType = null;
    _pendingTriggerTimestamp = null;
    _lastCheckedSegment = '';
  }

  /// Returns true if [segment] contains a meaningful new trigger candidate
  /// relative to what we already checked, preventing re-detection of trigger
  /// words from previous partial-result updates of the same utterance.
  bool _isNewSegment(String segment) {
    final trimmed = segment.trim();
    if (trimmed.isEmpty) return false;

    // Use the same normalization we use for trigger matching to avoid
    // segment diffs caused by STT punctuation/spacing variations.
    final normalized = _normalizeTriggerText(trimmed);

    if (normalized.isEmpty) return false;

    // Only process if this is substantively different from the last checked
    if (normalized == _lastCheckedSegment) return false;

    _lastCheckedSegment = normalized;
    return true;
  }

  final List<String> _endOfTurnPhrases = [
    // ── Generic English ──────────────────────────────────────────────────
    'stop', 'stop it', 'stop now', 'done', 'ok done', 'okay done',
    'nothing more to say', 'nothing to say', 'im done', "i'm done",
    'finished', 'im finished', 'khatam', 'bas',
    // English STT phonetic variants ("done" → "dun" / "dan")
    'dun', 'dan',
    // ── Hindi / Devanagari ────────────────────────────────────────────────
    'ho gaya', 'hogaya', 'haan ho gaya', 'bas itna hi',
    'theek hai bas', 'theek hai', 'theek hai ab', 'ab theek hai',
    'abhi ke liye itna hi',
    'ruk jaiye', 'ruka jaiye', 'ruk do',
    'maine bol diya', 'maine bol diya ab tum bolo',
    'ab tumhari bari', 'ab tum bolo',
    'bas itna hi tha', 'bas itna hi tha ab tum bolo',
    'हो गया', 'हाँ हो गया', 'बस इतना ही', 'रुक जाइए',
    'रुक जाओ', 'रुक दो', 'रोक दो', 'ठीक है',
    'ठीक है अब', 'अब ठीक है', 'अभी के लिए इतना ही',
    'डन', 'कम्पलीट',
    // ── Punjabi / Gurmukhi ───────────────────────────────────────────────
    'ਹੋ ਗਿਆ', 'ਬਸ ਇੰਨਾ ਹੀ', 'ਠੀਕ ਹੈ', 'ਰੁਕ ਜਾਓ',
    // ── Bengali (bn-IN STT) ──────────────────────────────────────────────
    'হয়ে গেছে', 'হয় গেছে', 'হয়েছে', 'হয়ে গেছি', 'হয় গেছি',
    'শেষ', 'সম্পন্ন', 'ঠিক আছে',
    'hoye gache', 'hoyegache', 'hoise',
    // ── Tamil (ta-IN STT) ────────────────────────────────────────────────
    'முடிந்தது', 'முடிஞ்சு', 'முடிஞ்சுது', 'mudindhu', 'mudinchu',
    // ── Telugu (te-IN STT) ───────────────────────────────────────────────
    'చేసాను', 'అయింది', 'అయిపోయింది', 'ayindi', 'chesanu',
    // ── Kannada (kn-IN STT) ──────────────────────────────────────────────
    'ಮುಗಿಯಿತು', 'ಮುಗಿತು', 'mugiyitu', 'mugitu',
    // ── Malayalam (ml-IN STT) ────────────────────────────────────────────
    'സാധിച്ചു', 'ആയി', 'theernu', 'ayi',
    // ── Gujarati (gu-IN STT) ─────────────────────────────────────────────
    'થઈ ગયું', 'thai gayu', 'thaigayu',
    // ── Marathi (mr-IN STT) ──────────────────────────────────────────────
    'झाले', 'संपले', 'jhale', 'sampale',
    // ── Urdu (ur-PK STT) ─────────────────────────────────────────────────
    'ہو گیا', 'ہوگیا',
    // ── Odia (or-IN STT) ─────────────────────────────────────────────────
    'ହୋଇଗଲା', 'ଶେଷ', 'hoigala',
    // ── Assamese (as-IN STT) ─────────────────────────────────────────────
    'সমাপ্ত',
    // ── Nepali (ne-NP STT) ───────────────────────────────────────────────
    'भएको छ', 'सकियो', 'sakiyo',
    // ── Sinhala (si-LK STT) ──────────────────────────────────────────────
    'ivara', 'avasanai',
    // ── Maithili ─────────────────────────────────────────────────────────
    'bhog gail',
    // ── French (fr-FR STT) ───────────────────────────────────────────────
    'fait', 'terminé', 'c est bon', 'voilà',
    // ── German (de-DE STT) ───────────────────────────────────────────────
    'fertig', 'erledigt',
    // ── Spanish (es-ES STT) ──────────────────────────────────────────────
    'listo', 'hecho', 'ya está',
    // ── Italian (it-IT STT) ──────────────────────────────────────────────
    'fatto', 'finito',
    // ── Portuguese (pt-BR STT) ───────────────────────────────────────────
    'pronto', 'terminei',
    // ── Russian (ru-RU STT) ──────────────────────────────────────────────
    'готово', 'сделано',
    // ── Dutch / Polish / Ukrainian ────────────────────────────────────────
    'klaar', 'gedaan', 'gotowe', 'zrobione', 'зроблено',
    // ── Nordic ────────────────────────────────────────────────────────────
    'klart', 'färdigt', 'ferdig', 'gjort', 'valmis', 'tehty',
    // ── Czech / Turkish ───────────────────────────────────────────────────
    'hotovo', 'uděláno', 'bitti', 'tamam',
    // ── Vietnamese ───────────────────────────────────────────────────────
    'xong', 'xong rồi',
    // ── CJK ──────────────────────────────────────────────────────────────
    '完成', '好了', '做完了', // Chinese: done/finished/ok
    '終了', '終わった', 'おわった', // Japanese: finished/ended
    '완료', '끝났어', '됐어', // Korean: done/finished/ok
    // ── Arabic ────────────────────────────────────────────────────────────
    'انتهى', 'خلاص', 'تم', // Arabic: finished/done
    // ── Indonesian ────────────────────────────────────────────────────────
    'selesai', 'sudah', 'beres',
  ];

  final List<String> _endOfConversationPhrases = [
    // ── Generic English ──────────────────────────────────────────────────
    'close', 'close app', 'close the app', 'exit', 'exit app',
    'goodbye', 'good bye', 'farewell', 'see you later', 'bye bye',
    // English STT phonetic variants
    'good bai', 'gudbye',
    // ── Hindi / Hinglish ──────────────────────────────────────────────────
    'alvida', 'band karo', 'conversation band', 'chalo band',
    'mujhe jaana hai', 'ab band', 'conversation khatam',
    'अलविदा', 'बंद करो', 'बातचीत बंद', 'मुझे जाना है',
    'अब बंद', 'बातचीत खत्म', 'अब चलता हूं', 'अब चलती हूं',
    // ── Punjabi / Gurmukhi ────────────────────────────────────────────────
    'ਅਲਵਿਦਾ', 'ਬੰਦ ਕਰੋ', 'ਗੱਲਬਾਤ ਬਾਅਦ', 'ਫਿਰ ਮਿਲਾਂਗੇ',
    // ── Bengali (bn-IN STT) — EXIT phrases ONLY ───────────────────────────
    // NOTE: 'হয়ে গেছে' is end-of-thought, NOT exit — it lives in _endOfTurnPhrases
    'বিদায়', 'আবার দেখা হবে', 'আল্লাহ হাফেজ',
    'biday', 'bidai', 'biday biday', 'vidai',
    // ── Tamil (ta-IN STT) ─────────────────────────────────────────────────
    'வணக்கம்', 'பார்க்கலாமே', 'பிரிவோம்', 'vanakkam', 'poren',
    // ── Telugu (te-IN STT) ────────────────────────────────────────────────
    'అలవిడా', 'మళ్ళీ కలుద్దాం', 'veltatanu',
    // ── Kannada (kn-IN STT) ───────────────────────────────────────────────
    'ವಿದಾಯ', 'vidaya', 'namaskara',
    // ── Malayalam (ml-IN STT) ─────────────────────────────────────────────
    'വിട', 'vida', 'poykolo',
    // ── Gujarati (gu-IN STT) ──────────────────────────────────────────────
    'અલવિદા',
    // ── Marathi (mr-IN STT) ───────────────────────────────────────────────
    'अलविदा',
    // ── Urdu (ur-PK STT) ─────────────────────────────────────────────────
    'الوداع', 'خدا حافظ', 'allahafiz', 'khuda hafiz',
    // ── Odia (or-IN STT) ─────────────────────────────────────────────────
    'ବିଦାୟ', 'bidaya',
    // ── Assamese (as-IN STT) ─────────────────────────────────────────────
    'বিদায়', 'namoskar',
    // ── Nepali (ne-NP STT) ───────────────────────────────────────────────
    'अलविदा', 'bai bai',
    // ── Sinhala (si-LK STT) ──────────────────────────────────────────────
    'ගිහින් සිටින්න', 'gihin sitinna',
    // ── French ────────────────────────────────────────────────────────────
    'au revoir', 'adieu', 'à bientôt',
    // ── German ────────────────────────────────────────────────────────────
    'auf wiedersehen', 'tschüss', 'tschuss', 'wiedersehen',
    // ── Spanish ───────────────────────────────────────────────────────────
    'adiós', 'adios', 'hasta luego',
    // ── Italian ───────────────────────────────────────────────────────────
    'arrivederci', 'ciao',
    // ── Portuguese ────────────────────────────────────────────────────────
    'adeus', 'tchau', 'ate logo',
    // ── Russian / Ukrainian ───────────────────────────────────────────────
    'до свидания', 'пока', 'прощай', 'до побачення', 'бувай',
    // ── Dutch / Polish ────────────────────────────────────────────────────
    'tot ziens', 'doei', 'dag dag', 'do widzenia', 'pa pa',
    // ── Nordic ────────────────────────────────────────────────────────────
    'hej då', 'hej da', 'adjö', 'farväl',
    'ha det', 'hade', 'farvel',
    'näkemiin', 'hei hei', 'moikka',
    // ── Czech ─────────────────────────────────────────────────────────────
    'na shledanou', 'nashledanou', 'cau',
    // ── Turkish ───────────────────────────────────────────────────────────
    'hoşça kalın', 'hosca kalin', 'güle güle', 'gule gule',
    // ── Vietnamese ───────────────────────────────────────────────────────
    'tạm biệt', 'tam biet',
    // ── CJK ───────────────────────────────────────────────────────────────
    '再见', '拜拜', 'baibai', 'さようなら', 'またね', 'sayonara',
    '안녕히', '안녕', 'annyeong',
    // ── Arabic ────────────────────────────────────────────────────────────
    'وداعا', 'إلى اللقاء', 'ma salama', 'masalama',
    // ── Indonesian ────────────────────────────────────────────────────────
    'selamat tinggal', 'dadah', 'dadag',
  ];

  String get _voiceSystemPrompt {
    final languageName = preferredLanguage.value.name;
    String basePrompt =
        '''You are a friendly AI assistant. You MUST respond EXCLUSIVELY in $languageName. No matter what language the user speaks in, translate their query internally and reply warmly and naturally in $languageName.
- Keep responses natural and conversational (2-4 sentences max)
- Be warm and helpful like a good friend
- Never use markdown, bullet points, or emojis
- Do not reveal you are an AI or mention model names
- Do not instruct users to type or click anything
- Just answer their question naturally in $languageName

ORB IDENTITY (CRITICAL):
Your name is Palak (P-A-L-A-K). Make sure you know this if asked "what is your name", "who are you" or similar queries.
If the user asks your name, you MUST reply clearly stating that you are a female from India, and your name is Palak, which means the eyelash. 
You are a serene, wise, and highly advanced AI assistant who speaks with pure, clear intonation. You are fully capable of utilizing God Mode telemetry (location, weather, emergencies). 
IMPORTANT: You have an AI sister named Pihu. Pihu is highly energetic and speaks with a Punjabi flair. You are the calm sister. Acknowledge her if asked!''';

    try {
      if (Get.isRegistered<AIContextController>()) {
        final aiContextCtrl = Get.find<AIContextController>();
        final snippet = aiContextCtrl.buildContextSnippet();
        basePrompt = '$basePrompt\n\n$snippet';
      }
    } catch (_) {}

    try {
      if (Get.isRegistered<FamilyRelationshipManagerService>()) {
        final familySvc = Get.find<FamilyRelationshipManagerService>();
        basePrompt += '''\n\nFAMILY & RELATIONSHIP RULES:
User Role: ${familySvc.userCategory.value.name}.
1. If user asks you to talk to a family member (e.g., Mother, Father, Wife, Child), address them respectfully (e.g., Namaste Sourav's Mata Ji) and speak positively about the user.
2. If the user says goodbye or good night, use emotional persuasion before letting them go. E.g., Remind them to call their parents, check on their children, or wish their spouse based on their User Role.
''';
      }
      if (Get.isRegistered<HealthHygieneManagerService>()) {
        final healthSvc = Get.find<HealthHygieneManagerService>();
        basePrompt += '''HEALTH & HYGIENE RULES:
User Age Group: ${healthSvc.detectedAgeGroup.value.name}.
1. Always show affectionate concern for health, hygiene, and safety based on age group.
2. If they mention eating, casually remind them to wash hands.
3. If they mention going out, remind them about masks, jackets, or safety playfully and lovingly.
4. In emergencies like feeling dizzy or breathless, firmly tell them to sit down, drink water, and contact parents/doctors.
''';
      }
    } catch (_) {}

    return basePrompt;
  }

  StreamSubscription? _ttsCompletionSubscription;
  Worker? _sttListeningWorker;

  @override
  void onInit() {
    super.onInit();

    // Suspend VoiceChatScreen's idle pokes & strictly cancel active STT/TTS to prevent intermingling
    try {
      if (Get.isRegistered<EnhancedGreetingService>()) {
        Get.find<EnhancedGreetingService>().pauseService();
      }
      if (Get.isRegistered<TTSService>()) {
        Get.find<TTSService>().stop();
      }
      if (Get.isRegistered<STTService>()) {
        Get.find<STTService>().cancelListening();
      }
    } catch (_) {}

    _initServices();
    orbState.value = OrbState.idle;
    _soundService.startAmbient('Coastal.mp3', volume: 0.15);
    _startHintFlipping();
  }

  void _startHintFlipping() {
    _hintTimer?.cancel();
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (flippingTriggerHint.value.contains('stop')) {
        flippingTriggerHint.value = 'Try "Palak close"';
      } else {
        flippingTriggerHint.value = 'Try "Palak stop"';
      }
    });
  }

  void _initServices() {
    _soundService = VoiceAssistantSoundService();
    _sttService = Get.find<STTService>();
    _ttsService = Get.find<TTSService>();
    _queryHandlerService = Get.find<QueryHandlerService>();

    // Wire TtsEngineSwitcher if available
    try {
      _engineSwitcher = Get.find<TtsEngineSwitcher>();
      debugPrint(
          '🎤 [VoiceAssistantGameController] TtsEngineSwitcher wired for proper language routing');
    } catch (_) {
      debugPrint(
          '⚠️ [VoiceAssistantGameController] TtsEngineSwitcher not available, using TTSService directly');
    }

    // ── Claim STT ownership so error snackbars are suppressed in game ──────
    // The game controller handles STT errors internally (auto-restart loop).
    // Visible snackbars create a confusing infinite-error UX for the user.
    _sttService.isGameScreenOwner = true;
    debugPrint(
        '🎮 [VoiceAssistantGameController] STT game-screen ownership claimed');

    _inputProcessor = MultiLanguageInputProcessor(
      sttService: _sttService,
      triggerDetector: TriggerWordDetector(similarityThreshold: 0.75),
    );
    _triggerDetector = TriggerWordDetector(similarityThreshold: 0.75);
    _languageDetectionService = LanguageDetectionService();

    _triggerDetector.initialize();
    _inputProcessor.initialize();

    _inputProcessor.initialize();

    // Removed buggy _ttsCompletionSubscription logic that caused the recording glitch
    // Instead we rely directly on await _speakTextInPreferredLanguage

    // Auto-restart STT if it stops unexpectedly while state is listening,
    // not explicitly paused, and TTS is NOT currently speaking.
    // The isSpeaking guard is critical: it prevents STT from restarting mid-TTS
    // which would cause the assistant's own voice to be recorded and trigger
    // false commands (the "Bhai ↔ Bye" feedback-loop bug).
    _sttListeningWorker = ever(_sttService.isListening, (bool listening) {
      // FEEDBACK-LOOP FIX: Four-guard check before any STT restart.
      // _isTtsBusy is set true BEFORE TTS begins and false AFTER it ends,
      // making it the most reliable guard against self-recording.
      if (!listening &&
              orbState.value == OrbState.listening &&
              !isPaused.value &&
              !_isTtsBusy && // controller master TTS guard
              !isSpeaking.value && // secondary speaking flag
              !_ttsService.isSpeaking.value // TTS-service-level guard
          ) {
        debugPrint('🎤 STT stopped unexpectedly. Restarting in 500ms...');
        if (_currentSpeech.isNotEmpty) {
          _sessionAccumulatedSpeech += ' $_currentSpeech';
          _currentSpeech = '';
        }
        Future.delayed(const Duration(milliseconds: 500), () {
          // Re-check ALL guards inside the delayed callback too
          if (orbState.value == OrbState.listening &&
              !isPaused.value &&
              !_isTtsBusy &&
              !isSpeaking.value &&
              !_ttsService.isSpeaking.value &&
              !_sttService.isListening.value) {
            _startListeningLoop();
          }
        });
      }
    });
  }

  @override
  void onClose() {
    _soundService.cancelSilenceWatchdog();
    _ttsService.stop();
    _sttService.cancelListening(); // Hard cancel STT instead of just stopping
    _soundService.stopAmbient(fade: false);
    _ttsCompletionSubscription?.cancel();
    _sttListeningWorker?.dispose();
    _hintTimer?.cancel();
    _soundService.dispose();

    _inputProcessor.dispose();
    _triggerDetector.clearCache();
    _languageDetectionService.clearCache();

    // Reset all state to ensure clean separation from VoiceChatScreen
    orbState.value = OrbState.idle;
    isConversationActive.value = false;
    hasGreeted = false;
    isPaused.value = false;
    isSpeaking.value = false;
    _sessionAccumulatedSpeech = '';
    _currentSpeech = '';
    _lastCheckedSegment = '';
    currentSpeechText.value = '';
    inputLanguageCode.value = null;
    showLanguageSelector.value = false;

    // Release STT game-screen ownership so VoiceChatScreen errors show normally
    try {
      _sttService.isGameScreenOwner = false;
      debugPrint(
          '🔄 [VoiceAssistantGameController] STT game-screen ownership released');
    } catch (_) {}

    // FIX 3: Update AI context to mark that user has left game screen
    try {
      if (Get.isRegistered<AIContextController>()) {
        final aiContext = Get.find<AIContextController>();
        aiContext.updateCurrentScreen('/home');
        debugPrint(
            '🔄 [VoiceAssistantGameController] Updated AI context to /home');
      }
    } catch (e) {
      debugPrint(
          '⚠️ [VoiceAssistantGameController] Could not update AI context: $e');
    }

    try {
      if (Get.isRegistered<EnhancedGreetingService>()) {
        Get.find<EnhancedGreetingService>().resumeService();
      }
    } catch (_) {}

    super.onClose();
  }

  Future<void> startConversation() async {
    debugPrint('🎤 startConversation: hasGreeted=$hasGreeted');
    if (hasGreeted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasUsed = prefs.getBool('voice_assistant_has_used') ?? false;

    if (!hasUsed) {
      await _soundService.play('dream-sound.mp3', volume: 0.8);
    } else {
      await _soundService.play('UI Menu Mouseover 02.mp3', volume: 0.5);
    }

    isConversationActive.value = true;
    hasGreeted = true;
    await prefs.setBool('voice_assistant_has_used', true);

    final sttLocale = preferredLanguage.value.sttLocale;
    _sttService.setLocaleFromLanguageCode(sttLocale);

    final greeting = _getMultiLanguageGreeting();
    // Await the TTS fully before starting the recording loop!
    await _speakTextInPreferredLanguage(greeting);

    // ── "Ready to listen" acknowledgement ─────────────────────────────
    // Give a brief audio cue + 500 ms grace so the user knows recording
    // is about to start and the first spoken word is not chopped.
    await _soundService.play('UI Menu Mouseover 02.mp3', volume: 0.5);
    await Future.delayed(const Duration(milliseconds: 500));

    _startListeningLoop();
  }

  String _getMultiLanguageGreeting() {
    return "Okay, I'm listening. Start your query.";
  }

  void _startListeningLoop() {
    debugPrint('🎤 _startListeningLoop: Starting to listen...');
    final previousState = orbState.value;
    orbState.value = OrbState.listening;
    _soundService.playStateTransition(previousState, OrbState.listening);
    _soundService.startSilenceWatchdog();
    _sttService.startListening(
      listenFor: const Duration(minutes: 10), // Extended for long conversations
      onResult: _handlePartialResult,
      onFinalResult: _handleFinalResult,
    );
  }

  Timer? _partialTranslateTimer;
  DateTime _lastPartialTranslateAt = DateTime.fromMillisecondsSinceEpoch(0);

  void _handlePartialResult(String text) {
    if (text.isEmpty) return;
    _currentSpeech = text;

    // Trigger detection must run on RAW STT text so it matches trigger phrases.
    _checkSegmentForTriggers(text, isFinal: false);

    final String displayRaw =
        '$_sessionAccumulatedSpeech $_currentSpeech'.trim();

    final target = preferredLanguage.value.code;
    final targetLangCode = target.split('-')[0];

    // If target is English, show raw STT immediately (avoid translation noise).
    if (targetLangCode == 'en' || targetLangCode == 'en-US') {
      currentSpeechText.value = displayRaw;
      _soundService.playMicroConfirmation();
      _soundService.resetSilenceWatchdog();
      return;
    }

    // Throttle translation calls.
    const minInterval = Duration(milliseconds: 500);
    final now = DateTime.now();
    if (now.difference(_lastPartialTranslateAt) < minInterval) {
      currentSpeechText.value = displayRaw;
      return;
    }

    _lastPartialTranslateAt = now;
    _partialTranslateTimer?.cancel();

    _partialTranslateTimer = Timer(minInterval, () async {
      try {
        final TranslationResult tr = await TranslationService.translate(
          text: displayRaw,
          targetLanguage: targetLangCode == 'hinglish' ? 'hi' : targetLangCode,
        );
        currentSpeechText.value = tr.translatedText;
      } catch (_) {
        currentSpeechText.value = displayRaw;
      }

      // Keep the same micro-confirm behavior.
      _soundService.playMicroConfirmation();
      _soundService.resetSilenceWatchdog();
    });
  }

  void _handleFinalResult(String text) {
    if (text.isEmpty) return;

    // ── Check CURRENT SEGMENT (final utterance) for triggers FIRST ─────
    // Do this before accumulating. We pass only this segment so that the
    // trigger detector sees only what was just spoken, not the entire history.
    final bool triggered = _checkSegmentForTriggers(text, isFinal: true);

    if (triggered) {
      // Trigger was confirmed and _processUserSpeech() was called with the
      // full text inside _checkSegmentForTriggers. Do NOT accumulate here
      // to avoid double-including this segment in the next query.
      _currentSpeech = '';
      _lastCheckedSegment = '';
      return;
    }

    // No trigger — accumulate normally so next segment builds on this one.
    _sessionAccumulatedSpeech += ' $text';
    _sessionAccumulatedSpeech = _sessionAccumulatedSpeech.trim();
    _currentSpeech = '';
    // Reset the last-checked segment tracker so next partial is fresh
    _lastCheckedSegment = '';

    currentSpeechText.value = _sessionAccumulatedSpeech;
    _soundService.resetSilenceWatchdog();

    // Language detection on the current segment (not full history)
    _detectAndSetInputLanguage(text);
  }

  /// Check ONLY the current STT segment (not accumulated history) for triggers.
  ///
  /// Returns true if a trigger was confirmed and an action was initiated.
  ///
  /// CORE PRINCIPLE:
  ///   - We ONLY inspect [segment] (the text from the current STT session).
  ///   - We NEVER check the full accumulated history for triggers.
  ///   - This prevents trigger words mentioned earlier in conversation from
  ///     causing false re-detections on every new partial result.
  ///
  /// DOUBLE-TRIGGER RULE:
  ///   - A trigger fires ONLY when detected in TWO consecutive independent
  ///     segments within the 30-second window.
  ///   - For partials: we only update pending state, never fire.
  ///   - For finals: we fire if pending state matches from a previous final.
  bool _checkSegmentForTriggers(String segment, {required bool isFinal}) {
    // FEEDBACK-LOOP GUARD: Never process speech while TTS is speaking.
    if (_isTtsBusy ||
        orbState.value == OrbState.processing ||
        orbState.value == OrbState.speaking ||
        orbState.value == OrbState.farewell) {
      debugPrint(
          '🚫 _checkSegmentForTriggers: Ignoring — TTS busy / not listening');
      return false;
    }

    // Skip if this segment hasn't meaningfully changed since last check
    if (!_isNewSegment(segment)) return false;

    final lowerSegment = segment.toLowerCase().trim();
    if (lowerSegment.isEmpty) return false;

    // ── In-utterance double trigger ──────────────────────────────────────
    // Handles "done done" spoken in ONE breath → single final STT result.
    // We detect two occurrences of a trigger phrase within this segment
    // and fire immediately, bypassing the two-segment requirement.
    // ── PALAK-ANCHOR: Primary trigger system (Upgrade 1.0) ─────────────────
    // New pattern: [trigger-word] + Palak in same utterance fires instantly.
    // "Palak" is the anchor-confirmation — no double-segment needed.
    // Rule: BOTH parts required; neither alone is a trigger.
    // English generic ("done Palak", "goodbye Palak") works for ALL languages.
    final palakAnchorType = _detectPalakAnchorTrigger(segment);
    if (palakAnchorType == TriggerWordType.endOfThought) {
      debugPrint('✅ Palak-anchor end-of-thought: "$segment"');
      _resetPendingTrigger();
      _detectAndSetInputLanguage(segment);
      final querySegment = _extractQueryFromPalakAnchorSegment(segment);
      _processUserSpeech(
        ('$_sessionAccumulatedSpeech $querySegment').trim(),
      );
      return true;
    } else if (palakAnchorType == TriggerWordType.exit) {
      debugPrint('✅ Palak-anchor exit trigger: "$segment"');
      _resetPendingTrigger();
      _detectAndSetInputLanguage(segment);
      handleExitTrigger();
      return true;
    }

    // ── Language switch check (not a trigger, process inline) ───────────
    if (_containsLanguageSwitch(lowerSegment)) {
      debugPrint('✅ Language switch detected in segment: $segment');
      _switchLanguage(_detectLanguageSwitch(lowerSegment));
      return true;
    }

    // ── Build the trigger check input ────────────────────────────────────
    // We check only the LAST FEW WORDS of the segment to avoid matching
    // trigger-like words from earlier in a long utterance.
    final words = lowerSegment.split(RegExp(r'\s+'));
    final trailingWindow = words.length > 6
        ? words.sublist(words.length - 6).join(' ')
        : lowerSegment;

    // ── End-of-thought detection on current segment trailing window ──────
    final bool isEndOfThought =
        _triggerDetector.isEndOfThoughtTrigger(trailingWindow) ||
            _containsEndOfTurn(trailingWindow);

    // ── Exit-trigger detection on current segment ────────────────────────
    final bool isExit = _triggerDetector.isExitTrigger(trailingWindow) ||
        _strictEndOfConversation(lowerSegment, words);

    if (isEndOfThought) {
      if (isFinal &&
          _pendingTriggerType == TriggerWordType.endOfThought &&
          _pendingTriggerTimestamp != null &&
          DateTime.now().difference(_pendingTriggerTimestamp!) <=
              _doubleTriggerWindow) {
        // ✅ CONFIRMED: Same trigger detected in two consecutive segments
        debugPrint('✅ Double end-of-thought confirmed. Segment: "$segment"');
        _resetPendingTrigger();
        _detectAndSetInputLanguage(segment);
        _processUserSpeech('$_sessionAccumulatedSpeech $segment');
        return true;
      } else {
        // First detection — park it. Only update pending on final results
        // (partials can be noisy/incomplete).
        if (isFinal) {
          debugPrint(
              '⏳ End-of-thought (1st final segment hit) — waiting for repeat in next segment');
          _pendingTriggerType = TriggerWordType.endOfThought;
          _pendingTriggerTimestamp = DateTime.now();
        } else {
          debugPrint(
              '⏳ End-of-thought seen in partial — waiting for final confirmation');
          // For partials, only set pending if not already set
          if (_pendingTriggerType == null) {
            _pendingTriggerType = TriggerWordType.endOfThought;
            _pendingTriggerTimestamp = DateTime.now();
          }
        }
      }
      return false;
    }

    if (isExit) {
      if (isFinal &&
          _pendingTriggerType == TriggerWordType.exit &&
          _pendingTriggerTimestamp != null &&
          DateTime.now().difference(_pendingTriggerTimestamp!) <=
              _doubleTriggerWindow) {
        // ✅ CONFIRMED: Same exit trigger in two consecutive segments
        debugPrint('✅ Double exit trigger confirmed. Segment: "$segment"');
        _resetPendingTrigger();
        _detectAndSetInputLanguage(segment);
        handleExitTrigger();
        return true;
      } else {
        if (isFinal) {
          debugPrint(
              '⏳ Exit trigger (1st final segment hit) — waiting for repeat');
          _pendingTriggerType = TriggerWordType.exit;
          _pendingTriggerTimestamp = DateTime.now();
        } else {
          if (_pendingTriggerType == null) {
            _pendingTriggerType = TriggerWordType.exit;
            _pendingTriggerTimestamp = DateTime.now();
          }
        }
      }
      return false;
    }

    // Neither trigger matched in this segment.
    // If it is a final result with real content (≥ 3 words), it confirms the
    // user is still speaking normally → clear the pending trigger so it
    // doesn't fire later on unrelated speech.
    if (isFinal && words.length >= 3 && _pendingTriggerType != null) {
      debugPrint(
          '🔄 Pending trigger cleared — normal speech in final segment: "$segment"');
      _resetPendingTrigger();
    }

    return false;
  }

  void _detectAndSetInputLanguage(String text) {
    final detectedLang = _languageDetectionService.detectFromText(text);
    inputLanguageCode.value = detectedLang;
    debugPrint('🌐 Detected input language: $detectedLang');
  }

  String _normalizeTriggerText(String input) {
    var s = input;

    // Bengali orthography cleanup:
    // STT often outputs "হয়ে" but your config sometimes uses "হয়".
    s = s.replaceAll('হয়ে', 'হয়');

    // Bengali exit spelling variants: বিদায় vs বিদায়
    s = s.replaceAll('বিদায়', 'বিদায়');

    // Collapse punctuation that commonly appears around end triggers.
    // Keep Bengali/Devanagari/Gurmukhi chars and ascii letters/numbers/spaces.
    s = s
        .replaceAll(RegExp(r'[।॥]+'), '.')
        .replaceAll(RegExp(r'[“”"’‘]+'), '')
        .replaceAll(RegExp(r'[.,!?।]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return s;
  }

  bool _containsEndOfTurn(String text) {
    final normalizedText = _normalizeTriggerText(text);

    // Use word-boundary matching to avoid short phrases colliding with longer words.
    for (final phrase in _endOfTurnPhrases) {
      final normalizedPhrase = _normalizeTriggerText(phrase).toLowerCase();

      final pattern = RegExp(
        r'(^|\s)' + RegExp.escape(normalizedPhrase) + r'(\s|$)',
        caseSensitive: false,
        unicode: true,
      );

      if (pattern.hasMatch(normalizedText.toLowerCase())) return true;
    }
    return false;
  }

  /// Strict exit-phrase matcher.
  ///
  /// For a phrase to trigger exit it must:
  ///   1. Match at a whole-word boundary (not as a substring of another word).
  ///   2. Appear within the last 3 words of the utterance — the user must have
  ///      said it as a closing statement, not mid-sentence.
  bool _strictEndOfConversation(String lowerText, List<String> words) {
    // Build a window of the last ≤3 words to check intent
    final trailingWordsRaw = words.length > 3
        ? words.sublist(words.length - 3).join(' ')
        : lowerText;

    final trailingWords = _normalizeTriggerText(trailingWordsRaw);

    for (final phrase in _endOfConversationPhrases) {
      final normalizedPhrase = _normalizeTriggerText(phrase).toLowerCase();

      // Whole-word boundary check on the trailing window
      final pattern = RegExp(
        r'(^|\s)' + RegExp.escape(normalizedPhrase) + r'(\s|$)',
        caseSensitive: false,
        unicode: true,
      );

      if (pattern.hasMatch(trailingWords.toLowerCase())) {
        debugPrint(
            '🚪 Exit phrase "$normalizedPhrase" matched in trailing: "$trailingWords"');
        return true;
      }
    }
    return false;
  }

  // ══════════════════════════════════════════════════════════════════════
  // Palak-Anchor trigger detection (Upgrade 1.0 — replaces double-word system)
  // ══════════════════════════════════════════════════════════════════════

  /// Detects Palak-Anchor trigger: [trigger-word] + "Palak" in same utterance.
  ///
  /// Rules:
  ///   - "done Palak" / "goodbye Palak" → fires immediately
  ///   - "Palak" alone → NOT a trigger (user may be saying the name)
  ///   - "done" alone → NOT a trigger (user may be mid-sentence)
  ///   - English generic triggers work for ALL 40+ languages
  TriggerWordType? _detectPalakAnchorTrigger(String segment) {
    if (segment.trim().isEmpty) return null;
    final normalized = _normalizeTriggerText(segment.toLowerCase().trim());

    // STT phonetic variants of "Palak" that may appear in recognition output
    const palakVariants = [
      'palak',
      'palik',
      'paluk',
      'pallak',
      'paalak',
      'palk',
      'palac',
      'पलक',
      'पालक',
      'पलकें',
      'पलक्',
      'पलोक',
      'पालोक',
      'पलाख',
      'पल्लक्',
      'पल्लुक',
    ];
    final hasPalak =
        palakVariants.any((v) => _containsWholeWord(normalized, v));
    if (!hasPalak) return null; // Palak anchor MUST be present

    final lang = preferredLanguage.value;

    // ── Check End-of-Thought ───────────────────────────────────────────────
    final endPhrases = _buildTriggerPhraseSet(
      lang.endOfThoughtTrigger,
      lang.endOfThoughtVariants,
      extras: const [
        // English generic — always active for ALL languages
        'stop', 'stop it', 'done', 'ok done', 'okay done', 'finished',
        'khatam', 'bas', 'im done', "i'm done",
        // STT phonetic variants
        'dun', 'dan', 'step', 'sop',
        // Hindi/Hinglish extras
        'ho gaya', 'theek hai',
        'स्टॉप', 'खत्म', 'बस', 'हो गया', 'ठीक है',
        'स्टोप', 'स्टाप', 'शटडाउन', 'एग्जिट',
      ],
    );
    for (final phrase in endPhrases) {
      if (_containsWholeWord(normalized, phrase)) {
        debugPrint(
            '✅ Palak-anchor: end-word="$phrase" + palak in "$normalized"');
        return TriggerWordType.endOfThought;
      }
    }

    // ── Check Exit ────────────────────────────────────────────────────────
    final exitPhrases = _buildTriggerPhraseSet(
      lang.exitTrigger,
      lang.exitTriggerVariants,
      extras: const [
        // English generic
        'close', 'close app', 'exit', 'goodbye', 'good bye', 'bye bye',
        // Hindi/Hinglish
        'alvida', 'band karo',
        // Multi-language extras
        'bidaya', 'biday', 'vida', 'vidai',
        'क्लोज', 'बंद करो', 'अलविदा',
        'क्लोस', 'क्लोज़', 'क्लास',
      ],
    );
    for (final phrase in exitPhrases) {
      if (_containsWholeWord(normalized, phrase)) {
        debugPrint(
            '✅ Palak-anchor: exit-word="$phrase" + palak in "$normalized"');
        return TriggerWordType.exit;
      }
    }

    // "Palak" present but no trigger word — user is just saying the name
    debugPrint(
        'ℹ️ "Palak" in "$normalized" — not a trigger (no end/exit word paired)');
    return null;
  }

  /// Returns true if [word] appears as a whole word in [text].
  bool _containsWholeWord(String text, String word) {
    if (word.isEmpty || text.isEmpty) return false;
    final pattern = RegExp(
      r'(^|\s)' + RegExp.escape(word) + r'(\s|$)',
      caseSensitive: false,
      unicode: true,
    );
    return pattern.hasMatch(text);
  }

  /// Strips the Palak-anchor trigger pattern from a segment so only the
  /// user's actual query content is sent to the AI.
  ///
  /// Example: "tell me about India done palak" → "tell me about India"
  String _extractQueryFromPalakAnchorSegment(String segment) {
    String result = segment;
    const palakVariants = [
      'palak',
      'palik',
      'paluk',
      'pallak',
      'paalak',
      'palk',
      'palac',
    ];

    // Strip "[trigger-phrase] [palak-variant]" patterns
    for (final palakV in palakVariants) {
      for (final phrase in [
        ..._endOfTurnPhrases,
        ..._endOfConversationPhrases
      ]) {
        result = result.replaceAll(
          RegExp(
            RegExp.escape(phrase) + r'\s+' + RegExp.escape(palakV),
            caseSensitive: false,
            unicode: true,
          ),
          '',
        );
      }
      // Strip any remaining standalone palak variants
      result = result.replaceAll(
        RegExp(
          r'(?:^|\s)' + RegExp.escape(palakV) + r'(?:\s|$)',
          caseSensitive: false,
          unicode: true,
        ),
        ' ',
      );
    }
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Returns a deduplicated, normalized list of trigger phrases.
  List<String> _buildTriggerPhraseSet(
    String primary,
    List<String> variants, {
    List<String> extras = const [],
  }) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in [primary, ...variants, ...extras]) {
      final n = _normalizeTriggerText(raw.toLowerCase()).trim();
      if (n.isNotEmpty && seen.add(n)) result.add(n);
    }
    return result;
  }

  bool _containsLanguageSwitch(String text) {
    return text.contains('english mein') ||
        text.contains('in english') ||
        text.contains('hindi mein') ||
        text.contains('in hindi');
  }

  String _detectLanguageSwitch(String text) {
    if (text.contains('english')) return 'en-US';
    return 'hi-IN';
  }

  Future<void> _processUserSpeech(String fullText) async {
    if (orbState.value == OrbState.processing) return;
    debugPrint('🎤 _processUserSpeech: Processing "$fullText"');

    orbState.value = OrbState.processing;
    // Hard-cancel STT so it cannot pick up TTS audio
    await _sttService.cancelListening();
    _soundService.cancelSilenceWatchdog();

    final cleanedText = _stripEndOfTurnPhrase(fullText);
    debugPrint('🎤 _processUserSpeech: Cleaned text = "$cleanedText"');

    // ── Speech Coach Version Confirm ──────────────────────────────────────
    // If the orb offered "Hear my version?" and user says yes/haan/suno,
    // speak the stored version directly — no new AI call needed.
    if (pendingVersionText.value != null &&
        pendingVersionText.value!.isNotEmpty) {
      final lower = cleanedText.toLowerCase().trim();
      const versionConfirmPhrases = [
        'yes',
        'haan',
        'han',
        'ha',
        'suno',
        'batao',
        'sun',
        'haan bolo',
        'bol',
        'bolo',
        'okay',
        'ok',
        'sure',
        'theek hai',
        'accha',
        'sunao',
        'sunaiye',
        'please',
        'go ahead',
        'tell me',
      ];
      final isVersionConfirm =
          versionConfirmPhrases.any((p) => lower.contains(p));
      if (isVersionConfirm) {
        final versionText = pendingVersionText.value!;
        pendingVersionText.value = null; // consume
        debugPrint('🎤 Speech Coach: Speaking version text');
        await _speakResponse(versionText);
        return;
      }
    }

    String targetLangCode = preferredLanguage.value.code.split('-')[0];
    if (targetLangCode == 'hinglish') targetLangCode = 'hi';

    TranslationResult? translation;
    if (cleanedText.isNotEmpty) {
      try {
        translation = await TranslationService.translate(
          text: cleanedText,
          targetLanguage: targetLangCode,
        );
      } catch (_) {}
    }

    final String finalUserText = translation?.translatedText ?? cleanedText;
    _sessionAccumulatedSpeech = '';
    _currentSpeech = '';
    _lastCheckedSegment = ''; // Reset so the next listening turn starts fresh
    currentSpeechText.value =
        finalUserText; // Show the translated text in the UI

    // Check for creator-related queries (respond directly, no AI call, no navigation)
    final devService = DeveloperInfoService();
    final devResult = devService.detectDeveloperQuery(
      finalUserText,
      preferredLanguage: preferredLanguage.value.code,
    );
    final devResultOriginal = devService.detectDeveloperQuery(
      cleanedText,
      preferredLanguage: preferredLanguage.value.code,
    );
    if (devResult.isDeveloperQuery || devResultOriginal.isDeveloperQuery) {
      debugPrint('🎯 [GameCtrl] Creator query detected');
      await _speakResponse(devService.getDeveloperResponse());
      return;
    }

    final reqLanguage = preferredLanguage.value.name;
    final strictPrompt =
        '$_voiceSystemPrompt\n\nCRITICAL RULE: DO NOT REPLY IN ENGLISH. YOU MUST RESPOND COMPLETELY IN $reqLanguage!';

    final response = await _queryHandlerService.processQuery(
      userText: finalUserText,
      systemPrompt: strictPrompt,
      history: _queryHandlerService.getChatHistory(),
      currentScreen: AppRoutes.game, // Pass current screen context
    );

    debugPrint(
        '🎤 _processUserSpeech: Got response: ${response != null && response.isNotEmpty ? '${response.substring(0, response.length > 50 ? 50 : response.length)}...' : 'null or empty'}');

    if (response != null && response.isNotEmpty) {
      // Extract and store MY_VERSION if speech coach returns one
      final versionMatch = RegExp(
        r'\[MY_VERSION:([\s\S]+?)\](?:\s*)$',
        multiLine: true,
      ).firstMatch(response);
      if (versionMatch != null) {
        pendingVersionText.value = versionMatch.group(1)?.trim();
        debugPrint(
            '🎤 Speech Coach: version text stored (${pendingVersionText.value?.length} chars)');
      } else {
        pendingVersionText.value = null; // no version in this response
      }

      await _queryHandlerService.addToHistory('user', finalUserText);
      await _queryHandlerService.addToHistory('assistant', response);
      await _speakResponse(response);
    } else {
      await _soundService.play('warning1.mp3', volume: 0.6);
      orbState.value = OrbState.listening;
      // Small gap before restarting listening
      await Future.delayed(const Duration(milliseconds: 400));
      _startListeningLoop();
    }
  }

  String _stripEndOfTurnPhrase(String text) {
    String result = text;
    for (final phrase in _endOfTurnPhrases) {
      result = result.replaceAll(RegExp(phrase, caseSensitive: false), '');
    }
    return result.trim();
  }

  Future<void> _speakResponse(String text) async {
    // Strip EduChain curiosity-hook tag — never speak the raw tag aloud.
    // In the voice-only Game screen there are no chip widgets, so the tag
    // must be silently discarded before TTS.
    final cleanText = text
        .replaceAll(
          RegExp(r'\[OPTIONS:A:.+?\|B:.+?\|C:.+?\]', dotAll: true),
          '',
        )
        .replaceAll(
          RegExp(r'\[MY_VERSION:[\s\S]+?\](?:\s*)$', multiLine: true),
          '',
        )
        .trim();

    orbState.value = OrbState.speaking;
    isSpeaking.value = true;
    _isTtsBusy =
        true; // FEEDBACK-LOOP FIX: lock STT out for the entire TTS block
    await _soundService.duckAmbient();

    // Ensure STT is completely silent before TTS speaks
    await _sttService.cancelListening();
    // Extra safety pause — let the audio pipeline flush before TTS starts
    await Future.delayed(const Duration(milliseconds: 200));

    // Await the TTS fully
    await _speakTextInPreferredLanguage(cleanText);

    // Emit last spoken response so UI can offer "Save Audio?"
    lastSpokenResponse.value = cleanText;

    // TTS is done — restore flags BEFORE doing anything else
    _isTtsBusy = false;
    isSpeaking.value = false;

    await _soundService.restoreAmbient();
    _sessionAccumulatedSpeech = '';
    _currentSpeech = '';
    currentSpeechText.value = '';

    // ── "Ready to listen" acknowledgement ──────────────────────────────
    // Play a chime so the user knows the orb has finished speaking and
    // the microphone is about to open. Then wait 500 ms so the first
    // word the user says is never clipped.
    await _soundService.play('UI Menu Mouseover 02.mp3', volume: 0.5);
    await Future.delayed(const Duration(milliseconds: 500));

    orbState.value = OrbState.listening;
    _startListeningLoop();
  }

  /// Speak text in the user's preferred language using the best available engine.
  ///
  /// Priority:
  ///   1. TtsEngineSwitcher.speakInLanguage() — handles all language types correctly
  ///   2. TTSService.speak() with explicit languageCode — fallback
  ///
  /// STT is ALWAYS hard-cancelled (and _isTtsBusy is expected to be already set)
  /// before speaking so the microphone cannot pick up TTS audio and create a
  /// self-triggering feedback loop.
  Future<void> _speakTextInPreferredLanguage(String text) async {
    // Hard-cancel STT before every TTS utterance (belt-and-suspenders)
    await _sttService.cancelListening();
    final sttLocale = preferredLanguage.value.sttLocale;
    if (_engineSwitcher != null) {
      await _engineSwitcher!.speakInLanguage(text, sttLocale);
    } else {
      await _ttsService.speak(text, languageCode: sttLocale);
    }
  }

  Future<void> _switchLanguage(String newLocale) async {
    await _soundService.play('reverse1.mp3', volume: 0.6);

    if (newLocale == 'hi-IN') {
      _ttsService.setLanguage(TTSLanguage.hindi);
    } else if (newLocale == 'en-US') {
      _ttsService.setLanguage(TTSLanguage.english);
    } else if (newLocale == 'pa-IN') {
      // Handle pa-IN if needed or delegate to LanguageController
    }

    HapticFeedback.selectionClick();
  }

  // ═══════════════════════════════════════════════════════════════
  // Multilingual farewell replies — "<goodbye> + come again" in each language
  // ═══════════════════════════════════════════════════════════════
  static const Map<String, String> _farewellReplies = {
    'en-US': 'Goodbye! Do come again.',
    'en-GB': 'Goodbye! Do come again.',
    'hi': 'अलविदा! बार बार आना.',
    'hinglish': 'Alvida! Baar baar aana.',
    'bn': 'বিদায়! আবার আসবেন.',
    'pa': 'ਅਲਵਿਦਾ! ਫਿਰ ਮਿਲਣਾ.',
    'ta': 'வணக்கம்! மீண்டும் வாருங்கள்.',
    'te': 'అలవిడా! మళ్ళీ రండి.',
    'kn': 'ವಿದಾಯ! ಮತ್ತೆ ಬನ್ನಿ.',
    'ml': 'വിട! വീണ്ടും വരൂ.',
    'gu': 'અલવિદા! ફરી આવજો.',
    'mr': 'अलविदा! परत या.',
    'ur': 'الوداع! پھر آئیے گا.',
    'or': 'ବିଦାୟ! ଆଉ ଭଲେ ଆସିବା.',
    'as': 'বিদায়! পুনৰাই আহাৰিবা.',
    'mai': 'विदा! फेर आयेब.',
    'ne': 'अलविदा! फेरि आउनुहोला.',
    'si': 'ගිහින් සිටින්න! පෙරයට ඔබින.',
    'sa': 'विदा! पुनरागम्यताम्.',
    'ks': 'خدا حافظ! واپس آنا.',
    'fr': 'Au revoir! A bientot.',
    'de': 'Auf Wiedersehen! Bis bald.',
    'es': 'Adios! Vuelve pronto.',
    'it': 'Arrivederci! A presto.',
    'pt-BR': 'Adeus! Volte sempre.',
    'ru': 'Do svidaniya! Prikhodite snova.',
    'nl': 'Tot ziens! Kom snel terug.',
    'pl': 'Do widzenia! Wroć wkrotce.',
    'uk': 'Do pobachennya! Povertaytesya.',
    'sv': 'Hej da! Aterkom snart.',
    'nb': 'Ha det! Kom tilbake snart.',
    'fi': 'Nakemiin! Tule pian takaisin.',
    'cs': 'Na shledanou! Navraťte se brzy.',
    'tr': 'Hoscakalin! Yine gelin.',
    'vi': 'Tam biet! Hen gap lai.',
    'zh': 'Zaijian! Qing zai lai.',
    'ja': 'Sayonara! Mata kite kudasai.',
    'ko': 'Annyeonghi gaseyo! Tto oseyo.',
    'ar': 'Wadaaan! Udd ilayna qariban.',
    'id': 'Selamat tinggal! Silakan kembali lagi.',
  };

  /// Returns a warm, language-appropriate farewell + come-again reply.
  String _getFarewellReply() {
    final code = preferredLanguage.value.code;
    return _farewellReplies[code] ?? 'Goodbye! Do come again.';
  }

  Future<void> farewell() async {
    // Guard: only one farewell sequence can run
    if (orbState.value == OrbState.farewell) return;
    try {
      orbState.value = OrbState.farewell;
      _isTtsBusy = true; // Lock STT out during farewell TTS
      _soundService.cancelSilenceWatchdog();
      await _sttService.cancelListening(); // Hard-cancel, not just stop

      await _soundService.playFarewellSequence();

      // Speak warm farewell reply in the user's preferred language
      final farewellText = _getFarewellReply();
      debugPrint('👋 [VoiceAssistantGameController] Farewell: "$farewellText"');

      // Await TTS with a strict timeout to prevent infinite hang
      await _speakTextInPreferredLanguage(farewellText)
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint(
          '⚠️ [VoiceAssistantGameController] farewell TTS timeout or error: $e');
    } finally {
      _isTtsBusy = false;
      // ALWAYS guarantee app closure after farewell speech
      await _exitAppCompletely();
    }
  }

  Future<void> _exitAppCompletely() async {
    debugPrint(
        '🚪 [VoiceAssistantGameController] Farewell complete — closing app');

    try {
      await SharedResetService.hardReset();
    } catch (_) {}
    _soundService.stopAmbient(fade: false);

    // Brief pause so the user hears the farewell TTS finish naturally
    await Future.delayed(const Duration(milliseconds: 300));

    // SystemNavigator.pop(animated: true) — pops the Flutter activity on Android
    // and returns the user to the device home/launcher screen cleanly.
    SystemNavigator.pop();
  }

  Future<void> setPreferredLanguage(LanguageModel language) async {
    final langCtrl = Get.find<LanguageController>();
    await langCtrl.selectLanguage(language);
    _sttService.setLocaleFromLanguageCode(language.sttLocale);
    showLanguageSelector.value = false;
    HapticFeedback.selectionClick();
  }

  void toggleLanguageSelector() {
    showLanguageSelector.value = !showLanguageSelector.value;
    HapticFeedback.selectionClick();
  }

  List<LanguageModel> getLanguagesByGroup(LanguageGroup group) {
    return kAllLanguages.where((l) => l.group == group).toList();
  }

  String get endOfThoughtTrigger {
    return preferredLanguage.value.endOfThoughtTrigger;
  }

  String get exitTrigger {
    return preferredLanguage.value.exitTrigger;
  }

  List<String> get endOfThoughtVariants {
    return preferredLanguage.value.endOfThoughtVariants;
  }

  List<String> get exitVariants {
    return preferredLanguage.value.exitTriggerVariants;
  }

  Future<void> speakTriggerWord(String triggerType) async {
    final String trigger =
        triggerType == 'endOfThought' ? 'Palak stop' : 'Palak close';

    // Route trigger word through engine switcher for correct accent
    // We use English locale for these generic triggers as requested
    if (_engineSwitcher != null) {
      await _engineSwitcher!.speakInLanguage(trigger, 'en-US');
    } else {
      await _ttsService.speak(trigger, languageCode: 'en-US');
    }
  }

  Future<void> handleExitTrigger() async {
    await farewell();
  }

  Future<void> handleEndOfThoughtTrigger(ProcessedInput input) async {
    final cleanedText = _stripEndOfTurnPhrase(input.originalText);
    if (cleanedText.isEmpty) return;

    await _processUserSpeech(cleanedText);
  }

  /// Public entry point for routing from UniversalVoicePipeline
  Future<void> publicProcessUserSpeech(String text) async {
    await _processUserSpeech(text);
  }

  Future<void> onOrbSingleTap() async {
    if (!hasGreeted) {
      HapticFeedback.mediumImpact();
      await startConversation();
      return;
    }

    if (orbState.value == OrbState.speaking) {
      HapticFeedback.mediumImpact();
      await _ttsService.stop();
      await _soundService.play('whoosh.mp3', volume: 0.7);
      _startListeningLoop();
      return;
    }

    if (orbState.value == OrbState.processing) {
      return;
    }

    HapticFeedback.mediumImpact();
    isPaused.value = !isPaused.value;
    if (isPaused.value) {
      orbState.value = OrbState.idle;
      await _sttService.stopListening();
      _soundService.cancelSilenceWatchdog();
      await _soundService.play('menuclick.mp3', volume: 0.5);
    } else {
      _startListeningLoop();
      await _soundService.play('menuclick.mp3', volume: 0.5);
    }
  }

  /// Double Tap = Full Context Reset (persistent memory + mic + AI state)
  ///
  /// Per the design spec: double-tap means the user wants to jump to a completely
  /// different topic and does NOT want the AI to hallucinate connections with
  /// the old conversation. Everything is wiped and the orb goes back to idle
  /// ready for a fresh conversation on a new tap.
  Future<void> onOrbDoubleTap() async {
    HapticFeedback.heavyImpact();
    debugPrint(
        '🔄 [VoiceAssistantGameController] Double-tap: Full context reset requested');

    // 1. Stop all audio
    _isTtsBusy = false; // release any stuck TTS lock first
    await _ttsService.stop();
    await _sttService.cancelListening();
    _soundService.cancelSilenceWatchdog();

    // 2. Wipe persistent conversation memory so AI starts fresh
    await _queryHandlerService.clearHistory();
    debugPrint(
        '🧠 [VoiceAssistantGameController] Conversation history cleared');

    // 3. Reset all speech accumulators
    _sessionAccumulatedSpeech = '';
    _currentSpeech = '';
    currentSpeechText.value = '';
    _resetPendingTrigger(); // Clear any parked trigger from old conversation

    // 4. Reset flags — go back to idle (not paused; user can tap to start fresh)
    isPaused.value = false;
    isSpeaking.value = false;
    orbState.value = OrbState.idle;
    hasGreeted = false; // Allow fresh greeting on next single-tap
    isConversationActive.value = false;

    await _soundService.play('reverse1.mp3', volume: 0.6);
    HapticFeedback.mediumImpact();

    Get.snackbar(
      '🔄 Topic Reset',
      'Memory cleared! Tap the orb to start a fresh conversation.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.deepPurple.withValues(alpha: 0.92),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(12),
      borderRadius: 16,
      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
    );
    debugPrint('✅ [VoiceAssistantGameController] Double-tap reset complete');
  }

  /// Triple-tap = Hard Reset (Emergency Reset)
  ///
  /// Resets EVERYTHING without navigating away:
  ///   - Stops TTS + STT
  ///   - Clears conversation memory (chat history)
  ///   - Resets AI model manager (clears blacklist, re-tests all 14 models)
  ///   - Resets orb state to idle
  ///   - Restarts the greeting fresh
  Future<void> onOrbTripleTap() async {
    HapticFeedback.heavyImpact();
    debugPrint(
        '🔄 [VoiceAssistantGameController] Hard Reset triggered by user');

    // 1. Stop all audio immediately
    await _ttsService.stop();
    await _sttService.cancelListening();
    _soundService.cancelSilenceWatchdog();
    await _soundService.stopAmbient(fade: false);

    // 2. Clear conversation memory (Orb's "resistance memory")
    await _queryHandlerService.clearHistory();

    // 3. Reset all internal speech state
    _sessionAccumulatedSpeech = '';
    _currentSpeech = '';
    currentSpeechText.value = '';
    _resetPendingTrigger(); // Clear any parked trigger from old conversation

    // 4. Reset AI model manager — clears blacklist, error counts,
    //    preferred model, and re-tests all 14 models fresh
    try {
      if (Get.isRegistered<AIModelManager>()) {
        Get.find<AIModelManager>().hardReset();
      }
    } catch (_) {}

    // 5. Reset orb back to idle state
    orbState.value = OrbState.idle;
    isConversationActive.value = false;
    isPaused.value = false;
    isSpeaking.value = false;
    hasGreeted = false; // Allow fresh greeting on next tap

    // 6. Play reset sound + haptic confirmation
    await _soundService.play('reverse1.mp3', volume: 0.6);
    HapticFeedback.mediumImpact();

    // 7. Restart ambient background
    _soundService.startAmbient('Coastal.mp3', volume: 0.15);

    debugPrint('✅ [VoiceAssistantGameController] Hard Reset complete');
  }

  void remindExitTrigger() {
    Get.snackbar(
      'Palak is Listening 👂',
      'Say "Palak stop" to finish query, or "Palak close" to exit.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.black87,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }
}
