import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_app/models/translation_model.dart';

void main() {
  group('TranslationRequest', () {
    test('should initialize with required fields', () {
      const request = TranslationRequest(
        sourceText: 'Hello',
        fromLanguage: 'en',
        toLanguage: 'hi',
      );

      expect(request.sourceText, 'Hello');
      expect(request.fromLanguage, 'en');
      expect(request.toLanguage, 'hi');
    });

    test('should support optional context', () {
      const request = TranslationRequest(
        sourceText: 'Hello',
        fromLanguage: 'en',
        toLanguage: 'hi',
        context: 'greeting',
      );

      expect(request.context, 'greeting');
    });

    test('should default preserveMeaning to true', () {
      const request = TranslationRequest(
        sourceText: 'Hello',
        fromLanguage: 'en',
        toLanguage: 'hi',
      );

      expect(request.preserveMeaning, true);
    });

    test('cacheKey should be unique for different inputs', () {
      const request1 = TranslationRequest(
        sourceText: 'Hello',
        fromLanguage: 'en',
        toLanguage: 'hi',
      );

      const request2 = TranslationRequest(
        sourceText: 'World',
        fromLanguage: 'en',
        toLanguage: 'hi',
      );

      expect(request1.cacheKey, isNot(equals(request2.cacheKey)));
    });

    test('toJson should serialize correctly', () {
      const request = TranslationRequest(
        sourceText: 'Hello',
        fromLanguage: 'en',
        toLanguage: 'hi',
        context: 'greeting',
        preserveMeaning: true,
      );

      final json = request.toJson();

      expect(json['sourceText'], 'Hello');
      expect(json['fromLanguage'], 'en');
      expect(json['toLanguage'], 'hi');
      expect(json['context'], 'greeting');
      expect(json['preserveMeaning'], true);
    });
  });

  group('TranslationResponse', () {
    test('should initialize with required fields', () {
      final response = TranslationResponse(
        translatedText: 'नमस्ते',
        fromLanguage: 'en',
        toLanguage: 'hi',
        confidence: 0.95,
        timestamp: DateTime(2024, 1, 1),
      );

      expect(response.translatedText, 'नमस्ते');
      expect(response.fromLanguage, 'en');
      expect(response.toLanguage, 'hi');
      expect(response.confidence, 0.95);
    });

    test('empty factory should create empty response', () {
      final response = TranslationResponse.empty();

      expect(response.translatedText, '');
      expect(response.isEmpty, true);
      expect(response.isNotEmpty, false);
    });

    test('alternatives should be optional', () {
      final response = TranslationResponse(
        translatedText: 'नमस्ते',
        fromLanguage: 'en',
        toLanguage: 'hi',
        confidence: 0.95,
        timestamp: DateTime(2024, 1, 1),
      );

      expect(response.alternatives, isNull);
    });

    test('copyWith should update fields correctly', () {
      final original = TranslationResponse(
        translatedText: 'नमस्ते',
        fromLanguage: 'en',
        toLanguage: 'hi',
        confidence: 0.95,
        timestamp: DateTime(2024, 1, 1),
      );

      final copied = original.copyWith(
        confidence: 0.99,
        alternatives: ['नमस्ते!', 'हेलो'],
      );

      expect(copied.translatedText, 'नमस्ते');
      expect(copied.confidence, 0.99);
      expect(copied.alternatives, hasLength(2));
    });

    test('toJson should serialize correctly', () {
      final response = TranslationResponse(
        translatedText: 'नमस्ते',
        fromLanguage: 'en',
        toLanguage: 'hi',
        confidence: 0.95,
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final json = response.toJson();

      expect(json['translatedText'], 'नमस्ते');
      expect(json['fromLanguage'], 'en');
      expect(json['toLanguage'], 'hi');
      expect(json['confidence'], 0.95);
    });
  });

  group('BatchTranslationRequest', () {
    test('should initialize with texts list', () {
      const request = BatchTranslationRequest(
        texts: ['Hello', 'World'],
        fromLanguage: 'en',
        toLanguage: 'hi',
      );

      expect(request.texts, hasLength(2));
      expect(request.fromLanguage, 'en');
      expect(request.toLanguage, 'hi');
    });

    test('should support optional context', () {
      const request = BatchTranslationRequest(
        texts: ['Hello'],
        fromLanguage: 'en',
        toLanguage: 'hi',
        context: 'greeting',
      );

      expect(request.context, 'greeting');
    });
  });

  group('BatchTranslationResponse', () {
    test('should initialize with translated texts', () {
      final response = BatchTranslationResponse(
        translatedTexts: ['नमस्ते', 'दुनिया'],
        fromLanguage: 'en',
        toLanguage: 'hi',
        confidences: [0.95, 0.90],
        timestamp: DateTime(2024, 1, 1),
      );

      expect(response.translatedTexts, hasLength(2));
      expect(response.confidences, hasLength(2));
    });

    test('empty factory should create empty response', () {
      final response = BatchTranslationResponse.empty();

      expect(response.isEmpty, true);
    });
  });
}
