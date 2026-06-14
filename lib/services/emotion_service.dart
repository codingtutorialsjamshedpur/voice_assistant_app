import 'dart:async';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'ruflo_service.dart';
import '../controllers/tts_chunk_controller.dart';

class EmotionService extends GetxService {
  final _ruflo = RuFloService();
  final RxString detectedEmotion = 'neutral'.obs;

  Future<void> analyzeVoiceEmotion(Uint8List audioData, String userId) async {
    unawaited(() async {
      try {
        final features = _extractAcousticFeatures(audioData);
        final result = await _ruflo.callTool('emotion_detector', {
          'features': features,
          'userId': userId,
          'previousEmotion': detectedEmotion.value,
        });
        detectedEmotion.value = result['emotion'] as String? ?? 'neutral';
        _adaptToEmotion(detectedEmotion.value);
      } catch (_) {}
    }());
  }

  void _adaptToEmotion(String emotion) {
    try {
      if (Get.isRegistered<TtsChunkController>()) {
        final ctrl = Get.find<TtsChunkController>();
        switch (emotion) {
          case 'stressed':
            ctrl.setSpeakingRate(0.85);
            ctrl.setPitch(-2);
            break;
          case 'tired':
            ctrl.setSpeakingRate(0.9);
            ctrl.setPitch(-1);
            break;
          case 'happy':
          case 'excited':
            ctrl.setSpeakingRate(1.1);
            ctrl.setPitch(1);
            break;
          default:
            ctrl.resetToOptimized();
        }
      }
    } catch (_) {}
  }

  Map<String, dynamic> _extractAcousticFeatures(Uint8List audio) {
    return {
      'avgPitchHz': 0.0,
      'pitchVariance': 0.0,
      'energyRms': 0.0,
      'speakingRateWps': 0.0,
    };
  }
}
