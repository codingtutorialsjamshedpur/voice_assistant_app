import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'stt_service.dart';
import 'tts_service.dart';
import 'ai_model_manager.dart';
import '../controllers/ai_context_controller.dart';
import 'query_handler_service.dart';

class SharedResetService {
  static Future<void> hardReset() async {
    debugPrint('🔄 [SharedResetService] Performing global hard reset...');
    try {
      if (Get.isRegistered<TTSService>()) {
        await Get.find<TTSService>().stop();
      }
      if (Get.isRegistered<STTService>()) {
        await Get.find<STTService>().cancelListening();
      }
      if (Get.isRegistered<AIModelManager>()) {
        Get.find<AIModelManager>().hardReset();
      }
      if (Get.isRegistered<QueryHandlerService>()) {
        await Get.find<QueryHandlerService>().clearHistory();
      }
      if (Get.isRegistered<AIContextController>()) {
        Get.find<AIContextController>()
            .updateCurrentScreen('/home'); // Reset context
      }
    } catch (e) {
      debugPrint('⚠️ [SharedResetService] Error during hard reset: $e');
    }
  }
}
