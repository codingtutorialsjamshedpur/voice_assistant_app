import 'package:get/get.dart';
import '../../../controllers/game_controller.dart';
import '../../../controllers/language_controller.dart';
import '../../../services/sound_service.dart';
import '../../../services/tts_service.dart';
import '../../../services/tts_engine_switcher.dart';
import '../../../services/stt_service.dart';
import '../../../services/open_router_service.dart';
import '../../../services/ai_model_manager.dart';
import '../../../controllers/voice_controller.dart';

abstract class VoiceGame {
  final GameController controller;

  VoiceGame(this.controller);

  String get userName {
    try {
      return Get.find<VoiceController>().userName.value;
    } catch (_) {
      return 'Player';
    }
  }

  Future<void> onStart();

  Future<void> onInput(String rawText);

  void onDispose() {}

  void addMessage(String message) {
    controller.addAssistantMessage(message);
  }

  /// Returns the BCP-47 locale code for the currently selected language.
  /// Used to route TTS and STT to the correct avatar/engine.
  String get _selectedLocale {
    try {
      return Get.find<LanguageController>().selectedLanguage.value.sttLocale;
    } catch (_) {
      return 'hi-IN'; // Safe fallback
    }
  }

  /// Speak [text] using the user's **currently selected** language/avatar.
  ///
  /// Uses TtsEngineSwitcher.speakInLanguage() when available (same routing
  /// logic as the Voice Chat screen), otherwise falls back to TTSService with
  /// an explicit languageCode so we never default to Hindi/Hinglish.
  void speak(String text) {
    try {
      final locale = _selectedLocale;

      // Prefer TtsEngineSwitcher — handles Sherpa, Google TTS, and flutter_tts
      // routing for every language, exactly as VoiceAssistantGameController does.
      try {
        final switcher = Get.find<TtsEngineSwitcher>();
        switcher.speakInLanguage(text, locale);
        return;
      } catch (_) {
        // TtsEngineSwitcher not registered — fall through to TTSService
      }

      // Fallback: direct TTSService call with the correct locale
      final tts = Get.find<TTSService>();
      tts.speak(text, languageCode: locale);
    } catch (_) {
      debugPrint('TTS not available');
    }
  }

  /// Apply the selected language's STT locale so speech recognition
  /// uses the correct language model throughout the game session.
  void applySttLocale() {
    try {
      final locale = _selectedLocale;
      Get.find<STTService>().setLocaleFromLanguageCode(locale);
      debugPrint('[VoiceGame] STT locale applied: $locale');
    } catch (_) {
      debugPrint('[VoiceGame] STT locale could not be applied');
    }
  }

  void playSound(String soundPath) {
    try {
      SoundService.to.playEffect(soundPath);
    } catch (_) {
      debugPrint('Sound not available');
    }
  }

  Future<String> askAISafe(String prompt, {String fallback = ''}) async {
    try {
      final router = Get.find<OpenRouterService>();
      final aiManager = Get.find<AIModelManager>();
      final route = aiManager.routeQuery(prompt);

      final response = await router.generateResponse(
        route: route,
        systemPrompt: prompt,
        userMessage: prompt,
      );

      return response ?? fallback;
    } catch (e) {
      debugPrint('AI Error: $e');
      return fallback;
    }
  }

  String normalize(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\u0900-\u097F]'), '');
  }

  void debugPrint(String msg) {
    // ignore: avoid_print
    print('[VoiceGame] $msg');
  }
}
