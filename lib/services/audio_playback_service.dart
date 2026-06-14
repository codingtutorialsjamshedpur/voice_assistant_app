import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/voice_recording_model.dart';

class AudioPlaybackService extends GetxService {
  static AudioPlaybackService get to => Get.find();

  final AudioPlayer _audioPlayer = AudioPlayer();

  // Observables
  final RxBool isPlaying = false.obs;
  final Rx<VoiceRecording?> currentRecording = Rx<VoiceRecording?>(null);
  final Rx<Duration> currentPosition = Duration.zero.obs;
  final Rx<Duration> totalDuration = Duration.zero.obs;
  final RxDouble playbackSpeed = 1.0.obs;

  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerStateSubscription;

  @override
  void onInit() {
    super.onInit();
    _setupListeners();
  }

  @override
  void onClose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.onClose();
  }

  void _setupListeners() {
    // Position updates
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      currentPosition.value = position;
    });

    // Duration updates
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      totalDuration.value = duration;
    });

    // Player state updates
    _playerStateSubscription =
        _audioPlayer.onPlayerStateChanged.listen((state) {
      isPlaying.value = state == PlayerState.playing;

      if (state == PlayerState.completed) {
        currentPosition.value = Duration.zero;
        isPlaying.value = false;
      }
    });
  }

  Future<bool> playRecording(VoiceRecording recording) async {
    try {
      // If playing a different recording, stop current
      if (currentRecording.value?.id != recording.id && isPlaying.value) {
        await stop();
      }

      // If same recording and paused, resume
      if (currentRecording.value?.id == recording.id && !isPlaying.value) {
        await _audioPlayer.resume();
        return true;
      }

      // Play new recording
      currentRecording.value = recording;
      await _audioPlayer.setPlaybackRate(playbackSpeed.value);
      await _audioPlayer.play(DeviceFileSource(recording.filePath));

      return true;
    } catch (e) {
      debugPrint('Error playing recording: $e');
      Get.snackbar(
        'Playback Error',
        'Failed to play recording: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.resume();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    currentPosition.value = Duration.zero;
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> seekToPosition(double percentage) async {
    if (totalDuration.value.inMilliseconds > 0) {
      final position = Duration(
        milliseconds: (totalDuration.value.inMilliseconds * percentage).round(),
      );
      await seek(position);
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    playbackSpeed.value = speed;
    await _audioPlayer.setPlaybackRate(speed);
  }

  Future<void> skipForward(Duration duration) async {
    final newPosition = currentPosition.value + duration;
    if (newPosition < totalDuration.value) {
      await seek(newPosition);
    } else {
      await seek(totalDuration.value);
    }
  }

  Future<void> skipBackward(Duration duration) async {
    final newPosition = currentPosition.value - duration;
    if (newPosition > Duration.zero) {
      await seek(newPosition);
    } else {
      await seek(Duration.zero);
    }
  }

  String get formattedCurrentPosition {
    final minutes = currentPosition.value.inMinutes;
    final seconds = currentPosition.value.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedTotalDuration {
    final minutes = totalDuration.value.inMinutes;
    final seconds = totalDuration.value.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double get progressPercentage {
    if (totalDuration.value.inMilliseconds == 0) return 0.0;
    return currentPosition.value.inMilliseconds /
        totalDuration.value.inMilliseconds;
  }

  void togglePlayPause(VoiceRecording recording) {
    if (currentRecording.value?.id == recording.id) {
      if (isPlaying.value) {
        pause();
      } else {
        resume();
      }
    } else {
      playRecording(recording);
    }
  }
}
