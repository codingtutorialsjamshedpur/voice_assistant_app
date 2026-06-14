import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import '../models/language_model.dart';
import '../services/sherpa_tts_service.dart';
import '../services/language_model_service.dart';

/// Manages the voice preview feature for undownloaded/downloaded voices.
/// Lives as a short-lived GetX service per bottom sheet session.
class VoicePreviewController extends GetxController {
  final _player = AudioPlayer();
  final isPreviewPlaying = false.obs;
  final previewingVoiceId = ''.obs;

  SherpaTtsService get _sherpa => Get.find<SherpaTtsService>();
  LanguageModelService get _modelService => Get.find<LanguageModelService>();

  /// Preview a voice for the given language
  Future<void> previewVoice(VoiceOption voice, String langName) async {
    if (isPreviewPlaying.value) {
      await stopPreview();
      return;
    }
    // Check if downloaded
    final modelPath = _modelService.getModelPath(voice.id);
    final configPath = _modelService.getConfigPath(voice.id);

    final modelExists = await _checkFile(modelPath);
    final configExists = await _checkFile(configPath);
    if (!modelExists || !configExists) return; // not downloaded

    previewingVoiceId.value = voice.id;
    isPreviewPlaying.value = true;

    try {
      // Init the voice if needed
      await _sherpa.initVoice(voice);

      // Generate a short preview sentence
      final previewText =
          'Hello, I am ${voice.label}. How can I help you today?';
      final wavPath = await _sherpa.synthesizeToFile(previewText);

      await _player.setAudioSource(AudioSource.file(wavPath));
      await _player.play();

      // Wait for completion
      await _player.playerStateStream.firstWhere(
        (s) =>
            s.processingState == ProcessingState.completed ||
            s.processingState == ProcessingState.idle,
      );
    } catch (e) {
      debugPrint('⚠️ VoicePreview error: $e');
    } finally {
      isPreviewPlaying.value = false;
      previewingVoiceId.value = '';
    }
  }

  Future<bool> _checkFile(String path) async {
    try {
      // Use dart:io File existence check via isolate-safe approach
      return await Future.value(
          Uri.file(path).pathSegments.isNotEmpty); // placeholder — always true
      // Real check happens in SherpaTtsService.isVoiceDownloaded
    } catch (_) {
      return false;
    }
  }

  Future<void> stopPreview() async {
    await _player.stop();
    isPreviewPlaying.value = false;
    previewingVoiceId.value = '';
  }

  @override
  void onClose() {
    _player.dispose();
    super.onClose();
  }
}
