import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TranslationResult {
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;

  TranslationResult({
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
  });
}

class TranslationService {
  /// Translates text to the target language code.
  /// Throws an exception if the API request fails.
  static Future<TranslationResult> translate({
    required String text,
    required String targetLanguage,
    String sourceLanguage = 'auto',
  }) async {
    if (text.trim().isEmpty) {
      return TranslationResult(
        translatedText: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
    }

    try {
      final uri =
          Uri.parse('https://translate.googleapis.com/translate_a/single')
              .replace(
        queryParameters: {
          'client': 'gtx',
          'sl': sourceLanguage,
          'tl': targetLanguage,
          'dt': 't',
          'q': text,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null &&
            data is List &&
            data.isNotEmpty &&
            data[0] is List) {
          final translatedChunks = data[0] as List;
          final sb = StringBuffer();
          for (var chunk in translatedChunks) {
            if (chunk is List && chunk.isNotEmpty) {
              sb.write(chunk[0].toString());
            }
          }
          final detectedSource = data.length > 2 && data[2] != null
              ? data[2].toString()
              : sourceLanguage;

          return TranslationResult(
            translatedText: sb.toString(),
            sourceLanguage: detectedSource,
            targetLanguage: targetLanguage,
          );
        }
      }

      debugPrint('Translation failed with status: ${response.statusCode}');
      return TranslationResult(
        translatedText: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
    } catch (e) {
      debugPrint('Translation exception: $e');
      return TranslationResult(
        translatedText: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );
    }
  }
}
