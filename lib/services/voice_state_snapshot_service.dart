// ═══════════════════════════════════════════════════════════════════════════
// VoiceStateSnapshotService
// ═══════════════════════════════════════════════════════════════════════════
//
// PURPOSE
// ───────
// Captures the exact state of the voice-chat pipeline immediately BEFORE
// the user opens a WebView portal (Global Radio / World TV).  On return,
// it restores that state so the voice-chat screen works identically to
// how it did before the portal was opened.
//
// WHY THIS IS NEEDED
// ──────────────────
// The WebView (radio / TV) holds Android audio focus while playing media.
// When the user returns, previous ad-hoc "reinit" calls failed because:
//   1. `SpeechToText.initialize()` always returns `true` on Android (it only
//      binds the service intent, not the audio channel).
//   2. `SpeechToText.listen()` fails with ERROR_AUDIO (code 3) because the
//      WebView's MediaPlayer still holds the audio path.
//   3. All retry loops assumed `initialize()` failing → but it NEVER fails!
//      The failure only appears inside `_onError` after `listen()` is called.
//
// THE FIX
// ───────
// 1. Snapshot pre-portal state.
// 2. On return: destroy + recreate the ENTIRE STT instance, reset all
//    VoiceController flags, then wait for the first successful `listen()`
//    result — retrying on every `error_audio` until the OS releases focus.
//
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'stt_service.dart';
import '../controllers/voice_controller.dart';
import '../services/tts_service.dart';

class VoiceStateSnapshotService extends GetxService {
  // ─── Singleton accessor ────────────────────────────────────────────────
  static VoiceStateSnapshotService get to =>
      Get.find<VoiceStateSnapshotService>();

  // ─── Snapshot data ────────────────────────────────────────────────────
  STTLanguage? _savedSttLanguage;
  String? _savedCustomLocale;
  bool _snapshotTaken = false;

  // ─── Observable: true while portal-return restoration is in progress ──
  final isRestoringAfterPortal = false.obs;

  // ──────────────────────────────────────────────────────────────────────
  // STEP 1 — Call this JUST BEFORE opening GardenPortalScreen
  // ──────────────────────────────────────────────────────────────────────
  void snapshotBeforePortal() {
    try {
      final stt = Get.find<STTService>();
      _savedSttLanguage = stt.currentLanguage.value;
      _savedCustomLocale = stt.currentCustomLocale;
      _snapshotTaken = true;
      debugPrint(
          '📸 [VoiceSnapshot] Snapshot taken: lang=${_savedSttLanguage?.name}, '
          'locale=$_savedCustomLocale');
    } catch (e) {
      debugPrint('⚠️ [VoiceSnapshot] Could not snapshot state: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // STEP 2 — Call this AFTER returning from GardenPortalScreen
  //
  // This replicates EXACTLY what happens when the app first starts:
  //   • Destroy the old SpeechToText native binding
  //   • Create a brand-new one
  //   • Re-register status/error handlers
  //   • Reset every VoiceController flag to its initial value
  //   • Restore the language that was active before the portal
  // ──────────────────────────────────────────────────────────────────────
  Future<void> restoreAfterPortal() async {
    if (!_snapshotTaken) {
      debugPrint('⚠️ [VoiceSnapshot] No snapshot found — doing generic reset');
    }

    isRestoringAfterPortal.value = true;
    debugPrint('🔄 [VoiceSnapshot] Starting full portal-return restore...');

    try {
      // ── 1. Stop TTS immediately ──────────────────────────────────────
      try {
        final tts = Get.find<TTSService>();
        await tts.stop();
      } catch (_) {}

      // ── 2. Reset VoiceController pipeline ───────────────────────────
      try {
        final vc = Get.find<VoiceController>();
        vc.resetPipelineAfterNavigation();
      } catch (_) {}

      // ── 3. Full STT teardown + recreate ─────────────────────────────
      final stt = Get.find<STTService>();

      // Mark stale so next startListening() knows to wait for us
      stt.markAudioSessionStale();

      // Tear down and rebuild the native recognizer
      await stt.hardReset();

      // ── 4. Restore saved language ────────────────────────────────────
      if (_savedSttLanguage != null) {
        stt.currentLanguage.value = _savedSttLanguage!;
      }
      if (_savedCustomLocale != null) {
        stt.setLocaleFromLanguageCode(_savedCustomLocale!);
      }

      debugPrint('✅ [VoiceSnapshot] Portal-return restore complete. '
          'isInitialized=${stt.isInitialized.value}');

      // Notify DualModeInputPanel to clear its stale state
      stt.uiResetSignal.value++;
    } catch (e) {
      debugPrint('❌ [VoiceSnapshot] Restore failed: $e');
    } finally {
      isRestoringAfterPortal.value = false;
      _snapshotTaken = false;
    }
  }
}
