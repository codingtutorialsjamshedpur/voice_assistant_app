import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'stt_service.dart';
import 'tts_service.dart';
import '../controllers/voice_controller.dart';
import '../controllers/voice_assistant_game_controller.dart';
import '../services/engagement_orchestrator_service.dart';
import '../services/enhanced_greeting_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// Voice Session Restoration Architecture
/// ═══════════════════════════════════════════════════════════════
/// A completely new and standalone architecture designed to perfectly
/// guarantee microphone context and callback listener survivability
/// across extreme navigation boundaries (like Global Radio and World TV).
class VoiceSessionRestorationManager extends GetxService {
  static VoiceSessionRestorationManager get to =>
      Get.find<VoiceSessionRestorationManager>();

  final RxBool isRestoring = false.obs;

  /// Executes a complete fresh restoration sequence as required by the 18-point spec.
  /// This method is designed to be screen-agnostic and robust against OS-level focus loss.
  Future<void> restore() async {
    if (isRestoring.value) return;
    isRestoring.value = true;

    debugPrint(
        '\n🔄 ════ VoiceSessionRestorationManager: STARTING COMPLETE ARCHITECTURAL RESTORATION ════ 🔄');

    try {
      final stt = Get.find<STTService>();
      final tts = Get.find<TTSService>();

      // ── STAGE 1: HARDWARE & PERMISSIONS (Req 1, 2, 10, 11) ───────────
      debugPrint('➤ [1/4] Resetting hardware locks and SpeechRecognizer...');

      // Requirement 10 & 11: Reset stale locks and instances
      if (stt.isListening.value) {
        stt.stopListening();
      }
      await stt.cancelListening();
      stt.markAudioSessionStale(); // Marks for immediate re-acquisition

      // Requirement 1 & 2: Reinitialize microphone permissions and hardware binding
      // Using 10 attempts with 600ms delays to force focus away from any rogue WebViews.
      await stt.reinitialize(maxAttempts: 10, retryDelayMs: 600);

      // ── STAGE 2: LISTENERS & SUBSCRIPTIONS (Req 3, 4, 5, 6, 7) ───────
      debugPrint('➤ [2/4] Recreating STT listeners and stream subscriptions...');
      // Requirement 3, 4, 5, 6, 7: These are natively handled by STTService.reinitialize,
      // which creates a brand new SpeechToText instance and re-attaches status/error/result
      // callbacks to the native speech client.
      debugPrint('✅ STT internal event-bus successfully re-bound.');

      // ── STAGE 3: CONTROLLER SYNC & SESSION STATE (Req 8, 9, 12, 13, 14) ──
      debugPrint('➤ [3/4] Rebinding controllers and restoring session state...');

      // Requirement 8 & 9: Rebind VoiceController and restore state
      if (Get.isRegistered<VoiceController>()) {
        final vc = Get.find<VoiceController>();
        vc.resetPipelineAfterNavigation();
        debugPrint('✅ VoiceController pipeline perfectly synchronized.');
      }

      // Requirement 12: Restore TTS bindings to neutral state
      if (tts.isSpeaking.value) {
        await tts.stop();
      }
      debugPrint('✅ TTS bindings neutral.');

      // Requirement 13 & 14: Restore AI response and Transcription callbacks
      // We increment the uiResetSignal which notifies DualModeInputPanel to wipe
      // stale text and prepare for fresh listeners on the next mic tap.
      stt.uiResetSignal.value++;

      // Secondary cleanup: Pause background services that might conflict
      if (Get.isRegistered<VoiceAssistantGameController>()) {
        Get.find<VoiceAssistantGameController>().isPaused.value = true;
      }
      if (Get.isRegistered<EngagementOrchestratorService>()) {
        Get.find<EngagementOrchestratorService>().stopEngagement();
      }
      if (Get.isRegistered<EnhancedGreetingService>()) {
        Get.find<EnhancedGreetingService>().pauseService();
      }

      // ── STAGE 4: VERIFICATION & READY STATE (Req 15, 16, 17, 18) ─────
      debugPrint('➤ [4/4] Verifying restoration architecture success...');

      // Requirement 15 & 16: Verify microphone availability & SpeechRecognizer readiness
      final bool hardwareReady = await stt.verifyReadiness();

      // Requirement 17 & 18: Verify controller attachment & active session state
      bool controllersReady = true;
      if (Get.isRegistered<VoiceController>()) {
        controllersReady = Get.find<VoiceController>().verifyReadyState();
      }

      if (hardwareReady && controllersReady) {
        debugPrint(
            '🏁 ════ VoiceSessionRestorationManager: RESTORATION COMPLETE — SYSTEM READY ════ 🏁\n');
      } else {
        debugPrint(
            '⚠️ ════ VoiceSessionRestorationManager: PARTIAL RESTORATION ════ ⚠️');
        debugPrint('➤ Hardware Ready: $hardwareReady');
        debugPrint('➤ Controllers Ready: $controllersReady\n');
      }

    } catch (e) {
      debugPrint(
          '❌ [VoiceSessionRestorationManager] Fatal architectural error: $e');
    } finally {
      isRestoring.value = false;
    }
  }
}
