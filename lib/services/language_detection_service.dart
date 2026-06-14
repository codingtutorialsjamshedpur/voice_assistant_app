import '../models/language_model.dart';
import '../constants/language_constants.dart';

class LanguageDetectionService {
  final Map<String, double> _confidenceCache = {};

  LanguageDetectionService({int cacheSize = 100});

  String detectFromText(String text) {
    if (text.isEmpty) return 'en-US';

    final normalizedText = text.toLowerCase().trim();

    for (final language in kAllLanguages) {
      if (_matchesLanguagePattern(normalizedText, language)) {
        return language.code;
      }
    }

    return _detectByCommonWords(normalizedText);
  }

  bool _matchesLanguagePattern(String text, LanguageModel language) {
    final patterns = _getLanguagePatterns(language.code);
    for (final pattern in patterns) {
      if (text.contains(pattern)) {
        return true;
      }
    }
    return false;
  }

  List<String> _getLanguagePatterns(String languageCode) {
    const patterns = {
      'hi': [
        'क्या',
        'कैसे',
        'कहाँ',
        'कौन',
        'मैं',
        'आप',
        'है',
        'हैं',
        'गया',
        'गयी',
        'हो गया',
        'अलविदा'
      ],
      'bn': [
        'কি',
        'কীভাবে',
        'কোথায়',
        'কে',
        'আমি',
        'আপনি',
        'হয়',
        'হয়েছে',
        'বিদায়'
      ],
      'ta': [
        'என்ன',
        'எப்படி',
        'எங்கே',
        'யார்',
        'நான்',
        'நீங்கள்',
        'இருக்கிறது',
        'வணக்கம்'
      ],
      'te': ['ఏమిటి', 'ఎలా', 'ఎక్కड', 'ఎవరు', 'నేను', 'మీరు', 'ఉంది', 'అలిడా'],
      'kn': ['ಏನು', 'ಹೇಗೆ', 'ಎಲ್ಲಿ', 'ಯಾರು', 'ನಾನು', 'ನೀವು', 'ಇದೆ', 'ವಿದಾಯ'],
      'ml': [
        'എന്ത്',
        'എങ്ങനെ',
        'എവിടെ',
        'ആരാണ്',
        'ഞാന്‍',
        'നിങ്ങള്‍',
        'ഉണ്ട്',
        'വിട'
      ],
      'gu': ['શું', 'કેવી રીતે', 'ક્યાં', 'કોણ', 'હું', 'તમે', 'છે', 'અલવિદા'],
      'mr': ['काय', 'कसे', 'कुठ', 'कोण', 'मी', 'तुम्ही', 'आहे', 'अलविदा'],
      'ur': ['کیا', 'کیسے', 'کہاں', 'کون', 'میں', 'آپ', 'ہے', 'الوداع'],
      'pa': ['ਕੀ', 'ਕਿਵੇਂ', 'ਕਿੱਥੇ', 'ਕੌਣ', 'ਮੈਂ', 'ਤੁਹਾਡਾ', 'ਹੈ', 'ਅਲਵਿਦਾ'],
      'fr': ['quoi', 'comment', 'où', 'qui', 'je', 'vous', 'est', 'au revoir'],
      'de': ['was', 'wie', 'wo', 'wer', 'ich', 'Sie', 'ist', 'auf wiedersehen'],
      'es': ['qué', 'cómo', 'dónde', 'quién', 'yo', 'usted', 'es', 'adiós'],
      'it': ['cosa', 'come', 'dove', 'chi', 'io', 'lei', 'è', 'arrivederci'],
      'pt-BR': ['o que', 'como', 'onde', 'quem', 'eu', 'você', 'é', 'adeus'],
      'ru': ['что', 'как', 'где', 'кто', 'я', 'вы', 'это', 'до свидания'],
      'zh': ['什么', '怎么', '哪里', '谁', '我', '你', '是', '再见'],
      'ja': ['何', 'どこ', '誰', '私', 'あなた', 'です', 'さようなら'],
      'ko': ['뭐', '어디', '누구', '나', '당신', '입니다', '안녕히'],
      'ar': ['ما', 'كيف', 'أين', 'من', 'أنا', 'أنت', 'هو', 'وداعا'],
    };
    return patterns[languageCode] ?? [];
  }

  String _detectByCommonWords(String text) {
    final wordCounts = <String, int>{};

    for (final language in kAllLanguages) {
      final patterns = _getLanguagePatterns(language.code);
      int matchCount = 0;

      for (final pattern in patterns) {
        if (text.contains(pattern)) {
          matchCount++;
        }
      }

      if (matchCount > 0) {
        wordCounts[language.code] = matchCount;
      }
    }

    if (wordCounts.isEmpty) return 'en-US';

    String bestLanguage = 'en-US';
    int bestCount = 0;

    for (final entry in wordCounts.entries) {
      if (entry.value > bestCount) {
        bestCount = entry.value;
        bestLanguage = entry.key;
      }
    }

    return bestLanguage;
  }

  double getConfidence(String languageCode) {
    return _confidenceCache[languageCode] ?? 0.85;
  }

  List<String> getAlternativeLanguages(String text, {int limit = 3}) {
    final alternatives = <String, int>{};

    for (final language in kAllLanguages) {
      if (language.code == 'en-US' || language.code == 'en-GB') continue;

      final patterns = _getLanguagePatterns(language.code);
      int matchCount = 0;

      for (final pattern in patterns) {
        if (text.toLowerCase().contains(pattern.toLowerCase())) {
          matchCount++;
        }
      }

      if (matchCount > 0) {
        alternatives[language.code] = matchCount;
      }
    }

    final sorted = alternatives.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => e.key).toList();
  }

  LanguageModel? getLanguageModel(String code) {
    for (final language in kAllLanguages) {
      if (language.code == code) {
        return language;
      }
    }
    return null;
  }

  List<LanguageModel> getAllLanguages() {
    return kAllLanguages;
  }

  List<LanguageModel> getLanguagesByGroup(LanguageGroup group) {
    return kAllLanguages.where((l) => l.group == group).toList();
  }

  void clearCache() {
    _confidenceCache.clear();
  }
}
