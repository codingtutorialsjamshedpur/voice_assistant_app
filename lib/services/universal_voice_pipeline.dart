import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'stt_service.dart';
import 'tts_service.dart';
import '../controllers/voice_controller.dart';
import '../controllers/game_controller.dart';
import '../controllers/voice_assistant_game_controller.dart';

/// ═══════════════════════════════════════════════════════════════
/// UNIVERSAL VOICE PIPELINE
/// ═══════════════════════════════════════════════════════════════
/// A completely fresh duplicate restoration workflow built exactly as requested.
/// This pipeline safely centralizes the fragmented "tap-to-speech" loops across
/// the Voice Chat Screen, Tic Tac Toe, Voice Assistant Game, and others.
///
/// Workflow Executed Here:
/// 1. Mic Tap (Restoration safe guard against Garden Portal context loss)
/// 2. STTService.startListening()
/// 3. SpeechRecognizer Transcribes natively
/// 4. onFinalResult(text)
/// 5. Route to appropriate active controller
/// 6. AI API processes request
/// 7. Chat text displayed + TTS spoken aloud automatically
class UniversalVoicePipeline extends GetxService {
  static UniversalVoicePipeline get to => Get.find<UniversalVoicePipeline>();

  final STTService _stt = Get.find<STTService>();
  final TTSService _tts = Get.find<TTSService>();

  /// Global flag so any screen can display a "thinking" indicator
  final RxBool isProcessingAPI = false.obs;

  /// The master entry point. Fire this when ANY microphone button is tapped.
  /// It completely abstracts the restoration polling and pipeline buffering.
  Future<bool> handleMicTap({
    required Function() onUIStartPulse,
    required Function() onUIStopPulse,
    required Function(String) onPartialText,
    required BuildContext context,
  }) async {
    HapticFeedback.mediumImpact();

    // 1. If currently listening, shut down neatly.
    if (_stt.isListening.value) {
      _stt.stopListening();
      onUIStopPulse();
      return true;
    }

    // 2. Pre-flight check: Immediately halt old TTS to prevent audio loops
    if (_tts.isSpeaking.value) {
      await _tts.stop();
    }

    // 3. Audio Session Restoration (The key fix against Global Radio / World TV)
    // Wait for native background STT loops to secure Android Audio Focus
    int waitCounter = 0;
    while (!_stt.isInitialized.value && waitCounter < 20) {
      // Up to 10s wait lock
      await Future.delayed(const Duration(milliseconds: 500));
      waitCounter++;
    }

    // If it *still* isn't initialized natively after 10s, abort gracefully.
    if (!_stt.isInitialized.value) {
      debugPrint(
          '❌ [UniversalVoicePipeline] STT failed to initialize context native microphone.');
      Get.snackbar(
        'Microphone Occupied',
        'System audio is still recovering. Please tap again.',
        backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
      onUIStopPulse();
      return false;
    }

    // 4. Start the Mic Sequence securely
    onUIStartPulse();
    isProcessingAPI.value = false;

    final success = await _stt.startListening(
      onResult: (text) {
        onPartialText(text); // Update any external UI text field in real-time
      },
      onFinalResult: (text) async {
        onUIStopPulse();
        // 5. STT finished — Hand off captured text to the correct AI engine
        if (text.trim().isNotEmpty) {
          isProcessingAPI.value = true;
          await _routeVoiceQueryToAIEngine(text);
          isProcessingAPI.value = false;
        }
      },
    );

    // If native plugin immediately refused, halt UI as well.
    if (!success) {
      onUIStopPulse();
    }
    return success;
  }

  /// 6 & 7. Determine which screen is active, push to its specific AI handler,
  /// causing chat update and TTS spoken aloud to trigger naturally.
  Future<void> _routeVoiceQueryToAIEngine(String queryText) async {
    final currentRoute = Get.currentRoute;
    debugPrint(
        '🛤️ [UniversalVoicePipeline] Routing query ("$queryText") for route: $currentRoute');

    try {
      // --> Route A: Game Screens (Tic Tac Toe, Ball Sort Puzzle, etc.)
      if (Get.isRegistered<GameController>() &&
          Get.find<GameController>().activeGame.value != null) {
        final gc = Get.find<GameController>();
        await gc.processGameInput(queryText);
        return;
      }

      // --> Route B: Dedicated Voice Assistant Game Screen
      if (Get.isRegistered<VoiceAssistantGameController>()) {
        final vac = Get.find<VoiceAssistantGameController>();
        // Internal controller handles API -> Text -> TTS automatically
        await vac.publicProcessUserSpeech(queryText);
        return;
      }

      // --> Route C: Voice Chat Screen (Default Core App Behavior)
      // Satisfies: VoiceController.sendMessage(text) -> AI API -> Chat displayed + TTS
      if (Get.isRegistered<VoiceController>()) {
        final vc = Get.find<VoiceController>();
        await vc.processVoiceInput(queryText);
        return;
      }
    } catch (e) {
      debugPrint('❌ [UniversalVoicePipeline] Error routing query: $e');
      Get.snackbar('Error', 'Failed to process voice query');
    }
  }
}
