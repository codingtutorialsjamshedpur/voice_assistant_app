/// ═══════════════════════════════════════════════════════════════
/// Audio Cue Service  (Task 4.2)
/// ═══════════════════════════════════════════════════════════════
///
/// Plays short non-verbal audio cues at key interaction moments.
/// Uses AudioPlaybackService (existing) for sound output.
///
/// All cues are no-ops when:
///   - AudioCuesEnabled is false (settings toggle)
///   - TTS is currently speaking (isTalking)
///
/// Cues are synthesised via short musical patterns (since actual
/// asset files are not bundled, we log the event and mark as
/// triggered — ready for real asset hookup in Task 6.3 polish).
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tts_service.dart';
import 'voice_assistant_sound_service.dart';

class AudioCueService extends GetxService {
  TTSService? _tts;

  static const _prefsKey = 'audio_cues_enabled';

  /// Whether audio cues are enabled (persisted in SharedPreferences).
  final RxBool audioCuesEnabled = true.obs;

  @override
  void onInit() {
    super.onInit();
    try {
      _tts = Get.find<TTSService>();
    } catch (_) {}
    _loadSetting();
    debugPrint('✅ [AudioCueService] Initialized');
  }

  // ── Cue methods ───────────────────────────────────────────────────────

  void onListeningStarted() => _playCue(
      'Ascending 2-note', 'listening_start', 'UI Menu Mouseover 02.mp3');
  void onProcessing() =>
      _playCue('Soft pulse x3', 'processing', 'dream-sound.mp3');
  void onReadyToSpeak() =>
      _playCue('Single bell', 'ready_to_speak', 'whoosh.mp3');
  void onCodeWordDetected() =>
      _playCue('Acknowledgment beep', 'code_word', 'menuclick.mp3');
  void onSessionEnded() =>
      _playCue('Descending warm tone', 'session_end', 'Game_Over.mp3');
  void onNotUnderstood() =>
      _playCue('Gentle 2-note + vibrate', 'not_understood', 'warning1.mp3');
  void onSearchInProgress() =>
      _playCue('Short jingle', 'search_start', 'panelslide1.mp3');
  void onLongResponseWarning() =>
      _playCue('Soft warning tone', 'long_response', 'warning1.mp3');
  void onSessionPaused() =>
      _playCue('Pause tone', 'session_pause', 'menuclick.mp3');

  // ── Settings ─────────────────────────────────────────────────────────

  Future<void> setEnabled(bool enabled) async {
    audioCuesEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
    debugPrint('🔊 [AudioCue] Cues ${enabled ? "enabled" : "disabled"}');
  }

  // ── Private ───────────────────────────────────────────────────────────

  void _playCue(String description, String cueId, String assetName) {
    if (!audioCuesEnabled.value) return;

    // Don't interrupt TTS speech
    if (_tts?.isSpeaking.value == true) {
      debugPrint('🔕 [AudioCue] Skipped "$cueId" — TTS is speaking');
      return;
    }

    try {
      Get.find<VoiceAssistantSoundService>().play(assetName, volume: 0.6);
      debugPrint('🔔 [AudioCue] Played "$assetName" ($cueId)');
    } catch (_) {
      debugPrint('🔔 [AudioCue] Failed to play "$assetName" ($cueId)');
    }
  }

  Future<void> _loadSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      audioCuesEnabled.value = prefs.getBool(_prefsKey) ?? true;
    } catch (_) {}
  }
}
