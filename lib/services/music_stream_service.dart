import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';

class MusicStreamService extends GetxService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final RxBool isPlaying = false.obs;
  final RxString currentTrackTitle = ''.obs;
  final RxDouble volume = 0.5.obs;

  @override
  void onInit() {
    super.onInit();

    // Listen for state changes
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      isPlaying.value = state == PlayerState.playing;
      debugPrint('🎵 [MusicStream] State changed: $state');
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      isPlaying.value = false;
      currentTrackTitle.value = '';
      debugPrint('🎵 [MusicStream] Track completed');
    });
  }

  Future<void> playTrack(String url, String title) async {
    try {
      debugPrint('🎵 [MusicStream] Attempting to play: $title ($url)');

      // Stop anything currently playing
      await stop();

      currentTrackTitle.value = title;
      await _audioPlayer.play(UrlSource(url));
      await _audioPlayer.setVolume(volume.value);
    } catch (e) {
      debugPrint('❌ [MusicStream] Error playing track: $e');
      isPlaying.value = false;
    }
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      isPlaying.value = false;
      currentTrackTitle.value = '';
    } catch (e) {
      debugPrint('❌ [MusicStream] Error stopping track: $e');
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    if (currentTrackTitle.value.isNotEmpty) {
      await _audioPlayer.resume();
    }
  }

  void setVolume(double val) {
    volume.value = val;
    _audioPlayer.setVolume(val);
  }

  @override
  void onClose() {
    _audioPlayer.dispose();
    super.onClose();
  }
}
