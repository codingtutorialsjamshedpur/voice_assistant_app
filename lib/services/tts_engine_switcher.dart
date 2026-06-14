import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import '../models/language_model.dart';
import '../services/tts_service.dart';
import '../services/sherpa_tts_service.dart';

/// Routes TTS calls to the correct engine based on the selected language
class TtsEngineSwitcher extends GetxService {
  TTSEngine _currentEngine = TTSEngine.flutterTts;

  // Single reusable AudioPlayer for sherpa WAV playback
  AudioPlayer? _audioPlayer;

  // Current language code for reference
  String _currentLanguageCode = 'en-US';

  final isSpeaking = false.obs;

  TTSService get _ttsService => Get.find<TTSService>();
  SherpaTtsService get _sherpaService => Get.find<SherpaTtsService>();

  @override
  void onInit() {
    super.onInit();
    _audioPlayer = AudioPlayer();
  }

  /// Configure the correct engine when user changes language
  Future<void> switchLanguage(LanguageModel lang) async {
    // Stop anything playing
    await stop();

    _currentEngine = lang.ttsEngine;
    _currentLanguageCode =
        lang.sttLocale; // Store standard BCP-47 language code for TTS

    switch (lang.ttsEngine) {
      case TTSEngine.flutterTts:
        // Map language code to TTSLanguage enum for the 3 main locales.
        // For ALL other locales (Odia, Sanskrit, Malayalam, Bengali, etc.),
        // we store the BCP-47 code in _currentLanguageCode and hand it directly
        // to flutter_tts on every speak() call — this is the accent/voice fix.
        switch (lang.code) {
          case 'en-US':
          case 'en-GB':
            _ttsService.setLanguage(TTSLanguage.english);
            break;
          case 'hi':
            _ttsService.setLanguage(TTSLanguage.hindi);
            break;
          case 'hinglish':
            _ttsService.setLanguage(TTSLanguage.hinglish);
            break;
          default:
            // Native Indian / International language — do NOT override to English.
            // Keep currentLanguage as-is (hinglish default is fine as enum fallback);
            // the actual locale is in _currentLanguageCode and used on speak().
            debugPrint(
                '🔀 TtsEngineSwitcher: Native language ${lang.name} (${lang.sttLocale}) — will use flutterTts with locale override');
        }
        break;

      case TTSEngine.sherpaOnnxPiper:
        // Voice will be initialized lazily on first speak
        if (lang.voices.isNotEmpty) {
          try {
            await _sherpaService.initVoice(lang.voices.first);
          } catch (e) {
            debugPrint('⚠️ TtsEngineSwitcher: Failed to init sherpa voice: $e');
          }
        }
        break;

      case TTSEngine.sherpaOnnxEspeak:
        // eSpeak voices via sherpa — init if voice entry present
        if (lang.voices.isNotEmpty) {
          try {
            await _sherpaService.initVoice(lang.voices.first);
          } catch (e) {
            debugPrint('⚠️ TtsEngineSwitcher: eSpeak init: $e');
          }
        }

        // Also configure Google TTS for this language if available
        try {
          final googleTts = Get.find(tag: 'GoogleTtsService') as dynamic;
          if (googleTts != null && googleTts.isInitialized != null) {
            googleTts.setLanguage(lang.code);
            debugPrint(
                '🌐 Google TTS configured for ${lang.name} (${lang.code})');
          }
        } catch (_) {
          // Google TTS not available
        }
        break;
    }

    debugPrint(
        '🔀 TtsEngineSwitcher: switched to ${lang.name} [${lang.ttsEngine.name}]');
  }

  /// Speak text using the currently configured engine
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    // Stop any current playback
    await stop();

    switch (_currentEngine) {
      case TTSEngine.flutterTts:
        isSpeaking.value = true;
        try {
          // ACCENT FIX: Always pass the current BCP-47 language code so flutter_tts
          // uses the correct locale (Odia, Sanskrit, Malayalam, etc.) not just hi-IN.
          await _ttsService.speak(text, languageCode: _currentLanguageCode);
        } finally {
          isSpeaking.value = false;
        }
        break;

      case TTSEngine.sherpaOnnxPiper:
      case TTSEngine.sherpaOnnxEspeak:
        // Try Google TTS first for Indian languages
        // If not configured, fallback to Sherpa
        await _speakViaGoogleOrSherpa(text);
        break;
    }
  }

  /// Speak via Google TTS if available, otherwise fallback to Sherpa
  Future<void> _speakViaGoogleOrSherpa(String text) async {
    try {
      dynamic googleTts;
      try {
        googleTts = Get.find(tag: 'GoogleTtsService') as dynamic;
      } catch (_) {
        // Google TTS not registered
      }

      if (googleTts != null &&
          googleTts.isInitialized != null &&
          (googleTts.isInitialized as dynamic).value == true) {
        debugPrint('📱 Using Google TTS for language: $_currentLanguageCode');
        isSpeaking.value = true;
        try {
          await googleTts.speak(text, languageCode: _currentLanguageCode)
              as Future<void>;
        } finally {
          isSpeaking.value = false;
        }
      } else {
        // Fallback to Sherpa
        debugPrint('⚠️ Google TTS not available, falling back to Sherpa');
        await _speakViaSherpa(text);
      }
    } catch (e) {
      debugPrint('❌ TtsEngineSwitcher._speakViaGoogleOrSherpa: $e');
      isSpeaking.value = false;
      // Final fallback to flutter_tts
      try {
        await _ttsService.speak(text, languageCode: _currentLanguageCode);
      } catch (_) {}
    }
  }

  /// Speak using sherpa_onnx → just_audio pipeline
  Future<void> _speakViaSherpa(String text) async {
    try {
      final processedText = _ttsService.preprocessText(text);
      // If sherpa not initialized, fall back to flutter_tts
      if (!_sherpaService.isInitialized) {
        isSpeaking.value = true;
        try {
          await _ttsService.speak(processedText,
              languageCode: _currentLanguageCode);
        } finally {
          isSpeaking.value = false;
        }
        return;
      }

      final wavPath = await _sherpaService.synthesizeToFile(processedText);

      isSpeaking.value = true;

      // Set file and play
      await _audioPlayer!.setAudioSource(
        AudioSource.file(wavPath),
      );

      // Listen for completion
      final completer = Future.any([
        _audioPlayer!.playerStateStream.firstWhere(
          (state) =>
              state.processingState == ProcessingState.completed ||
              state.processingState == ProcessingState.idle,
        ),
      ]);

      await _audioPlayer!.play();
      await completer;

      isSpeaking.value = false;
    } catch (e) {
      debugPrint('❌ TtsEngineSwitcher._speakViaSherpa: $e');
      isSpeaking.value = false;
      // Fallback to flutter_tts
      try {
        await _ttsService.speak(text, languageCode: _currentLanguageCode);
      } catch (_) {}
    }
  }

  /// Speak text in a specific language (used by Story Mode and main language routing).
  ///
  /// Temporarily switches to the specified BCP-47 language code,
  /// speaks the text, then restores the original language engine.
  /// If [languageCode] is empty, uses the currently configured engine.
  Future<void> speakInLanguage(String text, String languageCode) async {
    if (languageCode.isEmpty) {
      // Use default engine (current language)
      await speak(text);
      return;
    }

    // ENHANCED FIX: For native Indian languages (Odia, Assamese, Maithili, etc.)
    // that use sherpaOnnxEspeak but have no downloaded voices, we should use
    // flutter_tts with the proper language code for correct accent.
    //
    // Check if this is a sherpa-based language without downloaded voices
    final isSherpaBased = _currentEngine == TTSEngine.sherpaOnnxPiper ||
        _currentEngine == TTSEngine.sherpaOnnxEspeak;

    // Check if sherpa voices are actually available and initialized
    bool hasWorkingSherpaVoice = false;
    if (isSherpaBased) {
      try {
        // For sherpa languages, check if we have actual voice data
        // If voices array is empty or sherpa service isn't ready, use flutter_tts
        hasWorkingSherpaVoice = _sherpaService.isInitialized &&
            _sherpaService.currentVoiceId != null;
      } catch (e) {
        debugPrint('⚠️ TtsEngineSwitcher: Sherpa voice check failed: $e');
        hasWorkingSherpaVoice = false;
      }
    }

    // Decide which engine to use for this specific announcement
    if (isSherpaBased && hasWorkingSherpaVoice) {
      // Use sherpa for languages with properly downloaded and initialized voices
      debugPrint('🔀 TtsEngineSwitcher: Using Sherpa for $languageCode');
      await _speakViaSherpa(text);
    } else {
      // Use Google TTS or fallback to flutter_tts
      debugPrint(
          '🔀 TtsEngineSwitcher: Trying Google TTS or fallback for $languageCode');
      try {
        dynamic googleTts;
        try {
          googleTts = Get.find(tag: 'GoogleTtsService') as dynamic;
        } catch (_) {}

        if (googleTts != null &&
            googleTts.isInitialized != null &&
            (googleTts.isInitialized as dynamic).value == true) {
          isSpeaking.value = true;
          try {
            await googleTts.speak(text, languageCode: languageCode)
                as Future<void>;
          } finally {
            isSpeaking.value = false;
          }
        } else {
          isSpeaking.value = true;
          try {
            await _ttsService.speak(text, languageCode: languageCode);
          } finally {
            isSpeaking.value = false;
          }
        }
      } catch (e) {
        debugPrint('❌ TtsEngineSwitcher speak fallback error: $e');
        isSpeaking.value = false;
      }
    }
  }

  /// Stop all current playback regardless of engine
  Future<void> stop() async {
    try {
      // Stop flutter TTS
      await _ttsService.stop();
    } catch (_) {}

    try {
      // Stop just_audio player
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
      }
    } catch (_) {}

    isSpeaking.value = false;
  }

  /// Set speech speed on both engines
  Future<void> setSpeed(double speed) async {
    try {
      _ttsService.setSpeed(speed);
    } catch (_) {}
    try {
      await _sherpaService.setSpeed(speed);
    } catch (_) {}
  }

  /// Set pitch on both engines
  Future<void> setPitch(double pitch) async {
    try {
      _ttsService.setPitch(pitch);
    } catch (_) {}
    try {
      await _sherpaService.setPitch(pitch);
    } catch (_) {}
  }

  @override
  void onClose() {
    _audioPlayer?.dispose();
    super.onClose();
  }
}
