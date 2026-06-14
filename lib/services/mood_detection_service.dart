// lib/services/mood_detection_service.dart
// Phase 2 - Sprint 1 & 2: MoodDetectionService

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/mood_state_model.dart';

/// Service that analyses user text (and optionally voice metadata)
/// to detect the current emotional state.
///
/// Text scoring combines:
///   • Keyword dictionaries (English + Hindi/Hinglish)
///   • Punctuation patterns (!!!, ...)
///   • Text length heuristics
class MoodDetectionService extends GetxService {
  // ── Keyword dictionaries ──────────────────────────────────────────────────
  static const List<String> _happyKeywords = [
    'happy',
    'happiness',
    'khush',
    'khushi',
    'maza',
    'mazaa',
    'mst',
    'bahut achha',
    'bahut acha',
    'great',
    'wonderful',
    'awesome',
    'fantastic',
    'love it',
    'amazing',
    'best',
    'superb',
    'joy',
    'joyful',
    'excited',
    'excellent',
    'perfect',
    'yaay',
    'yay',
    'yayy',
  ];

  static const List<String> _sadKeywords = [
    'sad',
    'unhappy',
    'dukh',
    'dukhi',
    'udaas',
    'rona',
    'roya',
    'crying',
    'cry',
    'alone',
    'lonely',
    'miss',
    'heartbroken',
    'depressed',
    'depression',
    'broken',
    'lost',
    'pareshaan',
    'bura lag raha',
    'badhiya nahi',
    'acha nahi',
    'theek nahi',
  ];

  static const List<String> _stressKeywords = [
    'stress',
    'stressed',
    'tension',
    'tense',
    'pareshani',
    'problem',
    'dikkat',
    'trouble',
    'worried',
    'worry',
    'burden',
    'pressure',
    'overwhelmed',
    'exhausted',
    'frustrated',
    'bahut kaam',
    'overload',
    'deadline',
    'exam',
    'test',
    'fail',
    'failed',
  ];

  static const List<String> _anxiousKeywords = [
    'anxious',
    'anxiety',
    'nervous',
    'scared',
    'fear',
    'afraid',
    'dara hua',
    'dar',
    'panic',
    'uncertain',
    'unsure',
    'confused',
    'ghabra',
    'ghabrahat',
    'doubt',
    'doubtful',
  ];

  static const List<String> _excitedKeywords = [
    'excited',
    'wow',
    'amazing',
    'omg',
    'oh my god',
    'unbelievable',
    'cant believe',
    'thrilled',
    'ecstatic',
    'super',
    'incredible',
    'mast',
    'ek dum mast',
    'lit',
    'fire',
    'insane',
  ];

  static const List<String> _tiredKeywords = [
    'tired',
    'thak',
    'thaka',
    'thaki',
    'thakaan',
    'exhausted',
    'sleepy',
    'neend',
    'so jaana',
    'aaraam',
    'rest',
    'bore',
    'bored',
    'boring',
    'monotonous',
    'yawn',
    'drained',
  ];

  static const List<String> _angryKeywords = [
    'angry',
    'anger',
    'mad',
    'furious',
    'annoyed',
    'irritated',
    'gussa',
    'gussal',
    'krodh',
    'hate',
    'hateful',
    'disgusted',
    'ugh',
    'argh',
    'stupid',
    'idiot',
    'useless',
    'nonsense',
  ];

  // ── Main API ──────────────────────────────────────────────────────────────

  /// Analyse [text] to produce a [MoodState].
  MoodState analyzeMood({required String text}) {
    if (text.trim().isEmpty) return MoodState.neutral;
    return _analyzeText(text);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  MoodState _analyzeText(String text) {
    final lowerText = text.toLowerCase().trim();
    final indicators = <String>[];
    final scores = <MoodType, double>{
      MoodType.happy: 0.0,
      MoodType.sad: 0.0,
      MoodType.stressed: 0.0,
      MoodType.neutral: 0.1, // small baseline so neutral wins ties
      MoodType.anxious: 0.0,
      MoodType.excited: 0.0,
      MoodType.tired: 0.0,
      MoodType.angry: 0.0,
    };

    // ── Keyword scoring ───────────────────────────────────────
    void scoreKeywords(
        List<String> keywords, MoodType mood, String indicatorTag) {
      int hits = 0;
      for (final kw in keywords) {
        if (lowerText.contains(kw)) hits++;
      }
      if (hits > 0) {
        scores[mood] = (scores[mood] ?? 0) + (hits * 0.3).clamp(0.0, 0.9);
        indicators.add(indicatorTag);
      }
    }

    scoreKeywords(_happyKeywords, MoodType.happy, 'happy_keywords');
    scoreKeywords(_sadKeywords, MoodType.sad, 'sad_keywords');
    scoreKeywords(_stressKeywords, MoodType.stressed, 'stress_keywords');
    scoreKeywords(_anxiousKeywords, MoodType.anxious, 'anxious_keywords');
    scoreKeywords(_excitedKeywords, MoodType.excited, 'excited_keywords');
    scoreKeywords(_tiredKeywords, MoodType.tired, 'tired_keywords');
    scoreKeywords(_angryKeywords, MoodType.angry, 'angry_keywords');

    // ── Punctuation heuristics ────────────────────────────────
    if (lowerText.contains('!!!') || lowerText.contains('!!')) {
      scores[MoodType.excited] = (scores[MoodType.excited] ?? 0) + 0.2;
      indicators.add('exclamation_marks');
    }
    if (lowerText.contains('...')) {
      scores[MoodType.sad] = (scores[MoodType.sad] ?? 0) + 0.15;
      indicators.add('ellipsis_hesitation');
    }
    if (lowerText.contains('??')) {
      scores[MoodType.anxious] = (scores[MoodType.anxious] ?? 0) + 0.1;
      indicators.add('double_question_marks');
    }

    // ── Length heuristic ──────────────────────────────────────
    if (lowerText.length < 8) {
      scores[MoodType.tired] = (scores[MoodType.tired] ?? 0) + 0.1;
      indicators.add('short_response');
    }

    // ── Caps-lock heuristic ───────────────────────────────────
    final upperCount = text
        .split('')
        .where((c) => c == c.toUpperCase() && c != c.toLowerCase())
        .length;
    if (upperCount > text.length * 0.5 && text.length > 5) {
      scores[MoodType.angry] = (scores[MoodType.angry] ?? 0) + 0.15;
      indicators.add('caps_lock_intensity');
    }

    // ── Find dominant mood ────────────────────────────────────
    MoodType dominant = MoodType.neutral;
    double maxScore = 0.0;
    scores.forEach((mood, score) {
      if (score > maxScore) {
        maxScore = score;
        dominant = mood;
      }
    });

    final confidence = maxScore.clamp(0.05, 1.0);

    return MoodState(
      type: dominant,
      confidence: confidence,
      detectedAt: DateTime.now(),
      indicators: indicators,
    );
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  /// Returns a mood-aware system prompt modifier for the AI
  String getMoodSystemPromptModifier(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return 'The user seems happy and joyful. Match their positive energy. Celebrate with them!';
      case MoodType.sad:
        return 'The user seems sad. Respond with extra empathy and warmth. Gently check in on them. Use caring Hinglish.';
      case MoodType.stressed:
        return 'The user seems stressed. Provide calm, reassuring, solution-oriented responses. Avoid adding more pressure.';
      case MoodType.anxious:
        return 'The user seems anxious or nervous. Be reassuring, step-by-step in guidance. Keep your tone soothing.';
      case MoodType.excited:
        return 'The user is excited! Match their enthusiasm. Keep the energy high and engaging.';
      case MoodType.tired:
        return 'The user seems tired. Be gentle and supportive. Suggest rest when appropriate. Keep responses brief.';
      case MoodType.angry:
        return 'The user seems frustrated or angry. Acknowledge their feelings first. Stay calm, do not argue.';
      case MoodType.neutral:
        return '';
    }
  }

  @override
  void onInit() {
    super.onInit();
    debugPrint('✅ MoodDetectionService initialized');
  }
}
