/// ════════════════════════════════════════════════════════════════
/// User Profile Service (Age Adaptation) — Adapts AI responses
/// ════════════════════════════════════════════════════════════════
///
/// Determines the user's age group and adapts AI response
/// complexity accordingly. Integrates with the AI system prompt.
///
/// Age Groups:
///   Beginner  (5-12)  : Simple, step-by-step language
///   Intermediate (13-17): Moderate explanation depth
///   Advanced (18+)    : Direct, efficient responses
///
/// Mapped to task.md Task 4.4: Implement User Age Adaptation
/// ════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Age groups for response adaptation
enum AgeGroup {
  child, // 5–12 years
  teen, // 13–17 years
  adult, // 18+ years
}

class UserProfileService extends GetxService {
  static const String _ageGroupKey = 'user_age_group';

  // ── Observable State ──────────────────────────────────────────
  final currentAgeGroup = AgeGroup.adult.obs;
  final isProfileSet = false.obs;

  // ── Lifecycle ─────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _loadProfile();
  }

  // ═══════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════

  /// Set the user's age group
  Future<void> setAgeGroup(AgeGroup ageGroup) async {
    currentAgeGroup.value = ageGroup;
    isProfileSet.value = true;
    await _saveProfile(ageGroup);
    debugPrint('👤 [UserProfileService] Age group set → ${ageGroup.name}');
  }

  /// Set age group from an actual age number
  Future<void> setAge(int age) async {
    if (age <= 12) {
      await setAgeGroup(AgeGroup.child);
    } else if (age <= 17) {
      await setAgeGroup(AgeGroup.teen);
    } else {
      await setAgeGroup(AgeGroup.adult);
    }
  }

  /// Human-readable label for the current age group
  String get ageGroupLabel {
    switch (currentAgeGroup.value) {
      case AgeGroup.child:
        return 'Child (5–12)';
      case AgeGroup.teen:
        return 'Teen (13–17)';
      case AgeGroup.adult:
        return 'Adult (18+)';
    }
  }

  /// Returns the system prompt instructions for response adaptation
  String buildAgeAdaptationPrompt() {
    switch (currentAgeGroup.value) {
      case AgeGroup.child:
        return _childPrompt;
      case AgeGroup.teen:
        return _teenPrompt;
      case AgeGroup.adult:
        return _adultPrompt;
    }
  }

  /// Max word count recommendation for TTS responses
  int get maxResponseWords {
    switch (currentAgeGroup.value) {
      case AgeGroup.child:
        return 50;
      case AgeGroup.teen:
        return 100;
      case AgeGroup.adult:
        return 150;
    }
  }

  /// Whether to use simple vocabulary
  bool get useSimpleVocabulary {
    return currentAgeGroup.value == AgeGroup.child;
  }

  /// Whether to include explanatory examples
  bool get includeExamples {
    return currentAgeGroup.value != AgeGroup.adult;
  }

  // ═══════════════════════════════════════════════════════════════
  // PROMPT TEMPLATES
  // ═══════════════════════════════════════════════════════════════

  static const String _childPrompt = '''
AGE GROUP: Child (5-12 years)
RESPONSE RULES FOR THIS AGE:
- Use very simple, short sentences (max 50 words)
- Speak like a kind older sibling or teacher
- Use lots of encouragement ("Wah!", "Bahut achhe!", "Great job!")
- Avoid all technical terms — explain everything in the simplest possible way
- Use analogies with things kids understand (games, cartoons, school)
- Be playful and fun — add gentle humor when appropriate
- Step-by-step instructions only — never assume prior knowledge
- Do NOT use complex Hindi grammar — use simple everyday speech
''';

  static const String _teenPrompt = '''
AGE GROUP: Teen (13-17 years)
RESPONSE RULES FOR THIS AGE:
- Use moderate complexity — casual and friendly, not too formal
- Max 100 words per response
- It's okay to use slightly technical language with a brief explanation
- Be relatable and not patronizing — treat them as smart young adults
- Light humor is welcome — don't be overly formal or stiff
- Use examples from everyday teen life (phone, social media, school)
- Give clear step-by-step guidance but don't over-explain obvious things
''';

  static const String _adultPrompt = '''
AGE GROUP: Adult (18+ years)
RESPONSE RULES FOR THIS AGE:
- Be direct, clear, and efficient — no hand-holding needed
- Max 150 words per response
- Use professional but friendly language
- Technical terms are acceptable with minimal explanation
- Skip obvious steps — assume basic app literacy
- Give complete answers without being verbose
- Respect the user's time and intelligence
''';

  // ═══════════════════════════════════════════════════════════════
  // PERSISTENCE
  // ═══════════════════════════════════════════════════════════════

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_ageGroupKey);
      if (saved != null) {
        final group = AgeGroup.values.firstWhere(
          (g) => g.name == saved,
          orElse: () => AgeGroup.adult,
        );
        currentAgeGroup.value = group;
        isProfileSet.value = true;
        debugPrint('👤 [UserProfileService] Loaded age group → ${group.name}');
      }
    } catch (e) {
      debugPrint('⚠️ [UserProfileService] Failed to load profile: $e');
    }
  }

  Future<void> _saveProfile(AgeGroup group) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ageGroupKey, group.name);
    } catch (e) {
      debugPrint('⚠️ [UserProfileService] Failed to save profile: $e');
    }
  }
}
