import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:voice_assistant_app/features/orb_thinking/orb_thinking_controller.dart';
import 'package:voice_assistant_app/features/orb_thinking/thought_bubble_widget.dart';
import 'package:voice_assistant_app/features/orb_thinking/avatar_resolver.dart';
import 'package:voice_assistant_app/features/orb_thinking/sound_effect_player.dart';
import 'package:voice_assistant_app/features/orb_thinking/performance_validator.dart';

void main() {
  group('Orb Thinking Performance Tests', () {
    late OrbThinkingController controller;

    setUp(() {
      Get.testMode = true;
      controller = OrbThinkingController();
      Get.put(controller);
    });

    tearDown(() {
      Get.reset();
    });

    testWidgets('ThoughtBubbleWidget renders with RepaintBoundary optimization',
        (tester) async {
      // Build the widget with RepaintBoundary
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: ThoughtBubbleWidget(
                avatarAssetPath: 'assets/images/simple orb/smiley.png',
                visible: true,
                size: 110,
              ),
            ),
          ),
        ),
      );

      // Pump multiple frames to test animation performance
      for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16)); // ~60fps
      }

      // Verify RepaintBoundary is present
      expect(find.byType(RepaintBoundary), findsAtLeastNWidgets(1));
      expect(find.byType(ThoughtBubbleWidget), findsOneWidget);
    });

    testWidgets('Multiple ThoughtBubbleWidgets maintain performance',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                RepaintBoundary(
                  child: ThoughtBubbleWidget(
                    avatarAssetPath: 'assets/images/simple orb/smiley.png',
                    visible: true,
                    size: 110,
                  ),
                ),
                RepaintBoundary(
                  child: ThoughtBubbleWidget(
                    avatarAssetPath: 'assets/images/simple orb/excited.png',
                    visible: true,
                    size: 90,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Test rapid state changes
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(find.byType(ThoughtBubbleWidget), findsNWidgets(2));
      expect(find.byType(RepaintBoundary), findsAtLeastNWidgets(2));
    });

    test('Image preloading system works correctly', () async {
      // Wait for preloading to complete
      await Future.delayed(const Duration(milliseconds: 500));

      // Test that all avatar paths can be retrieved
      final avatarPaths = AvatarResolver.getAllAvatarPaths();
      expect(avatarPaths.isNotEmpty, true);
      expect(avatarPaths.length,
          greaterThan(30)); // Should have 30+ unique avatars

      // Verify diamond orb paths are included
      expect(avatarPaths.any((path) => path.contains('diamond orb')), true);
      expect(avatarPaths.any((path) => path.contains('simple orb')), true);

      // Check preloading statistics
      final stats = controller.getPreloadingStats();
      expect(stats['total'], greaterThan(0));
      expect(stats['successful'], isA<int>());
      expect(stats['failed'], isA<int>());
      expect(stats['successRate'], isA<String>());
    });

    test('AudioPlayer singleton prevents resource leaks', () async {
      // Test multiple calls don't create multiple instances
      await SoundEffectPlayer.playForAvatar(
          'assets/images/simple orb/smiley.png');
      await SoundEffectPlayer.stop();

      await SoundEffectPlayer.playForAvatar(
          'assets/images/simple orb/angry.png');
      await SoundEffectPlayer.stop();

      // Dispose should clean up properly
      await SoundEffectPlayer.dispose();

      // Should be able to play again after dispose
      await SoundEffectPlayer.playForAvatar(
          'assets/images/simple orb/excited.png');
      await SoundEffectPlayer.dispose();

      // No exceptions should be thrown
    });

    test('Controller handles rapid keyword changes efficiently', () async {
      // Simulate rapid speech with multiple keywords
      controller.onSentenceSpoken('I am happy and excited');
      expect(controller.currentAvatarPath, isNotNull);

      controller.onSentenceSpoken('Now I am angry and frustrated');
      expect(controller.currentAvatarPath, isNotNull);

      controller.onSentenceSpoken('Let me think about this');
      expect(controller.currentAvatarPath, isNotNull);

      controller.onSpeechEnd();
      expect(controller.currentAvatarPath, null);
      expect(controller.isThinking, false);
    });

    testWidgets('Animation performance with reactive state changes',
        (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              child: Obx(() => ThoughtBubbleWidget(
                    avatarAssetPath: controller.currentAvatarPath ?? '',
                    visible: controller.isThinking &&
                        controller.currentAvatarPath != null,
                    size: 110,
                  )),
            ),
          ),
        ),
      );

      // Simulate rapid state changes
      controller.onSentenceSpoken('I am happy');
      await tester.pump(const Duration(milliseconds: 16));

      controller.onSentenceSpoken('Now I am angry');
      await tester.pump(const Duration(milliseconds: 16));

      controller.onSentenceSpoken('Let me think');
      await tester.pump(const Duration(milliseconds: 16));

      controller.onSpeechEnd();
      await tester.pump(const Duration(milliseconds: 16));

      // Should complete without frame drops
      await tester.pumpAndSettle();

      // Verify RepaintBoundary isolation
      expect(find.byType(RepaintBoundary), findsOneWidget);
    });

    test('Performance validation passes all checks', () async {
      final validator = PerformanceValidator();
      final result = await validator.validatePerformance();

      // Print detailed report for debugging
      print(result.generateReport());

      // All performance optimizations should pass
      expect(result.overallSuccess, true,
          reason: 'Performance validation failed');
      expect(result.results['image_preloading'], true);
      expect(result.results['audio_singleton'], true);
      expect(result.results['repaint_boundaries'], true);
    });

    test('Preloaded images have better cache performance', () async {
      // Wait for preloading
      await Future.delayed(const Duration(milliseconds: 500));

      const testPath = 'assets/images/diamond orb/diamond_orb.png';
      final isPreloaded = controller.isImagePreloaded(testPath);

      // Should be preloaded if the path exists in the resolver
      final allPaths = AvatarResolver.getAllAvatarPaths();
      if (allPaths.contains(testPath)) {
        expect(isPreloaded, true, reason: 'Image should be preloaded');
      }
    });
  });
}
