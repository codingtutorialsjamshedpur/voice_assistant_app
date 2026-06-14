/// ═══════════════════════════════════════════════════════════════
/// Grade Level Detector Service  (Task 3.2)
/// ═══════════════════════════════════════════════════════════════
///
/// Estimates the user's grade level (1–12 or adult) from a single
/// query plus recent query history, using weighted heuristics.
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class GradeLevelDetectorService extends GetxService {
  @override
  void onInit() {
    super.onInit();
    debugPrint('✅ [GradeLevelDetector] Initialized');
  }

  // ── Public API ────────────────────────────────────────────────────────

  /// Detect grade level (1–12) for [query] using [recentQueries] for context.
  int detectGradeLevel(String query, List<String> recentQueries) {
    final metrics = _computeMetrics(query, recentQueries);

    // Score → grade mapping
    final score = _computeScore(metrics);

    final grade = _scoreToGrade(score);

    debugPrint(
        '📚 [GradeLevelDetector] score=${score.toStringAsFixed(2)} → grade=$grade '
        '| words=${metrics['wordCount']} clauses=${metrics['clauseCount']} '
        'tech=${metrics['technicalTerms']}');

    return grade;
  }

  /// Estimate confidence (0.0–1.0) for the detected grade.
  double detectConfidence(String query) {
    final wordCount = query.split(' ').where((w) => w.isNotEmpty).length;
    // Confidence grows with more words (more signal)
    return (wordCount / 20.0).clamp(0.1, 1.0);
  }

  // ── Private Helpers ───────────────────────────────────────────────────

  Map<String, double> _computeMetrics(
      String query, List<String> recentQueries) {
    final words = query.split(' ').where((w) => w.isNotEmpty).toList();
    final wordCount = words.length.toDouble();

    final clauseCount = (query.split(',').length -
            1 +
            ' and '.allMatches(query.toLowerCase()).length)
        .toDouble();

    final technicalTerms = _countTechnicalTerms(query);
    final questionDepth = _measureQuestionDepth(query);
    final avgHistorical = _avgQueryLength(recentQueries);

    return {
      'wordCount': wordCount,
      'clauseCount': clauseCount,
      'technicalTerms': technicalTerms,
      'questionDepth': questionDepth,
      'avgHistorical': avgHistorical,
    };
  }

  double _computeScore(Map<String, double> m) {
    // Weighted combination → 0.0–1.0
    final score = (m['wordCount']! / 40.0) * 0.3 +
        (m['clauseCount']! / 5.0) * 0.2 +
        (m['technicalTerms']! / 5.0) * 0.3 +
        (m['questionDepth']! / 3.0) * 0.1 +
        (m['avgHistorical']! / 40.0) * 0.1;
    return score.clamp(0.0, 1.0);
  }

  int _scoreToGrade(double score) {
    if (score < 0.10) return 1;
    if (score < 0.20) return 2;
    if (score < 0.28) return 3;
    if (score < 0.36) return 4;
    if (score < 0.44) return 5;
    if (score < 0.52) return 6;
    if (score < 0.60) return 7;
    if (score < 0.68) return 8;
    if (score < 0.74) return 9;
    if (score < 0.80) return 10;
    if (score < 0.88) return 11;
    return 12;
  }

  double _countTechnicalTerms(String query) {
    const terms = [
      'algorithm',
      'photosynthesis',
      'mitosis',
      'quantum',
      'entanglement',
      'differential',
      'integral',
      'molecule',
      'atom',
      'electron',
      'proton',
      'neutron',
      'metabolism',
      'hypothesis',
      'derivative',
      'velocity',
      'acceleration',
      'gravity',
      'electromagnetic',
      'chromosome',
      'genetics',
      'ecosystem',
      'thermodynamics',
      'entropy',
      'polynomial',
      'trigonometry',
      'calculus',
      'neuroscience',
      'protein',
      'dna',
      'rna',
      'evolution',
      'metabolism',
      'philosophy',
      'democracy',
      'constitution',
      'inflation',
      'macroeconomics',
      'jurisprudence',
      'implementation',
      'abstract',
    ];
    final lower = query.toLowerCase();
    return terms.where((t) => lower.contains(t)).length.toDouble();
  }

  /// Maps question starters to depth: what=1, why=2, how/explain=3.
  double _measureQuestionDepth(String query) {
    final lower = query.toLowerCase().trim();
    if (lower.startsWith('what is') || lower.startsWith('क्या है')) return 1;
    if (lower.startsWith('why') || lower.startsWith('क्यों')) return 2;
    if (lower.startsWith('how') ||
        lower.startsWith('explain') ||
        lower.startsWith('what are the implications') ||
        lower.startsWith('describe the mechanism')) {
      return 3;
    }
    return 1;
  }

  double _avgQueryLength(List<String> queries) {
    if (queries.isEmpty) return 0;
    final total = queries.fold<int>(0, (sum, q) => sum + q.split(' ').length);
    return (total / queries.length).toDouble();
  }
}
