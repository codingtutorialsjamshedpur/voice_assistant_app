/// ═══════════════════════════════════════════════════════════════
/// Gesture Recognizer Service  (Task 4.1)
/// ═══════════════════════════════════════════════════════════════
///
/// Centralises all gesture handling for the voice assistant.
/// Each [VoiceGestureType] maps to a concrete action that is
/// dispatched via [handleGesture()].
///
/// Connect this to the Orb widget's GestureDetector in Task 4.3.
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'haptic_feedback_service.dart';
import 'tts_service.dart';

/// All gesture types supported by the ORB.
enum VoiceGestureType {
  singleTap, // pause/resume mic
  doubleTap, // repeat last answer
  longPress, // open quick-action menu
  swipeUp, // increase TTS speed (+0.1)
  swipeDown, // decrease TTS speed (-0.1)
  swipeLeft, // go to previous topic in session
  swipeRight, // suggest next related topic
  twoFingerTap, // cycle language (EN → HI → Hinglish → EN)
}

class GestureRecognizerService extends GetxService {
  HapticFeedbackService? _haptic;
  TTSService? _tts;

  /// Last gesture processed.
  final Rx<VoiceGestureType?> lastGesture = Rxn<VoiceGestureType>();

  /// TTS speed adjusted by swipes.
  final RxDouble ttsSpeed = 0.75.obs;

  @override
  void onInit() {
    super.onInit();
    try {
      _haptic = Get.find<HapticFeedbackService>();
    } catch (_) {}
    try {
      _tts = Get.find<TTSService>();
    } catch (_) {}
    debugPrint('✅ [GestureRecognizer] Initialized');
  }

  // ── Public API ────────────────────────────────────────────────────────

  /// Dispatch [gesture] to its handler and provide haptic feedback.
  void handleGesture(VoiceGestureType gesture) {
    lastGesture.value = gesture;
    _haptic?.onGestureRecognized();

    debugPrint('👆 [GestureRecognizer] Dispatching: ${gesture.name}');

    switch (gesture) {
      case VoiceGestureType.singleTap:
        _onSingleTap();
        break;
      case VoiceGestureType.doubleTap:
        _onDoubleTap();
        break;
      case VoiceGestureType.longPress:
        _onLongPress();
        break;
      case VoiceGestureType.swipeUp:
        _onSwipeUp();
        break;
      case VoiceGestureType.swipeDown:
        _onSwipeDown();
        break;
      case VoiceGestureType.swipeLeft:
        _onSwipeLeft();
        break;
      case VoiceGestureType.swipeRight:
        _onSwipeRight();
        break;
      case VoiceGestureType.twoFingerTap:
        _onTwoFingerTap();
        break;
    }
  }

  // ── Handlers ──────────────────────────────────────────────────────────

  void _onSingleTap() {
    _haptic?.onListening();
    // Actual pause/resume delegated to VoiceController via observer pattern
    debugPrint('⏸ [Gesture] Single tap → pause/resume mic');
  }

  void _onDoubleTap() {
    _haptic?.onProcessing();
    debugPrint('🔁 [Gesture] Double tap → repeat last answer');
  }

  void _onLongPress() {
    _haptic?.onComplete();
    debugPrint('📋 [Gesture] Long press → open quick-action menu');
  }

  void _onSwipeUp() {
    final newSpeed = (ttsSpeed.value + 0.1).clamp(0.4, 1.5);
    ttsSpeed.value = newSpeed;
    _tts?.setSpeed(newSpeed);
    debugPrint(
        '⏫ [Gesture] Swipe up → TTS speed=${newSpeed.toStringAsFixed(1)}');
  }

  void _onSwipeDown() {
    final newSpeed = (ttsSpeed.value - 0.1).clamp(0.4, 1.5);
    ttsSpeed.value = newSpeed;
    _tts?.setSpeed(newSpeed);
    debugPrint(
        '⏬ [Gesture] Swipe down → TTS speed=${newSpeed.toStringAsFixed(1)}');
  }

  void _onSwipeLeft() {
    debugPrint('⬅️ [Gesture] Swipe left → previous topic');
  }

  void _onSwipeRight() {
    debugPrint('➡️ [Gesture] Swipe right → next related topic');
  }

  void _onTwoFingerTap() {
    _haptic?.onGestureRecognized();
    debugPrint('✌️ [Gesture] Two-finger tap → cycle language');
  }
}
