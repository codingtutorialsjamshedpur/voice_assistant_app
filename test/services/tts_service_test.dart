import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:voice_assistant_app/services/tts_service.dart';

void main() {
  group('TTSService Tests', () {
    late TTSService ttsService;

    setUp(() {
      Get.reset();
      ttsService = TTSService();
    });

    tearDown(() {
      ttsService.onClose();
    });

    test('TTSService initializes with default values', () {
      expect(ttsService.isInitialized.value, isA<bool>());
      expect(ttsService.currentLanguage.value, TTSLanguage.hinglish);
      expect(ttsService.voiceSpeed.value, greaterThan(0));
      expect(ttsService.pitch.value, greaterThan(0));
    });

    test('TTSService supports multiple languages', () {
      expect(TTSLanguage.values.length, greaterThan(1));
      expect(
        TTSLanguage.values,
        contains(TTSLanguage.english),
      );
      expect(TTSLanguage.values, contains(TTSLanguage.hindi));
      expect(TTSLanguage.values, contains(TTSLanguage.hinglish));
    });

    test('Voice speed can be adjusted', () {
      final initialSpeed = ttsService.voiceSpeed.value;
      expect(initialSpeed, greaterThan(0));
    });

    test('Pitch can be adjusted', () {
      final initialPitch = ttsService.pitch.value;
      expect(initialPitch, greaterThan(0));
    });

    test('Speaking mode can be changed', () {
      expect(ttsService.speakingMode.value, isA<SpeakingMode>());
    });

    test('Emotion detection is supported', () {
      expect(ttsService.currentEmotion.value, isNotEmpty);
    });

    test('Animal voice personas are available', () {
      expect(ttsService.animalVoiceConfigs.isNotEmpty, true);
      expect(
        ttsService.animalVoiceConfigs.containsKey('Fun: Dog'),
        true,
      );
    });

    test('Progress word index tracking works', () {
      expect(ttsService.progressWordIndex.value, greaterThanOrEqualTo(-1));
    });

    test('isSpeaking state is observable', () {
      expect(ttsService.isSpeaking.value, isFalse);
    });
  });
}
