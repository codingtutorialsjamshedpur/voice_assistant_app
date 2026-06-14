/// ═══════════════════════════════════════════════════════════════
/// Learning Style Detector Service  (Task 3.3)
/// ═══════════════════════════════════════════════════════════════
///
/// Tracks cumulative phrase patterns across a rolling window of the
/// last 20 queries to detect the user's dominant learning style:
///   'visual' | 'logical' | 'storytelling' | 'auditory'
///
/// Defaults to 'logical' when no clear pattern is detected.
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LearningStyleDetectorService extends GetxService {
  static const _windowSize = 20;

  // Rolling window of last 20 queries
  final _queryWindow = <String>[];

  // Cumulative pattern counts across the rolling window
  final _counts = <String, int>{
    'storytelling': 0,
    'visual': 0,
    'logical': 0,
    'auditory': 0,
  };

  @override
  void onInit() {
    super.onInit();
    debugPrint('✅ [LearningStyleDetector] Initialized');
  }

  // ── Trigger patterns per style ──────────────────────────────────────────

  static const _patterns = <String, List<String>>{
    'storytelling': [
      'tell me a story',
      'what happened',
      'once upon',
      'story of',
      'history of',
      'long ago',
      'legend of',
      'tale of',
      'narrative',
    ],
    'visual': [
      'how does it look',
      'show me',
      'describe',
      'what color',
      'what does it look like',
      'appearance',
      'shape of',
      'picture of',
      'visualize',
    ],
    'logical': [
      'why',
      'how does it work',
      'prove it',
      'what is the reason',
      'explain',
      'mechanism',
      'because',
      'cause and effect',
      'logic',
      'proof',
      'justify',
    ],
    'auditory': [
      'what sounds like',
      'what does it feel like',
      'describe the sound',
      'how does it feel',
      'emotion',
      'texture',
      'sensation',
    ],
  };

  // ── Public API ────────────────────────────────────────────────────────

  /// Add a new query to the rolling window and update counts.
  void trackQuery(String query) {
    if (_queryWindow.length >= _windowSize) {
      // Remove oldest query and subtract its counts
      final oldest = _queryWindow.removeAt(0);
      _subtractCounts(oldest);
    }
    _queryWindow.add(query);
    _addCounts(query);
  }

  /// Returns the dominant learning style for the current rolling window.
  String detectStyle() {
    if (_counts.values.every((v) => v == 0)) return 'logical'; // default
    final best = _counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    debugPrint(
        '🎓 [LearningStyleDetector] counts=$_counts → style=${best.key}');
    return best.key;
  }

  /// Returns confidence 0.0–1.0 how certain the detection is.
  double getConfidence() {
    final total = _counts.values.fold<int>(0, (s, v) => s + v);
    if (total == 0) return 0.0;
    final best = _counts.values.reduce((a, b) => a > b ? a : b);
    return (best / total).clamp(0.0, 1.0);
  }

  // ── Private ───────────────────────────────────────────────────────────

  void _addCounts(String query) {
    final lower = query.toLowerCase();
    for (final style in _patterns.keys) {
      for (final pattern in _patterns[style]!) {
        if (lower.contains(pattern)) {
          _counts[style] = (_counts[style] ?? 0) + 1;
        }
      }
    }
  }

  void _subtractCounts(String query) {
    final lower = query.toLowerCase();
    for (final style in _patterns.keys) {
      for (final pattern in _patterns[style]!) {
        if (lower.contains(pattern)) {
          _counts[style] = ((_counts[style] ?? 1) - 1).clamp(0, 9999);
        }
      }
    }
  }
}
