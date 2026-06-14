import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'input_analyzer_service.dart';

enum ExpertiseLevel { beginner, intermediate, advanced }

class DetectedUserProfile {
  final ExpertiseLevel level;
  final double confidence;
  final DateTime lastUpdated;
  final String reason;

  DetectedUserProfile({
    required this.level,
    required this.confidence,
    required this.lastUpdated,
    required this.reason,
  });
}

class EnrichedUserProfile {
  final DetectedUserProfile currentLevel;
  final ExpertiseLevel historicalLevel;
  final String trendDirection;
  final List<ExpertiseLevel> recentHistory;

  EnrichedUserProfile({
    required this.currentLevel,
    required this.historicalLevel,
    required this.trendDirection,
    required this.recentHistory,
  });
}

class UserProfilingEngineService extends GetxService {
  late final InputAnalyzerService _analyzer;
  static const String _profileHistoryKey = 'user_profile_history';

  final currentExpertiseLevel = ExpertiseLevel.intermediate.obs;
  final profilingConfidence = 0.0.obs;
  final profilingReason = ''.obs;
  final recentQueries = <String>[].obs;
  final trendDirection = 'stable'.obs;

  @override
  void onInit() {
    super.onInit();
    _analyzer = Get.find<InputAnalyzerService>();
    _loadProfileHistory();
  }

  Future<void> _loadProfileHistory() async {
    final history = await _getRecentHistoryLevels();
    if (history.isNotEmpty) {
      final historicalLevel = _detectHistoricalTrend(history);
      currentExpertiseLevel.value = historicalLevel;
      trendDirection.value = _determineTrend(history);
    }
  }

  Future<EnrichedUserProfile> profileUser(
    String query,
    List<String> recentQueryList,
  ) async {
    final signals = _analyzer.analyzeQuery(query);

    final currentDetection = _detectLevelFromSignals(signals);

    final recentHistory = await _getRecentHistoryLevels();
    final historicalLevel = _detectHistoricalTrend(recentHistory);

    final finalLevel = _combineCurrentAndHistorical(
      current: currentDetection.level,
      historical: historicalLevel,
      currentConfidence: currentDetection.confidence,
    );

    final finalConfidence = _calculateFinalConfidence(
      currentDetection.confidence,
      historicalLevel,
      recentHistory,
    );

    final trend = _determineTrend(recentHistory);

    final profile = DetectedUserProfile(
      level: finalLevel,
      confidence: finalConfidence,
      lastUpdated: DateTime.now(),
      reason: _generateReason(signals, finalLevel, finalConfidence),
    );

    await _saveToHistory(profile.level);

    currentExpertiseLevel.value = finalLevel;
    profilingConfidence.value = finalConfidence;
    profilingReason.value = profile.reason;
    trendDirection.value = trend;

    return EnrichedUserProfile(
      currentLevel: profile,
      historicalLevel: historicalLevel,
      trendDirection: trend,
      recentHistory: recentHistory,
    );
  }

  DetectedUserProfile _detectLevelFromSignals(InputSignals signals) {
    double score = 0.0;
    String reason = '';

    score += signals.vocabularyComplexity * 0.25;
    if (signals.vocabularyComplexity > 0.7) {
      reason += 'Complex vocabulary. ';
    }

    final technicalDensity =
        signals.technicalTerms.length / (signals.wordCount + 1);
    score += (technicalDensity.clamp(0.0, 1.0)) * 0.25;
    if (signals.technicalTerms.isNotEmpty) {
      reason += 'Uses technical terms: ${signals.technicalTerms.join(", ")}. ';
    }

    score += signals.sentenceComplexity * 0.20;
    if (signals.sentenceComplexity > 0.6) {
      reason += 'Complex sentence structure. ';
    }

    if (signals.queryType == QueryType.whyQuestion) {
      score += 0.15;
      reason += 'Asks "why" questions. ';
    }

    if (signals.tone == ToneType.technical) {
      score += 0.15;
      reason += 'Technical tone. ';
    }

    ExpertiseLevel level;
    if (score < 0.35) {
      level = ExpertiseLevel.beginner;
    } else if (score < 0.65) {
      level = ExpertiseLevel.intermediate;
    } else {
      level = ExpertiseLevel.advanced;
    }

    return DetectedUserProfile(
      level: level,
      confidence: _calculateConfidenceFromScore(score),
      lastUpdated: DateTime.now(),
      reason: reason.isNotEmpty ? reason : 'Default classification',
    );
  }

  Future<List<ExpertiseLevel>> _getRecentHistoryLevels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_profileHistoryKey) ?? [];

      final start = historyJson.length > 5 ? historyJson.length - 5 : 0;
      final recent = historyJson.sublist(start);

      return recent.map((json) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return _stringToLevel(map['level'] as String);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  ExpertiseLevel _detectHistoricalTrend(List<ExpertiseLevel> history) {
    if (history.isEmpty) {
      return ExpertiseLevel.intermediate;
    }

    final map = <ExpertiseLevel, int>{};
    for (var level in history) {
      map[level] = (map[level] ?? 0) + 1;
    }

    var maxLevel = history.first;
    var maxCount = 0;
    map.forEach((level, count) {
      if (count > maxCount) {
        maxCount = count;
        maxLevel = level;
      }
    });

    return maxLevel;
  }

  ExpertiseLevel _combineCurrentAndHistorical({
    required ExpertiseLevel current,
    required ExpertiseLevel historical,
    required double currentConfidence,
  }) {
    if (currentConfidence > 0.75) {
      return current;
    }

    if (current == historical) {
      return current;
    }

    return historical;
  }

  double _calculateFinalConfidence(
    double currentConfidence,
    ExpertiseLevel historicalLevel,
    List<ExpertiseLevel> recentHistory,
  ) {
    double confidence = currentConfidence;

    if (recentHistory.isNotEmpty) {
      final recentMostCommon = _getMode(recentHistory);
      if (recentMostCommon == historicalLevel) {
        confidence += 0.15;
      }
    }

    return (confidence).clamp(0.0, 0.95);
  }

  String _determineTrend(List<ExpertiseLevel> history) {
    if (history.length < 3) return 'insufficient_data';

    final values = history.map((l) {
      if (l == ExpertiseLevel.beginner) return 0;
      if (l == ExpertiseLevel.intermediate) return 1;
      return 2;
    }).toList();

    final firstHalf = values.take((values.length / 2).ceil()).toList();
    final secondHalf = values.skip((values.length / 2).ceil()).toList();

    if (firstHalf.isEmpty || secondHalf.isEmpty) return 'stable';

    final firstAvg =
        firstHalf.fold<double>(0, (a, b) => a + b) / firstHalf.length;
    final secondAvg =
        secondHalf.fold<double>(0, (a, b) => a + b) / secondHalf.length;

    final diff = secondAvg - firstAvg;

    if (diff > 0.3) return 'ascending';
    if (diff < -0.3) return 'descending';
    return 'stable';
  }

  Future<void> _saveToHistory(ExpertiseLevel level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_profileHistoryKey) ?? [];

      final entry = jsonEncode({
        'level': _levelToString(level),
        'timestamp': DateTime.now().toIso8601String(),
      });

      history.add(entry);

      if (history.length > 20) {
        history.removeRange(0, history.length - 20);
      }

      await prefs.setStringList(_profileHistoryKey, history);
    } catch (e) {
      debugPrint('Error saving profile history: $e');
    }
  }

  String _levelToString(ExpertiseLevel level) {
    switch (level) {
      case ExpertiseLevel.beginner:
        return 'beginner';
      case ExpertiseLevel.intermediate:
        return 'intermediate';
      case ExpertiseLevel.advanced:
        return 'advanced';
    }
  }

  ExpertiseLevel _stringToLevel(String str) {
    switch (str) {
      case 'beginner':
        return ExpertiseLevel.beginner;
      case 'intermediate':
        return ExpertiseLevel.intermediate;
      case 'advanced':
        return ExpertiseLevel.advanced;
      default:
        return ExpertiseLevel.intermediate;
    }
  }

  ExpertiseLevel _getMode(List<ExpertiseLevel> list) {
    final map = <ExpertiseLevel, int>{};
    for (var item in list) {
      map[item] = (map[item] ?? 0) + 1;
    }

    var mode = list.first;
    var maxCount = 0;
    map.forEach((level, count) {
      if (count > maxCount) {
        maxCount = count;
        mode = level;
      }
    });

    return mode;
  }

  double _calculateConfidenceFromScore(double score) {
    final distanceFromCenter = (score - 0.5).abs();
    final confidence = 1.0 - (distanceFromCenter * 0.5);
    return confidence.clamp(0.50, 0.95);
  }

  String _generateReason(
      InputSignals signals, ExpertiseLevel level, double confidence) {
    final levelStr = level.toString().split('.').last;
    return 'Detected as $levelStr (${(confidence * 100).toStringAsFixed(0)}% confidence)';
  }

  String getLevelName(ExpertiseLevel level) {
    switch (level) {
      case ExpertiseLevel.beginner:
        return 'Beginner';
      case ExpertiseLevel.intermediate:
        return 'Intermediate';
      case ExpertiseLevel.advanced:
        return 'Advanced';
    }
  }

  String getCurrentLevelName() {
    return getLevelName(currentExpertiseLevel.value);
  }

  bool shouldAskForConfirmation() {
    return profilingConfidence.value < 0.70;
  }
}
