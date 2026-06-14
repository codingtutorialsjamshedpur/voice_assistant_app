import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import '../models/language_model.dart';
import 'language_model_service.dart';

/// Offline TTS service using sherpa_onnx (Piper ONNX / eSpeak voices)
class SherpaTtsService extends GetxService {
  sherpa.OfflineTts? _tts;
  String? _currentVoiceId;
  bool _isInitialized = false;
  double _speed = 0.85; // Comfortable 1× pace (was 1.0)

  // Keep last N temp files
  static const int _maxTempFiles = 5;
  final List<String> _tempFilePaths = [];

  bool get isInitialized => _isInitialized;
  String? get currentVoiceId => _currentVoiceId;

  /// Load a Piper ONNX model
  Future<void> initVoice(VoiceOption voice) async {
    if (voice.isSystem || voice.modelUrl.isEmpty) return;

    // Already loaded — skip
    if (_isInitialized && _currentVoiceId == voice.id) return;

    await disposeCurrentVoice();

    try {
      final modelService = Get.find<LanguageModelService>();
      final modelPath = modelService.getModelPath(voice.id);
      final configPath = modelService.getConfigPath(voice.id);
      final espeakPath = modelService.getEspeakDataPath();

      final modelConfig = sherpa.OfflineTtsVitsModelConfig(
        model: modelPath,
        lexicon: '',
        tokens: configPath,
        dataDir: espeakPath,
        noiseScale: 0.667,
        noiseScaleW: 0.8,
        lengthScale: _speed,
      );

      final ttsModelConfig = sherpa.OfflineTtsModelConfig(
        vits: modelConfig,
        numThreads: 2,
        debug: false,
        provider: 'cpu',
      );

      final ttsConfig = sherpa.OfflineTtsConfig(
        model: ttsModelConfig,
        ruleFsts: '',
      );

      _tts = sherpa.OfflineTts(ttsConfig);
      _currentVoiceId = voice.id;
      _isInitialized = true;

      debugPrint('✅ SherpaTtsService: Loaded voice ${voice.id}');
    } catch (e) {
      debugPrint('❌ SherpaTtsService.initVoice error: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Synthesize text to a WAV file and return its path
  Future<String> synthesizeToFile(String text) async {
    if (!_isInitialized || _tts == null) {
      throw StateError('SherpaTtsService: No voice loaded');
    }

    try {
      final audio = _tts!.generate(text: text, sid: 0, speed: _speed);

      // Write WAV file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final wavPath = '${tempDir.path}/sherpa_tts_$timestamp.wav';

      _writeWav(audio.samples, audio.sampleRate, wavPath);

      // Track temp files and clean old ones
      _tempFilePaths.add(wavPath);
      _cleanupOldTempFiles();

      return wavPath;
    } catch (e) {
      debugPrint('❌ SherpaTtsService.synthesizeToFile error: $e');
      rethrow;
    }
  }

  /// Write a 16-bit mono PCM WAV file
  void _writeWav(List<double> samples, int sampleRate, String path) {
    final numSamples = samples.length;
    final dataSize = numSamples * 2; // 16-bit = 2 bytes per sample
    final fileSize = 44 + dataSize; // RIFF header size

    final buffer = ByteData(fileSize);
    int offset = 0;

    // RIFF chunk descriptor
    _writeString(buffer, offset, 'RIFF');
    offset += 4;
    buffer.setUint32(offset, fileSize - 8, Endian.little); // chunk size
    offset += 4;
    _writeString(buffer, offset, 'WAVE');
    offset += 4;

    // fmt sub-chunk
    _writeString(buffer, offset, 'fmt ');
    offset += 4;
    buffer.setUint32(offset, 16, Endian.little); // sub-chunk size
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // PCM format
    offset += 2;
    buffer.setUint16(offset, 1, Endian.little); // mono
    offset += 2;
    buffer.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    buffer.setUint32(offset, sampleRate * 2, Endian.little); // byte rate
    offset += 4;
    buffer.setUint16(offset, 2, Endian.little); // block align
    offset += 2;
    buffer.setUint16(offset, 16, Endian.little); // bits per sample
    offset += 2;

    // data sub-chunk
    _writeString(buffer, offset, 'data');
    offset += 4;
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;

    // PCM samples (clamp to [-1.0, 1.0], convert to int16)
    for (final sample in samples) {
      final clamped = sample.clamp(-1.0, 1.0);
      final pcm = (clamped * 32767).round().clamp(-32768, 32767);
      buffer.setInt16(offset, pcm, Endian.little);
      offset += 2;
    }

    File(path).writeAsBytesSync(buffer.buffer.asUint8List());
  }

  void _writeString(ByteData buffer, int offset, String value) {
    for (int i = 0; i < value.length; i++) {
      buffer.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  /// Delete old temp WAV files, keeping only the last N
  void _cleanupOldTempFiles() {
    while (_tempFilePaths.length > _maxTempFiles) {
      final old = _tempFilePaths.removeAt(0);
      try {
        final f = File(old);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  /// Free the current TTS model from memory
  Future<void> disposeCurrentVoice() async {
    if (_tts != null) {
      _tts!.free();
      _tts = null;
    }
    _currentVoiceId = null;
    _isInitialized = false;
  }

  /// Set speech speed (maps to lengthScale: lower = faster)
  Future<void> setSpeed(double speed) async {
    _speed = speed.clamp(0.5, 2.0);
    // If model loaded, reload to apply new length scale
    // (sherpa_onnx config is set at init time)
  }

  /// Set pitch — maps to lengthScale in sherpa (same as speed for VITS)
  Future<void> setPitch(double pitch) async {
    // In sherpa VITS, pitch is approximated via lengthScale
    await setSpeed(pitch);
  }

  /// Preview a voice by synthesizing a short sample (must already be downloaded)
  Future<void> previewVoice(VoiceOption voice, String previewText) async {
    await initVoice(voice);
    await synthesizeToFile(previewText);
  }

  @override
  void onClose() {
    _tts?.free();
    _tts = null;
    super.onClose();
  }
}
