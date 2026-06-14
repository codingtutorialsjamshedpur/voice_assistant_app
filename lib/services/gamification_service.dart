/// ═══════════════════════════════════════════════════════════════
/// Gamification Service  (Task 6.2)
/// ═══════════════════════════════════════════════════════════════
///
/// Manages XP, levels, and achievement badges for the voice assistant.
///
/// XP Level System:
///   Level 1  0–100    Curious Cub 🐻
///   Level 2  100–300  Explorer 🔭
///   Level 3  300–600  Thinker 💡
///   Level 4  600–1000 Scholar 📚
///   Level 5  1000+    Mastermind 🧠
///
/// All data persisted in SharedPreferences (JSON).
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Achievement model
// ---------------------------------------------------------------------------

class Achievement {
  final String id;
  final String badge; // emoji
  final String title;
  final String trigger;
  final int xp;
  final bool unlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.badge,
    required this.title,
    required this.trigger,
    required this.xp,
    this.unlocked = false,
    this.unlockedAt,
  });

  Achievement copyWith({bool? unlocked, DateTime? unlockedAt}) => Achievement(
        id: id,
        badge: badge,
        title: title,
        trigger: trigger,
        xp: xp,
        unlocked: unlocked ?? this.unlocked,
        unlockedAt: unlockedAt ?? this.unlockedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'badge': badge,
        'title': title,
        'trigger': trigger,
        'xp': xp,
        'unlocked': unlocked,
        'unlockedAt': unlockedAt?.toIso8601String(),
      };

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'] as String,
        badge: json['badge'] as String,
        title: json['title'] as String,
        trigger: json['trigger'] as String,
        xp: json['xp'] as int,
        unlocked: json['unlocked'] as bool? ?? false,
        unlockedAt: json['unlockedAt'] != null
            ? DateTime.parse(json['unlockedAt'] as String)
            : null,
      );
}

// ---------------------------------------------------------------------------
// GamificationService
// ---------------------------------------------------------------------------

class GamificationService extends GetxService {
  static const _prefsKey = 'gamification_data';

  final RxInt totalXP = 0.obs;
  final RxInt currentLevel = 1.obs;
  final RxList<Achievement> achievements = <Achievement>[].obs;
  final RxInt totalQuestions = 0.obs;
  final RxInt sessionQuestions = 0.obs;
  final RxInt consecutiveCorrectQuizzes = 0.obs;
  final RxSet<String> languagesUsed = <String>{}.obs;
  final RxInt storyRequests = 0.obs;
  final RxInt consecutiveDays = 0.obs;
  DateTime? _lastUsedDate;

  /// Callback that the caller can override to speak an achievement unlock.
  void Function(String text)? onAchievementUnlocked;

  // ── Achievement definitions ─────────────────────────────────────────────
  static final _definitions = [
    const Achievement(
      id: 'first_question',
      badge: '🌟',
      title: 'First Question',
      trigger: 'totalQuestionsAsked == 1',
      xp: 10,
    ),
    const Achievement(
      id: 'curiosity_cat',
      badge: '🐱',
      title: 'Curiosity Cat',
      trigger: '10 questions in one session',
      xp: 50,
    ),
    const Achievement(
      id: 'language_master',
      badge: '🌐',
      title: 'Language Master',
      trigger: 'Used all 3 languages',
      xp: 75,
    ),
    const Achievement(
      id: 'deep_thinker',
      badge: '🧠',
      title: 'Deep Thinker',
      trigger: '5+ complex questions (grade 6+ complexity)',
      xp: 100,
    ),
    const Achievement(
      id: 'quiz_champion',
      badge: '🏆',
      title: 'Quiz Champion',
      trigger: '80%+ on 5 consecutive quizzes',
      xp: 150,
    ),
    const Achievement(
      id: 'story_lover',
      badge: '📖',
      title: 'Story Lover',
      trigger: '10 story requests',
      xp: 60,
    ),
    const Achievement(
      id: 'daily_learner',
      badge: '📅',
      title: 'Daily Learner',
      trigger: '7 consecutive days of app use',
      xp: 200,
    ),
    const Achievement(
      id: 'night_owl',
      badge: '🦉',
      title: 'Night Owl',
      trigger: 'Questions asked after 9 PM',
      xp: 15,
    ),
    const Achievement(
      id: 'conversationalist',
      badge: '💬',
      title: 'Conversationalist',
      trigger: '30+ Q&As total',
      xp: 80,
    ),
  ];

  @override
  void onInit() {
    super.onInit();
    _initAchievements();
    _load();
    debugPrint('✅ [GamificationService] Initialized');
  }

  void _initAchievements() {
    if (achievements.isEmpty) {
      achievements.addAll(_definitions);
    }
  }

  // ── Public API ────────────────────────────────────────────────────────

  /// Award [amount] XP for [reason] and update the level.
  void awardXP(int amount, String reason) {
    totalXP.value += amount;
    final newLevel = getLevel();
    if (newLevel > currentLevel.value) {
      currentLevel.value = newLevel;
      final levelInfo = _levelInfo(newLevel);
      debugPrint(
          '🎉 [Gamification] Level up → $newLevel ${levelInfo['title']}');
      onAchievementUnlocked?.call(
          'Amazing! You just reached Level $newLevel: ${levelInfo['title']}!');
    }
    debugPrint(
        '⭐ [Gamification] +$amount XP ($reason) → total=${totalXP.value}');
    _save();
  }

  /// Returns current level 1–5 based on total XP.
  int getLevel() {
    if (totalXP.value >= 1000) return 5;
    if (totalXP.value >= 600) return 4;
    if (totalXP.value >= 300) return 3;
    if (totalXP.value >= 100) return 2;
    return 1;
  }

  /// Returns all unlocked achievements.
  List<Achievement> getUnlockedAchievements() =>
      achievements.where((a) => a.unlocked).toList();

  /// Check and award any newly earned achievements.
  /// Call this after every query.
  void checkAndAwardAchievements({
    int? gradeLevel,
    String? language,
    bool isStoryRequest = false,
    bool isNightTime = false,
  }) {
    totalQuestions.value++;
    sessionQuestions.value++;

    // Update language set
    if (language != null && language.isNotEmpty) {
      languagesUsed.add(language);
    }

    // Story requests
    if (isStoryRequest) storyRequests.value++;

    // Night owl check
    final hour = DateTime.now().hour;
    if (hour >= 21 || hour < 4) {
      _tryUnlock('night_owl');
    }

    // Milestone checks
    if (totalQuestions.value == 1) _tryUnlock('first_question');
    if (sessionQuestions.value >= 10) _tryUnlock('curiosity_cat');
    if (languagesUsed.length >= 3) _tryUnlock('language_master');
    if (totalQuestions.value >= 30) _tryUnlock('conversationalist');
    if (storyRequests.value >= 10) _tryUnlock('story_lover');

    // Track consecutive days
    final today = DateTime.now();
    if (_lastUsedDate != null) {
      final diff = today
          .difference(DateTime(
              _lastUsedDate!.year, _lastUsedDate!.month, _lastUsedDate!.day))
          .inDays;
      if (diff == 1) {
        consecutiveDays.value++;
        if (consecutiveDays.value >= 7) _tryUnlock('daily_learner');
      } else if (diff > 1) {
        consecutiveDays.value = 1; // streak broken
      }
    }
    _lastUsedDate = today;

    _save();
  }

  /// Record a quiz result. Award XP and check quiz-champion achievement.
  void recordQuizResult(bool isCorrect) {
    if (isCorrect) {
      awardXP(20, 'Correct quiz answer');
      consecutiveCorrectQuizzes.value++;
      if (consecutiveCorrectQuizzes.value >= 5) {
        _tryUnlock('quiz_champion');
      }
    } else {
      consecutiveCorrectQuizzes.value = 0;
    }
    _save();
  }

  // ── Level info ────────────────────────────────────────────────────────

  Map<String, dynamic> _levelInfo(int level) {
    const info = {
      1: {'title': 'Curious Cub 🐻', 'range': '0–100'},
      2: {'title': 'Explorer 🔭', 'range': '100–300'},
      3: {'title': 'Thinker 💡', 'range': '300–600'},
      4: {'title': 'Scholar 📚', 'range': '600–1000'},
      5: {'title': 'Mastermind 🧠', 'range': '1000+'},
    };
    return info[level] ?? {'title': 'Curious Cub 🐻', 'range': '0–100'};
  }

  // ── Private ───────────────────────────────────────────────────────────

  void _tryUnlock(String id) {
    final idx = achievements.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    final achievement = achievements[idx];
    if (achievement.unlocked) return;

    final unlocked = achievement.copyWith(
      unlocked: true,
      unlockedAt: DateTime.now(),
    );
    achievements[idx] = unlocked;

    awardXP(achievement.xp, 'Achievement: ${achievement.title}');

    onAchievementUnlocked?.call(
        'Wow! You just earned the ${achievement.title} badge! ${achievement.badge}');

    debugPrint('🏅 [Gamification] Achievement unlocked: ${achievement.title}');
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey,
          jsonEncode({
            'totalXP': totalXP.value,
            'totalQuestions': totalQuestions.value,
            'sessionQuestions': sessionQuestions.value,
            'consecutiveCorrectQuizzes': consecutiveCorrectQuizzes.value,
            'languagesUsed': languagesUsed.toList(),
            'storyRequests': storyRequests.value,
            'consecutiveDays': consecutiveDays.value,
            'lastUsedDate': _lastUsedDate?.toIso8601String(),
            'achievements': achievements.map((a) => a.toJson()).toList(),
          }));
    } catch (e) {
      debugPrint('⚠️ [Gamification] Save failed: $e');
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      totalXP.value = data['totalXP'] as int? ?? 0;
      totalQuestions.value = data['totalQuestions'] as int? ?? 0;
      sessionQuestions.value = 0; // reset per session
      consecutiveCorrectQuizzes.value =
          data['consecutiveCorrectQuizzes'] as int? ?? 0;
      languagesUsed.addAll(
          (data['languagesUsed'] as List<dynamic>?)?.cast<String>() ?? []);
      storyRequests.value = data['storyRequests'] as int? ?? 0;
      consecutiveDays.value = data['consecutiveDays'] as int? ?? 0;
      if (data['lastUsedDate'] != null) {
        _lastUsedDate = DateTime.parse(data['lastUsedDate'] as String);
      }

      // Merge saved unlock states into definition list
      final savedAchievements = (data['achievements'] as List<dynamic>?)
              ?.map((e) => Achievement.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      achievements.clear();
      achievements.addAll(_definitions.map((def) {
        final saved = savedAchievements.firstWhere((a) => a.id == def.id,
            orElse: () => def);
        return saved;
      }));

      currentLevel.value = getLevel();
      debugPrint(
          '📂 [Gamification] Restored: XP=${totalXP.value} Level=${currentLevel.value}');
    } catch (e) {
      debugPrint('⚠️ [Gamification] Load failed: $e');
      _initAchievements();
    }
  }
}
