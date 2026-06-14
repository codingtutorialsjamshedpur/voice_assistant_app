import '../models/language_model.dart';

class LanguagePreferenceState {
  final LanguageModel preferredLanguage;
  final String? inputLanguage;
  final List<String> lastUsedLanguages;
  final DateTime preferenceTimestamp;
  final Map<String, int> languageUsageCount;

  const LanguagePreferenceState({
    required this.preferredLanguage,
    this.inputLanguage,
    this.lastUsedLanguages = const [],
    required this.preferenceTimestamp,
    this.languageUsageCount = const {},
  });

  factory LanguagePreferenceState.initial() {
    return LanguagePreferenceState(
      preferredLanguage: _getDefaultLanguage(),
      preferenceTimestamp: DateTime.now(),
      lastUsedLanguages: [],
      languageUsageCount: {},
    );
  }

  static LanguageModel _getDefaultLanguage() {
    return const LanguageModel(
      code: 'en-US',
      name: 'English (US)',
      nativeName: 'English (US)',
      flag: '🇺🇸',
      group: LanguageGroup.main,
      ttsEngine: TTSEngine.flutterTts,
      sttLocale: 'en-US',
      voices: [],
    );
  }

  LanguagePreferenceState copyWith({
    LanguageModel? preferredLanguage,
    String? inputLanguage,
    List<String>? lastUsedLanguages,
    DateTime? preferenceTimestamp,
    Map<String, int>? languageUsageCount,
  }) {
    return LanguagePreferenceState(
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      inputLanguage: inputLanguage ?? this.inputLanguage,
      lastUsedLanguages: lastUsedLanguages ?? this.lastUsedLanguages,
      preferenceTimestamp: preferenceTimestamp ?? this.preferenceTimestamp,
      languageUsageCount: languageUsageCount ?? this.languageUsageCount,
    );
  }

  LanguagePreferenceState updatePreferredLanguage(LanguageModel language) {
    final updatedUsageCount = Map<String, int>.from(languageUsageCount);
    updatedUsageCount[language.code] =
        (updatedUsageCount[language.code] ?? 0) + 1;

    final updatedLastUsed = [
      language.code,
      ...lastUsedLanguages.where((l) => l != language.code)
    ].take(5).toList();

    return LanguagePreferenceState(
      preferredLanguage: language,
      inputLanguage: inputLanguage,
      lastUsedLanguages: updatedLastUsed,
      preferenceTimestamp: DateTime.now(),
      languageUsageCount: updatedUsageCount,
    );
  }

  LanguagePreferenceState updateInputLanguage(String language) {
    return LanguagePreferenceState(
      preferredLanguage: preferredLanguage,
      inputLanguage: language,
      lastUsedLanguages: lastUsedLanguages,
      preferenceTimestamp: preferenceTimestamp,
      languageUsageCount: languageUsageCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preferredLanguageCode': preferredLanguage.code,
      'inputLanguage': inputLanguage,
      'lastUsedLanguages': lastUsedLanguages,
      'preferenceTimestamp': preferenceTimestamp.toIso8601String(),
      'languageUsageCount': languageUsageCount,
    };
  }

  factory LanguagePreferenceState.fromJson(Map<String, dynamic> json) {
    return LanguagePreferenceState(
      preferredLanguage: _getDefaultLanguage(),
      inputLanguage: json['inputLanguage'] as String?,
      lastUsedLanguages: List<String>.from(json['lastUsedLanguages'] ?? []),
      preferenceTimestamp:
          DateTime.parse(json['preferenceTimestamp'] as String),
      languageUsageCount:
          Map<String, int>.from(json['languageUsageCount'] ?? {}),
    );
  }

  @override
  String toString() {
    return 'LanguagePreferenceState(preferredLanguage: ${preferredLanguage.code}, '
        'inputLanguage: $inputLanguage, lastUsed: $lastUsedLanguages)';
  }
}
