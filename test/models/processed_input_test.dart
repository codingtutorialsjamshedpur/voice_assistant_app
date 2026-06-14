import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_app/models/processed_input.dart';
import 'package:voice_assistant_app/models/trigger_word_configuration.dart';
import 'package:voice_assistant_app/models/language_model.dart';

void main() {
  group('ProcessedInput', () {
    test('should initialize with required fields', () {
      final input = ProcessedInput(
        originalText: 'Hello world',
        inputLanguage: 'en-US',
        preferredLanguage: 'en-US',
        timestamp: DateTime(2024, 1, 1),
        confidence: 0.85,
      );

      expect(input.originalText, 'Hello world');
      expect(input.inputLanguage, 'en-US');
      expect(input.preferredLanguage, 'en-US');
      expect(input.confidence, 0.85);
    });

    test('should support optional translated text', () {
      final input = ProcessedInput(
        originalText: 'Hola mundo',
        inputLanguage: 'es',
        translatedText: 'Hello world',
        preferredLanguage: 'en-US',
        timestamp: DateTime(2024, 1, 1),
        confidence: 0.90,
      );

      expect(input.translatedText, 'Hello world');
    });

    test('should support optional trigger word', () {
      const trigger = TriggerWordConfiguration(
        triggerWord: 'हो गया',
        variants: [],
        language: 'hi',
        type: TriggerWordType.endOfThought,
        description: 'Test',
      );

      final input = ProcessedInput(
        originalText: 'मुझे बताओ हो गया',
        inputLanguage: 'hi',
        preferredLanguage: 'hi',
        triggerWord: trigger,
        timestamp: DateTime(2024, 1, 1),
        confidence: 0.95,
      );

      expect(input.triggerWord, isNotNull);
      expect(input.hasTriggerWord, true);
    });

    test('isExit should return correct value', () {
      final exitInput = ProcessedInput(
        originalText: 'अलविदा',
        inputLanguage: 'hi',
        preferredLanguage: 'hi',
        action: 'exit',
        timestamp: DateTime(2024, 1, 1),
        confidence: 0.95,
      );

      final processInput = ProcessedInput(
        originalText: 'Hello',
        inputLanguage: 'en-US',
        preferredLanguage: 'en-US',
        action: 'process',
        timestamp: DateTime(2024, 1, 1),
        confidence: 0.85,
      );

      expect(exitInput.isExit, true);
      expect(processInput.isExit, false);
    });

    test('isEndOfThought should return correct value', () {
      const endOfThoughtTrigger = TriggerWordConfiguration(
        triggerWord: 'हो गया',
        variants: [],
        language: 'hi',
        type: TriggerWordType.endOfThought,
        description: 'Test',
      );

      const exitTrigger = TriggerWordConfiguration(
        triggerWord: 'अलविदा',
        variants: [],
        language: 'hi',
        type: TriggerWordType.exit,
        description: 'Test',
      );

      final endInput = ProcessedInput(
        originalText: 'बताओ हो गया',
        inputLanguage: 'hi',
        preferredLanguage: 'hi',
        triggerWord: endOfThoughtTrigger,
        timestamp: DateTime(2024, 1, 1),
        confidence: 0.95,
      );

      final exitInput = ProcessedInput(
        originalText: 'अलविदा',
        inputLanguage: 'hi',
        preferredLanguage: 'hi',
        triggerWord: exitTrigger,
        timestamp: DateTime(2024, 1, 1),
        confidence: 0.95,
      );

      expect(endInput.isEndOfThought, true);
      expect(exitInput.isEndOfThought, false);
    });

    test('copyWith should create new instance with updated fields', () {
      final original = ProcessedInput(
        originalText: 'Hello',
        inputLanguage: 'en-US',
        preferredLanguage: 'en-US',
        timestamp: DateTime(2024, 1, 1),
        confidence: 0.85,
      );

      final copied = original.copyWith(
        translatedText: 'Translated',
        confidence: 0.95,
      );

      expect(copied.originalText, 'Hello');
      expect(copied.translatedText, 'Translated');
      expect(copied.confidence, 0.95);
      expect(original.confidence, 0.85);
    });

    test('toJson should serialize correctly', () {
      final input = ProcessedInput(
        originalText: 'Hello',
        inputLanguage: 'en-US',
        preferredLanguage: 'en-US',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        confidence: 0.85,
      );

      final json = input.toJson();

      expect(json['originalText'], 'Hello');
      expect(json['inputLanguage'], 'en-US');
      expect(json['preferredLanguage'], 'en-US');
      expect(json['confidence'], 0.85);
    });

    test('fromJson should deserialize correctly', () {
      final json = {
        'originalText': 'Hello',
        'inputLanguage': 'en-US',
        'preferredLanguage': 'en-US',
        'timestamp': '2024-01-01T12:00:00.000',
        'confidence': 0.85,
      };

      final input = ProcessedInput.fromJson(json);

      expect(input.originalText, 'Hello');
      expect(input.inputLanguage, 'en-US');
      expect(input.preferredLanguage, 'en-US');
      expect(input.confidence, 0.85);
    });
  });
}
