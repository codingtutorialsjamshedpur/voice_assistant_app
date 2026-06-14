import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_app/models/language_model.dart';

void main() {
  group('LanguageModel', () {
    test('should initialize with all required fields', () {
      const model = LanguageModel(
        code: 'hi',
        name: 'Hindi',
        nativeName: 'हिन्दी',
        flag: '🇮🇳',
        group: LanguageGroup.main,
        ttsEngine: TTSEngine.sherpaOnnxEspeak,
        sttLocale: 'hi-IN',
        voices: [],
      );

      expect(model.code, 'hi');
      expect(model.name, 'Hindi');
      expect(model.nativeName, 'हिन्दी');
      expect(model.flag, '🇮🇳');
      expect(model.group, LanguageGroup.main);
      expect(model.ttsEngine, TTSEngine.sherpaOnnxEspeak);
      expect(model.sttLocale, 'hi-IN');
      expect(model.voices, isEmpty);
    });

    test('should initialize with trigger words', () {
      const model = LanguageModel(
        code: 'hi',
        name: 'Hindi',
        nativeName: 'हिन्दी',
        flag: '🇮🇳',
        group: LanguageGroup.main,
        ttsEngine: TTSEngine.sherpaOnnxEspeak,
        sttLocale: 'hi-IN',
        voices: [],
        endOfThoughtTrigger: 'हो गया',
        endOfThoughtVariants: ['हो गया', 'होगया', 'ho gaya'],
        exitTrigger: 'अलविदा',
        exitTriggerVariants: ['अलविदा', 'alvida', 'bye'],
      );

      expect(model.endOfThoughtTrigger, 'हो गया');
      expect(model.endOfThoughtVariants, contains('होगया'));
      expect(model.exitTrigger, 'अलविदा');
      expect(model.exitTriggerVariants, contains('alvida'));
    });

    test('should have default values for optional trigger fields', () {
      const model = LanguageModel(
        code: 'en-US',
        name: 'English',
        nativeName: 'English',
        flag: '🇺🇸',
        group: LanguageGroup.main,
        ttsEngine: TTSEngine.flutterTts,
        sttLocale: 'en-US',
        voices: [],
      );

      expect(model.endOfThoughtTrigger, '');
      expect(model.endOfThoughtVariants, isEmpty);
      expect(model.exitTrigger, '');
      expect(model.exitTriggerVariants, isEmpty);
      expect(model.translationLLMCode, isNull);
    });
  });

  group('LanguageGroup', () {
    test('should have correct enum values', () {
      expect(LanguageGroup.values.length, 3);
      expect(LanguageGroup.values.contains(LanguageGroup.main), true);
      expect(LanguageGroup.values.contains(LanguageGroup.nativeIndian), true);
      expect(LanguageGroup.values.contains(LanguageGroup.international), true);
    });
  });

  group('TTSEngine', () {
    test('should have correct enum values', () {
      expect(TTSEngine.values.length, 3);
      expect(TTSEngine.values.contains(TTSEngine.flutterTts), true);
      expect(TTSEngine.values.contains(TTSEngine.sherpaOnnxPiper), true);
      expect(TTSEngine.values.contains(TTSEngine.sherpaOnnxEspeak), true);
    });
  });

  group('VoiceOption', () {
    test('should initialize with required fields', () {
      const voice = VoiceOption(
        id: 'test-voice',
        label: 'Test Voice',
        gender: 'female',
        quality: 'high',
      );

      expect(voice.id, 'test-voice');
      expect(voice.label, 'Test Voice');
      expect(voice.gender, 'female');
      expect(voice.quality, 'high');
      expect(voice.isSystem, false);
    });

    test('should support system voice flag', () {
      const voice = VoiceOption(
        id: 'system-voice',
        label: 'System Voice',
        gender: 'neutral',
        quality: 'high',
        isSystem: true,
      );

      expect(voice.isSystem, true);
    });
  });
}
