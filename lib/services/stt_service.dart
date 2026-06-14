import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

/// STT Language options
enum STTLanguage {
  englishUS,
  englishUK,
  hindi,
  hinglish,
}

/// Enhanced STT Service with multi-language support
/// Handles English, Hindi, and Hinglish speech recognition
class STTService extends GetxService {
  stt.SpeechToText _speech = stt.SpeechToText();

  // Observable states
  final isListening = false.obs;
  final isInitialized = false.obs;
  final recognizedText = ''.obs;
  final accumulatedText = ''.obs;
  final currentLanguage = STTLanguage.hinglish.obs;
  final recordingTime = 0.obs;
  final confidenceLevel = 0.0.obs;
  final status = 'Ready'.obs;

  // ── Screen-ownership flag ───────────────────────────────────────────
  // When the game screen owns STT, we suppress the user-visible error snackbars
  // because the game controller handles errors internally and will auto-restart.
  bool isGameScreenOwner = false;

  // ── Audio-session stale flag ─────────────────────────────────────────
  // Set SYNCHRONOUSLY by GardenPortalScreen the moment its WebView disposes.
  // The WebView media player (Radio/TV) takes exclusive Android audio focus
  // (STREAM_MUSIC), which silently invalidates the SpeechRecognizer even
  // though [isInitialized] stays true.  By flagging this immediately (no
  // async delay), startListening() detects and heals the stale state even if
  // the user taps the mic within milliseconds of returning from the portal.
  bool _audioSessionStale = false;

  /// Public read-only access to the stale flag (used by GardenPortalScreen
  /// to decide whether a second reinit pass is needed).
  bool get isAudioSessionStale => _audioSessionStale;

  // ── Auto-retry listen state ─────────────────────────────────────────
  // When listen() fails with error_audio, we auto-retry without any user
  // action.  The stored callbacks let _onError restart the listen session.
  Function(String)? _pendingOnResult;
  Function(String)? _pendingOnFinalResult;
  int _autoRetryCount = 0;
  static const int _maxAutoRetries = 6;

  /// True while auto-retry is in progress after an error_audio failure.
  /// The UI shows a subtle spinner so the user knows the mic is recovering.
  final isAutoRetrying = false.obs;

  /// Fires every time a portal-return reset completes.
  /// DualModeInputPanel listens to this and clears its stale text + reset button.
  final uiResetSignal = 0.obs; // increments on each reset

  // every 5 seconds regardless of how many STT restarts happen.
  DateTime? _lastErrorSnackbarTime;
  static const _snackbarCooldown = Duration(seconds: 5);

  // Timer for recording duration
  Timer? _recordingTimer;

  // Custom locale set by LanguageController (overrides enum locale)
  String? _customLocale;

  /// Expose current custom locale so snapshot service can save/restore it.
  String? get currentCustomLocale => _customLocale;

  // Language locale mapping
  final Map<STTLanguage, String> languageLocales = {
    STTLanguage.englishUS: 'en-US',
    STTLanguage.englishUK: 'en-GB',
    STTLanguage.hindi: 'hi-IN',
    STTLanguage.hinglish: 'hi-IN', // Hinglish uses Hindi locale
  };

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeSTT();
  }

  /// Initialize STT
  Future<void> _initializeSTT() async {
    try {
      debugPrint('🎤 _initializeSTT: Starting initialization...');
      final bool available = await _speech.initialize(
        onStatus: _onStatusChanged,
        onError: _onError,
        debugLogging: true,
      );

      isInitialized.value = available;

      if (available) {
        debugPrint('✅ STT Service Initialized');
      } else {
        debugPrint('❌ STT Not Available');
        status.value = 'Not Available';
      }
    } catch (e) {
      debugPrint('❌ STT Initialization Error: $e');
      status.value = 'Error';
    }
  }

  /// Status change handler
  void _onStatusChanged(String statusText) {
    debugPrint('🎤 STT Status: $statusText');

    switch (statusText) {
      case 'listening':
        isListening.value = true;
        status.value = 'Listening...';
        break;
      case 'notListening':
        isListening.value = false;
        status.value = 'Ready';
        _stopRecordingTimer();
        break;
      case 'done':
        isListening.value = false;
        status.value = 'Ready';
        _stopRecordingTimer();
        break;
    }
  }

  /// Error handler
  void _onError(dynamic error) {
    final String errMsg = error?.errorMsg?.toString() ?? '';
    debugPrint('❌ STT Error: $errMsg');
    status.value = 'Error: $errMsg';
    isListening.value = false;
    _stopRecordingTimer();

    // ── AUTO-HEALING: error_audio ───────────────────────────────────────
    // Android code 3 (ERROR_AUDIO) fires when listen() can't open the
    // audio recording channel — typically because the WebView media player
    // still holds audio focus after Radio / TV closes.
    //
    // STRATEGY: Auto-retry the full startListening() cycle using the
    // stored callbacks (_pendingOnResult / _pendingOnFinalResult) with
    // exponential back-off so the user NEVER has to tap the mic twice.
    if (errMsg.contains('error_audio') ||
        errMsg.contains('error_3') ||
        errMsg.contains('ERROR_AUDIO')) {
      if (_autoRetryCount < _maxAutoRetries && _pendingOnResult != null) {
        _autoRetryCount++;
        isAutoRetrying.value = true;
        status.value = 'Mic recovering...';

        // Exponential back-off: 1s, 2s, 3s ...
        final delay = Duration(milliseconds: 1000 * _autoRetryCount);
        debugPrint(
            '⚠️ [STTService] error_audio — auto-retry #$_autoRetryCount in ${delay.inMilliseconds}ms');

        Future.delayed(delay, () async {
          // Recreate the native binding fresh
          await reinitialize(maxAttempts: 3, retryDelayMs: 600);
          if (!isInitialized.value) {
            // Reinit failed; recurse via a synthetic error if retries remain
            debugPrint('⚠️ [STTService] Reinit during auto-retry failed');
            isAutoRetrying.value = _autoRetryCount < _maxAutoRetries;
            return;
          }
          // Re-attempt listen with the saved callbacks
          debugPrint(
              '🎤 [STTService] Auto-retry #$_autoRetryCount — calling listen()');
          await _doListen(
            onResult: _pendingOnResult,
            onFinalResult: _pendingOnFinalResult,
          );
        });
      } else {
        // Max retries exhausted
        isAutoRetrying.value = false;
        _pendingOnResult = null;
        _pendingOnFinalResult = null;
        status.value = 'Ready';
        debugPrint('❌ [STTService] error_audio auto-retry exhausted');
      }
      return; // Never show snackbar for transient audio errors
    }

    isAutoRetrying.value = false;

    // ─ Suppress snackbars when game screen owns STT ───────────────────
    if (isGameScreenOwner) {
      debugPrint(
          '\u26a0\ufe0f STT error suppressed (game screen owns STT): $errMsg');
      return;
    }

    // ─ Cooldown guard ────────────────────────────────────────────────
    final now = DateTime.now();
    if (_lastErrorSnackbarTime != null &&
        now.difference(_lastErrorSnackbarTime!) < _snackbarCooldown) {
      return;
    }

    if (errMsg.contains('notAvailable')) {
      _lastErrorSnackbarTime = now;
      Get.snackbar('Speech Recognition',
          'Speech recognition is not available on this device',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } else if (errMsg.contains('error_no_match') && recordingTime.value < 1) {
      // glitch — suppress
    } else if (errMsg.contains('error_no_match')) {
      _lastErrorSnackbarTime = now;
      Get.snackbar(
          'Speech Recognition', 'Could not understand. Please try again.',
          backgroundColor: Colors.orangeAccent, colorText: Colors.white);
    }
  }

  /// Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.status;

    if (status.isGranted) {
      return true;
    } else if (status.isDenied) {
      final result = await Permission.microphone.request();
      return result.isGranted;
    } else if (status.isPermanentlyDenied) {
      Get.snackbar(
        'Permission Required',
        'Microphone permission is required for voice input. Please enable in settings.',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        mainButton: TextButton(
          onPressed: () => openAppSettings(),
          child: const Text('SETTINGS', style: TextStyle(color: Colors.white)),
        ),
      );
      return false;
    }

    return false;
  }

  /// Start listening with specified language
  Future<bool> startListening({
    STTLanguage? language,
    Function(String)? onResult,
    Function(String)? onFinalResult,
    Duration? listenFor,
  }) async {
    debugPrint('🎤 STT startListening: Checking permission...');
    // Check permission
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      status.value = 'Permission Denied';
      debugPrint('❌ STT: Permission denied');
      return false;
    }

    // ── Store callbacks for auto-retry on error_audio ──────────────────────
    // If listen() fails, _onError uses these to re-call _doListen()
    // automatically so the user never has to tap the mic twice.
    _pendingOnResult = onResult;
    _pendingOnFinalResult = onFinalResult;
    _autoRetryCount = 0;
    isAutoRetrying.value = false;

    // ── Audio-session stale guard ───────────────────────────────────────
    // If a WebView portal (Radio/TV) marked the audio session stale, we must
    // reinitialize NOW — before calling listen(). The old SpeechRecognizer is
    // dead; isInitialized may still be true (stale cache), so we can't rely on
    // the normal isInitialized check below to catch this.
    if (_audioSessionStale) {
      debugPrint(
          '⚠️ [STTService] Audio session stale — quick reinit before listen');
      _audioSessionStale = false; // Clear before reinit to avoid re-entering

      await reinitialize(maxAttempts: 2, retryDelayMs: 400);
      debugPrint(
          '✅ [STTService] Quick reinit pass completed. Continuing to background await loop.');
    }

    // ── Wait for background initialization ──────────────────────────────
    // Instead of dropping the user's tap instantly, we wait up to 8 seconds
    // (16 polls) for any background reinitialization loops to finish reclaiming audio focus.
    int waitCount = 0;
    while (!isInitialized.value && waitCount < 16) {
      debugPrint(
          '⏳ [STTService] Waiting for background init... (\${waitCount+1}/16)');
      await Future.delayed(const Duration(milliseconds: 500));
      waitCount++;
    }

    // Check initialization (normal path — covers cold start / crash cases)
    if (!isInitialized.value) {
      debugPrint('⚠️ STT not initialized, initializing now...');
      await _initializeSTT();
      if (!isInitialized.value) {
        Get.snackbar(
          'Speech Recognition',
          'Speech recognition is not available',
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
        );
        debugPrint('❌ STT: Still not available after init');
        return false;
      }
    }

    // Set language
    if (language != null) {
      currentLanguage.value = language;
    }

    // Ensure hard reset of previous native state before starting a new one
    if (isListening.value || _speech.isListening) {
      await cancelListening(); // Aborts the previous session safely
      await Future.delayed(
          const Duration(milliseconds: 150)); // Teardown buffer
    }

    // Reset states
    recognizedText.value = '';
    accumulatedText.value = '';
    recordingTime.value = 0;
    confidenceLevel.value = 0.0;

    // Start recording timer
    _startRecordingTimer();

    await _doListen(onResult: onResult, onFinalResult: onFinalResult);
    return true;
  }

  /// Internal: calls _speech.listen() with the given callbacks.
  /// Separated so both [startListening] and the auto-retry code share
  /// the same listen logic.
  Future<void> _doListen({
    Function(String)? onResult,
    Function(String)? onFinalResult,
  }) async {
    // Get locale — prefer custom locale if set
    final String locale =
        _customLocale ?? (languageLocales[currentLanguage.value] ?? 'hi-IN');

    debugPrint('🎤 _doListen: locale=$locale');

    try {
      await _speech.listen(
        onResult: (result) {
          debugPrint(
              '🎤 STT onResult: recognized="${result.recognizedWords}", final=${result.finalResult}');
          recognizedText.value = result.recognizedWords;
          confidenceLevel.value = result.confidence;

          if (result.finalResult) {
            // Success — clear auto-retry state
            isAutoRetrying.value = false;
            _autoRetryCount = 0;
            accumulatedText.value = result.recognizedWords;
            if (onFinalResult != null) {
              debugPrint('🎤 STT: Calling onFinalResult');
              onFinalResult(result.recognizedWords);
            }
          } else if (onResult != null) {
            debugPrint('🎤 STT: Calling onResult');
            onResult(result.recognizedWords);
          }
        },
        localeId: locale,
        listenFor: const Duration(minutes: 10),
        pauseFor: const Duration(seconds: 120),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
      );

      isListening.value = true;
      status.value = 'Listening...';
    } catch (e) {
      debugPrint('❌ STT _doListen error: $e');
      isInitialized.value = false;
      isListening.value = false;
      isAutoRetrying.value = false;
      _stopRecordingTimer();
      status.value = 'Error';
      await _initializeSTT();
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    await _speech.stop();
    isListening.value = false;
    _stopRecordingTimer();
    status.value = 'Ready';
  }

  /// Cancel listening and clear text
  Future<void> cancelListening() async {
    await _speech.cancel();
    isListening.value = false;
    recognizedText.value = '';
    accumulatedText.value = '';
    _stopRecordingTimer();
    recordingTime.value = 0;
    status.value = 'Ready';
  }

  /// Start recording timer
  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    recordingTime.value = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      recordingTime.value++;
    });
  }

  /// Stop recording timer
  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  /// Format recording time to MM:SS
  String formatRecordingTime(int seconds) {
    final int minutes = seconds ~/ 60;
    final int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Set language
  void setLanguage(STTLanguage language) {
    currentLanguage.value = language;
    debugPrint('🎤 STT Language set to: ${getLanguageName(language)}');
  }

  Future<void> setLocaleFromLanguageCode(String bcp47Locale) async {
    // Intentionally NOT setting _customLocale so the user can speak freely
    // in their selected panel Language (English/Hindi/Hinglish) and have it
    // flawlessly captured before translation to the preferred destination language.
    debugPrint(
        '🎤 STT custom locale ignored for auto-translation workflow: $bcp47Locale');
  }

  /// Get language name
  String getLanguageName(STTLanguage lang) {
    switch (lang) {
      case STTLanguage.englishUS:
        return 'English (US)';
      case STTLanguage.englishUK:
        return 'English (UK)';
      case STTLanguage.hindi:
        return 'Hindi';
      case STTLanguage.hinglish:
        return 'Hinglish';
    }
  }

  /// Check if speech is available
  Future<bool> checkAvailability() async {
    if (!isInitialized.value) {
      await _initializeSTT();
    }
    return isInitialized.value;
  }

  /// Verify that STT is fully initialized and microphone hardware is accessible.
  /// Used by VoiceSessionRestorationManager to confirm recovery success.
  Future<bool> verifyReadiness() async {
    debugPrint('🔍 [STTService] Verifying hardware readiness...');

    // 1. Check native initialization state
    if (!isInitialized.value) {
      debugPrint('❌ [STTService] Readiness Check: Not initialized');
      return false;
    }

    // 2. Verify microphone permission state
    final permStatus = await Permission.microphone.status;
    if (!permStatus.isGranted) {
      debugPrint('❌ [STTService] Readiness Check: Permission not granted ($permStatus)');
      return false;
    }

    // 3. Confirm SpeechRecognizer is not in a crashed/locked state
    // Note: SpeechToText doesn't have a direct isError property.
    // We rely on the isInitialized value and status.value being neutral.
    if (status.value.toLowerCase().contains('error')) {
      debugPrint('❌ [STTService] Readiness Check: SpeechRecognizer in error state (${status.value})');
      return false;
    }

    debugPrint('✅ [STTService] Hardware readiness VERIFIED');
    return true;
  }

  /// Mark the audio session as stale due to WebView media focus steal.
  ///
  /// Call this SYNCHRONOUSLY from any screen that takes exclusive Android
  /// audio focus (e.g. GardenPortalScreen).  The next [startListening] call
  /// will detect this flag and immediately reinitialize before listening,
  /// so the mic works even if tapped within milliseconds of returning.
  void markAudioSessionStale() {
    _audioSessionStale = true;
    debugPrint('⚠️ [STTService] Audio session marked stale by WebView portal');
  }

  /// Force a full teardown + re-initialization of the STT engine.
  ///
  /// Retries up to [maxAttempts] times with [retryDelayMs] between each try.
  /// This is necessary because Android's AudioManager may not immediately
  /// release audio focus after the WebView portal closes — it can take 3-5 s.
  /// A single reinit attempt (all previous approaches) would silently fail if
  /// it fires while the focus is still held; the retry loop guarantees we
  /// succeed the first moment the OS hands focus back.
  Future<void> reinitialize({
    int maxAttempts = 10,
    int retryDelayMs = 1000,
  }) async {
    debugPrint(
        '🔄 [STTService] Starting reinitialize (maxAttempts=$maxAttempts)...');

    // Requirement 1: Reinitialize microphone permissions
    await requestPermission();

    // Clear any stale flag — this reinit makes the session fresh.
    _audioSessionStale = false;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      // Cancel any live session before each attempt.
      try {
        await _speech.cancel();
      } catch (_) {}

      // Re-create the plugin wrapper each time — this detaches from any dead
      // native AudioRecord channels left by the WebView media player.
      _speech = stt.SpeechToText();

      isListening.value = false;
      isInitialized.value = false;
      _stopRecordingTimer();
      recognizedText.value = '';
      accumulatedText.value = '';
      recordingTime.value = 0;
      status.value = 'Reinitializing...';

      // Try to initialize
      bool success = false;
      try {
        success = await _speech.initialize(
          onStatus: _onStatusChanged,
          onError: _onError,
          debugLogging: true,
        );
      } catch (e) {
        debugPrint('⚠️ [STTService] reinit attempt $attempt threw: $e');
      }

      if (success) {
        isInitialized.value = true;
        status.value = 'Ready';
        debugPrint(
            '✅ [STTService] Reinitialization succeeded on attempt $attempt');
        return; // ← Done!
      }

      debugPrint('⚠️ [STTService] reinit attempt $attempt failed'
          '${attempt < maxAttempts ? " — retrying in ${retryDelayMs}ms" : " — giving up"}');

      if (attempt < maxAttempts) {
        await Future.delayed(Duration(milliseconds: retryDelayMs));
      }
    }

    // All attempts exhausted — STT unavailable (e.g. no microphone hardware)
    isInitialized.value = false;
    status.value = 'Not Available';
    debugPrint('❌ [STTService] All $maxAttempts reinit attempts failed');
  }

  /// Hard reset — public alias for reinitialize() used by VoiceStateSnapshotService.
  /// Destroys and recreates the entire SpeechToText native binding.
  Future<void> hardReset() => reinitialize(maxAttempts: 10, retryDelayMs: 1000);

  @override
  void onClose() {
    _recordingTimer?.cancel();
    _speech.cancel();
    super.onClose();
  }
}
