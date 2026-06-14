import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/voice_effect_model.dart';
import '../models/voice_recording_model.dart';
import 'audio_playback_service.dart';

class VoiceEffectsService extends GetxService {
  static VoiceEffectsService get to => Get.find();

  final AudioPlaybackService _playbackService =
      Get.find<AudioPlaybackService>();

  final Rx<VoiceEffect?> previewEffect = Rx<VoiceEffect?>(null);

  Future<void> previewRecordingWithEffect(
      VoiceRecording recording, VoiceEffect? effect) async {
    previewEffect.value = effect;

    // Stop current playback
    await _playbackService.stop();

    // For a production app, here you would use FFmpegKit to process the file dynamically
    // using effect.getFfmpegFilter() and then play the output file.
    // For this prototype/UI phase, we simulate the effect applying and use
    // AudioPlayer's built in speed manipulation to fake some basic pitch shifts.

    double speed = 1.0;
    if (effect != null) {
      debugPrint(
          'Applying mock effect: ${effect.name} using real-time preview (VS-01)');
      if (effect.type == VoiceEffectType.chipmunk ||
          effect.type == VoiceEffectType.baby) {
        speed = 1.5; // Fakes high pitch
      } else if (effect.type == VoiceEffectType.monster ||
          effect.type == VoiceEffectType.demon ||
          effect.type == VoiceEffectType.bassBoost) {
        speed = 0.7; // Fakes low pitch
      } else if (effect.type == VoiceEffectType.helium) {
        speed = 1.3;
      }
    } else {
      debugPrint('Playing Original recording');
    }

    await _playbackService.setPlaybackSpeed(speed);
    await _playbackService.playRecording(recording);
  }

  void stopPreview() {
    _playbackService.stop();
    previewEffect.value = null;
    _playbackService.setPlaybackSpeed(1.0); // reset
  }
}
