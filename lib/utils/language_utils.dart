import '../models/language_model.dart';
import '../constants/language_constants.dart';

class LanguageUtils {
  static String languageCodeToSTTLocale(String languageCode) {
    const localeMap = {
      'hi': 'hi-IN',
      'en-US': 'en-US',
      'en-GB': 'en-GB',
      'bn': 'bn-IN',
      'pa': 'pa-IN',
      'ta': 'ta-IN',
      'te': 'te-IN',
      'kn': 'kn-IN',
      'ml': 'ml-IN',
      'gu': 'gu-IN',
      'mr': 'mr-IN',
      'ur': 'ur-IN',
      'or': 'or-IN',
      'as': 'as-IN',
      'ne': 'ne-NP',
      'si': 'si-LK',
      'fr': 'fr-FR',
      'de': 'de-DE',
      'es': 'es-ES',
      'it': 'it-IT',
      'pt-BR': 'pt-BR',
      'ru': 'ru-RU',
      'zh': 'zh-CN',
      'ja': 'ja-JP',
      'ko': 'ko-KR',
      'ar': 'ar-SA',
    };
    return localeMap[languageCode] ?? 'en-US';
  }

  static LanguageModel? getLanguageByCode(String code) {
    for (final lang in kAllLanguages) {
      if (lang.code == code) return lang;
    }
    return null;
  }

  static List<LanguageModel> getLanguagesByGroup(LanguageGroup group) {
    return kAllLanguages.where((l) => l.group == group).toList();
  }

  static List<LanguageModel> getMainLanguages() {
    return getLanguagesByGroup(LanguageGroup.main);
  }

  static List<LanguageModel> getNativeIndianLanguages() {
    return getLanguagesByGroup(LanguageGroup.nativeIndian);
  }

  static List<LanguageModel> getInternationalLanguages() {
    return getLanguagesByGroup(LanguageGroup.international);
  }

  static String getTriggerWordForLanguage(
      String languageCode, TriggerWordType type) {
    final lang = getLanguageByCode(languageCode);
    if (lang == null) {
      return type == TriggerWordType.endOfThought ? 'done' : 'goodbye';
    }

    return type == TriggerWordType.endOfThought
        ? lang.endOfThoughtTrigger
        : lang.exitTrigger;
  }

  static List<String> getTriggerWordsForType(TriggerWordType type) {
    final words = <String>[];
    for (final lang in kAllLanguages) {
      final word = type == TriggerWordType.endOfThought
          ? lang.endOfThoughtTrigger
          : lang.exitTrigger;
      if (word.isNotEmpty && !words.contains(word)) {
        words.add(word);
      }
    }
    return words;
  }

  static String normalizeText(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\s\u0900-\u097F\u0980-\u09FF]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String removeDiacritics(String text) {
    const diacritics = 'àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ';
    const replacements = 'aaaaaaaceeeeiiiidnoooooouuuuyby';

    String result = text.toLowerCase();
    for (int i = 0; i < diacritics.length; i++) {
      result = result.replaceAll(diacritics[i], replacements[i]);
    }
    return result;
  }

  static String romanizeText(String text) {
    const devanagariToRoman = {
      'अ': 'a',
      'आ': 'aa',
      'इ': 'i',
      'ई': 'ee',
      'उ': 'u',
      'ऊ': 'oo',
      'ए': 'e',
      'ऐ': 'ai',
      'ओ': 'o',
      'औ': 'au',
      'क': 'k',
      'ख': 'kh',
      'ग': 'g',
      'घ': 'gh',
      'ङ': 'n',
      'च': 'ch',
      'छ': 'chh',
      'ज': 'j',
      'झ': 'jh',
      'ञ': 'n',
      'ट': 't',
      'ठ': 'th',
      'ड': 'd',
      'ढ': 'dh',
      'ण': 'n',
      'त': 't',
      'थ': 'th',
      'द': 'd',
      'ध': 'dh',
      'न': 'n',
      'प': 'p',
      'फ': 'ph',
      'ब': 'b',
      'भ': 'bh',
      'म': 'm',
      'य': 'y',
      'र': 'r',
      'ल': 'l',
      'व': 'v',
      'श': 'sh',
      'ष': 'sh',
      'स': 's',
      'ह': 'h',
      'ा': 'aa',
      'ि': 'i',
      'ी': 'ee',
      'ु': 'u',
      'ू': 'oo',
      'े': 'e',
      'ै': 'ai',
      'ो': 'o',
      'ौ': 'au',
      'ं': 'n',
      'ः': 'h',
    };

    String result = '';
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      result += devanagariToRoman[char] ?? char;
    }
    return result;
  }

  static bool isSameLangFamily(String lang1, String lang2) {
    const families = {
      'indoAryan': ['hi', 'bn', 'gu', 'mr', 'pa', 'as', 'or', 'ur', 'sa'],
      'dravidian': ['ta', 'te', 'kn', 'ml'],
      'germanic': ['en-US', 'en-GB', 'de', 'nl'],
      'romance': ['fr', 'it', 'es', 'pt-BR'],
      'slavic': ['ru', 'uk', 'pl', 'cs'],
      'eastAsian': ['zh', 'ja', 'ko', 'vi'],
    };

    for (final family in families.entries) {
      if (family.value.contains(lang1) && family.value.contains(lang2)) {
        return true;
      }
    }
    return false;
  }

  static String getLanguageDisplayName(String code, {bool useNative = false}) {
    final lang = getLanguageByCode(code);
    if (lang == null) return code;
    return useNative ? lang.nativeName : lang.name;
  }

  static bool isSupported(String languageCode) {
    return kAllLanguages.any((l) => l.code == languageCode);
  }

  static int getSupportedLanguageCount() {
    return kAllLanguages.length;
  }

  static List<String> getAllLanguageCodes() {
    return kAllLanguages.map((l) => l.code).toList();
  }

  static Map<String, String> getLanguageCodeToNameMap(
      {bool useNative = false}) {
    final map = <String, String>{};
    for (final lang in kAllLanguages) {
      map[lang.code] = useNative ? lang.nativeName : lang.name;
    }
    return map;
  }

  static double calculateTextSimilarity(String text1, String text2) {
    if (text1.isEmpty || text2.isEmpty) return 0.0;
    if (text1 == text2) return 1.0;

    final normalized1 = normalizeText(text1);
    final normalized2 = normalizeText(text2);

    final distance = _levenshteinDistance(normalized1, normalized2);
    final maxLength = normalized1.length > normalized2.length
        ? normalized1.length
        : normalized2.length;

    return 1.0 - (distance / maxLength);
  }

  static int _levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final matrix =
        List.generate(b.length + 1, (i) => List.filled(a.length + 1, 0));

    for (int i = 0; i <= a.length; i++) {
      matrix[0][i] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[j][0] = j;
    }

    for (int j = 1; j <= b.length; j++) {
      for (int i = 1; i <= a.length; i++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[j][i] = [
          matrix[j][i - 1] + 1,
          matrix[j - 1][i] + 1,
          matrix[j - 1][i - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }

    return matrix[b.length][a.length];
  }

  static List<LanguageModel> searchLanguages(String query) {
    if (query.isEmpty) return kAllLanguages;

    final lowerQuery = query.toLowerCase();
    return kAllLanguages.where((lang) {
      return lang.name.toLowerCase().contains(lowerQuery) ||
          lang.nativeName.contains(query) ||
          lang.code.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  static List<LanguageModel> getRecommendedLanguages() {
    return [
      getLanguageByCode('hi')!,
      getLanguageByCode('en-US')!,
      getLanguageByCode('bn')!,
      getLanguageByCode('ta')!,
    ];
  }
}
