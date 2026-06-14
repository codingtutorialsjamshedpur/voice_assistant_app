import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_app/models/trigger_word_configuration.dart';
import 'package:voice_assistant_app/models/language_model.dart';

void main() {
  group('TriggerWordConfiguration', () {
    test('should initialize with required fields', () {
      const config = TriggerWordConfiguration(
        triggerWord: 'हो गया',
        variants: ['हो गया', 'होगया', 'ho gaya'],
        language: 'hi',
        type: TriggerWordType.endOfThought,
        description: 'Trigger word to finish speaking',
      );

      expect(config.triggerWord, 'हो गया');
      expect(config.variants.length, 3);
      expect(config.language, 'hi');
      expect(config.type, TriggerWordType.endOfThought);
      expect(config.description, 'Trigger word to finish speaking');
    });

    test('should have default confidence threshold', () {
      const config = TriggerWordConfiguration(
        triggerWord: 'done',
        variants: ['done', 'finished'],
        language: 'en-US',
        type: TriggerWordType.endOfThought,
        description: 'Test',
      );

      expect(config.confidenceThreshold, 0.75);
      expect(config.pauseBeforeTrigger, 300);
    });

    test('should support custom thresholds', () {
      const config = TriggerWordConfiguration(
        triggerWord: 'done',
        variants: [],
        language: 'en-US',
        type: TriggerWordType.endOfThought,
        description: 'Test',
        confidenceThreshold: 0.85,
        pauseBeforeTrigger: 500,
      );

      expect(config.confidenceThreshold, 0.85);
      expect(config.pauseBeforeTrigger, 500);
    });

    test('matches should detect exact trigger word', () {
      const config = TriggerWordConfiguration(
        triggerWord: 'हो गया',
        variants: ['ho gaya'],
        language: 'hi',
        type: TriggerWordType.endOfThought,
        description: 'Test',
      );

      expect(config.matches('हो गया'), true);
      expect(config.matches('हो गया '), true);
      expect(config.matches(' हो गया'), true);
    });

    test('matches should detect variants', () {
      const config = TriggerWordConfiguration(
        triggerWord: 'हो गया',
        variants: ['ho gaya', 'hogaya'],
        language: 'hi',
        type: TriggerWordType.endOfThought,
        description: 'Test',
      );

      expect(config.matches('ho gaya'), true);
      expect(config.matches('hogaya'), true);
    });

    test('matches should be case insensitive', () {
      const config = TriggerWordConfiguration(
        triggerWord: 'done',
        variants: ['finished'],
        language: 'en-US',
        type: TriggerWordType.endOfThought,
        description: 'Test',
      );

      expect(config.matches('DONE'), true);
      expect(config.matches('Done'), true);
    });

    test('calculateSimilarity should return 1.0 for identical strings', () {
      const config = TriggerWordConfiguration(
        triggerWord: 'hello',
        variants: [],
        language: 'en-US',
        type: TriggerWordType.endOfThought,
        description: 'Test',
      );

      expect(config.calculateSimilarity('hello'), 1.0);
    });

    test('calculateSimilarity should return lower values for different strings',
        () {
      const config = TriggerWordConfiguration(
        triggerWord: 'hello',
        variants: [],
        language: 'en-US',
        type: TriggerWordType.endOfThought,
        description: 'Test',
      );

      final similarity = config.calculateSimilarity('hallo');
      expect(similarity, lessThan(1.0));
      expect(similarity, greaterThan(0.5));
    });

    test('fromLanguage factory should create correct config', () {
      final endOfThought = TriggerWordConfiguration.fromLanguage(
          'hi', TriggerWordType.endOfThought);
      final exit =
          TriggerWordConfiguration.fromLanguage('hi', TriggerWordType.exit);

      expect(endOfThought.language, 'hi');
      expect(endOfThought.type, TriggerWordType.endOfThought);
      expect(exit.type, TriggerWordType.exit);
    });
  });

  group('TriggerWordType', () {
    test('should have correct enum values', () {
      expect(TriggerWordType.values.length, 2);
      expect(
          TriggerWordType.values.contains(TriggerWordType.endOfThought), true);
      expect(TriggerWordType.values.contains(TriggerWordType.exit), true);
    });
  });
}
