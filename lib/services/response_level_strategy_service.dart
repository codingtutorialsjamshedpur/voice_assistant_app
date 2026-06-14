/// ═══════════════════════════════════════════════════════════════
/// Response Level Strategy Service
/// ═══════════════════════════════════════════════════════════════
///
/// Defines how the AI should respond based on detected user level:
///   beginner | intermediate | advanced
///
/// Each level maps to a concrete ResponseLevelStrategy that contains
/// vocabulary limits, sentence length caps, tone settings, etc.
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ---------------------------------------------------------------------------
// ResponseLevel enum
// ---------------------------------------------------------------------------

/// The three expertise levels supported by the response-level pipeline.
enum ResponseLevel { beginner, intermediate, advanced }

// ---------------------------------------------------------------------------
// ChildProfile — lightweight model for child-context injection
// ---------------------------------------------------------------------------

/// Represents detected child characteristics used to further personalise
/// the response strategy (e.g. grade level, learning style).
class ChildProfile {
  final int detectedGradeLevel; // 1–12
  final String
      learningStyle; // 'visual' | 'logical' | 'storytelling' | 'auditory'
  final Set<String> vocabularyUsed;
  final List<String> interestedTopics;
  final double sentenceComplexity; // 0.0–1.0
  final double curiosityScore; // ratio of follow-up questions
  final List<String> favoriteQuestionTypes;
  final Duration avgEngagementTime;
  final int totalQuestionsAsked;
  final DateTime firstInteractionDate;

  const ChildProfile({
    this.detectedGradeLevel = 5,
    this.learningStyle = 'logical',
    this.vocabularyUsed = const {},
    this.interestedTopics = const [],
    this.sentenceComplexity = 0.3,
    this.curiosityScore = 0.5,
    this.favoriteQuestionTypes = const [],
    this.avgEngagementTime = const Duration(minutes: 5),
    this.totalQuestionsAsked = 0,
    required this.firstInteractionDate,
  });

  factory ChildProfile.defaultProfile() => ChildProfile(
        firstInteractionDate: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'detectedGradeLevel': detectedGradeLevel,
        'learningStyle': learningStyle,
        'vocabularyUsed': vocabularyUsed.toList(),
        'interestedTopics': interestedTopics,
        'sentenceComplexity': sentenceComplexity,
        'curiosityScore': curiosityScore,
        'favoriteQuestionTypes': favoriteQuestionTypes,
        'avgEngagementTimeSeconds': avgEngagementTime.inSeconds,
        'totalQuestionsAsked': totalQuestionsAsked,
        'firstInteractionDate': firstInteractionDate.toIso8601String(),
      };

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
        detectedGradeLevel: json['detectedGradeLevel'] as int? ?? 5,
        learningStyle: json['learningStyle'] as String? ?? 'logical',
        vocabularyUsed: Set<String>.from(
            (json['vocabularyUsed'] as List<dynamic>? ?? []).cast<String>()),
        interestedTopics: List<String>.from(
            (json['interestedTopics'] as List<dynamic>? ?? []).cast<String>()),
        sentenceComplexity:
            (json['sentenceComplexity'] as num?)?.toDouble() ?? 0.3,
        curiosityScore: (json['curiosityScore'] as num?)?.toDouble() ?? 0.5,
        favoriteQuestionTypes: List<String>.from(
            (json['favoriteQuestionTypes'] as List<dynamic>? ?? [])
                .cast<String>()),
        avgEngagementTime:
            Duration(seconds: json['avgEngagementTimeSeconds'] as int? ?? 300),
        totalQuestionsAsked: json['totalQuestionsAsked'] as int? ?? 0,
        firstInteractionDate: json['firstInteractionDate'] != null
            ? DateTime.parse(json['firstInteractionDate'] as String)
            : DateTime.now(),
      );

  ChildProfile copyWith({
    int? detectedGradeLevel,
    String? learningStyle,
    Set<String>? vocabularyUsed,
    List<String>? interestedTopics,
    double? sentenceComplexity,
    double? curiosityScore,
    List<String>? favoriteQuestionTypes,
    Duration? avgEngagementTime,
    int? totalQuestionsAsked,
    DateTime? firstInteractionDate,
  }) =>
      ChildProfile(
        detectedGradeLevel: detectedGradeLevel ?? this.detectedGradeLevel,
        learningStyle: learningStyle ?? this.learningStyle,
        vocabularyUsed: vocabularyUsed ?? this.vocabularyUsed,
        interestedTopics: interestedTopics ?? this.interestedTopics,
        sentenceComplexity: sentenceComplexity ?? this.sentenceComplexity,
        curiosityScore: curiosityScore ?? this.curiosityScore,
        favoriteQuestionTypes:
            favoriteQuestionTypes ?? this.favoriteQuestionTypes,
        avgEngagementTime: avgEngagementTime ?? this.avgEngagementTime,
        totalQuestionsAsked: totalQuestionsAsked ?? this.totalQuestionsAsked,
        firstInteractionDate: firstInteractionDate ?? this.firstInteractionDate,
      );
}

// ---------------------------------------------------------------------------
// ResponseLevelStrategy
// ---------------------------------------------------------------------------

/// A concrete strategy object that describes how the AI should structure
/// and deliver a response for a given [ResponseLevel].
class ResponseLevelStrategy {
  final ResponseLevel level;
  final double vocabularyLimit; // 0.0–1.0 (0.3 = simple, 0.9 = PhD)
  final int sentenceLengthMax; // max words per sentence
  final bool useSimiles;
  final bool includeExamples;
  final bool includeHistoricalContext;
  final bool includeEdgeCases;
  final int paragraphLengthMax; // max total words per paragraph (0 = unlimited)
  final String tone; // 'playful' | 'clear' | 'formal'

  const ResponseLevelStrategy({
    required this.level,
    required this.vocabularyLimit,
    required this.sentenceLengthMax,
    required this.useSimiles,
    required this.includeExamples,
    required this.includeHistoricalContext,
    required this.includeEdgeCases,
    required this.paragraphLengthMax,
    required this.tone,
  });

  // ── Factory ───────────────────────────────────────────────────────────────

  /// Build the correct strategy for a given [level].
  static ResponseLevelStrategy fromLevel(ResponseLevel level) {
    switch (level) {
      case ResponseLevel.beginner:
        return const ResponseLevelStrategy(
          level: ResponseLevel.beginner,
          vocabularyLimit: 0.3,
          sentenceLengthMax: 10,
          useSimiles: true,
          includeExamples: true,
          includeHistoricalContext: false,
          includeEdgeCases: false,
          paragraphLengthMax: 30,
          tone: 'playful',
        );
      case ResponseLevel.intermediate:
        return const ResponseLevelStrategy(
          level: ResponseLevel.intermediate,
          vocabularyLimit: 0.6,
          sentenceLengthMax: 18,
          useSimiles: true,
          includeExamples: true,
          includeHistoricalContext: false,
          includeEdgeCases: false,
          paragraphLengthMax: 60,
          tone: 'clear',
        );
      case ResponseLevel.advanced:
        return const ResponseLevelStrategy(
          level: ResponseLevel.advanced,
          vocabularyLimit: 0.9,
          sentenceLengthMax: 35,
          useSimiles: false,
          includeExamples: false,
          includeHistoricalContext: true,
          includeEdgeCases: true,
          paragraphLengthMax: 0, // unlimited
          tone: 'formal',
        );
    }
  }

  // ── System Prompt Injection ───────────────────────────────────────────────

  /// Build the system-prompt section that instructs the AI
  /// how to respond at this level.
  ///
  /// Optionally receives a [childProfile] for additional constraints.
  String getSystemPromptInjection([ChildProfile? childProfile]) {
    final buffer = StringBuffer();

    switch (level) {
      case ResponseLevel.beginner:
        buffer.writeln('RESPONSE LEVEL: BEGINNER (Grade 1–3 equivalent)');
        buffer.writeln('- Max $sentenceLengthMax words per sentence');
        buffer.writeln('- Vocabulary: everyday words only, no jargon');
        buffer.writeln('- Use similes comparing to animals, toys, food, sky');
        buffer.writeln('- Include 2 concrete examples');
        buffer.writeln('- Tone: warm, playful, encouraging');
        buffer.writeln('- End with: "Do you want to know more about...?"');
        break;

      case ResponseLevel.intermediate:
        buffer.writeln('RESPONSE LEVEL: INTERMEDIATE (Grade 5–8 equivalent)');
        buffer.writeln('- Max $sentenceLengthMax words per sentence');
        buffer.writeln('- Vocabulary: clear language; define uncommon terms');
        buffer.writeln('- Use 1–2 analogies for complex ideas');
        buffer.writeln('- Provide 2 examples (one simple, one complex)');
        buffer.writeln('- Tone: clear, engaging, friendly');
        buffer.writeln(
            '- End with: "Would you like to explore [related topic]?"');
        break;

      case ResponseLevel.advanced:
        buffer.writeln('RESPONSE LEVEL: ADVANCED (Expert / PhD level)');
        buffer.writeln('- No limit on sentence length or vocabulary');
        buffer.writeln('- Use precise technical terminology freely');
        buffer.writeln('- Include edge cases and open questions');
        buffer.writeln('- Optionally cite research frontiers or references');
        buffer.writeln('- Tone: formal, rigorous, concise');
        buffer.writeln(
            '- End with: "The frontier here is..." or "Current research explores..."');
        break;
    }

    // Extra constraints when child profile is detected
    if (childProfile != null) {
      buffer.writeln(
          '- Detected Grade Level: ${childProfile.detectedGradeLevel}');
      buffer.writeln('- Learning Style: ${childProfile.learningStyle}');
    }

    return buffer.toString().trim();
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'level': level.name,
        'vocabularyLimit': vocabularyLimit,
        'sentenceLengthMax': sentenceLengthMax,
        'useSimiles': useSimiles,
        'includeExamples': includeExamples,
        'includeHistoricalContext': includeHistoricalContext,
        'includeEdgeCases': includeEdgeCases,
        'paragraphLengthMax': paragraphLengthMax,
        'tone': tone,
      };

  factory ResponseLevelStrategy.fromJson(Map<String, dynamic> json) {
    final levelStr = json['level'] as String? ?? 'intermediate';
    final level = ResponseLevel.values.firstWhere(
      (l) => l.name == levelStr,
      orElse: () => ResponseLevel.intermediate,
    );
    return ResponseLevelStrategy(
      level: level,
      vocabularyLimit: (json['vocabularyLimit'] as num?)?.toDouble() ?? 0.6,
      sentenceLengthMax: json['sentenceLengthMax'] as int? ?? 18,
      useSimiles: json['useSimiles'] as bool? ?? true,
      includeExamples: json['includeExamples'] as bool? ?? true,
      includeHistoricalContext:
          json['includeHistoricalContext'] as bool? ?? false,
      includeEdgeCases: json['includeEdgeCases'] as bool? ?? false,
      paragraphLengthMax: json['paragraphLengthMax'] as int? ?? 60,
      tone: json['tone'] as String? ?? 'clear',
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory ResponseLevelStrategy.fromJsonString(String s) =>
      ResponseLevelStrategy.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

// ---------------------------------------------------------------------------
// ResponseLevelStrategyService  (GetxService wrapper)
// ---------------------------------------------------------------------------

/// A thin GetxService wrapper so the strategy factory can be
/// dependency-injected via GetX.
class ResponseLevelStrategyService extends GetxService {
  /// Current active strategy.
  final Rx<ResponseLevelStrategy> currentStrategy = Rx<ResponseLevelStrategy>(
      ResponseLevelStrategy.fromLevel(ResponseLevel.intermediate));

  /// Build strategy from a level and optionally apply it as current.
  ResponseLevelStrategy buildStrategy(ResponseLevel level,
      {bool setAsCurrent = false}) {
    final strategy = ResponseLevelStrategy.fromLevel(level);
    if (setAsCurrent) {
      currentStrategy.value = strategy;
      debugPrint('📊 [ResponseLevelStrategy] Level set → ${level.name} '
          '| Tone: ${strategy.tone} | MaxSentence: ${strategy.sentenceLengthMax} words');
    }
    return strategy;
  }
}
