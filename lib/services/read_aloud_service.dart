import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/voice_controller.dart';
import '../services/tts_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// Read Aloud Service
/// ═══════════════════════════════════════════════════════════════
/// Handles text-to-speech read operations across all screens.
///
/// When user presses the "Read" button:
/// - Adds the text as a user message to Voice Chat Screen
/// - Triggers TTS to speak the text
/// - Activates AI Agent Orb animation (120px) with talking gestures
///
/// IMPORTANT: This is NOT an AI query - the text is read as-is
/// without processing through AI models.
///
/// This service is used by the GlassInputPanel (DualModeInputPanel)
/// across all 9 screens:
/// - Voice Chat Screen
/// - Game Screen
/// - Voice Studio Screen
/// - Alarm Screen
/// - Naam Jaap Screen
/// - History Screen
/// - Settings Screen
/// - Reminders Screen
/// - About Screen
/// ═══════════════════════════════════════════════════════════════
class ReadAloudService extends GetxService {
  static ReadAloudService get to => Get.find<ReadAloudService>();

  // Track if currently reading
  final isReading = false.obs;

  /// Read text aloud with full Voice Chat integration
  ///
  /// [text] - The text to read
  /// [addToChat] - Whether to add as message in Voice Chat (default: true)
  /// [showOrbAnimation] - Whether to show AI Orb animation (default: true)
  Future<void> readText({
    required String text,
    bool addToChat = true,
    bool showOrbAnimation = true,
  }) async {
    if (text.trim().isEmpty) return;

    // ── Re-entry guard: prevent double-tap from adding duplicate messages ──
    // If a previous read is already in flight, stop it and start fresh.
    if (isReading.value) {
      debugPrint(
          '🔇 [ReadAloudService] Already reading — stopping before new read');
      stopReading();
      await Future.delayed(const Duration(milliseconds: 150));
    }

    isReading.value = true;

    try {
      final vc = Get.find<VoiceController>();

      // Stop any overlapping TTS that may still be running
      try {
        await vc.stopSpeaking();
      } catch (_) {}

      // ── Immediate feedback — shown BEFORE awaiting TTS so the user knows
      // the button worked even though the bottom sheet has already closed.
      Get.snackbar(
        '🔊 Reading',
        'Playing your text aloud...',
        backgroundColor: Colors.blue.withAlpha(230),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
        snackPosition: SnackPosition.TOP,
        icon: const Icon(Icons.volume_up, color: Colors.white),
      );

      // Create message (isReadAloud = true so UI shows AudioExportPanel)
      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'user',
        content: text,
        timestamp: DateTime.now(),
        modelName: null,
        isReadAloud: true,
      );

      // Add exactly ONE message to the chat list
      vc.messages.add(message);

      // Scroll to the new message
      Future.delayed(const Duration(milliseconds: 100), () {
        if (vc.scrollController.hasClients) {
          vc.scrollController.animateTo(
            vc.scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      // Speak via the chunked TTS flow (handles word highlighting & orb)
      await vc.speakMessage(message);
    } catch (e) {
      debugPrint('ReadAloudService error: $e');
    } finally {
      isReading.value = false;
    }
  }

  /// Stop current reading
  void stopReading() {
    try {
      final ttsService = Get.find<TTSService>();
      ttsService.stop();
      isReading.value = false;
    } catch (_) {}
  }
}
