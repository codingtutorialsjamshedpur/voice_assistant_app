import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:voice_assistant_app/controllers/ai_context_controller.dart';
import 'package:voice_assistant_app/data/language_strings.dart';

void main() {
  group('AIContextController Tests', () {
    late AIContextController controller;

    setUp(() {
      Get.reset();
      controller = AIContextController();
    });

    test('Initialization defaults to voice-chat', () {
      expect(controller.currentRoute.value, '/voice-chat');
    });

    test('Update screen sets correct context values', () {
      controller.updateCurrentScreen('/history');
      expect(controller.currentRoute.value, '/history');
      expect(controller.currentScreenName.value, 'History');
      expect(controller.currentScreenContext.value.isNotEmpty, true);
    });

    test('System prompt contains dynamic info', () {
      controller.updateCurrentScreen('/game');
      final prompt =
          controller.buildFullSystemPrompt(language: AssistantLanguage.english);

      expect(prompt, contains('CURRENT SCREEN CONTEXT:'));
      expect(prompt, contains('CURRENT SCREEN: Game Hub'));
      expect(prompt, contains('English'));
      expect(prompt, contains('Sourav Kumar'));
    });

    test('Screen intro script generation', () {
      controller.updateCurrentScreen('/naam-jaap');
      final script = controller.getScreenIntroScript(language: 'english');
      expect(script, contains('Welcome to Naam Jaap'));
    });
  });
}
