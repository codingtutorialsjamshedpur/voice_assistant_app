import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';

/// Voice Memo Model
class VoiceMemo {
  final String id;
  final String filePath;
  final String fileName;
  final DateTime createdAt;
  final Duration duration;
  final String? title;
  final int fileSize;

  VoiceMemo({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.createdAt,
    required this.duration,
    this.title,
    required this.fileSize,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        'fileName': fileName,
        'createdAt': createdAt.toIso8601String(),
        'duration': duration.inMilliseconds,
        'title': title,
        'fileSize': fileSize,
      };

  factory VoiceMemo.fromJson(Map<String, dynamic> json) => VoiceMemo(
        id: json['id'],
        filePath: json['filePath'],
        fileName: json['fileName'],
        createdAt: DateTime.parse(json['createdAt']),
        duration: Duration(milliseconds: json['duration']),
        title: json['title'],
        fileSize: json['fileSize'],
      );
}

/// Voice Memo Recording Status
enum VoiceMemoStatus {
  idle,
  recording,
  paused,
  playing,
  stopped,
}

/// Enhanced Voice Memo Service for recording and playback
class VoiceMemoService extends GetxService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  // Observable states
  final status = VoiceMemoStatus.idle.obs;
  final isRecording = false.obs;
  final isPaused = false.obs;
  final isPlaying = false.obs;
  final recordingDuration = Duration.zero.obs;
  final playbackPosition = Duration.zero.obs;
  final playbackDuration = Duration.zero.obs;
  final currentMemo = Rxn<VoiceMemo>();
  final memos = <VoiceMemo>[].obs;
  final recordingAmplitudes = <double>[].obs;

  // Timer for recording/playback
  Timer? _timer;
  StreamSubscription? _amplitudeSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;

  // Recording configuration
  final String _recordingsDirectory = 'voice_memos';
  String? _currentRecordingPath;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeService();
  }

  /// Initialize service
  Future<void> _initializeService() async {
    try {
      // Load saved memos
      await _loadMemos();

      // Setup player listeners
      _setupPlayerListeners();

      debugPrint('✅ Voice Memo Service Initialized');
    } catch (e) {
      debugPrint('❌ Voice Memo Service Init Error: $e');
    }
  }

  /// Setup player listeners
  void _setupPlayerListeners() {
    // Listen to position changes
    _positionSubscription = _player.onPositionChanged.listen((position) {
      playbackPosition.value = position;
    });

    // Listen to duration changes
    _durationSubscription = _player.onDurationChanged.listen((duration) {
      playbackDuration.value = duration;
    });

    // Listen to player state
    _player.onPlayerStateChanged.listen((state) {
      isPlaying.value = state == PlayerState.playing;
      if (state == PlayerState.completed) {
        status.value = VoiceMemoStatus.stopped;
        playbackPosition.value = Duration.zero;
      }
    });
  }

  /// Request permissions
  Future<bool> _requestPermissions() async {
    // Microphone permission
    final micStatus = await Permission.microphone.status;
    if (micStatus.isDenied) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        Get.snackbar(
          'Permission Required',
          'Microphone permission is needed to record voice memos',
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
        );
        return false;
      }
    }

    // Storage permission is not required for application documents directory
    return true;
  }

  /// Start recording
  Future<void> startRecording() async {
    // Check permissions
    final hasPermission = await _requestPermissions();
    if (!hasPermission) return;

    // Check if already recording
    if (isRecording.value) {
      debugPrint('⚠️ Already recording');
      return;
    }

    // Stop TTS to prevent audio session conflict
    try {
      final ttsService = Get.find<dynamic>(tag: 'TTSService');
      await ttsService.stop();
    } catch (_) {
      try {
        // Fallback if not injected with tag or using VoiceController
        final vc = Get.find<dynamic>(tag: 'VoiceController');
        await vc.stopSpeaking();
      } catch (_) {}
    }

    try {
      // Create recording directory
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir =
          Directory('${directory.path}/$_recordingsDirectory');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      // Generate filename
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      _currentRecordingPath = '${recordingsDir.path}/memo_$timestamp.m4a';

      // Configure recording
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      // Start recording
      await _recorder.start(config, path: _currentRecordingPath!);

      // Update state
      status.value = VoiceMemoStatus.recording;
      isRecording.value = true;
      isPaused.value = false;
      recordingDuration.value = Duration.zero;
      recordingAmplitudes.clear();

      // Start timer
      _startRecordingTimer();

      // Start amplitude monitoring
      _startAmplitudeMonitoring();

      debugPrint('🎙️ Started recording: $_currentRecordingPath');
    } catch (e) {
      debugPrint('❌ Recording Error: $e');
      Get.snackbar(
        'Recording Error',
        'Could not start recording: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  /// Pause recording
  Future<void> pauseRecording() async {
    if (!isRecording.value || isPaused.value) return;

    try {
      await _recorder.pause();
      _timer?.cancel();
      _amplitudeSubscription?.pause();

      status.value = VoiceMemoStatus.paused;
      isPaused.value = true;

      debugPrint('⏸️ Recording paused');
    } catch (e) {
      debugPrint('❌ Pause Error: $e');
    }
  }

  /// Resume recording
  Future<void> resumeRecording() async {
    if (!isRecording.value || !isPaused.value) return;

    try {
      await _recorder.resume();
      _startRecordingTimer();
      _amplitudeSubscription?.resume();

      status.value = VoiceMemoStatus.recording;
      isPaused.value = false;

      debugPrint('▶️ Recording resumed');
    } catch (e) {
      debugPrint('❌ Resume Error: $e');
    }
  }

  /// Stop recording and save
  Future<VoiceMemo?> stopRecording() async {
    if (!isRecording.value) return null;

    try {
      // Stop recording
      final path = await _recorder.stop();

      // Stop timer and monitoring
      _timer?.cancel();
      _amplitudeSubscription?.cancel();

      // Reset state
      status.value = VoiceMemoStatus.idle;
      isRecording.value = false;
      isPaused.value = false;

      if (path == null || path.isEmpty) {
        debugPrint('❌ No recording file generated');
        return null;
      }

      // Get file info
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('❌ Recording file not found');
        return null;
      }

      final fileSize = await file.length();

      // Create memo object
      final memo = VoiceMemo(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filePath: path,
        fileName: path.split('/').last,
        createdAt: DateTime.now(),
        duration: recordingDuration.value,
        title: 'Voice Memo ${memos.length + 1}',
        fileSize: fileSize,
      );

      // Add to list
      memos.add(memo);
      memos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Save to storage
      await _saveMemos();

      debugPrint('✅ Recording saved: ${memo.fileName}');

      // Reset duration
      recordingDuration.value = Duration.zero;
      recordingAmplitudes.clear();

      return memo;
    } catch (e) {
      debugPrint('❌ Stop Recording Error: $e');
      status.value = VoiceMemoStatus.idle;
      isRecording.value = false;
      isPaused.value = false;
      return null;
    }
  }

  /// Cancel recording without saving
  Future<void> cancelRecording() async {
    if (!isRecording.value) return;

    try {
      await _recorder.stop();

      // Delete the file
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Stop timer and monitoring
      _timer?.cancel();
      _amplitudeSubscription?.cancel();

      // Reset state
      status.value = VoiceMemoStatus.idle;
      isRecording.value = false;
      isPaused.value = false;
      recordingDuration.value = Duration.zero;
      recordingAmplitudes.clear();

      debugPrint('🗑️ Recording cancelled');
    } catch (e) {
      debugPrint('❌ Cancel Error: $e');
    }
  }

  /// Start recording timer
  void _startRecordingTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      recordingDuration.value += const Duration(seconds: 1);
    });
  }

  /// Start amplitude monitoring for waveform visualization
  void _startAmplitudeMonitoring() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = Stream.periodic(const Duration(milliseconds: 100))
        .asyncMap((_) => _recorder.getAmplitude())
        .listen((amp) {
      // Convert amplitude to 0-1 range for visualization
      final normalizedAmp =
          (amp.current + 40) / 40; // Approximate normalization
      recordingAmplitudes.add(normalizedAmp.clamp(0.0, 1.0));

      // Keep only last 100 values
      if (recordingAmplitudes.length > 100) {
        recordingAmplitudes.removeAt(0);
      }
    });
  }

  /// Play a voice memo
  Future<void> playMemo(VoiceMemo memo) async {
    try {
      // Stop current playback if any
      if (isPlaying.value) {
        await stopPlayback();
      }

      currentMemo.value = memo;

      // Set the audio source
      await _player.setSource(DeviceFileSource(memo.filePath));

      // Start playing
      await _player.resume();

      status.value = VoiceMemoStatus.playing;

      debugPrint('▶️ Playing: ${memo.fileName}');
    } catch (e) {
      debugPrint('❌ Playback Error: $e');
      Get.snackbar(
        'Playback Error',
        'Could not play recording: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  /// Pause playback
  Future<void> pausePlayback() async {
    try {
      await _player.pause();
      status.value = VoiceMemoStatus.paused;
      debugPrint('⏸️ Playback paused');
    } catch (e) {
      debugPrint('❌ Pause Playback Error: $e');
    }
  }

  /// Resume playback
  Future<void> resumePlayback() async {
    try {
      await _player.resume();
      status.value = VoiceMemoStatus.playing;
      debugPrint('▶️ Playback resumed');
    } catch (e) {
      debugPrint('❌ Resume Playback Error: $e');
    }
  }

  /// Stop playback
  Future<void> stopPlayback() async {
    try {
      await _player.stop();
      status.value = VoiceMemoStatus.stopped;
      playbackPosition.value = Duration.zero;
      debugPrint('⏹️ Playback stopped');
    } catch (e) {
      debugPrint('❌ Stop Playback Error: $e');
    }
  }

  /// Seek to position
  Future<void> seekTo(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('❌ Seek Error: $e');
    }
  }

  /// Delete a memo
  Future<void> deleteMemo(VoiceMemo memo) async {
    try {
      // Delete file
      final file = File(memo.filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Remove from list
      memos.removeWhere((m) => m.id == memo.id);

      // Save to storage
      await _saveMemos();

      // Reset current if deleted
      if (currentMemo.value?.id == memo.id) {
        currentMemo.value = null;
        await stopPlayback();
      }

      debugPrint('🗑️ Deleted memo: ${memo.fileName}');
    } catch (e) {
      debugPrint('❌ Delete Error: $e');
    }
  }

  /// Rename a memo
  Future<void> renameMemo(VoiceMemo memo, String newTitle) async {
    try {
      final index = memos.indexWhere((m) => m.id == memo.id);
      if (index != -1) {
        final updatedMemo = VoiceMemo(
          id: memo.id,
          filePath: memo.filePath,
          fileName: memo.fileName,
          createdAt: memo.createdAt,
          duration: memo.duration,
          title: newTitle,
          fileSize: memo.fileSize,
        );

        memos[index] = updatedMemo;
        await _saveMemos();

        if (currentMemo.value?.id == memo.id) {
          currentMemo.value = updatedMemo;
        }

        debugPrint('✏️ Renamed memo to: $newTitle');
      }
    } catch (e) {
      debugPrint('❌ Rename Error: $e');
    }
  }

  /// Load memos from storage
  Future<void> _loadMemos() async {
    try {
      // This is a placeholder - in a real app, you'd load from SharedPreferences or a database
      // For now, we scan the recordings directory
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir =
          Directory('${directory.path}/$_recordingsDirectory');

      if (await recordingsDir.exists()) {
        final files = await recordingsDir.list().toList();
        final loadedMemos = <VoiceMemo>[];

        for (var file in files) {
          if (file is File && file.path.endsWith('.m4a')) {
            final stat = await file.stat();
            final memo = VoiceMemo(
              id: stat.modified.millisecondsSinceEpoch.toString(),
              filePath: file.path,
              fileName: file.path.split('/').last,
              createdAt: stat.modified,
              duration: Duration.zero, // Would need to get actual duration
              title: 'Voice Memo',
              fileSize: stat.size,
            );
            loadedMemos.add(memo);
          }
        }

        memos.value = loadedMemos
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (e) {
      debugPrint('❌ Load Memos Error: $e');
    }
  }

  /// Save memos to storage
  Future<void> _saveMemos() async {
    // Placeholder - would save to SharedPreferences or database
    debugPrint('💾 Saved ${memos.length} memos');
  }

  /// Format duration to MM:SS
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String minutes = twoDigits(duration.inMinutes.remainder(60));
    final String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// Get file size in readable format
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  void onClose() {
    _timer?.cancel();
    _amplitudeSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.onClose();
  }
}
