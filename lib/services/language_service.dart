/// ════════════════════════════════════════════════════════════════
/// Language Service — User language preference detection
/// ════════════════════════════════════════════════════════════════
///
/// Detects and manages the user's preferred language for STT/TTS.
/// Supports Hindi, English, and Hinglish.
///
/// Mapped to task.md Task 4.3: Add Language Support
/// ════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/language_strings.dart';

class LanguageService extends GetxService {
  static const String _prefKey = 'ai_preferred_language';

  // ── Observable State ──────────────────────────────────────────
  // Default to HINDI for new users (Hindi-speaking audience)
  final currentLanguage = AssistantLanguage.hindi.obs;

  // ── Lifecycle ─────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _loadPreference();
  }

  // ═══════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════

  /// Switch to a specific language
  Future<void> setLanguage(AssistantLanguage lang) async {
    currentLanguage.value = lang;
    await _savePreference(lang);
    debugPrint('🌐 [LanguageService] Language set → ${lang.name}');
  }

  /// Cycle through available languages (Hindi → English → Hinglish → ...)
  Future<void> cycleLanguage() async {
    const langs = AssistantLanguage.values;
    final currentIndex = langs.indexOf(currentLanguage.value);
    final nextIndex = (currentIndex + 1) % langs.length;
    await setLanguage(langs[nextIndex]);
  }

  /// Get a localized string for the current language
  String get(Map<AssistantLanguage, String> strings) {
    return LanguageStrings.get(strings, language: currentLanguage.value);
  }

  /// Detect language from an STT locale string
  AssistantLanguage detectFromLocale(String locale) {
    return LanguageStrings.detectLanguage(locale);
  }

  /// Get the system prompt language instruction for the current language
  String buildLanguageInstruction() {
    return LanguageStrings.buildLanguageInstruction(currentLanguage.value);
  }

  /// Get the BCP-47 locale code for STT (speech recognition)
  String get sttLocale {
    switch (currentLanguage.value) {
      case AssistantLanguage.hindi:
        return 'hi-IN';
      case AssistantLanguage.english:
        return 'en-US';
      case AssistantLanguage.hinglish:
        return 'hi-IN'; // Hinglish uses Hindi STT as base
    }
  }

  /// Get the BCP-47 locale code for TTS (speech synthesis)
  String get ttsLocale {
    switch (currentLanguage.value) {
      case AssistantLanguage.hindi:
        return 'hi-IN';
      case AssistantLanguage.english:
        return 'en-US';
      case AssistantLanguage.hinglish:
        return 'hi-IN'; // Default to Hindi for Hinglish
    }
  }

  /// Human-readable name for the current language
  String get languageName {
    switch (currentLanguage.value) {
      case AssistantLanguage.hindi:
        return 'Hindi';
      case AssistantLanguage.english:
        return 'English';
      case AssistantLanguage.hinglish:
        return 'Hinglish';
    }
  }

  /// Flag emoji for the current language
  String get languageFlag {
    switch (currentLanguage.value) {
      case AssistantLanguage.hindi:
        return '🇮🇳';
      case AssistantLanguage.english:
        return '🇺🇸';
      case AssistantLanguage.hinglish:
        return '🇮🇳';
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // SMART DETECTION
  // ═══════════════════════════════════════════════════════════════

  /// Detect the likely language of a text input
  AssistantLanguage detectFromText(String text) {
    if (text.isEmpty) return currentLanguage.value;

    // Check for Devanagari script (Hindi)
    final devanagariRegex = RegExp(r'[\u0900-\u097F]');
    final hasDevanagari = devanagariRegex.hasMatch(text);
    if (hasDevanagari) return AssistantLanguage.hindi;

    // Common Hinglish keywords
    final hinglishWords = [
      'kya',
      'kaise',
      'kyun',
      'yeh',
      'woh',
      'hoon',
      'hai',
      'main',
      'aap',
      'tum',
      'mujhe',
      'batao',
      'bolo',
      'karo',
      'karo',
      'nahi',
      'haan',
      'theek',
      'accha',
      'bahut',
      'bada',
    ];
    final lowerText = text.toLowerCase();
    for (final word in hinglishWords) {
      if (lowerText.contains(word)) return AssistantLanguage.hinglish;
    }

    // Defaulting to language preference
    return currentLanguage.value;
  }

  // ═══════════════════════════════════════════════════════════════
  // PERSISTENCE
  // ═══════════════════════════════════════════════════════════════

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        final lang = AssistantLanguage.values.firstWhere(
          (l) => l.name == saved,
          orElse: () => AssistantLanguage.hinglish,
        );
        currentLanguage.value = lang;
        debugPrint('🌐 [LanguageService] Loaded preference → ${lang.name}');
      }
    } catch (e) {
      debugPrint('⚠️ [LanguageService] Failed to load preference: $e');
    }
  }

  Future<void> _savePreference(AssistantLanguage lang) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, lang.name);
    } catch (e) {
      debugPrint('⚠️ [LanguageService] Failed to save preference: $e');
    }
  }
}
