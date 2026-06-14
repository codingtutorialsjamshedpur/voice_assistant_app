import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:voice_assistant_app/services/stt_service.dart';

void main() {
  group('STTService Tests', () {
    late STTService sttService;

    setUp(() {
      Get.reset();
      sttService = STTService();
    });

    tearDown(() {
      sttService.onClose();
    });

    test('STTService initializes with default values', () {
      expect(sttService.isInitialized.value, isA<bool>());
      expect(sttService.isListening.value, false);
      expect(sttService.recognizedText.value, isEmpty);
      expect(sttService.accumulatedText.value, isEmpty);
    });

    test('STTService supports multiple languages', () {
      expect(STTLanguage.values.length, greaterThan(1));
      expect(STTLanguage.values, contains(STTLanguage.englishUS));
      expect(STTLanguage.values, contains(STTLanguage.hindi));
      expect(STTLanguage.values, contains(STTLanguage.hinglish));
    });

    test('Current language can be set', () {
      sttService.currentLanguage.value = STTLanguage.hindi;
      expect(sttService.currentLanguage.value, STTLanguage.hindi);
    });

    test('Recording time is tracked', () {
      expect(sttService.recordingTime.value, greaterThanOrEqualTo(0));
    });

    test('Confidence level is available', () {
      expect(sttService.confidenceLevel.value, greaterThanOrEqualTo(0));
      expect(sttService.confidenceLevel.value, lessThanOrEqualTo(1));
    });

    test('Status is observable', () {
      expect(sttService.status.value, isNotEmpty);
    });

    test('Language locale mapping is complete', () {
      expect(sttService.languageLocales.isNotEmpty, true);
      expect(
        sttService.languageLocales[STTLanguage.englishUS],
        isNotEmpty,
      );
      expect(
        sttService.languageLocales[STTLanguage.hindi],
        isNotEmpty,
      );
    });

    test('Recognized text can be updated', () {
      sttService.recognizedText.value = 'Test recognition';
      expect(sttService.recognizedText.value, 'Test recognition');
    });

    test('Accumulated text aggregates recognized text', () {
      sttService.accumulatedText.value = 'Accumulated text';
      expect(sttService.accumulatedText.value, 'Accumulated text');
    });
  });
}
