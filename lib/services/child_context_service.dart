/// ═══════════════════════════════════════════════════════════════
/// Child Context Service  (Task 3.1)
/// ═══════════════════════════════════════════════════════════════
///
/// Maintains a live [ChildProfile] that is updated after every query.
/// Coordinates GradeLevelDetector, LearningStyleDetector, and
/// VocabularyTracker to build an evolving understanding of the child.
///
/// Stored in SharedPreferences (JSON) for cross-session persistence.
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'grade_level_detector_service.dart';
import 'learning_style_detector_service.dart';
import 'vocabulary_tracker_service.dart';
import 'response_level_strategy_service.dart';

class ChildContextService extends GetxService {
  late GradeLevelDetectorService _gradeDetector;
  late LearningStyleDetectorService _styleDetector;
  late VocabularyTrackerService _vocabTracker;

  static const _prefsKey = 'child_context_profile';

  /// Observable child profile updated on every query.
  final Rx<ChildProfile> currentChildProfile =
      Rx<ChildProfile>(ChildProfile.defaultProfile());

  @override
  void onInit() {
    super.onInit();
    _gradeDetector = Get.find<GradeLevelDetectorService>();
    _styleDetector = Get.find<LearningStyleDetectorService>();
    _vocabTracker = Get.find<VocabularyTrackerService>();
    _loadProfile();
    debugPrint('✅ [ChildContextService] Initialized');
  }

  // ── Public API ────────────────────────────────────────────────────────

  /// Update the child profile based on the latest [query].
  /// Called after every user query.
  Future<void> updateProfile(String query) async {
    final recentQueries = _getRecentQueries();

    // Detect grade level
    final grade = _gradeDetector.detectGradeLevel(query, recentQueries);

    // Detect learning style
    _styleDetector.trackQuery(query);
    final style = _styleDetector.detectStyle();

    // Update vocabulary
    _vocabTracker.trackQuery(query);

    final old = currentChildProfile.value;
    final updated = old.copyWith(
      detectedGradeLevel: grade,
      learningStyle: style,
      vocabularyUsed: {...old.vocabularyUsed, ..._vocabTracker.recentWords},
      totalQuestionsAsked: old.totalQuestionsAsked + 1,
    );

    currentChildProfile.value = updated;
    await _saveProfile(updated);

    debugPrint(
        '🧩 [ChildContext] Grade=$grade Style=$style Questions=${updated.totalQuestionsAsked}');
  }

  // ── Private ───────────────────────────────────────────────────────────

  List<String> _getRecentQueries() {
    // Delegate to vocab tracker's rolling window
    return _vocabTracker.recentQueries;
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        currentChildProfile.value =
            ChildProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        debugPrint(
            '📂 [ChildContext] Restored profile: grade=${currentChildProfile.value.detectedGradeLevel}');
      }
    } catch (e) {
      debugPrint('⚠️ [ChildContext] Load failed: $e');
    }
  }

  Future<void> _saveProfile(ChildProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(profile.toJson()));
    } catch (e) {
      debugPrint('⚠️ [ChildContext] Save failed: $e');
    }
  }
}
