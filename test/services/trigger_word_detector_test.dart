import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_app/services/trigger_word_detector.dart';
import 'package:voice_assistant_app/models/language_model.dart';
import 'package:voice_assistant_app/constants/language_constants.dart';

void main() {
  late TriggerWordDetector detector;

  setUp(() {
    detector = TriggerWordDetector(similarityThreshold: 0.75);
    detector.initialize();
  });

  group('TriggerWordDetector', () {
    test('should initialize and load all languages', () {
      expect(detector.supportedLanguageCount, kAllLanguages.length);
    });

    test('should detect Hindi end of thought trigger', () {
      final config = detector.detectTriggerWord('मुझे बताओ हो गया');

      expect(config, isNotNull);
      expect(config!.type, TriggerWordType.endOfThought);
      expect(config.language, 'hi');
    });

    test('should detect Hindi exit trigger', () {
      final config = detector.detectTriggerWord('अलविदा');

      expect(config, isNotNull);
      expect(config!.type, TriggerWordType.exit);
      expect(config.language, 'hi');
    });

    test('should detect Hinglish end of thought trigger', () {
      final config = detector.detectTriggerWord('mujhe bolo ho gaya');

      expect(config, isNotNull);
      expect(config!.type, TriggerWordType.endOfThought);
    });

    test('should detect English end of thought trigger', () {
      final config = detector.detectTriggerWord('thats all done');

      expect(config, isNotNull);
      expect(config!.type, TriggerWordType.endOfThought);
    });

    test('should detect English exit trigger', () {
      final config = detector.detectTriggerWord('goodbye');

      expect(config, isNotNull);
      expect(config!.type, TriggerWordType.exit);
    });

    test('should detect Bengali trigger word', () {
      final config = detector.detectTriggerWord('শেষ হয় গেছে');

      expect(config, isNotNull);
      expect(config!.type, TriggerWordType.endOfThought);
    });

    test('should detect Tamil trigger word', () {
      final config = detector.detectTriggerWord('முடிந்தது');

      expect(config, isNotNull);
      expect(config!.type, TriggerWordType.endOfThought);
    });

    test('should detect Telugu trigger word', () {
      final config = detector.detectTriggerWord('చేసాను');

      expect(config, isNotNull);
    });

    test('isEndOfThoughtTrigger should return true for end of thought', () {
      expect(detector.isEndOfThoughtTrigger('हो गया'), true);
      expect(detector.isEndOfThoughtTrigger('done'), true);
    });

    test('isExitTrigger should return true for exit', () {
      expect(detector.isExitTrigger('अलविदा'), true);
      expect(detector.isExitTrigger('goodbye'), true);
    });

    test('isTriggerWord should detect triggers in any language', () {
      expect(detector.isTriggerWord('हो गया', 'hi'), true);
      expect(detector.isTriggerWord('done', 'en-US'), true);
      expect(detector.isTriggerWord('अलविदा', null), true);
    });

    test('getTriggerWordsForLanguage should return configs for language', () {
      final configs = detector.getTriggerWordsForLanguage('hi');

      expect(configs, hasLength(2));
      expect(configs.any((c) => c.type == TriggerWordType.endOfThought), true);
      expect(configs.any((c) => c.type == TriggerWordType.exit), true);
    });

    test('getTriggerWordsByType should return all triggers of type', () {
      final endOfThoughtTriggers =
          detector.getTriggerWordsByType(TriggerWordType.endOfThought);

      expect(endOfThoughtTriggers.length, greaterThan(10));
    });

    test('detectTriggerType should return correct type', () {
      expect(
          detector.detectTriggerType('हो गया'), TriggerWordType.endOfThought);
      expect(detector.detectTriggerType('अलविदा'), TriggerWordType.exit);
    });

    test('getTriggerWordsSummary should return map of all triggers', () {
      final summary = detector.getTriggerWordsSummary();

      expect(summary.containsKey('hi'), true);
      expect(summary['hi']['endOfThought'], isNotNull);
      expect(summary['hi']['exit'], isNotNull);
    });

    test('clearCache should clear all cached triggers', () {
      detector.clearCache();

      expect(detector.supportedLanguageCount, 0);
    });
  });

  group('TriggerWordDetector fuzzy matching', () {
    test('should calculate fuzzy similarity', () {
      final similarity = detector.calculateFuzzySimilarity('हो गया', 'होगया');

      expect(similarity, greaterThan(0.7));
    });

    test('should handle exact matches', () {
      final similarity = detector.calculateFuzzySimilarity('done', 'done');

      expect(similarity, 1.0);
    });

    test('should return low similarity for different strings', () {
      final similarity = detector.calculateFuzzySimilarity('hello', 'goodbye');

      expect(similarity, lessThan(0.5));
    });
  });

  group('TriggerWordDetector cross-language detection', () {
    test('should detect Hindi trigger when preferred is different', () {
      final config = detector.detectTriggerWord('say hello हो गया');

      expect(config, isNotNull);
      expect(config!.type, TriggerWordType.endOfThought);
    });

    test('should handle mixed language input', () {
      final config = detector.detectTriggerWord('tell me about it alvida');

      expect(config, isNotNull);
      expect(config!.type, TriggerWordType.exit);
    });
  });
}
