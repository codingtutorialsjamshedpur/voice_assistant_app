/// ═══════════════════════════════════════════════════════════════
/// Haptic Feedback Service  (Task 4.4)
/// ═══════════════════════════════════════════════════════════════
///
/// A thin wrapper around Flutter's HapticFeedback API that
/// maps named interaction moments to concrete haptic patterns.
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class HapticFeedbackService extends GetxService {
  @override
  void onInit() {
    super.onInit();
    debugPrint('✅ [HapticFeedbackService] Initialized');
  }

  void onListening() => _trigger(HapticFeedback.lightImpact, 'listening');
  void onProcessing() => _trigger(HapticFeedback.mediumImpact, 'processing');
  void onComplete() => _trigger(HapticFeedback.heavyImpact, 'complete');
  void onError() => _trigger(HapticFeedback.vibrate, 'error');
  void onGestureRecognized() =>
      _trigger(HapticFeedback.selectionClick, 'gesture');

  void _trigger(Future<void> Function() fn, String label) {
    fn().catchError((e) {
      debugPrint('⚠️ [Haptic] "$label" failed: $e');
    });
    debugPrint('📳 [Haptic] $label');
  }
}
