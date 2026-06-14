/// ═══════════════════════════════════════════════════════════════
/// Emotion Adapter Service  (Task 5.2)
/// ═══════════════════════════════════════════════════════════════
///
/// Detects the emotional context of a user query and adapts
/// TTS tone (pitch + speed) accordingly before speaking.
///
/// Emotions detected:
///   compassionate | enthusiastic | patient | storyteller | gameshow
///
/// Usage (in VoiceController before ttsService.speak):
///   final emotion = emotionAdapter.detectEmotion(query);
///   await emotionAdapter.adaptTone(emotion);
///   await ttsService.speak(response);
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'tts_service.dart';

/// Named emotion categories.
enum DetectedEmotion {
  neutral,
  compassionate,
  enthusiastic,
  patient,
  storyteller,
  gameshow,
}

class EmotionAdapterService extends GetxService {
  TTSService? _tts;

  /// Last detected emotion (observable for UI binding / orb animation).
  final Rx<DetectedEmotion> currentEmotion =
      Rx<DetectedEmotion>(DetectedEmotion.neutral);

  @override
  void onInit() {
    super.onInit();
    try {
      _tts = Get.find<TTSService>();
    } catch (_) {}
    debugPrint('✅ [EmotionAdapterService] Initialized');
  }

  // ── Public API ────────────────────────────────────────────────────────

  /// Detect emotional context from [query] text.
  DetectedEmotion detectEmotion(String query) {
    final lower = query.toLowerCase();

    if (_containsAny(lower, [
      'sad',
      'scared',
      'help',
      'hurt',
      'lonely',
      'depressed',
      'anxious',
      'worried',
      'afraid',
      'crying'
    ])) {
      return DetectedEmotion.compassionate;
    }

    if (_containsAny(lower, [
      'excited',
      'amazing',
      'wow',
      'awesome',
      'incredible',
      'fantastic',
      'great news',
      'so happy'
    ])) {
      return DetectedEmotion.enthusiastic;
    }

    if (_containsAny(lower, [
      'confused',
      "don't understand",
      "can't understand",
      'what?',
      'huh?',
      'not sure',
      'unclear',
      'lost me',
      'complicated'
    ])) {
      return DetectedEmotion.patient;
    }

    if (_containsAny(lower, [
      'tell me a story',
      'once upon',
      'story about',
      'bedtime story',
      'fairy tale',
      'legend',
      'narrate'
    ])) {
      return DetectedEmotion.storyteller;
    }

    if (_containsAny(lower, [
      'quiz',
      'test me',
      'question',
      'challenge me',
      'trivia',
      'let\'s play',
      'game',
      'score'
    ])) {
      return DetectedEmotion.gameshow;
    }

    return DetectedEmotion.neutral;
  }

  /// Adapt TTS pitch and speed for [emotion] before speaking.
  ///
  /// Returns [pitch] and [speed] applied.
  Future<Map<String, double>> adaptTone(DetectedEmotion emotion) async {
    currentEmotion.value = emotion;

    double pitch = 1.0;
    double speed = 0.75;

    switch (emotion) {
      case DetectedEmotion.compassionate:
        pitch = 0.8;
        speed = 0.65;
        break;
      case DetectedEmotion.enthusiastic:
        pitch = 1.1;
        speed = 1.0;
        break;
      case DetectedEmotion.patient:
        pitch = 0.95;
        speed = 0.70;
        break;
      case DetectedEmotion.storyteller:
        pitch = 1.05;
        speed = 0.80;
        break;
      case DetectedEmotion.gameshow:
        pitch = 1.1;
        speed = 0.95;
        break;
      case DetectedEmotion.neutral:
        pitch = 1.0;
        speed = 0.75;
        break;
    }

    try {
      _tts?.setPitch(pitch);
      _tts?.setSpeed(speed);
    } catch (e) {
      debugPrint('⚠️ [EmotionAdapter] TTS adapt failed: $e');
    }

    debugPrint(
        '🎭 [EmotionAdapter] ${emotion.name} → pitch=$pitch speed=$speed');

    return {'pitch': pitch, 'speed': speed};
  }

  // ── Private ───────────────────────────────────────────────────────────

  bool _containsAny(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));
}
