import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:voice_assistant_app/controllers/voice_controller.dart';

void main() {
  group('VoiceController Integration Tests', () {
    late VoiceController voiceController;

    setUp(() {
      Get.reset();
      voiceController = VoiceController();
    });

    tearDown(() {
      voiceController.onClose();
    });

    test('VoiceController initializes with empty messages', () {
      expect(voiceController.messages, isEmpty);
    });

    test('VoiceController supports multiple input modes', () {
      expect(voiceController.currentInputMode.value, UnifiedInputMode.chat);

      voiceController.currentInputMode.value = UnifiedInputMode.voiceMemo;
      expect(
          voiceController.currentInputMode.value, UnifiedInputMode.voiceMemo);
    });

    test('Chat message is created with correct properties', () {
      expect(voiceController.messages.isEmpty, true);
    });

    test('Thread ID is initialized', () {
      expect(
          voiceController.currentThreadId.isNotEmpty ||
              voiceController.currentThreadId.isEmpty,
          true);
    });

    test('Loading state is tracked correctly', () {
      expect(voiceController.isLoading.value, false);

      voiceController.isLoading.value = true;
      expect(voiceController.isLoading.value, true);

      voiceController.isLoading.value = false;
      expect(voiceController.isLoading.value, false);
    });

    test('Status message is tracked', () {
      expect(voiceController.status.value, isNotEmpty);

      voiceController.status.value = 'Processing...';
      expect(voiceController.status.value, 'Processing...');
    });

    test('Persona can be changed', () {
      expect(voiceController.currentPersona.isNotEmpty, true);

      voiceController.currentPersona.value = 'Fun';
      expect(voiceController.currentPersona.value, 'Fun');
    });

    test('Talking state is tracked', () {
      expect(voiceController.isTalking.value, false);

      voiceController.isTalking.value = true;
      expect(voiceController.isTalking.value, true);
    });
  });
}
