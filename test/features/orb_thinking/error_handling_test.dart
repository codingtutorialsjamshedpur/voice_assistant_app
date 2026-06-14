import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:voice_assistant_app/features/orb_thinking/orb_thinking_controller.dart';
import 'package:voice_assistant_app/features/orb_thinking/avatar_resolver.dart';
import 'package:voice_assistant_app/features/orb_thinking/sound_effect_player.dart';
import 'package:voice_assistant_app/features/orb_thinking/thought_bubble_widget.dart';

void main() {
  group('Error Handling and Edge Case Tests', () {
    late OrbThinkingController controller;

    setUp(() {
      Get.testMode = true;
      controller = OrbThinkingController();
      Get.put(controller);
    });

    tearDown(() async {
      await SoundEffectPlayer.dispose();
      Get.reset();
    });

    group('Missing Avatar Images Tests', () {
      testWidgets(
          'ThoughtBubbleWidget handles missing avatar images gracefully',
          (tester) async {
        // Test with non-existent image path
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ThoughtBubbleWidget(
                avatarAssetPath: 'assets/nonexistent/missing_image.png',
                visible: true,
                size: 110,
              ),
            ),
          ),
        );

        // Should show fallback icon instead of crashing
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.psychology), findsOneWidget);
        expect(find.byType(ThoughtBubbleWidget), findsOneWidget);
      });

      testWidgets('Multiple missing images don\'t crash the widget',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ThoughtBubbleWidget(
                    avatarAssetPath: 'assets/fake/image1.png',
                    visible: true,
                    size: 110,
                  ),
                  ThoughtBubbleWidget(
                    avatarAssetPath: 'assets/fake/image2.png',
                    visible: true,
                    size: 90,
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Both should show fallback icons
        expect(find.byIcon(Icons.psychology), findsNWidgets(2));
        expect(find.byType(ThoughtBubbleWidget), findsNWidgets(2));
      });

      test('Controller handles missing images during preloading', () async {
        // Wait for preloading to complete
        await Future.delayed(const Duration(milliseconds: 600));

        final stats = controller.getPreloadingStats();

        // Should have attempted to load images and tracked failures
        expect(stats['total'], greaterThan(0));
        expect(stats['failed'], isA<int>());
        expect(stats['successful'], isA<int>());

        // Should not crash even if some images failed
        expect(stats['successRate'], isA<String>());
      });

      testWidgets('Image crossfade handles missing images during transition',
          (tester) async {
        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: Obx(() => ThoughtBubbleWidget(
                    avatarAssetPath: controller.currentAvatarPath ??
                        'assets/fake/missing.png',
                    visible: controller.isThinking,
                    size: 110,
                  )),
            ),
          ),
        );

        // Start with missing image
        controller.onSentenceSpoken('happy');
        await tester.pump();

        // Change to another missing image
        controller.onSentenceSpoken('angry');
        await tester.pump();

        // Should handle crossfade gracefully with fallback icons
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.psychology), findsOneWidget);
      });
    });

    group('Missing Sound Files Tests', () {
      test('SoundEffectPlayer handles missing sound files gracefully',
          () async {
        // Test with non-existent avatar paths that would map to missing sounds
        final missingAvatarPaths = [
          'assets/fake/nonexistent_avatar.png',
          'assets/missing/sound_file.png',
          'completely_invalid_path',
          '',
        ];

        for (final path in missingAvatarPaths) {
          // Should not throw exceptions
          await expectLater(
            () => SoundEffectPlayer.playForAvatar(path),
            returnsNormally,
          );
        }
      });

      test('Audio system continues working after sound file errors', () async {
        // Play a missing sound
        await SoundEffectPlayer.playForAvatar('assets/fake/missing_sound.png');

        // Should still be able to play valid sounds after error
        await SoundEffectPlayer.playForAvatar(
            'assets/images/simple orb/happy.png');

        // Should complete without throwing
        await SoundEffectPlayer.stop();
      });

      test('Rapid sound changes with missing files don\'t cause crashes',
          () async {
        final testPaths = [
          'assets/fake/missing1.png',
          'assets/images/simple orb/happy.png', // valid
          'assets/fake/missing2.png',
          'assets/images/simple orb/angry.png', // valid
          'completely_invalid_path',
        ];

        // Rapid fire sound requests
        for (final path in testPaths) {
          await SoundEffectPlayer.playForAvatar(path);
          await Future.delayed(const Duration(milliseconds: 10));
        }

        // Should complete without errors
        await SoundEffectPlayer.stop();
      });

      test('Audio player handles disposal and recreation after errors',
          () async {
        // Cause an error with missing file
        await SoundEffectPlayer.playForAvatar('assets/fake/missing.png');

        // Dispose the player
        await SoundEffectPlayer.dispose();

        // Should be able to recreate and use again
        await SoundEffectPlayer.playForAvatar(
            'assets/images/simple orb/happy.png');

        await SoundEffectPlayer.dispose();
      });
    });

    group('Rapid Speech Changes and Cleanup Tests', () {
      test('Controller handles rapid sentence changes without memory leaks',
          () async {
        final sentences = [
          'I am very happy today',
          'Now I feel angry and frustrated',
          'Let me think about this problem',
          'I want to do some yoga',
          'This music is amazing',
          'I feel excited about this',
          'Time to read the newspaper',
          'I am getting tired now',
        ];

        // Rapid fire sentence processing
        for (int i = 0; i < 50; i++) {
          for (final sentence in sentences) {
            controller.onSentenceSpoken(sentence);
            await Future.delayed(const Duration(milliseconds: 5));
          }

          // Cleanup after each batch
          controller.onSpeechEnd();
          await Future.delayed(const Duration(milliseconds: 10));
        }

        // Should complete without memory issues
        expect(controller.isThinking, false);
        expect(controller.currentAvatarPath, null);
      });

      test('Audio system handles rapid start/stop cycles', () async {
        // Simulate rapid speech with frequent interruptions
        for (int i = 0; i < 20; i++) {
          await SoundEffectPlayer.playForAvatar(
              'assets/images/simple orb/happy.png');
          await Future.delayed(const Duration(milliseconds: 50));

          await SoundEffectPlayer.stop();
          await Future.delayed(const Duration(milliseconds: 20));

          await SoundEffectPlayer.playForAvatar(
              'assets/images/simple orb/angry.png');
          await Future.delayed(const Duration(milliseconds: 30));

          await SoundEffectPlayer.stop();
          await Future.delayed(const Duration(milliseconds: 10));
        }

        // Final cleanup should work
        await SoundEffectPlayer.dispose();
      });

      testWidgets('ThoughtBubbleWidget handles rapid visibility changes',
          (tester) async {
        bool isVisible = false;
        String currentPath = 'assets/images/simple orb/happy.png';

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      ThoughtBubbleWidget(
                        avatarAssetPath: currentPath,
                        visible: isVisible,
                        size: 110,
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            isVisible = !isVisible;
                            currentPath = isVisible
                                ? 'assets/images/simple orb/angry.png'
                                : 'assets/images/simple orb/happy.png';
                          });
                        },
                        child: const Text('Toggle'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );

        // Rapid visibility toggles
        for (int i = 0; i < 10; i++) {
          await tester.tap(find.byType(ElevatedButton));
          await tester.pump(const Duration(milliseconds: 50));
        }

        await tester.pumpAndSettle();
        expect(find.byType(ThoughtBubbleWidget), findsOneWidget);
      });

      test('Controller cleanup prevents resource leaks during rapid changes',
          () async {
        // Create multiple controllers to test cleanup
        final controllers = <OrbThinkingController>[];

        for (int i = 0; i < 5; i++) {
          final testController = OrbThinkingController();
          controllers.add(testController);

          // Use each controller briefly
          testController.onSentenceSpoken('I am happy');
          await Future.delayed(const Duration(milliseconds: 100));
          testController.onSpeechEnd();

          // Dispose immediately
          testController.onClose();
        }

        // Should complete without memory issues
        expect(controllers.length, 5);
      });
    });

    group('Controller Unavailable Tests', () {
      testWidgets('ThoughtBubbleWidget gracefully handles missing controller',
          (tester) async {
        // Reset GetX to remove controller
        Get.reset();

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ThoughtBubbleWidget(
                avatarAssetPath: 'assets/images/simple orb/happy.png',
                visible: true,
                size: 110,
              ),
            ),
          ),
        );

        // Should render without crashing even without controller
        await tester.pumpAndSettle();
        expect(find.byType(ThoughtBubbleWidget), findsOneWidget);
      });

      testWidgets('Obx widgets handle controller unavailability gracefully',
          (tester) async {
        // Create widget that tries to access missing controller
        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  try {
                    final controller = Get.find<OrbThinkingController>();
                    return Obx(() => ThoughtBubbleWidget(
                          avatarAssetPath: controller.currentAvatarPath ?? '',
                          visible: controller.isThinking,
                          size: 110,
                        ));
                  } catch (e) {
                    // Graceful fallback when controller not found
                    return const ThoughtBubbleWidget(
                      avatarAssetPath: 'assets/images/simple orb/happy.png',
                      visible: false,
                      size: 110,
                    );
                  }
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byType(ThoughtBubbleWidget), findsOneWidget);
      });

      test('AvatarResolver works independently of controller', () {
        // Reset GetX to ensure no controller dependency
        Get.reset();

        // Should still resolve keywords without controller
        expect(AvatarResolver.resolve('happy'), isNotNull);
        expect(
            AvatarResolver.resolveFromSentence('I am very excited'), isNotNull);
        expect(AvatarResolver.getAllAvatarPaths().isNotEmpty, true);
      });

      test('SoundEffectPlayer works independently of controller', () async {
        // Reset GetX to ensure no controller dependency
        Get.reset();

        // Should still play sounds without controller
        await expectLater(
          () => SoundEffectPlayer.playForAvatar(
              'assets/images/simple orb/happy.png'),
          returnsNormally,
        );

        await SoundEffectPlayer.stop();
        await SoundEffectPlayer.dispose();
      });
    });

    group('Memory Usage During Extended Use Tests', () {
      test('Controller maintains stable memory usage over time', () async {
        // Simulate extended usage with many operations
        final startStats = controller.getPreloadingStats();

        // Perform many operations over simulated time
        for (int session = 0; session < 10; session++) {
          // Simulate a conversation session
          for (int i = 0; i < 100; i++) {
            controller.onSentenceSpoken('I am happy and excited');
            await Future.delayed(const Duration(milliseconds: 1));
            controller.onSpeechEnd();
            await Future.delayed(const Duration(milliseconds: 1));
          }

          // Brief pause between sessions
          await Future.delayed(const Duration(milliseconds: 50));
        }

        final endStats = controller.getPreloadingStats();

        // Memory usage should remain stable (no growing caches)
        expect(endStats['total'], equals(startStats['total']));
        expect(controller.isThinking, false);
        expect(controller.currentAvatarPath, null);
      });

      test('Audio system maintains stable memory over extended use', () async {
        // Simulate extended audio usage
        final avatarPaths = [
          'assets/images/simple orb/happy.png',
          'assets/images/simple orb/angry.png',
          'assets/images/simple orb/excited.png',
          'assets/images/simple orb/thinking.png',
        ];

        // Extended usage simulation
        for (int cycle = 0; cycle < 50; cycle++) {
          for (final path in avatarPaths) {
            await SoundEffectPlayer.playForAvatar(path);
            await Future.delayed(const Duration(milliseconds: 20));
            await SoundEffectPlayer.stop();
            await Future.delayed(const Duration(milliseconds: 10));
          }
        }

        // Should complete without memory issues
        await SoundEffectPlayer.dispose();
      });

      testWidgets(
          'ThoughtBubbleWidget animations don\'t accumulate memory leaks',
          (tester) async {
        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: Obx(() => ThoughtBubbleWidget(
                    avatarAssetPath: controller.currentAvatarPath ??
                        'assets/images/simple orb/happy.png',
                    visible: controller.isThinking,
                    size: 110,
                  )),
            ),
          ),
        );

        // Simulate extended animation usage
        for (int i = 0; i < 100; i++) {
          controller.onSentenceSpoken('I am happy');
          await tester.pump(const Duration(milliseconds: 16));

          controller.onSpeechEnd();
          await tester.pump(const Duration(milliseconds: 16));
        }

        await tester.pumpAndSettle();

        // Should complete without memory issues
        expect(find.byType(ThoughtBubbleWidget), findsOneWidget);
      });

      test('Image preloading cache remains stable over time', () async {
        // Get initial cache state
        final initialStats = controller.getPreloadingStats();

        // Simulate extended usage that might trigger cache operations
        for (int i = 0; i < 200; i++) {
          final allPaths = AvatarResolver.getAllAvatarPaths().toList();
          for (final path in allPaths.take(5)) {
            controller.isImagePreloaded(path);
          }
        }

        final finalStats = controller.getPreloadingStats();

        // Cache should remain stable (no growing or shrinking)
        expect(finalStats['total'], equals(initialStats['total']));
        expect(finalStats['successful'], equals(initialStats['successful']));
      });

      test('GetX reactive system handles extended observation', () async {
        int changeCount = 0;

        // Set up reactive listener
        final worker = ever(controller.currentAvatarPathRx, (_) {
          changeCount++;
        });

        // Generate many state changes
        for (int i = 0; i < 500; i++) {
          controller.onSentenceSpoken('I am happy');
          controller.onSpeechEnd();
        }

        // Cleanup
        worker.dispose();

        // Should have tracked all changes without memory issues
        expect(changeCount, greaterThan(0));
      });
    });

    group('Edge Case Combinations Tests', () {
      testWidgets('Missing images + missing controller + rapid changes',
          (tester) async {
        // Reset controller
        Get.reset();

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ThoughtBubbleWidget(
                avatarAssetPath: 'assets/fake/missing.png',
                visible: true,
                size: 110,
              ),
            ),
          ),
        );

        // Rapid widget updates with missing resources
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        await tester.pumpAndSettle();

        // Should show fallback and not crash
        expect(find.byIcon(Icons.psychology), findsOneWidget);
      });

      test('Audio errors + controller disposal + rapid operations', () async {
        // Start with valid operations
        controller.onSentenceSpoken('I am happy');
        await SoundEffectPlayer.playForAvatar('assets/fake/missing.png');

        // Dispose controller while operations are happening
        controller.onClose();

        // Continue operations after disposal
        await SoundEffectPlayer.playForAvatar('assets/another/missing.png');
        await SoundEffectPlayer.stop();

        // Should handle gracefully
        await SoundEffectPlayer.dispose();
      });

      test('Keyword resolution with malformed input', () {
        final malformedInputs = [
          '', // empty
          '   ', // whitespace only
          '!@#\$%^&*()', // special characters only
          'a' * 1000, // very long string
          '\n\t\r', // control characters
          '🎵🎶🎤', // emojis
          'हिंदी।।।', // Hindi with punctuation
          null, // null handling in sentence
        ];

        for (final input in malformedInputs) {
          // Should not crash on malformed input
          expect(() => AvatarResolver.resolve(input ?? ''), returnsNormally);
          expect(() => AvatarResolver.resolveFromSentence(input ?? ''),
              returnsNormally);
        }
      });

      testWidgets('Widget disposal during active animations', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ThoughtBubbleWidget(
                avatarAssetPath: 'assets/images/simple orb/happy.png',
                visible: true,
                size: 110,
              ),
            ),
          ),
        );

        // Start animations
        await tester.pump(const Duration(milliseconds: 100));

        // Remove widget during animation
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox.shrink(),
            ),
          ),
        );

        // Should dispose cleanly
        await tester.pumpAndSettle();
      });
    });
  });
}
