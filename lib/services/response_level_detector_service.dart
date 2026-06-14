/// ═══════════════════════════════════════════════════════════════
/// Response Level Detector Service
/// ═══════════════════════════════════════════════════════════════
///
/// Detects the appropriate [ResponseLevel] for a given user query
/// by combining four weighted signals:
///
///   1. Explicit keyword check  (weight 1.0 — always wins if present)
///   2. Profile preference      (weight 0.5)
///   3. Real-time query complexity (weight 0.4)
///   4. Historical trend        (weight 0.3)
///
/// Usage:
///   final level = await detector.detectResponseLevel(query);
///   final strategy = ResponseLevelStrategy.fromLevel(level);
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'input_analyzer_service.dart';
import 'response_level_strategy_service.dart';
import 'user_profiling_engine_service.dart';
import '../controllers/profile_controller.dart';

class ResponseLevelDetectorService extends GetxService {
  late InputAnalyzerService _inputAnalyzer;

  /// Cache of the last detected level for quick reads.
  final Rx<ResponseLevel> currentLevel =
      Rx<ResponseLevel>(ResponseLevel.intermediate);

  @override
  void onInit() {
    super.onInit();
    _inputAnalyzer = Get.find<InputAnalyzerService>();
    debugPrint('✅ [ResponseLevelDetector] Initialized');
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Detect the best [ResponseLevel] for [query].
  ///
  /// Evaluates all four signals and combines them via weighted scoring.
  Future<ResponseLevel> detectResponseLevel(String query) async {
    debugPrint(
        '🔍 [ResponseLevelDetector] Analyzing: "${query.length > 60 ? '${query.substring(0, 60)}...' : query}"');

    // ── Signal 1: Explicit keyword ─────────────────────────────────────────
    final ResponseLevel? explicitLevel = _checkExplicitKeywords(query);
    if (explicitLevel != null) {
      debugPrint(
          '  Signal 1 (Explicit keywords): ${explicitLevel.name} → WINS (weight 1.0)');
      currentLevel.value = explicitLevel;
      return explicitLevel;
    }
    debugPrint('  Signal 1 (Explicit keywords): none detected');

    // ── Signal 2: Profile preference ───────────────────────────────────────
    double profileScore = 0.5; // default: intermediate
    try {
      final profileCtrl = Get.find<ProfileController>();
      final anticipation =
          profileCtrl.userProfile.value.anticipation.toLowerCase();
      profileScore = _parseProfileAnticipation(anticipation);
      debugPrint('  Signal 2 (Profile preference): score=$profileScore');
    } catch (e) {
      debugPrint('  Signal 2 (Profile preference): unavailable — $e');
    }

    // ── Signal 3: Real-time query complexity ──────────────────────────────
    final inputSignals = _inputAnalyzer.analyzeQuery(query);
    final complexityScore = inputSignals.vocabularyComplexity;
    debugPrint(
        '  Signal 3 (Query complexity): score=${complexityScore.toStringAsFixed(2)}');

    // ── Signal 4: Historical trend ─────────────────────────────────────────
    double trendScore = 0.5;
    try {
      final profilingEngine = Get.find<UserProfilingEngineService>();
      final trendDir = profilingEngine.trendDirection.value;
      trendScore = _parseTrendDirection(trendDir);
      debugPrint(
          '  Signal 4 (Historical trend): trend=$trendDir score=$trendScore');
    } catch (e) {
      debugPrint('  Signal 4 (Historical trend): unavailable — $e');
    }

    // ── Combine signals ────────────────────────────────────────────────────
    final level = _combineSignals(profileScore, complexityScore, trendScore);
    debugPrint('  → Combined result: ${level.name}');
    currentLevel.value = level;
    return level;
  }

  // ── Private Helpers ───────────────────────────────────────────────────────

  /// Return explicit level if the query contains a clear keyword trigger,
  /// otherwise null (no override).
  ResponseLevel? _checkExplicitKeywords(String query) {
    final lower = query.toLowerCase();

    // Beginner indicators
    const beginnerTriggers = [
      "like i'm 5",
      'like i am 5',
      'eli5',
      'explain simply',
      'simple explanation',
      'easy',
      'simple',
      'basic',
      'beginner',
      'for kids',
      'child friendly',
      'layman',
      'dumbed down',
      'in simple terms',
      'in easy words',
    ];
    for (final t in beginnerTriggers) {
      if (lower.contains(t)) return ResponseLevel.beginner;
    }

    // Advanced indicators
    const advancedTriggers = [
      'technical',
      'in depth',
      'in-depth',
      'phd',
      'expert',
      'advanced',
      'deep dive',
      'detailed analysis',
      'comprehensive',
      'methodolog',
      'implications',
      'nuance',
      'academic',
      'research level',
      'like a scientist',
      'like an expert',
    ];
    for (final t in advancedTriggers) {
      if (lower.contains(t)) return ResponseLevel.advanced;
    }

    return null; // No explicit override
  }

  /// Map the user's anticipation/expectation string to a 0.0–1.0 score.
  double _parseProfileAnticipation(String anticipation) {
    if (anticipation.contains('phd') ||
        anticipation.contains('expert') ||
        anticipation.contains('advanced') ||
        anticipation.contains('technical') ||
        anticipation.contains('12th') ||
        anticipation.contains('college') ||
        anticipation.contains('university')) {
      return 0.9;
    }
    if (anticipation.contains('10th') ||
        anticipation.contains('9th') ||
        anticipation.contains('8th') ||
        anticipation.contains('high school') ||
        anticipation.contains('intermediate')) {
      return 0.6;
    }
    if (anticipation.contains('simple') ||
        anticipation.contains('basic') ||
        anticipation.contains('easy') ||
        anticipation.contains('child') ||
        anticipation.contains('5th') ||
        anticipation.contains('4th') ||
        anticipation.contains('3rd') ||
        anticipation.contains('2nd') ||
        anticipation.contains('1st')) {
      return 0.2;
    }
    return 0.5; // default: intermediate
  }

  /// Map trend direction string to a 0.0–1.0 score.
  double _parseTrendDirection(String trend) {
    switch (trend.toLowerCase()) {
      case 'rising':
      case 'up':
        return 0.7;
      case 'falling':
      case 'down':
        return 0.3;
      case 'stable':
      default:
        return 0.5;
    }
  }

  /// Combine scored signals into a [ResponseLevel] using weighted average.
  ///
  /// Weights:
  ///   profileScore:    0.5
  ///   complexityScore: 0.4
  ///   trendScore:      0.3
  ResponseLevel _combineSignals(
      double profileScore, double complexityScore, double trendScore) {
    final weighted =
        (profileScore * 0.5 + complexityScore * 0.4 + trendScore * 0.3) /
            (0.5 + 0.4 + 0.3);

    debugPrint('  Weighted combined score: ${weighted.toStringAsFixed(2)}');

    if (weighted < 0.33) return ResponseLevel.beginner;
    if (weighted < 0.66) return ResponseLevel.intermediate;
    return ResponseLevel.advanced;
  }
}
