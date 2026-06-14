import '../models/language_model.dart';
import '../models/trigger_word_configuration.dart';
import '../constants/language_constants.dart';

class TriggerWordDetector {
  final Map<String, List<TriggerWordConfiguration>> _triggerCache = {};
  final double _similarityThreshold;

  TriggerWordDetector({
    double similarityThreshold = 0.75,
    bool cacheEnabled = true,
  }) : _similarityThreshold = similarityThreshold;

  void initialize() {
    for (final language in kAllLanguages) {
      _loadTriggerWordsForLanguage(language);
    }
  }

  void _loadTriggerWordsForLanguage(LanguageModel language) {
    final endOfThought = TriggerWordConfiguration(
      triggerWord: language.endOfThoughtTrigger,
      variants: language.endOfThoughtVariants,
      language: language.code,
      type: TriggerWordType.endOfThought,
      confidenceThreshold: _similarityThreshold,
      pauseBeforeTrigger: 300,
      description: 'Trigger word to finish speaking',
    );

    final exit = TriggerWordConfiguration(
      triggerWord: language.exitTrigger,
      variants: language.exitTriggerVariants,
      language: language.code,
      type: TriggerWordType.exit,
      confidenceThreshold: _similarityThreshold,
      pauseBeforeTrigger: 300,
      description: 'Trigger word to exit app',
    );

    _triggerCache[language.code] = [endOfThought, exit];
  }

  TriggerWordConfiguration? detectTriggerWord(String text) {
    if (text.isEmpty) return null;

    final normalizedText = _normalizeText(text);
    final words = normalizedText.split(RegExp(r'\s+'));

    if (words.isEmpty) return null;

    final lastWord = words.last;
    final lastTwoWords =
        words.length >= 2 ? '${words[words.length - 2]} ${words.last}' : null;

    TriggerWordConfiguration? bestMatch;
    double bestSimilarity = 0.0;

    for (final languageCode in _triggerCache.keys) {
      final configs = _triggerCache[languageCode] ?? [];

      for (final config in configs) {
        if (_matchesTriggerWord(lastWord, config)) {
          final similarity = config.calculateSimilarity(lastWord);
          if (similarity > bestSimilarity &&
              similarity >= _similarityThreshold) {
            bestSimilarity = similarity;
            bestMatch = config;
          }
        }

        if (lastTwoWords != null && _matchesTriggerWord(lastTwoWords, config)) {
          final similarity = config.calculateSimilarity(lastTwoWords);
          if (similarity > bestSimilarity &&
              similarity >= _similarityThreshold) {
            bestSimilarity = similarity;
            bestMatch = config;
          }
        }

        for (final variant in config.variants) {
          final normalizedVariant = _normalizeText(variant);
          if (_matchesTriggerWord(lastWord, normalizedVariant) ||
              (lastTwoWords != null &&
                  _matchesTriggerWord(lastTwoWords, normalizedVariant))) {
            final similarity = config.calculateSimilarity(lastWord);
            if (similarity > bestSimilarity) {
              bestSimilarity = similarity;
              bestMatch = config;
            }
          }
        }
      }
    }

    return bestMatch;
  }

  bool _matchesTriggerWord(String input, dynamic trigger) {
    final triggerWord = trigger is String
        ? trigger
        : (trigger as TriggerWordConfiguration).triggerWord;
    final normalizedInput = input.toLowerCase().trim();
    final normalizedTrigger = triggerWord.toLowerCase().trim();

    return normalizedInput == normalizedTrigger ||
        normalizedInput.contains(normalizedTrigger) ||
        normalizedTrigger.contains(normalizedInput);
  }

  List<TriggerWordConfiguration> getTriggerWordsForLanguage(
      String languageCode) {
    return _triggerCache[languageCode] ?? [];
  }

  List<TriggerWordConfiguration> getTriggerWordsByType(TriggerWordType type) {
    final results = <TriggerWordConfiguration>[];
    for (final configs in _triggerCache.values) {
      results.addAll(configs.where((c) => c.type == type));
    }
    return results;
  }

  bool isTriggerWord(String word, String? languageCode) {
    final normalizedWord = _normalizeText(word);

    if (languageCode != null && _triggerCache.containsKey(languageCode)) {
      for (final config in _triggerCache[languageCode]!) {
        if (_matchesTriggerWord(normalizedWord, config)) {
          return true;
        }
      }
    }

    for (final configs in _triggerCache.values) {
      for (final config in configs) {
        if (_matchesTriggerWord(normalizedWord, config)) {
          return true;
        }
      }
    }

    return false;
  }

  Map<String, List<TriggerWordConfiguration>> getAllTriggerWords() {
    return Map.from(_triggerCache);
  }

  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(
            RegExp(
                r'[^\w\s\u0900-\u097F\u0980-\u09FF\u0A00-\u0A7F\u0A80-\u0AFF\u0B00-\u0B7F\u0B80-\u0BFF\u0C00-\u0C7F\u0C80-\u0CFF\u0D00-\u0D7F]'),
            '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  double calculateFuzzySimilarity(String word1, String word2) {
    final normalized1 = _normalizeText(word1);
    final normalized2 = _normalizeText(word2);
    return _levenshteinSimilarity(normalized1, normalized2);
  }

  double _levenshteinSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a == b) return 1.0;

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
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    final distance = matrix[b.length][a.length];
    final maxLength = a.length > b.length ? a.length : b.length;
    return 1.0 - (distance / maxLength);
  }

  TriggerWordType? detectTriggerType(String text) {
    final config = detectTriggerWord(text);
    return config?.type;
  }

  bool isEndOfThoughtTrigger(String text) {
    final type = detectTriggerType(text);
    return type == TriggerWordType.endOfThought;
  }

  bool isExitTrigger(String text) {
    final type = detectTriggerType(text);
    return type == TriggerWordType.exit;
  }

  Map<String, dynamic> getTriggerWordsSummary() {
    final summary = <String, dynamic>{};

    for (final entry in _triggerCache.entries) {
      summary[entry.key] = {
        'endOfThought': entry.value
            .firstWhere((c) => c.type == TriggerWordType.endOfThought,
                orElse: () => entry.value.first)
            .triggerWord,
        'exit': entry.value
            .firstWhere((c) => c.type == TriggerWordType.exit,
                orElse: () => entry.value.last)
            .triggerWord,
      };
    }

    return summary;
  }

  void clearCache() {
    _triggerCache.clear();
  }

  int get supportedLanguageCount => _triggerCache.length;
}
