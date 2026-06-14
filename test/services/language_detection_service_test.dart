import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_app/services/language_detection_service.dart';
import 'package:voice_assistant_app/models/language_model.dart';
import 'package:voice_assistant_app/constants/language_constants.dart';

void main() {
  late LanguageDetectionService service;

  setUp(() {
    service = LanguageDetectionService();
  });

  group('LanguageDetectionService', () {
    test('should detect Hindi from text', () {
      final detected = service.detectFromText('क्या आप मुझे बता सकते हैं');

      expect(detected, 'hi');
    });

    test('should detect Bengali from text', () {
      final detected = service.detectFromText('আপনি কি আমাকে বলতে পারেন');

      expect(detected, 'bn');
    });

    test('should detect Tamil from text', () {
      final detected = service.detectFromText('நீங்கள் எனக்கு சொல்ல முடியுமா');

      expect(detected, 'ta');
    });

    test('should detect Telugu from text', () {
      final detected = service.detectFromText('మీరు నాకు చెప్పగలరా');

      expect(detected, 'te');
    });

    test('should detect Kannada from text', () {
      final detected = service.detectFromText('ನೀವು ನನಗೆ ಹೇಳಬಹುದೇ');

      expect(detected, 'kn');
    });

    test('should detect Gujarati from text', () {
      final detected = service.detectFromText('તમે મને કહી શકો છો');

      expect(detected, 'gu');
    });

    test('should detect Marathi from text', () {
      final detected = service.detectFromText('तुम्ही मला सांगू शकता');

      expect(detected, 'mr');
    });

    test('should detect Punjabi from text', () {
      final detected = service.detectFromText('ਤੁਸੀਂ ਮੈਨੂੰ ਦੱਸ ਸਕਦੇ ਹੋ');

      expect(detected, 'pa');
    });

    test('should detect Urdu from text', () {
      final detected = service.detectFromText('آپ مجھے بتا سکتے ہیں');

      expect(detected, 'ur');
    });

    test('should detect French from text', () {
      final detected = service.detectFromText('pouvez-vous me dire');

      expect(detected, 'fr');
    });

    test('should detect German from text', () {
      final detected = service.detectFromText('können Sie mir sagen');

      expect(detected, 'de');
    });

    test('should detect Spanish from text', () {
      final detected = service.detectFromText('puedes decirme');

      expect(detected, 'es');
    });

    test('should detect Italian from text', () {
      final detected = service.detectFromText('puoi dirmi');

      expect(detected, 'it');
    });

    test('should detect Russian from text', () {
      final detected = service.detectFromText('можете ли вы мне сказать');

      expect(detected, 'ru');
    });

    test('should detect Chinese from text', () {
      final detected = service.detectFromText('你能告诉我吗');

      expect(detected, 'zh');
    });

    test('should detect Japanese from text', () {
      final detected = service.detectFromText('教えてください');

      expect(detected, 'ja');
    });

    test('should detect Korean from text', () {
      final detected = service.detectFromText('말해줄 수 있나요');

      expect(detected, 'ko');
    });

    test('should detect Arabic from text', () {
      final detected = service.detectFromText('هل يمكنك أن تخبرني');

      expect(detected, 'ar');
    });

    test('should return en-US for empty text', () {
      final detected = service.detectFromText('');

      expect(detected, 'en-US');
    });

    test('should return default for unknown text', () {
      final detected = service.detectFromText('xyz abc def');

      expect(detected, isNotEmpty);
    });

    test('getConfidence should return confidence value', () {
      final confidence = service.getConfidence('hi');

      expect(confidence, 0.85);
    });

    test('getAlternativeLanguages should return alternatives', () {
      final alternatives = service.getAlternativeLanguages('क्या आप', limit: 3);

      expect(alternatives, isNotEmpty);
      expect(alternatives.length, lessThanOrEqualTo(3));
    });

    test('getLanguageModel should return correct model', () {
      final model = service.getLanguageModel('hi');

      expect(model, isNotNull);
      expect(model!.code, 'hi');
      expect(model.name, 'Hindi');
    });

    test('getLanguageModel should return null for unknown code', () {
      final model = service.getLanguageModel('xyz');

      expect(model, isNull);
    });

    test('getAllLanguages should return all languages', () {
      final languages = service.getAllLanguages();

      expect(languages.length, kAllLanguages.length);
    });

    test('getLanguagesByGroup should filter by group', () {
      final mainLanguages = service.getLanguagesByGroup(LanguageGroup.main);
      final indianLanguages =
          service.getLanguagesByGroup(LanguageGroup.nativeIndian);
      final intlLanguages =
          service.getLanguagesByGroup(LanguageGroup.international);

      expect(mainLanguages.length, 4);
      expect(indianLanguages.length, greaterThan(10));
      expect(intlLanguages.length, greaterThan(10));
    });

    test('clearCache should clear internal cache', () {
      service.clearCache();

      expect(service.getConfidence('hi'), 0.85);
    });
  });
}
