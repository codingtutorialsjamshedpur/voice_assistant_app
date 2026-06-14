/// ═══════════════════════════════════════════════════════════════
/// Curiosity Hook Service  (Task 2.1)
/// ═══════════════════════════════════════════════════════════════
///
/// Generates exciting follow-up curiosity hooks after the AI finishes
/// explaining a topic. Hooks are child-friendly, contextually relevant,
/// and rate-limited to avoid spamming the user.
///
/// Flow:
///   Answer arrives → extract entities → call AI for 3 hook ideas
///   → score by user interests → return top 2 → auto-speak top hook
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'open_router_service.dart';
import '../controllers/profile_controller.dart';

// ---------------------------------------------------------------------------
// CuriosityHook model
// ---------------------------------------------------------------------------

class CuriosityHook {
  final String hookText; // "Did you know...?" (spoken)
  final String followUpQuestion; // "Want to explore why...?"
  final String relatedTopic; // topic extracted from the last answer
  final double relevanceScore; // 0.0–1.0
  final int estimatedDurationSeconds;

  const CuriosityHook({
    required this.hookText,
    required this.followUpQuestion,
    required this.relatedTopic,
    this.relevanceScore = 0.5,
    this.estimatedDurationSeconds = 15,
  });

  factory CuriosityHook.fromJson(Map<String, dynamic> json) => CuriosityHook(
        hookText: json['hook_text'] as String? ?? '',
        followUpQuestion: json['follow_up_question'] as String? ?? '',
        relatedTopic: json['topic'] as String? ?? '',
        relevanceScore: (json['relevance_score'] as num?)?.toDouble() ?? 0.5,
        estimatedDurationSeconds:
            json['estimated_duration_seconds'] as int? ?? 15,
      );

  Map<String, dynamic> toJson() => {
        'hook_text': hookText,
        'follow_up_question': followUpQuestion,
        'topic': relatedTopic,
        'relevance_score': relevanceScore,
        'estimated_duration_seconds': estimatedDurationSeconds,
      };
}

// ---------------------------------------------------------------------------
// CuriosityHookService
// ---------------------------------------------------------------------------

class CuriosityHookService extends GetxService {
  late OpenRouterService _routerService;

  /// The most recent suggested hook (null = none pending).
  final Rxn<CuriosityHook> suggestedHook = Rxn<CuriosityHook>();

  /// Timestamp of the last generated hook (for rate-limiting).
  DateTime? _lastHookTime;

  /// Minimum gap between hook generations.
  static const _minGapSeconds = 10;

  @override
  void onInit() {
    super.onInit();
    _routerService = Get.find<OpenRouterService>();
    debugPrint('✅ [CuriosityHookService] Initialized');
  }

  // ── Public API ─────────────────────────────────────────────────────────

  /// Generate up to 2 curiosity hooks relevant to the last Q&A exchange.
  ///
  /// Returns an empty list if rate-limited or if AI fails.
  Future<List<CuriosityHook>> generateHooks({
    required String question,
    required String answer,
    List<String>? userInterests,
  }) async {
    // Rate-limit: don't generate if last hook was < 10 seconds ago
    if (_lastHookTime != null) {
      final elapsed = DateTime.now().difference(_lastHookTime!).inSeconds;
      if (elapsed < _minGapSeconds) {
        debugPrint(
            '⏱ [CuriosityHook] Rate-limited ($elapsed s < ${_minGapSeconds}s)');
        return [];
      }
    }

    // Derive related topic from the question
    final relatedTopic = _extractTopic(question, answer);

    debugPrint(
        '🔍 [CuriosityHook] Generating hooks for topic: "$relatedTopic"');

    // Build AI prompt
    final prompt = '''
The child just learned about: $relatedTopic

Generate 3 follow-up curiosity hooks that:
- Are exciting for a child aged 6–14
- Connect naturally to what they just learned
- Are 1–2 sentences each
- End with a question

Return ONLY valid JSON array (no markdown, no code fences):
[{"topic": "...", "hook_text": "Did you know...?", "follow_up_question": "Want to know...?"}]
''';

    try {
      final route = _routerService.defaultRoute;
      final raw = await _routerService.generateResponse(
        route: route,
        systemPrompt:
            'You are a helpful assistant. Return only valid JSON, no markdown.',
        userMessage: prompt,
      );

      if (raw == null || raw.trim().isEmpty) {
        debugPrint('⚠️ [CuriosityHook] Empty AI response');
        return [];
      }

      // Parse JSON
      final List<dynamic> parsed = _safeParseJsonArray(raw);
      final List<CuriosityHook> hooks = parsed
          .map((e) => CuriosityHook.fromJson(e as Map<String, dynamic>))
          .toList();

      // Score by relevance to user interests
      final interests = userInterests ?? _getUserInterests();
      for (var i = 0; i < hooks.length; i++) {
        hooks[i] = CuriosityHook(
          hookText: hooks[i].hookText,
          followUpQuestion: hooks[i].followUpQuestion,
          relatedTopic: hooks[i].relatedTopic,
          relevanceScore: _scoreRelevance(hooks[i].relatedTopic, interests),
          estimatedDurationSeconds: hooks[i].estimatedDurationSeconds,
        );
      }

      // Sort descending by relevance and return top 2
      hooks.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
      final top2 = hooks.take(2).toList();

      _lastHookTime = DateTime.now();

      for (final h in top2) {
        debugPrint(
            '💡 [CuriosityHook] "${h.relatedTopic}" score=${h.relevanceScore.toStringAsFixed(2)}');
      }

      return top2;
    } catch (e) {
      debugPrint('❌ [CuriosityHook] Generation error: $e');
      return [];
    }
  }

  /// Clear the current suggested hook.
  void dismissHook() {
    suggestedHook.value = null;
    debugPrint('🚫 [CuriosityHook] Dismissed');
  }

  /// Accept the hook — returns the follow-up question so the caller can
  /// send it as a new user message.
  String? acceptHook() {
    final hook = suggestedHook.value;
    suggestedHook.value = null;
    debugPrint('✅ [CuriosityHook] Accepted: "${hook?.followUpQuestion}"');
    return hook?.followUpQuestion;
  }

  // ── Private Helpers ─────────────────────────────────────────────────────

  String _extractTopic(String question, String answer) {
    // Use the first few words of the question as the topic
    final words = question
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length <= 5) return question;
    return words.skip(1).take(4).join(' ');
  }

  double _scoreRelevance(String topic, List<String> interests) {
    if (interests.isEmpty) return 0.5;
    final topicLower = topic.toLowerCase();
    int matches = 0;
    for (final interest in interests) {
      if (topicLower.contains(interest.toLowerCase()) ||
          interest.toLowerCase().contains(topicLower)) {
        matches++;
      }
    }
    return (matches / interests.length).clamp(0.0, 1.0);
  }

  List<String> _getUserInterests() {
    try {
      final pc = Get.find<ProfileController>();
      final raw = pc.userProfile.value.fieldOfInterest;
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<dynamic> _safeParseJsonArray(String raw) {
    // Strip markdown code fences if present
    final cleaned = raw
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    // Find first [ and last ]
    final start = cleaned.indexOf('[');
    final end = cleaned.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) return [];

    final jsonStr = cleaned.substring(start, end + 1);
    return jsonDecode(jsonStr) as List<dynamic>;
  }
}
