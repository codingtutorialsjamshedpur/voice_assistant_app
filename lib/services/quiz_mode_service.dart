/// ═══════════════════════════════════════════════════════════════
/// Quiz Mode Service  (Task 6.1)
/// ═══════════════════════════════════════════════════════════════
///
/// Interactive quiz flow that activates after substantial AI explanations:
///
///   1. shouldSuggestQuiz(topic) → decides whether to offer a quiz
///   2. generateQuizQuestion(topic) → AI generates the question
///   3. validateAnswer(question, answer, topic) → AI grades the answer
///   4. Results fed to GamificationService for XP awards
///
/// Supported question types:
///   recall | trueFalse | fillIn | creative
///
/// All quiz history persisted in SharedPreferences.
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'open_router_service.dart';
import 'gamification_service.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

enum QuizQuestionType { recall, trueFalse, fillIn, creative }

class QuizQuestion {
  final String questionText;
  final String topic;
  final QuizQuestionType type;
  final String? hint;

  const QuizQuestion({
    required this.questionText,
    required this.topic,
    required this.type,
    this.hint,
  });

  Map<String, dynamic> toJson() => {
        'questionText': questionText,
        'topic': topic,
        'type': type.name,
        'hint': hint,
      };

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
        questionText: json['questionText'] as String,
        topic: json['topic'] as String,
        type: QuizQuestionType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => QuizQuestionType.recall,
        ),
        hint: json['hint'] as String?,
      );
}

class QuizResult {
  final bool isCorrect;
  final String feedbackText;
  final int xpEarned;
  final String topic;
  final DateTime answeredAt;

  const QuizResult({
    required this.isCorrect,
    required this.feedbackText,
    required this.xpEarned,
    required this.topic,
    required this.answeredAt,
  });

  Map<String, dynamic> toJson() => {
        'isCorrect': isCorrect,
        'feedbackText': feedbackText,
        'xpEarned': xpEarned,
        'topic': topic,
        'answeredAt': answeredAt.toIso8601String(),
      };

  factory QuizResult.fromJson(Map<String, dynamic> json) => QuizResult(
        isCorrect: json['isCorrect'] as bool,
        feedbackText: json['feedbackText'] as String,
        xpEarned: json['xpEarned'] as int,
        topic: json['topic'] as String,
        answeredAt: DateTime.parse(json['answeredAt'] as String),
      );
}

// ---------------------------------------------------------------------------
// QuizModeService
// ---------------------------------------------------------------------------

class QuizModeService extends GetxService {
  static const _prefsKey = 'quiz_history';
  final _rng = Random();

  OpenRouterService? _routerService;
  GamificationService? _gamification;

  // Observable state
  final RxBool isQuizActive = false.obs;
  final Rxn<QuizQuestion> currentQuestion = Rxn<QuizQuestion>();
  final RxList<QuizResult> quizHistory = <QuizResult>[].obs;

  @override
  void onInit() {
    super.onInit();
    try {
      _routerService = Get.find<OpenRouterService>();
    } catch (_) {}
    try {
      _gamification = Get.find<GamificationService>();
    } catch (_) {}
    _load();
    debugPrint('✅ [QuizModeService] Initialized');
  }

  // ── Public API ────────────────────────────────────────────────────────

  /// Decide whether to suggest a quiz after an explanation.
  ///
  /// Rules:
  /// - Only after substantial explanations (response > 3 sentences ~ 50 words)
  /// - Random probability cap 30%
  /// - Not if a quiz is already active
  bool shouldSuggestQuiz(String lastAIResponse, String topic) {
    if (isQuizActive.value) return false;
    final wordCount = lastAIResponse.split(' ').length;
    if (wordCount < 50) return false;
    return _rng.nextDouble() <= 0.30;
  }

  /// Generate a quiz question for [topic] using AI.
  Future<QuizQuestion?> generateQuizQuestion(String topic) async {
    if (_routerService == null) return null;

    final prompt = '''
Create one quiz question about: $topic

Choose ONE of these types:
- recall: open-ended question about a fact
- trueFalse: a true/false statement question
- fillIn: fill-in-the-blank sentence
- creative: "explain in your own words"

Return ONLY valid JSON (no markdown):
{"question_text": "...", "type": "recall|trueFalse|fillIn|creative", "hint": "optional hint"}
''';

    try {
      final route = _routerService!.defaultRoute;
      final raw = await _routerService!.generateResponse(
        route: route,
        systemPrompt:
            'You are a quiz generator. Return ONLY valid JSON, no markdown.',
        userMessage: prompt,
      );

      if (raw == null) return null;

      final cleaned = raw
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final data = jsonDecode(cleaned) as Map<String, dynamic>;
      final q = QuizQuestion(
        questionText:
            data['question_text'] as String? ?? 'Tell me about $topic.',
        topic: topic,
        type: QuizQuestionType.values.firstWhere(
          (t) => t.name == data['type'],
          orElse: () => QuizQuestionType.recall,
        ),
        hint: data['hint'] as String?,
      );

      currentQuestion.value = q;
      isQuizActive.value = true;
      debugPrint('❓ [Quiz] Generated: "${q.questionText}" (${q.type.name})');
      return q;
    } catch (e) {
      debugPrint('❌ [Quiz] Generation error: $e');
      return null;
    }
  }

  /// Validate a [userAnswer] against [question] using AI.
  Future<QuizResult> validateAnswer({
    required QuizQuestion question,
    required String userAnswer,
  }) async {
    isQuizActive.value = false;
    currentQuestion.value = null;

    if (_routerService == null) {
      return QuizResult(
        isCorrect: false,
        feedbackText: 'Could not validate answer. Please try again.',
        xpEarned: 0,
        topic: question.topic,
        answeredAt: DateTime.now(),
      );
    }

    final prompt = '''
Quiz question: "${question.questionText}"
Topic: ${question.topic}
User's answer: "$userAnswer"

Is the answer correct or approximately correct?
Return ONLY valid JSON:
{"is_correct": true/false, "feedback": "brief encouraging feedback", "explanation": "optional short correction if wrong"}
''';

    try {
      final route = _routerService!.defaultRoute;
      final raw = await _routerService!.generateResponse(
        route: route,
        systemPrompt:
            'You are a quiz evaluator. Return ONLY valid JSON, no markdown.',
        userMessage: prompt,
      );

      bool isCorrect = false;
      String feedback = '';

      if (raw != null) {
        final cleaned = raw
            .replaceAll(RegExp(r'```json\s*'), '')
            .replaceAll(RegExp(r'```\s*'), '')
            .trim();
        final data = jsonDecode(cleaned) as Map<String, dynamic>;
        isCorrect = data['is_correct'] as bool? ?? false;
        feedback = data['feedback'] as String? ?? '';
        if (!isCorrect && data['explanation'] != null) {
          feedback += ' ${data['explanation']}';
        }
      }

      final xpEarned = isCorrect ? 20 : 0;
      final result = QuizResult(
        isCorrect: isCorrect,
        feedbackText: feedback.isNotEmpty
            ? feedback
            : (isCorrect
                ? 'Great job! That is correct!'
                : 'Not quite right. Let me explain...'),
        xpEarned: xpEarned,
        topic: question.topic,
        answeredAt: DateTime.now(),
      );

      quizHistory.add(result);
      _gamification?.recordQuizResult(isCorrect);

      if (xpEarned > 0) {
        _gamification?.awardXP(xpEarned, 'Correct quiz answer');
      }

      await _save();

      debugPrint('✅ [Quiz] Result: correct=$isCorrect xp=$xpEarned');
      return result;
    } catch (e) {
      debugPrint('❌ [Quiz] Validation error: $e');
      return QuizResult(
        isCorrect: false,
        feedbackText: 'Could not grade this answer. Great effort!',
        xpEarned: 0,
        topic: question.topic,
        answeredAt: DateTime.now(),
      );
    }
  }

  /// Get quiz success rate (0.0–1.0).
  double getSuccessRate() {
    if (quizHistory.isEmpty) return 0.0;
    final correct = quizHistory.where((r) => r.isCorrect).length;
    return correct / quizHistory.length;
  }

  // ── Private ───────────────────────────────────────────────────────────

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey, jsonEncode(quizHistory.map((r) => r.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final list = (jsonDecode(raw) as List<dynamic>)
            .map((e) => QuizResult.fromJson(e as Map<String, dynamic>))
            .toList();
        quizHistory.addAll(list);
        debugPrint('📂 [Quiz] Restored ${quizHistory.length} previous results');
      }
    } catch (_) {}
  }
}
