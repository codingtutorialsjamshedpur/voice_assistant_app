import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_app/models/screen_info.dart';

void main() {
  group('ScreenInfo Model Tests', () {
    test('ScreenInfo can be instantiated', () {
      const screenInfo = ScreenInfo(
        name: 'test_screen',
        displayName: 'Test Screen',
        description: 'A test screen',
        purpose: 'Testing purposes',
        features: ['Feature 1', 'Feature 2'],
        buttons: [],
        gestures: [],
        voiceCommands: ['test'],
        navigatesTo: ['/other-screen'],
        hasAIInteraction: true,
      );

      expect(screenInfo.name, 'test_screen');
      expect(screenInfo.displayName, 'Test Screen');
      expect(screenInfo.description, 'A test screen');
      expect(screenInfo.purpose, 'Testing purposes');
      expect(screenInfo.features.length, 2);
      expect(screenInfo.hasAIInteraction, true);
    });

    test('ScreenInfo features list is preserved', () {
      final features = ['Voice input', 'Text input', 'History'];
      final screenInfo = ScreenInfo(
        name: 'voice_chat',
        displayName: 'Voice Chat',
        description: 'Main chat screen',
        purpose: 'AI interaction',
        features: features,
        buttons: [],
        gestures: [],
        voiceCommands: [],
        navigatesTo: [],
        hasAIInteraction: true,
      );

      expect(screenInfo.features, features);
      expect(screenInfo.features.length, 3);
    });

    test('ScreenInfo with buttons', () {
      final buttons = [
        const ButtonInfo(
          name: 'Send',
          description: 'Send message',
          onTap: 'send_message',
        ),
      ];

      final screenInfo = ScreenInfo(
        name: 'chat',
        displayName: 'Chat',
        description: 'Chat screen',
        purpose: 'Chatting',
        features: [],
        buttons: buttons,
        gestures: [],
        voiceCommands: [],
        navigatesTo: [],
        hasAIInteraction: true,
      );

      expect(screenInfo.buttons.length, 1);
      expect(screenInfo.buttons.first.name, 'Send');
    });

    test('ScreenInfo with gestures', () {
      final gestures = [
        const GestureInfo(
          type: 'tap',
          description: 'Tap to select',
          action: 'select',
        ),
      ];

      final screenInfo = ScreenInfo(
        name: 'game',
        displayName: 'Game',
        description: 'Game screen',
        purpose: 'Playing games',
        features: [],
        buttons: [],
        gestures: gestures,
        voiceCommands: [],
        navigatesTo: [],
        hasAIInteraction: false,
      );

      expect(screenInfo.gestures.length, 1);
      expect(screenInfo.gestures.first.type, 'tap');
    });

    test('ScreenInfo voice commands are stored', () {
      final commands = ['help', 'go back', 'next'];
      final screenInfo = ScreenInfo(
        name: 'voice_assistant',
        displayName: 'Voice Assistant',
        description: 'Voice interaction',
        purpose: 'Voice control',
        features: [],
        buttons: [],
        gestures: [],
        voiceCommands: commands,
        navigatesTo: [],
        hasAIInteraction: true,
      );

      expect(screenInfo.voiceCommands, commands);
      expect(screenInfo.voiceCommands.length, 3);
    });

    test('ScreenInfo navigation links are preserved', () {
      final navigatesTo = ['/home', '/settings', '/about'];
      final screenInfo = ScreenInfo(
        name: 'menu',
        displayName: 'Menu',
        description: 'Navigation menu',
        purpose: 'Navigation',
        features: [],
        buttons: [],
        gestures: [],
        voiceCommands: [],
        navigatesTo: navigatesTo,
        hasAIInteraction: false,
      );

      expect(screenInfo.navigatesTo, navigatesTo);
      expect(screenInfo.navigatesTo.length, 3);
    });
  });

  group('ButtonInfo Model Tests', () {
    test('ButtonInfo can be instantiated', () {
      const button = ButtonInfo(
        name: 'Submit',
        description: 'Submit form',
        onTap: 'submit_form',
      );

      expect(button.name, 'Submit');
      expect(button.description, 'Submit form');
      expect(button.onTap, 'submit_form');
    });

    test('ButtonInfo with double tap action', () {
      const button = ButtonInfo(
        name: 'Settings',
        description: 'Open settings',
        onTap: 'open_settings',
        onDoubleTap: 'reset_settings',
      );

      expect(button.onDoubleTap, 'reset_settings');
    });

    test('ButtonInfo with long press action', () {
      const button = ButtonInfo(
        name: 'Delete',
        description: 'Delete item',
        onTap: 'delete_item',
        onLongPress: 'confirm_delete',
      );

      expect(button.onLongPress, 'confirm_delete');
    });
  });

  group('GestureInfo Model Tests', () {
    test('GestureInfo can be instantiated', () {
      const gesture = GestureInfo(
        type: 'double_tap',
        description: 'Double tap to zoom',
        action: 'zoom',
      );

      expect(gesture.type, 'double_tap');
      expect(gesture.description, 'Double tap to zoom');
      expect(gesture.action, 'zoom');
    });

    test('GestureInfo supports various gesture types', () {
      final gestures = [
        const GestureInfo(type: 'tap', description: 'Single tap', action: 'select'),
        const GestureInfo(
            type: 'double_tap', description: 'Double tap', action: 'zoom'),
        const GestureInfo(
            type: 'long_press', description: 'Long press', action: 'menu'),
        const GestureInfo(type: 'swipe', description: 'Swipe', action: 'navigate'),
      ];

      expect(gestures.length, 4);
      expect(gestures.map((g) => g.type).toList(),
          ['tap', 'double_tap', 'long_press', 'swipe']);
    });

    test('GestureInfo toMap conversion works', () {
      const gesture = GestureInfo(
        type: 'tap',
        description: 'Single tap action',
        action: 'select',
      );

      final map = gesture.toMap();
      expect(map['type'], 'tap');
      expect(map['description'], 'Single tap action');
      expect(map['action'], 'select');
    });
  });
}
