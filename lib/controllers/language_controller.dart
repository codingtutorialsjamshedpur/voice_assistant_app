import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/storage_service.dart';
import '../models/language_model.dart';
import '../constants/language_constants.dart';
import '../services/language_model_service.dart';
import '../services/tts_engine_switcher.dart';
import '../services/stt_service.dart';

/// GetX controller for language selection and model download state
class LanguageController extends GetxController {
  static const String _prefKey = 'selected_language_code';

  // ── Observables ──────────────────────────────────────────────────────────────
  final selectedLanguage = Rx<LanguageModel>(kAllLanguages
      .firstWhere((l) => l.code == 'hi', orElse: () => kAllLanguages[0]));
  final downloadedVoiceIds = <String>[].obs;
  final isDownloading = false.obs;
  final downloadProgress = 0.0.obs;
  final downloadStatusMessage = ''.obs;
  final showDownloadPrompt = false.obs;
  final pendingLanguage = Rxn<LanguageModel>();

  // ── Lazy services ────────────────────────────────────────────────────────────
  LanguageModelService get _modelService => Get.find<LanguageModelService>();
  TtsEngineSwitcher get _engineSwitcher => Get.find<TtsEngineSwitcher>();
  STTService get _sttService => Get.find<STTService>();

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  Future<void> _initialize() async {
    debugPrint('🌐 [LanguageController] Initializing...');

    // RULE: User Preference > Default Language
    // Load saved language preference first
    final savedCode = StorageService.to.read(_prefKey);

    if (savedCode != null && savedCode.isNotEmpty) {
      // User has a saved preference - ALWAYS use it
      final found = kAllLanguages.where((l) => l.code == savedCode).toList();
      if (found.isNotEmpty) {
        selectedLanguage.value = found.first;
        debugPrint(
            '🌐 [LanguageController] Loaded saved preference: ${found.first.name} ($savedCode)');
      } else {
        // Saved code no longer exists - fallback to Hindi
        debugPrint(
            '⚠️ [LanguageController] Saved language code "$savedCode" not found. Falling back to Hindi.');
        selectedLanguage.value = kAllLanguages.firstWhere(
          (l) => l.code == 'hi',
          orElse: () => kAllLanguages[0],
        );
      }
    } else {
      // No saved preference - check if this is a new user (first launch)
      // Default to English for new users (as per app design)
      selectedLanguage.value = kAllLanguages.firstWhere(
        (l) => l.code == 'en-GB',
        orElse: () => kAllLanguages[0],
      );
      debugPrint(
          '🌐 [LanguageController] New user - defaulting to English (UK)');

      // Auto-save this default preference
      try {
        await StorageService.to.write(_prefKey, 'en-GB');
      } catch (e) {
        debugPrint(
            '⚠️ [LanguageController] Failed to save default preference: $e');
      }
    }

    // Scan already-downloaded models
    await _refreshDownloadedVoices();

    debugPrint(
        '✅ LanguageController initialized with: ${selectedLanguage.value.name}');
  }

  Future<void> _refreshDownloadedVoices() async {
    final ids = await _modelService.getDownloadedVoiceIds();
    downloadedVoiceIds.value = ids;
  }

  /// Select a language — triggers download prompt if needed
  Future<void> selectLanguage(LanguageModel lang) async {
    final needsDownload = _needsDownload(lang);

    if (needsDownload && !isDownloaded(lang)) {
      pendingLanguage.value = lang;
      showDownloadPrompt.value = true;
    } else {
      await _switchLanguage(lang);
    }
  }

  /// Whether a language model needs to be downloaded before use
  bool _needsDownload(LanguageModel lang) {
    if (lang.ttsEngine == TTSEngine.flutterTts) return false;
    if (lang.voices.isEmpty) return false;
    final voice = lang.voices.first;
    return !voice.isSystem && voice.modelUrl.isNotEmpty;
  }

  /// Start downloading the pending language's voice model
  Future<void> confirmDownload() async {
    final lang = pendingLanguage.value;
    if (lang == null || lang.voices.isEmpty) return;

    showDownloadPrompt.value = false;
    isDownloading.value = true;
    downloadProgress.value = 0;
    downloadStatusMessage.value = 'Preparing download...';

    try {
      final voice = lang.voices.first;

      downloadStatusMessage.value =
          'Downloading ${lang.name} voice (${voice.sizeMB}MB)...';

      await _modelService.downloadVoice(
        voice,
        onProgress: (progress) {
          downloadProgress.value = progress;
          if (progress < 0.5) {
            downloadStatusMessage.value =
                'Downloading model... ${(progress * 100).toInt()}%';
          } else if (progress < 0.9) {
            downloadStatusMessage.value =
                'Downloading config... ${(progress * 100).toInt()}%';
          } else {
            downloadStatusMessage.value = 'Extracting language data...';
          }
        },
      );

      await _refreshDownloadedVoices();
      downloadStatusMessage.value = 'Ready!';
      downloadProgress.value = 1.0;

      await Future.delayed(const Duration(milliseconds: 500));
      await _switchLanguage(lang);
    } catch (e) {
      debugPrint('❌ confirmDownload error: $e');
      downloadStatusMessage.value = 'Download failed. Please try again.';
      Get.snackbar(
        'Download Failed',
        'Could not download ${pendingLanguage.value?.name} voice. Check your connection.',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isDownloading.value = false;
      pendingLanguage.value = null;
    }
  }

  /// Cancel the pending download prompt
  void cancelDownload() {
    pendingLanguage.value = null;
    showDownloadPrompt.value = false;
  }

  /// Internal: switch to a language and notify all services
  Future<void> _switchLanguage(LanguageModel lang) async {
    debugPrint('🔄 [LanguageController] Switching to: ${lang.name} (${lang.code}), Engine: ${lang.ttsEngine.name}');
    
    selectedLanguage.value = lang;

    // Notify TTS engine switcher
    try {
      await _engineSwitcher.switchLanguage(lang);
      debugPrint('✅ [LanguageController] TTS engine switched successfully');
    } catch (e) {
      debugPrint('⚠️ [LanguageController] TtsEngineSwitcher.switchLanguage error: $e');
    }

    // Notify STT service
    try {
      await _sttService.setLocaleFromLanguageCode(lang.sttLocale);
      debugPrint('✅ [LanguageController] STT locale set successfully');
    } catch (e) {
      debugPrint('⚠️ [LanguageController] SttService.setLocaleFromLanguageCode error: $e');
    }

    // Persist selection
    try {
      await StorageService.to.write(_prefKey, lang.code);
      debugPrint('✅ [LanguageController] Language preference saved');
    } catch (e) {
      debugPrint('⚠️ [LanguageController] StorageService save error: $e');
    }

    debugPrint('✅ [LanguageController] Language switch complete: ${lang.name} (${lang.code})');
  }

  /// Delete a downloaded voice model to free space
  Future<void> deleteVoice(String voiceId) async {
    await _modelService.deleteVoice(voiceId);
    await _refreshDownloadedVoices();
  }

  // ── Filtered language lists ──────────────────────────────────────────────────
  List<LanguageModel> get mainLanguages =>
      kAllLanguages.where((l) => l.group == LanguageGroup.main).toList();

  List<LanguageModel> get nativeIndianLanguages => kAllLanguages
      .where((l) => l.group == LanguageGroup.nativeIndian)
      .toList();

  List<LanguageModel> get internationalLanguages => kAllLanguages
      .where((l) => l.group == LanguageGroup.international)
      .toList();

  /// Whether the voice for this language is available locally
  bool isDownloaded(LanguageModel lang) {
    if (lang.ttsEngine == TTSEngine.flutterTts) return true;
    if (lang.voices.isEmpty) {
      return true; // eSpeak — no download needed beyond data
    }
    final voice = lang.voices.first;
    if (voice.isSystem) return true;
    return downloadedVoiceIds.contains(voice.id);
  }
}
