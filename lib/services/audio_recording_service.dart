import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/voice_effect_model.dart';
import '../models/voice_recording_model.dart';
import 'sound_service.dart';
import 'voice_effect_processor.dart';
import 'history_logger_service.dart';

class AudioRecordingService extends GetxService {
  static AudioRecordingService get to => Get.find();

  final AudioRecorder _audioRecorder = AudioRecorder();
  final Uuid _uuid = const Uuid();

  // Observables
  final RxBool isRecording = false.obs;
  final RxBool isProcessing = false.obs;
  final Rx<Duration> recordingDuration = Duration.zero.obs;
  final RxDouble amplitude = 0.0.obs;
  final Rx<VoiceEffect?> selectedEffect = Rx<VoiceEffect?>(null);
  final RxList<VoiceRecording> recordings = <VoiceRecording>[].obs;

  Timer? _recordingTimer;
  Timer? _amplitudeTimer;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  @override
  void onInit() {
    super.onInit();
    _loadRecordings();
  }

  @override
  void onClose() {
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
    _amplitudeTimer?.cancel();
    super.onClose();
  }

  Future<void> _loadRecordings() async {
    // Recordings are kept in memory for this session.
    // Persistence can be added via SharedPreferences/Hive later.
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Permissions
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> checkPermissions() async {
    final micStatus = await Permission.microphone.request();

    if (Platform.isAndroid) {
      // Android 13+ uses READ_MEDIA_AUDIO; older uses READ/WRITE_EXTERNAL_STORAGE
      final audioStatus = await Permission.audio.request();
      final storageStatus = await Permission.storage.request();
      return micStatus.isGranted &&
          (audioStatus.isGranted || storageStatus.isGranted);
    }

    return micStatus.isGranted;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Effect selection
  // ─────────────────────────────────────────────────────────────────────────

  void selectEffect(VoiceEffect effect) {
    selectedEffect.value = effect;
    SoundService.to.playClick();
    Get.snackbar(
      'Effect Selected ✨',
      '${effect.name} — ${effect.description}',
      backgroundColor: effect.color.withValues(alpha: 0.9),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void clearEffect() {
    selectedEffect.value = null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Recording
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> startRecording() async {
    if (isRecording.value) return false;

    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      Get.snackbar(
        'Permission Denied',
        'Microphone permission is required to record.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'raw_$ts.wav';
      _currentRecordingPath = '${recordingsDir.path}/$fileName';

      // Record as PCM WAV so our DSP processor can read it directly
      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
        bitRate: 128000,
      );

      await _audioRecorder.start(config, path: _currentRecordingPath!);

      _recordingStartTime = DateTime.now();
      isRecording.value = true;
      recordingDuration.value = Duration.zero;

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        recordingDuration.value += const Duration(seconds: 1);
      });

      _amplitudeTimer =
          Timer.periodic(const Duration(milliseconds: 100), (_) async {
        try {
          final amp = await _audioRecorder.getAmplitude();
          amplitude.value = ((amp.current + 100) / 100).clamp(0.0, 1.0);
        } catch (_) {}
      });

      return true;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      Get.snackbar(
        'Recording Error',
        'Failed to start recording: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  Future<VoiceRecording?> stopRecording() async {
    if (!isRecording.value) return null;

    try {
      _recordingTimer?.cancel();
      _amplitudeTimer?.cancel();

      final path = await _audioRecorder.stop();
      isRecording.value = false;
      amplitude.value = 0.0;

      if (path == null || _currentRecordingPath == null) return null;

      SoundService.to.playSuccess();

      final duration = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!)
          : recordingDuration.value;

      final rawFile = File(_currentRecordingPath!);
      final rawSize = await rawFile.exists() ? await rawFile.length() : 0;

      // Apply DSP effect if one is selected
      String finalPath = _currentRecordingPath!;
      if (selectedEffect.value != null) {
        isProcessing.value = true;
        try {
          finalPath = await VoiceEffectProcessor.applyEffect(
            _currentRecordingPath!,
            selectedEffect.value!,
          );
          // Delete the raw file if a processed version was created
          if (finalPath != _currentRecordingPath && await rawFile.exists()) {
            await rawFile.delete().catchError((_) => rawFile);
          }
        } catch (e) {
          debugPrint('Effect processing error: $e');
          finalPath = _currentRecordingPath!;
        } finally {
          isProcessing.value = false;
        }
      }

      final processedFile = File(finalPath);
      final fileSize =
          await processedFile.exists() ? await processedFile.length() : rawSize;

      final recording = VoiceRecording(
        id: _uuid.v4(),
        title: 'Recording ${recordings.length + 1}',
        filePath: finalPath,
        effectId: selectedEffect.value?.id,
        effectType: selectedEffect.value?.type,
        createdAt: DateTime.now(),
        duration: duration,
        fileSize: fileSize,
      );

      recordings.insert(0, recording);

      await HistoryLoggerService().logVoiceStudioActivity(
        recordingName: recording.title,
        durationSeconds: recording.duration.inSeconds,
      );

      _currentRecordingPath = null;
      _recordingStartTime = null;

      return recording;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      isRecording.value = false;
      isProcessing.value = false;
      Get.snackbar(
        'Recording Error',
        'Failed to stop recording: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save to device storage (Downloads / Music folder)
  // ─────────────────────────────────────────────────────────────────────────

  Future<String?> saveToDevice(VoiceRecording recording) async {
    try {
      final srcFile = File(recording.filePath);
      if (!await srcFile.exists()) {
        Get.snackbar('Error', 'Recording file not found',
            backgroundColor: Colors.red, colorText: Colors.white);
        return null;
      }

      // Request storage permission
      bool hasPermission = false;
      if (Platform.isAndroid) {
        // Android 10+ (API 29+): use MediaStore / scoped storage
        // For simplicity we write to the app's external files dir which
        // doesn't need WRITE_EXTERNAL_STORAGE on API 29+.
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final musicDir = Directory('${extDir.path}/VoiceStudio');
          if (!await musicDir.exists()) {
            await musicDir.create(recursive: true);
          }
          final fileName = _buildExportFileName(recording);
          final destPath = '${musicDir.path}/$fileName';
          await srcFile.copy(destPath);
          Get.snackbar(
            '✅ Saved to Device',
            'Saved as $fileName\nLocation: VoiceStudio folder',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
          return destPath;
        }

        // Fallback: try Downloads via legacy permission
        final storageStatus = await Permission.storage.request();
        hasPermission = storageStatus.isGranted;
        if (!hasPermission) {
          Get.snackbar(
            'Permission Required',
            'Storage permission is needed to save to device.',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
          return null;
        }
      }

      // iOS / fallback
      final dir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${dir.path}/exports');
      if (!await exportDir.exists()) await exportDir.create(recursive: true);
      final fileName = _buildExportFileName(recording);
      final destPath = '${exportDir.path}/$fileName';
      await srcFile.copy(destPath);

      Get.snackbar(
        '✅ Saved',
        'Recording saved as $fileName',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return destPath;
    } catch (e) {
      debugPrint('saveToDevice error: $e');
      Get.snackbar('Error', 'Failed to save: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
      return null;
    }
  }

  String _buildExportFileName(VoiceRecording recording) {
    final effectSuffix =
        recording.effectId != null ? '_${recording.effectId}' : '';
    final ts = recording.createdAt.millisecondsSinceEpoch;
    final ext = recording.filePath.endsWith('.wav') ? 'wav' : 'm4a';
    return '${recording.title.replaceAll(' ', '_')}${effectSuffix}_$ts.$ext';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CRUD helpers
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> deleteRecording(VoiceRecording recording) async {
    try {
      final file = File(recording.filePath);
      if (await file.exists()) await file.delete();
      recordings.removeWhere((r) => r.id == recording.id);
      Get.snackbar('Deleted', 'Recording deleted successfully',
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete recording',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> renameRecording(
      VoiceRecording recording, String newTitle) async {
    final index = recordings.indexWhere((r) => r.id == recording.id);
    if (index != -1) {
      recordings[index] = recording.copyWith(title: newTitle);
      Get.snackbar('Renamed', 'Recording renamed to "$newTitle"',
          backgroundColor: Colors.green, colorText: Colors.white);
    }
  }

  Future<String?> exportRecording(VoiceRecording recording) async {
    try {
      final file = File(recording.filePath);
      if (!await file.exists()) {
        Get.snackbar('Error', 'Recording file not found',
            backgroundColor: Colors.red, colorText: Colors.white);
        return null;
      }
      return recording.filePath;
    } catch (e) {
      debugPrint('Error exporting: $e');
      return null;
    }
  }

  Future<String?> toggleFavorite(VoiceRecording recording) async {
    final index = recordings.indexWhere((r) => r.id == recording.id);
    if (index != -1) {
      recordings[index] = recording.copyWith(isFavorite: !recording.isFavorite);
      return recording.isFavorite
          ? 'Removed from favorites'
          : 'Added to favorites';
    }
    return null;
  }

  List<VoiceRecording> getFavoriteRecordings() {
    return recordings.where((r) => r.isFavorite).toList();
  }

  List<VoiceRecording> getRecordingsByEffect(String effectId) {
    return recordings.where((r) => r.effectId == effectId).toList();
  }
}
