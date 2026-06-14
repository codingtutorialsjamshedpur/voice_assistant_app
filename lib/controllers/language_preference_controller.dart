import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/language_model.dart';
import '../constants/language_constants.dart';

class LanguagePreferenceController extends GetxController {
  late SharedPreferences _prefs;
  final RxnString savedLanguageCode = RxnString();
  final Rxn<LanguageModel> preferredLanguage = Rxn<LanguageModel>();
  final RxList<String> lastUsedLanguages = <String>[].obs;
  final RxMap<String, int> languageUsageCount = <String, int>{}.obs;

  static const String _languageKey = 'preferred_language';
  static const String _lastUsedKey = 'last_used_languages';
  static const String _usageCountKey = 'language_usage_count';

  @override
  void onInit() {
    super.onInit();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();

    savedLanguageCode.value = _prefs.getString(_languageKey);

    final lastUsed = _prefs.getStringList(_lastUsedKey);
    if (lastUsed != null) {
      lastUsedLanguages.assignAll(lastUsed);
    }

    final usageCount = _prefs.getString(_usageCountKey);
    if (usageCount != null) {
      final parts = usageCount.split(',');
      for (final part in parts) {
        if (part.contains(':')) {
          final kv = part.split(':');
          languageUsageCount[kv[0]] = int.tryParse(kv[1]) ?? 0;
        }
      }
    }

    if (savedLanguageCode.value != null) {
      preferredLanguage.value = _getLanguageByCode(savedLanguageCode.value!);
    }
  }

  LanguageModel? _getLanguageByCode(String code) {
    for (final lang in kAllLanguages) {
      if (lang.code == code) return lang;
    }
    return null;
  }

  Future<void> saveLanguagePreference(LanguageModel language) async {
    preferredLanguage.value = language;
    savedLanguageCode.value = language.code;

    await _prefs.setString(_languageKey, language.code);

    final updatedLastUsed = [
      language.code,
      ...lastUsedLanguages.where((l) => l != language.code)
    ].take(5).toList();
    lastUsedLanguages.assignAll(updatedLastUsed);
    await _prefs.setStringList(_lastUsedKey, updatedLastUsed);

    final newCount = (languageUsageCount[language.code] ?? 0) + 1;
    languageUsageCount[language.code] = newCount;
    await _saveUsageCount();

    debugPrint('💾 Saved language preference: ${language.name}');
  }

  Future<void> _saveUsageCount() async {
    final parts = <String>[];
    languageUsageCount.forEach((key, value) {
      parts.add('$key:$value');
    });
    await _prefs.setString(_usageCountKey, parts.join(','));
  }

  Future<void> clearPreferences() async {
    await _prefs.remove(_languageKey);
    await _prefs.remove(_lastUsedKey);
    await _prefs.remove(_usageCountKey);
    savedLanguageCode.value = null;
    preferredLanguage.value = null;
    lastUsedLanguages.clear();
    languageUsageCount.clear();
  }

  bool get hasSavedLanguage => savedLanguageCode.value != null;

  List<LanguageModel> getTopLanguages({int limit = 3}) {
    final sorted = languageUsageCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .take(limit)
        .map((e) => _getLanguageByCode(e.key))
        .whereType<LanguageModel>()
        .toList();
  }

  String get mostUsedLanguageCode {
    if (languageUsageCount.isEmpty) return 'hi';

    final sorted = languageUsageCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.isNotEmpty ? sorted.first.key : 'hi';
  }
}
