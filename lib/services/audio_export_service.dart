import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'tts_service.dart';
import 'tts_sanitizer.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AudioExportService
///
/// Provides per-message TTS audio file generation, playback, sharing and
/// deletion for the VoiceChatScreen and VoiceAssistantGameScreen.
///
/// Observable state per messageId:
///   audioFiles         → path of ready file  (null = not yet generated)
///   isGenerating       → synthesis is in progress
///   generationProgress → 0.0–1.0 estimated progress during synthesis
///   currentlyPlayingId → which message is actively playing back
///
/// Usage flow:
///   1. generateAudioFile(messageId, text)   → synthesises to a temp .wav
///   2. playAudio(messageId)                 → plays via just_audio
///   3. shareAudio(messageId)                → opens system share sheet
///   4. deleteAudio(messageId)               → removes temp file + clears state
///   5. cancelGeneration(messageId)          → stops synthesis in progress
/// ─────────────────────────────────────────────────────────────────────────────
class AudioExportService extends GetxService {
  // ── Internal TTS engine for file synthesis (separate from the main TTSService)
  final FlutterTts _exportTts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();

  // ── Observable state keyed by messageId ──────────────────────────────────

  /// messageId → absolute file path (non-null = file exists and is ready)
  final audioFiles = <String, String>{}.obs;

  /// Which message is currently being synthesised
  final isGenerating = <String, bool>{}.obs;

  /// Estimated synthesis progress per message (0.0 – 1.0)
  final generationProgress = <String, double>{}.obs;

  /// Which message is currently being played back
  final currentlyPlayingId = ''.obs;

  // ── Global "is any synthesis in progress?" convenience flag ──────────────
  final RxBool anyGenerating = false.obs;

  // Internal progress timers
  final _progressTimers = <String, Timer>{};

  // Cancellation tokens per message (simple map, not observable)
  final _cancellationTokens = <String, bool>{};
  @override
  Future<void> onInit() async {
    super.onInit();
    await _initExportTts();

    // Clean up when playback ends naturally
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        currentlyPlayingId.value = '';
      }
    });
  }

  Future<void> _initExportTts() async {
    try {
      await _exportTts.setLanguage('hi-IN');
      await _exportTts.setSpeechRate(0.75);
      await _exportTts.setPitch(1.2);
      await _exportTts.setVolume(1.0);
      debugPrint('✅ AudioExportService: export TTS ready');
    } catch (e) {
      debugPrint('❌ AudioExportService init error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // GENERATE
  // ──────────────────────────────────────────────────────────────────────────

  /// Synthesise [text] to a WAV file and store the path under [messageId].
  ///
  /// Progress (0.0 – 1.0) is estimated based on character count and exposed
  /// via [generationProgress] so the UI can show a determinate progress ring.
  ///
  /// [brandingScreen] controls which branding tag is appended:
  ///   - 'voiceChat'  → "...via Voice Chat."
  ///   - 'game'       → "...via Voice Assistant."
  ///
  /// Returns the file path on success, null on failure.
  Future<String?> generateAudioFile(
    String messageId,
    String text, {
    String brandingScreen = 'voiceChat',
    String? languageCode,
  }) async {
    if (isGenerating[messageId] == true) return null;

    // ── Mark as generating and reset progress ──
    isGenerating[messageId] = true;
    generationProgress[messageId] = 0.0;
    anyGenerating.value = true;
    isGenerating.refresh();
    generationProgress.refresh();

    // ── Reset cancellation flag ──
    _cancellationTokens[messageId] = false;

    // ── Start pseudo-progress ticking ──────────────────────────────────────
    final charCount = text.length;
    final estimatedMs = (charCount * 1.2).clamp(2000.0, 30000.0);
    const tickMs = 120;
    final totalTicks = estimatedMs / tickMs;
    int tickCount = 0;

    _progressTimers[messageId]?.cancel();
    _progressTimers[messageId] = Timer.periodic(
      const Duration(milliseconds: tickMs),
      (t) {
        if (_cancellationTokens[messageId] == true) {
          t.cancel();
          return;
        }
        tickCount++;
        final progress = (tickCount / totalTicks).clamp(0.0, 0.92);
        generationProgress[messageId] = progress;
        generationProgress.refresh();
        if (progress >= 0.92) t.cancel();
      },
    );
    // ───────────────────────────────────────────────────────────────────────────

    try {
      // ── 1. Sanitise text ──
      final clean = TtsSanitizer.sanitize(text);

      // ── 2. Branded outro ──
      final branding = brandingScreen == 'game'
          ? 'This audio was generated using CTJ Chat v1.0 via Voice Assistant. Thank you for using our app.'
          : 'This audio was generated using CTJ Chat v1.0 via Voice Chat. Thank you for using our app.';
      final finalText = '$clean. $branding';

      // ── 3. Build locale fallback chain ─────────────────────────────────────
      // Not all device TTS engines support every BCP-47 locale for FILE synthesis
      // (synthesizeToFile).  We try the requested locale first, then fall back to
      // hi-IN (always present on Indian devices) then en-US as a last resort.
      String primaryLocale = 'hi-IN';
      try {
        final mainTts = Get.find<TTSService>();
        switch (mainTts.currentLanguage.value) {
          case TTSLanguage.english:
            primaryLocale = 'en-US';
            break;
          case TTSLanguage.hindi:
          case TTSLanguage.hinglish:
            primaryLocale = 'hi-IN';
            break;
        }
      } catch (_) {}

      // Explicit languageCode always takes priority
      if (languageCode != null && languageCode.isNotEmpty) {
        primaryLocale = languageCode;
      }

      // Fallback chain: requested locale → hi-IN → en-US
      final List<String> localeFallbacks = [
        primaryLocale,
        if (primaryLocale != 'hi-IN') 'hi-IN',
        if (primaryLocale != 'en-US') 'en-US',
      ];

      // ── 4. Build output path ──
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/ctj_audio_$timestamp.wav';

      // ── 5. Attempt synthesis with locale fallbacks ──────────────────────
      String? successPath;
      for (final locale in localeFallbacks) {
        // Check user didn't cancel while we were iterating fallbacks
        if (_cancellationTokens[messageId] == true) break;

        debugPrint(
            '🎤 AudioExportService: trying locale=$locale, chars=$charCount');

        // Set up a fresh completion completer for each attempt
        final completer = Completer<bool>();
        _exportTts.setCompletionHandler(() {
          if (!completer.isCompleted) completer.complete(true);
        });
        _exportTts.setErrorHandler((msg) {
          debugPrint(
              '🟥 AudioExportService TTS error for locale $locale: $msg');
          if (!completer.isCompleted) completer.complete(false);
        });

        try {
          await _exportTts.setLanguage(locale);
        } catch (e) {
          debugPrint('⚠️ AudioExportService: setLanguage($locale) failed: $e');
          continue; // try next fallback
        }

        final result = await _exportTts.synthesizeToFile(finalText, path);
        debugPrint(
            '📁 synthesizeToFile result=$result  locale=$locale  path=$path');

        // result==1 means the engine accepted the request; wait for completion
        if (result == 1) {
          bool completed = false;
          try {
            completed = await completer.future.timeout(
              Duration(milliseconds: estimatedMs.toInt() + 8000),
            );
          } catch (_) {
            debugPrint(
                '⏳ AudioExportService: synthesis timed out for locale=$locale');
            completed = false;
          }

          if (!completed) {
            // Synthesis started but TTS never called completionHandler —
            // try stopping and move to next fallback locale
            try {
              await _exportTts.stop();
            } catch (_) {}
            continue;
          }

          // Check if user cancelled during synthesis
          if (_cancellationTokens[messageId] == true) break;

          // Verify file was actually written
          final file = File(path);
          if (await file.exists() && await file.length() > 0) {
            successPath = path;
            break; // 🎉 success
          }

          // Check alternative extensions the plugin may use
          for (final ext in ['.wav', '.mp3', '.aac']) {
            final altPath = '${dir.path}/ctj_audio_$timestamp$ext';
            final altFile = File(altPath);
            if (await altFile.exists() && await altFile.length() > 0) {
              successPath = altPath;
              break;
            }
          }
          if (successPath != null) break;

          debugPrint(
              '⚠️ AudioExportService: file empty/missing for locale=$locale, trying fallback');
        } else {
          // Engine rejected the request immediately (result != 1)
          debugPrint(
              '⚠️ AudioExportService: synthesizeToFile rejected (result=$result) for locale=$locale');
        }
      } // end for fallback loop

      // Cancel user-cancel path
      if (_cancellationTokens[messageId] == true) {
        debugPrint('⏸️ AudioExportService: generation cancelled by user');
        _progressTimers[messageId]?.cancel();
        _cleanup(messageId, failed: true);
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {}
        return null;
      }

      _progressTimers[messageId]?.cancel();

      if (successPath != null) {
        generationProgress[messageId] = 1.0;
        generationProgress.refresh();
        await Future.delayed(const Duration(milliseconds: 200));
        audioFiles[messageId] = successPath;
        audioFiles.refresh();
        _cleanup(messageId);
        return successPath;
      }

      debugPrint(
          '⚠️ AudioExportService: all locale fallbacks exhausted, file not found');
      _cleanup(messageId, failed: true);
      return null;
    } catch (e) {
      debugPrint('❌ AudioExportService.generateAudioFile: $e');
      _cleanup(messageId, failed: true);
      return null;
    }
  }

  void _cleanup(String messageId, {bool failed = false}) {
    _progressTimers[messageId]?.cancel();
    _progressTimers.remove(messageId);
    _cancellationTokens.remove(messageId); // Clean up cancellation token
    isGenerating[messageId] = false;
    isGenerating.refresh();
    if (failed) {
      generationProgress[messageId] = 0.0;
      generationProgress.refresh();
    }
    // Recompute global flag
    anyGenerating.value = isGenerating.values.any((v) => v == true);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PLAYBACK
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> playAudio(String messageId) async {
    final path = audioFiles[messageId];
    if (path == null) return;

    try {
      if (_player.playing) await _player.stop();
      currentlyPlayingId.value = messageId;
      await _player.setFilePath(path);
      _player.play();
    } catch (e) {
      debugPrint('❌ AudioExportService.playAudio: $e');
      currentlyPlayingId.value = '';
    }
  }

  Future<void> stopPlayback() async {
    try {
      await _player.stop();
      currentlyPlayingId.value = '';
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SHARE
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> shareAudio(String messageId) async {
    final path = audioFiles[messageId];
    if (path == null) return;

    try {
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Check this voice message from CTJ Voice Chat 🎙️',
        subject: 'CTJ Voice Chat – Audio Message',
      );
    } catch (e) {
      debugPrint('❌ AudioExportService.shareAudio: $e');
      Get.snackbar(
        'Share Error',
        'Could not share the audio file.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade800,
        colorText: Colors.white,
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DELETE
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> deleteAudio(String messageId) async {
    final path = audioFiles[messageId];
    if (path == null) return;

    if (currentlyPlayingId.value == messageId) await stopPlayback();

    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}

    audioFiles.remove(messageId);
    isGenerating.remove(messageId);
    generationProgress.remove(messageId);
    audioFiles.refresh();
    generationProgress.refresh();
    anyGenerating.value = isGenerating.values.any((v) => v == true);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CANCEL GENERATION
  // ──────────────────────────────────────────────────────────────────────────

  /// Cancel synthesis for a specific message
  Future<void> cancelGeneration(String messageId) async {
    if (isGenerating[messageId] != true) return;

    debugPrint('⏸️ AudioExportService: cancelling generation for $messageId');

    // Set cancellation flag
    _cancellationTokens[messageId] = true;

    // Stop the progress timer
    _progressTimers[messageId]?.cancel();

    // Try to stop TTS (may not work mid-synthesis)
    try {
      await _exportTts.stop();
    } catch (_) {}

    // Cleanup state
    _cleanup(messageId, failed: true);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  bool isFileReady(String messageId) =>
      audioFiles.containsKey(messageId) && audioFiles[messageId] != null;

  bool isPlaying(String messageId) =>
      currentlyPlayingId.value == messageId && _player.playing;

  bool isCurrentlyGenerating(String messageId) =>
      isGenerating[messageId] == true;

  double getProgress(String messageId) => generationProgress[messageId] ?? 0.0;

  @override
  void onClose() {
    for (final t in _progressTimers.values) {
      t.cancel();
    }
    _progressTimers.clear();
    _player.dispose();
    super.onClose();
  }
}
