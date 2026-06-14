import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_app/models/screen_info.dart';

void main() {
  group('ScreenInfo Model Test', () {
    test('ScreenInfo initialization', () {
      const button = ButtonInfo(
        name: 'TestBtn',
        description: 'A test button',
        onTap: 'Does something testy',
      );

      const gesture = GestureInfo(
        type: 'tap',
        description: 'Single tap',
        action: 'Does action',
      );

      const screen = ScreenInfo(
        name: '/test',
        displayName: 'Test Screen',
        description: 'A screen for testing',
        purpose: 'To test',
        features: ['Test feature'],
        gestures: [gesture],
        buttons: [button],
        voiceCommands: ['Test command'],
        hasAIInteraction: true,
      );

      expect(screen.name, '/test');
      expect(screen.displayName, 'Test Screen');
      expect(screen.buttons.length, 1);
      expect(screen.gestures.length, 1);
      expect(screen.toContextString(), contains('Test Screen'));
      expect(screen.toContextString(), contains('Test feature'));
      expect(screen.toContextString(), contains('TestBtn'));
    });
  });
}
