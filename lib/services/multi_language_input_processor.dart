import 'dart:typed_data';
import '../models/language_model.dart';
import '../models/processed_input.dart';
import '../models/trigger_word_configuration.dart';
import 'translation_service.dart';
import 'trigger_word_detector.dart';
import 'stt_service.dart';

class MultiLanguageInputProcessor {
  final STTService? _sttService;
  final TriggerWordDetector _triggerDetector;
  final TranslationService? _translationService;

  bool _isInitialized = false;

  MultiLanguageInputProcessor({
    STTService? sttService,
    TriggerWordDetector? triggerDetector,
    TranslationService? translationService,
  })  : _sttService = sttService,
        _triggerDetector = triggerDetector ?? TriggerWordDetector(),
        _translationService = translationService;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _triggerDetector.initialize();
    _isInitialized = true;
  }

  Future<ProcessedInput> processInput({
    required String recognizedText,
    required String detectedLanguage,
    required LanguageModel preferredLanguage,
    double confidence = 0.85,
  }) async {
    await initialize();

    final trigger = _triggerDetector.detectTriggerWord(recognizedText);

    String? translatedText;

    if (trigger == null && detectedLanguage != preferredLanguage.code) {
      translatedText = await _translateText(
        recognizedText,
        detectedLanguage,
        preferredLanguage.code,
      );
    }

    final action = trigger?.type == TriggerWordType.exit ? 'exit' : 'process';

    return ProcessedInput(
      originalText: recognizedText,
      inputLanguage: detectedLanguage,
      translatedText: translatedText,
      preferredLanguage: preferredLanguage.code,
      triggerWord: trigger,
      action: action,
      timestamp: DateTime.now(),
      confidence: confidence,
    );
  }

  Future<ProcessedInput> processInputFromAudio({
    required Uint8List audioData,
    required LanguageModel preferredLanguage,
  }) async {
    if (_sttService == null) {
      throw Exception('STT Service not available');
    }

    final languageCode = _detectLanguageFromAudio(audioData);

    final recognizedText = await _performSTT(audioData, languageCode);

    return processInput(
      recognizedText: recognizedText,
      detectedLanguage: languageCode,
      preferredLanguage: preferredLanguage,
    );
  }

  String _detectLanguageFromAudio(Uint8List audioData) {
    return 'hi';
  }

  Future<String> _performSTT(Uint8List audioData, String languageCode) async {
    return '';
  }

  Future<String?> _translateText(
    String text,
    String fromLanguage,
    String toLanguage,
  ) async {
    if (_translationService == null) return null;

    try {
      final result = await TranslationService.translate(
        text: text,
        targetLanguage: toLanguage,
        sourceLanguage: fromLanguage,
      );
      return result.translatedText;
    } catch (e) {
      return null;
    }
  }

  TriggerWordConfiguration? extractTriggerWord(String text) {
    return _triggerDetector.detectTriggerWord(text);
  }

  List<TriggerWordConfiguration> getTriggerWordsForLanguage(
      String languageCode) {
    return _triggerDetector.getTriggerWordsForLanguage(languageCode);
  }

  bool isEndOfThoughtTrigger(String text) {
    return _triggerDetector.isEndOfThoughtTrigger(text);
  }

  bool isExitTrigger(String text) {
    return _triggerDetector.isExitTrigger(text);
  }

  Map<String, List<TriggerWordConfiguration>> getAllTriggerWords() {
    return _triggerDetector.getAllTriggerWords();
  }

  int get supportedLanguagesCount => _triggerDetector.supportedLanguageCount;

  void dispose() {
    _triggerDetector.clearCache();
  }
}
