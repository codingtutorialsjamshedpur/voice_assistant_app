import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:voice_assistant_app/features/orb_thinking/orb_thinking_controller.dart';
import 'package:voice_assistant_app/features/orb_thinking/thought_bubble_widget.dart';
import 'package:voice_assistant_app/screens/voice_chat/voice_chat_screen.dart';
import 'package:voice_assistant_app/screens/game/voice_assistant_game_screen.dart';
import 'package:voice_assistant_app/screens/voice_chat/extended_voice_chat_screen.dart';
import 'package:voice_assistant_app/controllers/voice_controller.dart';
import 'package:voice_assistant_app/controllers/profile_controller.dart';
import 'package:voice_assistant_app/controllers/voice_assistant_game_controller.dart';
import 'package:voice_assistant_app/services/query_handler_service.dart';
import 'package:voice_assistant_app/services/idle_prompt_service.dart';
import 'package:voice_assistant_app/services/profile_context_service.dart';
import 'package:voice_assistant_app/services/engagement_orchestrator_service.dart';
import 'package:voice_assistant_app/services/enhanced_greeting_service.dart';
import 'package:voice_assistant_app/services/stt_service.dart';
import 'package:voice_assistant_app/services/tts_service.dart';
import 'package:voice_assistant_app/services/family_relationship_manager_service.dart';
import 'package:voice_assistant_app/services/health_hygiene_manager_service.dart';
import 'package:voice_assistant_app/services/gesture_recognizer_service.dart';

void main() {
  group('Cross-Screen Consistency Tests', () {
    late OrbThinkingController orbController;

    setUp(() {
      // Initialize GetX
      Get.testMode = true;

      // Register all required dependencies
      Get.put(VoiceController());
      Get.put(ProfileController());
      Get.put(VoiceAssistantGameController());
      Get.put(QueryHandlerService());
      Get.put(IdlePromptService());
      Get.put(ProfileContextService());
      Get.put(EngagementOrchestratorService());
      Get.put(EnhancedGreetingService());
      Get.put(STTService());
      Get.put(TTSService());
      Get.put(FamilyRelationshipManagerService());
      Get.put(HealthHygieneManagerService());
      Get.put(GestureRecognizerService());

      // Register OrbThinkingController
      orbController = Get.put(OrbThinkingController());
    });

    tearDown(() {
      Get.reset();
    });

    group('Voice Chat Screen Integration', () {
      testWidgets('should display thought bubble above main orb',
          (tester) async {
        await tester.pumpWidget(
          const GetMaterialApp(
            home: VoiceChatScreen(),
          ),
        );

        // Wait for initial build
        await tester.pumpAndSettle();

        // Trigger a thought bubble by setting avatar
        orbController.showAvatar('assets/images/simple orb/happy.png');
        await tester.pumpAndSettle();

        // Find the thought bubble widget
        final thoughtBubbleFinder = find.byType(ThoughtBubbleWidget);
        expect(thoughtBubbleFinder, findsOneWidget);

        // Verify the thought bubble is positioned correctly
        final thoughtBubbleWidget =
            tester.widget<ThoughtBubbleWidget>(thoughtBubbleFinder);
        expect(thoughtBubbleWidget.size, equals(110)); // Voice Chat Screen size
        expect(thoughtBubbleWidget.visible, isTrue);
        expect(thoughtBubbleWidget.avatarAssetPath,
            equals('assets/images/simple orb/happy.png'));

        // Verify positioning using Positioned widget
        final positionedFinder = find.ancestor(
          of: thoughtBubbleFinder,
          matching: find.byType(Positioned),
        );
        expect(positionedFinder, findsOneWidget);

        final positioned = tester.widget<Positioned>(positionedFinder);
        expect(positioned.right, equals(-60)); // Voice Chat Screen offset
        expect(positioned.top, equals(-80));
      });

      testWidgets('should hide thought bubble when avatar is cleared',
          (tester) async {
        await tester.pumpWidget(
          const GetMaterialApp(
            home: VoiceChatScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // Show avatar first
        orbController.showAvatar('assets/images/simple orb/happy.png');
        await tester.pumpAndSettle();

        // Verify bubble is visible
        final thoughtBubbleWidget = tester.widget<ThoughtBubbleWidget>(
          find.byType(ThoughtBubbleWidget),
        );
        expect(thoughtBubbleWidget.visible, isTrue);

        // Clear avatar
        orbController.onSpeechEnd();
        await tester.pumpAndSettle();

        // Verify bubble is hidden
        final updatedThoughtBubbleWidget = tester.widget<ThoughtBubbleWidget>(
          find.byType(ThoughtBubbleWidget),
        );
        expect(updatedThoughtBubbleWidget.visible, isFalse);
      });
    });

    group('Voice Assistant Game Screen Integration', () {
      testWidgets(
          'should display thought bubble above game orb with correct sizing',
          (tester) async {
        await tester.pumpWidget(
          const GetMaterialApp(
            home: VoiceAssistantGameScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // Trigger a thought bubble
        orbController.showAvatar('assets/images/diamond orb/diamond_orb.png');
        await tester.pumpAndSettle();

        // Find the thought bubble widget
        final thoughtBubbleFinder = find.byType(ThoughtBubbleWidget);
        expect(thoughtBubbleFinder, findsOneWidget);

        // Verify the thought bubble has game screen sizing
        final thoughtBubbleWidget =
            tester.widget<ThoughtBubbleWidget>(thoughtBubbleFinder);
        expect(
            thoughtBubbleWidget.size, equals(120)); // Game Screen size (larger)
        expect(thoughtBubbleWidget.visible, isTrue);
        expect(thoughtBubbleWidget.avatarAssetPath,
            equals('assets/images/diamond orb/diamond_orb.png'));

        // Verify positioning for game screen
        final positionedFinder = find.ancestor(
          of: thoughtBubbleFinder,
          matching: find.byType(Positioned),
        );
        expect(positionedFinder, findsOneWidget);

        final positioned = tester.widget<Positioned>(positionedFinder);
        expect(positioned.right,
            equals(-70)); // Game Screen offset (different from Voice Chat)
        expect(positioned.top, equals(-90));
      });

      testWidgets('should be wrapped in RepaintBoundary for performance',
          (tester) async {
        await tester.pumpWidget(
          const GetMaterialApp(
            home: VoiceAssistantGameScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // Find RepaintBoundary wrapping the orb stack
        final repaintBoundaryFinder = find.byType(RepaintBoundary);
        expect(repaintBoundaryFinder, findsAtLeastNWidgets(1));

        // Verify ThoughtBubbleWidget is within a RepaintBoundary
        final thoughtBubbleFinder = find.byType(ThoughtBubbleWidget);
        final repaintBoundaryAncestor = find.ancestor(
          of: thoughtBubbleFinder,
          matching: find.byType(RepaintBoundary),
        );
        expect(repaintBoundaryAncestor, findsOneWidget);
      });
    });

    group('Extended Voice Chat Screen Integration', () {
      testWidgets('should have no orb and no thought bubble integration',
          (tester) async {
        await tester.pumpWidget(
          const GetMaterialApp(
            home: ExtendedVoiceChatScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // Verify no ThoughtBubbleWidget exists
        final thoughtBubbleFinder = find.byType(ThoughtBubbleWidget);
        expect(thoughtBubbleFinder, findsNothing);

        // Verify no orb-related widgets exist
        final orbFinder = find.byKey(const Key('animated_orb'));
        expect(orbFinder, findsNothing);

        // Trigger avatar to ensure it doesn't affect this screen
        orbController.showAvatar('assets/images/simple orb/happy.png');
        await tester.pumpAndSettle();

        // Still no thought bubble should appear
        final stillNoThoughtBubble = find.byType(ThoughtBubbleWidget);
        expect(stillNoThoughtBubble, findsNothing);
      });

      testWidgets('should display extended chat interface without orb elements',
          (tester) async {
        await tester.pumpWidget(
          const GetMaterialApp(
            home: ExtendedVoiceChatScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // Verify extended chat mode elements exist
        expect(find.text('Extended Chat Mode'), findsOneWidget);
        expect(find.text('Suggested Prompts'), findsOneWidget);
        expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

        // Verify topic cards exist
        expect(find.text('Meditation'), findsOneWidget);
        expect(find.text('Wisdom'), findsOneWidget);
        expect(find.text('Healing'), findsOneWidget);

        // But no orb or thought bubble elements
        expect(find.byType(ThoughtBubbleWidget), findsNothing);
      });
    });

    group('Shared Controller State Management', () {
      testWidgets('should maintain consistent state across screen transitions',
          (tester) async {
        // Start with Voice Chat Screen
        await tester.pumpWidget(
          const GetMaterialApp(
            home: VoiceChatScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // Set an avatar state
        orbController.showAvatar('assets/images/simple orb/excited.png');
        await tester.pumpAndSettle();

        // Verify state is set
        expect(orbController.currentAvatarPath,
            equals('assets/images/simple orb/excited.png'));
        expect(orbController.isThinking, isTrue);

        // Simulate screen transition to Game Screen
        await tester.pumpWidget(
          const GetMaterialApp(
            home: VoiceAssistantGameScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // Verify state is maintained
        expect(orbController.currentAvatarPath,
            equals('assets/images/simple orb/excited.png'));
        expect(orbController.isThinking, isTrue);

        // Verify thought bubble appears on new screen with same avatar
        final thoughtBubbleWidget = tester.widget<ThoughtBubbleWidget>(
          find.byType(ThoughtBubbleWidget),
        );
        expect(thoughtBubbleWidget.avatarAssetPath,
            equals('assets/images/simple orb/excited.png'));
        expect(thoughtBubbleWidget.visible, isTrue);
      });

      testWidgets(
          'should clear state when speech ends regardless of current screen',
          (tester) async {
        // Start with Game Screen
        await tester.pumpWidget(
          const GetMaterialApp(
            home: VoiceAssistantGameScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // Set avatar state
        orbController
            .showAvatar('assets/images/diamond orb/diamond_orb_music.png');
        await tester.pumpAndSettle();

        // Verify state is active
        expect(orbController.isThinking, isTrue);

        // End speech
        orbController.onSpeechEnd();
        await tester.pumpAndSettle();

        // Verify state is cleared
        expect(orbController.isThinking, isFalse);
        expect(orbController.currentAvatarPath, isNull);

        // Switch to Voice Chat Screen
        await tester.pumpWidget(
          const GetMaterialApp(
            home: VoiceChatScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // Verify cleared state is maintained
        final thoughtBubbleWidget = tester.widget<ThoughtBubbleWidget>(
          find.byType(ThoughtBubbleWidget),
        );
        expect(thoughtBubbleWidget.visible, isFalse);
      });

      testWidgets('should handle rapid state changes consistently',
          (tester) async {
        await tester.pumpWidget(
          const GetMaterialApp(
            home: VoiceChatScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // Rapid avatar changes
        orbController.showAvatar('assets/images/simple orb/happy.png');
        await tester.pump(const Duration(milliseconds: 50));

        orbController.showAvatar('assets/images/simple orb/sad.png');
        await tester.pump(const Duration(milliseconds: 50));

        orbController.showAvatar('assets/images/diamond orb/diamond_orb.png');
        await tester.pumpAndSettle();

        // Verify final state
        expect(orbController.currentAvatarPath,
            equals('assets/images/diamond orb/diamond_orb.png'));
        expect(orbController.isThinking, isTrue);

        final thoughtBubbleWidget = tester.widget<ThoughtBubbleWidget>(
          find.byType(ThoughtBubbleWidget),
        );
        expect(thoughtBubbleWidget.avatarAssetPath,
            equals('assets/images/diamond orb/diamond_orb.png'));
        expect(thoughtBubbleWidget.visible, isTrue);
      });
    });

    group('Performance and Isolation Tests', () {
      testWidgets('should maintain RepaintBoundary isolation on both screens',
          (tester) async {
        // Test Voice Chat Screen
        await tester.pumpWidget(
          const GetMaterialApp(
            home: VoiceChatScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // Find RepaintBoundary around orb+bubble stack
        final voiceChatRepaintBoundary = find.byType(RepaintBoundary);
        expect(voiceChatRepaintBoundary, findsAtLeastNWidgets(1));

        // Test Game Screen
        await tester.pumpWidget(
          const GetMaterialApp(
            home: VoiceAssistantGameScreen(),
          ),
        );

        await tester.pumpAndSettle();

        // Find RepaintBoundary around orb+bubble stack
        final gameRepaintBoundary = find.byType(RepaintBoundary);
        expect(gameRepaintBoundary, findsAtLeastNWidgets(1));
      });

      testWidgets('should handle controller access failures gracefully',
          (tester) async {
        // Remove controller to simulate failure
        Get.delete<OrbThinkingController>();

        await tester.pumpWidget(
          const GetMaterialApp(
            home: VoiceChatScreen(),
          ),
        );

        // Should not crash even without controller
        await tester.pumpAndSettle();

        // Screen should still render
        expect(find.byType(VoiceChatScreen), findsOneWidget);
      });
    });

    group('Screen-Specific Positioning Tests', () {
      testWidgets('should use correct positioning offsets for each screen',
          (tester) async {
        // Test Voice Chat Screen positioning
        await tester.pumpWidget(
          const GetMaterialApp(
            home: VoiceChatScreen(),
          ),
        );

        await tester.pumpAndSettle();

        orbController.showAvatar('assets/images/simple orb/happy.png');
        await tester.pumpAndSettle();

        var positioned = tester.widget<Positioned>(
          find.ancestor(
            of: find.byType(ThoughtBubbleWidget),
            matching: find.byType(Positioned),
          ),
        );

        expect(positioned.right, equals(-60));
        expect(positioned.top, equals(-80));

        // Test Game Screen positioning
        await tester.pumpWidget(
          const GetMaterialApp(
            home: VoiceAssistantGameScreen(),
          ),
        );

        await tester.pumpAndSettle();

        positioned = tester.widget<Positioned>(
          find.ancestor(
            of: find.byType(ThoughtBubbleWidget),
            matching: find.byType(Positioned),
          ),
        );

        expect(positioned.right, equals(-70));
        expect(positioned.top, equals(-90));
      });

      testWidgets('should use correct bubble sizes for each screen',
          (tester) async {
        // Voice Chat Screen - 110px
        await tester.pumpWidget(
          const GetMaterialApp(
            home: VoiceChatScreen(),
          ),
        );

        await tester.pumpAndSettle();

        orbController.showAvatar('assets/images/simple orb/happy.png');
        await tester.pumpAndSettle();

        var thoughtBubble = tester.widget<ThoughtBubbleWidget>(
          find.byType(ThoughtBubbleWidget),
        );
        expect(thoughtBubble.size, equals(110));

        // Game Screen - 120px
        await tester.pumpWidget(
          const GetMaterialApp(
            home: VoiceAssistantGameScreen(),
          ),
        );

        await tester.pumpAndSettle();

        thoughtBubble = tester.widget<ThoughtBubbleWidget>(
          find.byType(ThoughtBubbleWidget),
        );
        expect(thoughtBubble.size, equals(120));
      });
    });
  });
}
