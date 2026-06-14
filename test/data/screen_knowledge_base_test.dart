import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_app/data/screen_knowledge_base.dart';

void main() {
  group('ScreenKnowledgeBase Tests', () {
    test('Should return ScreenInfo for recognized route', () {
      final info = ScreenKnowledgeBase.getScreenInfo('/voice-chat');
      expect(info, isNotNull);
      expect(info?.displayName, 'Voice Chat');
      expect(info?.hasAIInteraction, true);
    });

    test('Should return null for unknown route', () {
      final info = ScreenKnowledgeBase.getScreenInfo('/unknown-screen');
      expect(info, isNull);
    });

    test('Should build specific system prompt section', () {
      final prompt =
          ScreenKnowledgeBase.buildSystemPromptSection('/voice-chat');
      expect(prompt, contains('CURRENT SCREEN: Voice Chat'));
      expect(prompt, contains('VOICE COMMANDS'));
    });

    test('Should return correct AI screens list', () {
      final aiScreens = ScreenKnowledgeBase.getAIScreens();
      expect(aiScreens.isNotEmpty, true);

      // Ensure splash is not included
      final hasSplash = aiScreens.any((s) => s.name == '/splash');
      expect(hasSplash, false);
    });
  });
}
