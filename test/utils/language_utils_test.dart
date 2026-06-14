import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_app/utils/language_utils.dart';
import 'package:voice_assistant_app/models/language_model.dart';

void main() {
  group('LanguageUtils', () {
    test('languageCodeToSTTLocale should return correct locale', () {
      expect(LanguageUtils.languageCodeToSTTLocale('hi'), 'hi-IN');
      expect(LanguageUtils.languageCodeToSTTLocale('en-US'), 'en-US');
      expect(LanguageUtils.languageCodeToSTTLocale('bn'), 'bn-IN');
      expect(LanguageUtils.languageCodeToSTTLocale('fr'), 'fr-FR');
    });

    test('getLanguageByCode should return correct language', () {
      final lang = LanguageUtils.getLanguageByCode('hi');

      expect(lang, isNotNull);
      expect(lang!.code, 'hi');
      expect(lang.name, 'Hindi');
    });

    test('getLanguageByCode should return null for unknown code', () {
      final lang = LanguageUtils.getLanguageByCode('xyz');

      expect(lang, isNull);
    });

    test('getLanguagesByGroup should filter correctly', () {
      final mainLanguages =
          LanguageUtils.getLanguagesByGroup(LanguageGroup.main);
      final indianLanguages =
          LanguageUtils.getLanguagesByGroup(LanguageGroup.nativeIndian);
      final intlLanguages =
          LanguageUtils.getLanguagesByGroup(LanguageGroup.international);

      expect(mainLanguages.length, 4);
      expect(indianLanguages.length, 16);
      expect(intlLanguages.length, 20);
    });

    test('getMainLanguages should return main group', () {
      final mainLanguages = LanguageUtils.getMainLanguages();

      expect(mainLanguages.length, 4);
    });

    test('getNativeIndianLanguages should return Indian group', () {
      final indianLanguages = LanguageUtils.getNativeIndianLanguages();

      expect(indianLanguages.length, 16);
    });

    test('getInternationalLanguages should return international group', () {
      final intlLanguages = LanguageUtils.getInternationalLanguages();

      expect(intlLanguages.length, 20);
    });

    test('getTriggerWordForLanguage should return correct word', () {
      final endWord = LanguageUtils.getTriggerWordForLanguage(
          'hi', TriggerWordType.endOfThought);
      final exitWord =
          LanguageUtils.getTriggerWordForLanguage('hi', TriggerWordType.exit);

      expect(endWord, isNotEmpty);
      expect(exitWord, isNotEmpty);
    });

    test('normalizeText should normalize input', () {
      final normalized = LanguageUtils.normalizeText('  Hello  World  ');

      expect(normalized, 'hello world');
    });

    test('removeDiacritics should remove accents', () {
      final result = LanguageUtils.removeDiacritics('café');

      expect(result.contains('é'), false);
    });

    test('isSameLangFamily should detect language families', () {
      expect(LanguageUtils.isSameLangFamily('hi', 'bn'), true);
      expect(LanguageUtils.isSameLangFamily('ta', 'te'), true);
      expect(LanguageUtils.isSameLangFamily('en-US', 'de'), false);
    });

    test('getLanguageDisplayName should return name', () {
      expect(LanguageUtils.getLanguageDisplayName('hi'), 'Hindi');
      expect(LanguageUtils.getLanguageDisplayName('hi', useNative: true),
          'हिन्दी');
    });

    test('isSupported should check language support', () {
      expect(LanguageUtils.isSupported('hi'), true);
      expect(LanguageUtils.isSupported('en-US'), true);
      expect(LanguageUtils.isSupported('xyz'), false);
    });

    test('getSupportedLanguageCount should return count', () {
      final count = LanguageUtils.getSupportedLanguageCount();

      expect(count, 40);
    });

    test('getAllLanguageCodes should return all codes', () {
      final codes = LanguageUtils.getAllLanguageCodes();

      expect(codes.contains('hi'), true);
      expect(codes.contains('en-US'), true);
      expect(codes.length, 40);
    });

    test('getLanguageCodeToNameMap should return map', () {
      final map = LanguageUtils.getLanguageCodeToNameMap();

      expect(map['hi'], 'Hindi');
      expect(map['en-US'], 'English (US)');
    });

    test('getLanguageCodeToNameMap with useNative should return native names',
        () {
      final map = LanguageUtils.getLanguageCodeToNameMap(useNative: true);

      expect(map['hi'], 'हिन्दी');
      expect(map['en-US'], 'English (US)');
    });

    test('calculateTextSimilarity should return similarity', () {
      final similarity =
          LanguageUtils.calculateTextSimilarity('hello', 'hello');

      expect(similarity, 1.0);
    });

    test('calculateTextSimilarity should handle different strings', () {
      final similarity =
          LanguageUtils.calculateTextSimilarity('hello', 'hallo');

      expect(similarity, lessThan(1.0));
      expect(similarity, greaterThan(0.5));
    });

    test('searchLanguages should find by name', () {
      final results = LanguageUtils.searchLanguages('Hindi');

      expect(results.any((l) => l.code == 'hi'), true);
    });

    test('searchLanguages should find by native name', () {
      final results = LanguageUtils.searchLanguages('हिन्दी');

      expect(results.any((l) => l.code == 'hi'), true);
    });

    test('searchLanguages should find by code', () {
      final results = LanguageUtils.searchLanguages('hi');

      expect(results.any((l) => l.code == 'hi'), true);
    });

    test('searchLanguages should return all for empty query', () {
      final results = LanguageUtils.searchLanguages('');

      expect(results.length, 40);
    });

    test('getRecommendedLanguages should return popular languages', () {
      final recommended = LanguageUtils.getRecommendedLanguages();

      expect(recommended.length, 4);
      expect(recommended.any((l) => l.code == 'hi'), true);
      expect(recommended.any((l) => l.code == 'en-US'), true);
    });
  });
}
