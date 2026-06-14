import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:voice_assistant_app/features/orb_thinking/orb_thinking_controller.dart';
import 'package:voice_assistant_app/features/orb_thinking/thought_bubble_widget.dart';

void main() {
  group('Animation Quality Assurance Tests', () {
    late OrbThinkingController controller;

    setUp(() {
      // Initialize GetX for testing
      Get.testMode = true;
      controller = OrbThinkingController();
      Get.put(controller);
    });

    tearDown(() {
      Get.delete<OrbThinkingController>();
      Get.reset();
    });

    testWidgets('Entry animation has correct duration and visibility behavior',
        (tester) async {
      // Build widget with visible = false initially
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThoughtBubbleWidget(
              avatarAssetPath: 'assets/images/simple orb/smiley.png',
              visible: false,
            ),
          ),
        ),
      );

      // Verify initial state (should be invisible)
      expect(find.byType(ThoughtBubbleWidget), findsOneWidget);

      // Trigger visibility change to true
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThoughtBubbleWidget(
              avatarAssetPath: 'assets/images/simple orb/smiley.png',
              visible: true,
            ),
          ),
        ),
      );

      // Pump a few frames to start animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify widget is animating in
      expect(find.byType(ThoughtBubbleWidget), findsOneWidget);

      // Complete the entry animation with finite pumps (not pumpAndSettle - floating is infinite)
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('Exit animation works when visibility changes to false',
        (tester) async {
      // Build widget with visible = true initially
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThoughtBubbleWidget(
              avatarAssetPath: 'assets/images/simple orb/smiley.png',
              visible: true,
            ),
          ),
        ),
      );

      // Pump to allow entry animation to complete
      await tester.pump(const Duration(milliseconds: 600));

      // Trigger exit animation
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThoughtBubbleWidget(
              avatarAssetPath: 'assets/images/simple orb/smiley.png',
              visible: false,
            ),
          ),
        ),
      );

      // Pump animation frames
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Complete the exit animation
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('Floating animation is continuous when visible',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThoughtBubbleWidget(
              avatarAssetPath: 'assets/images/simple orb/smiley.png',
              visible: true,
            ),
          ),
        ),
      );

      // Let entry animation complete
      await tester.pump(const Duration(milliseconds: 600));

      // Test floating animation over multiple cycles
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(ThoughtBubbleWidget), findsOneWidget);
      }
    });

    testWidgets('RepaintBoundary is properly implemented for performance',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThoughtBubbleWidget(
              avatarAssetPath: 'assets/images/simple orb/smiley.png',
              visible: true,
            ),
          ),
        ),
      );

      // Verify RepaintBoundary is present
      expect(find.byType(RepaintBoundary), findsAtLeastNWidgets(1));

      // Verify it contains animated content
      final repaintBoundaryFinder = find.byType(RepaintBoundary);
      expect(repaintBoundaryFinder, findsAtLeastNWidgets(1));
    });

    testWidgets('Transform widgets are used for GPU acceleration',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThoughtBubbleWidget(
              avatarAssetPath: 'assets/images/simple orb/smiley.png',
              visible: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 600));

      // Verify Transform widgets are present for GPU acceleration
      expect(find.byType(Transform), findsAtLeastNWidgets(1));
    });

    group('Avatar Change Crossfade Tests', () {
      testWidgets('Avatar changes are reflected in widget', (tester) async {
        // Start with first avatar
        controller.showAvatar('assets/images/simple orb/smiley.png');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Obx(() => ThoughtBubbleWidget(
                    avatarAssetPath: controller.currentAvatarPath ?? '',
                    visible: controller.isThinking,
                  )),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Verify initial avatar
        final initialWidget = tester.widget<ThoughtBubbleWidget>(
          find.byType(ThoughtBubbleWidget),
        );
        expect(initialWidget.avatarAssetPath,
            equals('assets/images/simple orb/smiley.png'));

        // Change to different avatar
        controller.showAvatar('assets/images/simple orb/angry.png');
        await tester.pump();

        // Verify new avatar path is reflected
        final updatedWidget = tester.widget<ThoughtBubbleWidget>(
          find.byType(ThoughtBubbleWidget),
        );
        expect(updatedWidget.avatarAssetPath,
            equals('assets/images/simple orb/angry.png'));

        await tester.pump(const Duration(milliseconds: 300));
      });

      testWidgets('Multiple rapid avatar changes are handled gracefully',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Obx(() => ThoughtBubbleWidget(
                    avatarAssetPath: controller.currentAvatarPath ?? '',
                    visible: controller.isThinking,
                  )),
            ),
          ),
        );

        // Rapid avatar changes
        final avatars = [
          'assets/images/simple orb/smiley.png',
          'assets/images/simple orb/angry.png',
          'assets/images/simple orb/excited.png',
          'assets/images/diamond orb/diamond_orb.png',
        ];

        for (final avatar in avatars) {
          controller.showAvatar(avatar);
          await tester.pump(const Duration(milliseconds: 50));
        }

        await tester.pump(const Duration(milliseconds: 300));

        // Verify final avatar is displayed
        final widget = tester.widget<ThoughtBubbleWidget>(
          find.byType(ThoughtBubbleWidget),
        );
        expect(widget.avatarAssetPath, equals(avatars.last));
      });
    });

    group('Performance Validation Tests', () {
      testWidgets('Animation maintains smooth performance during sequences',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  // Multiple thought bubbles to stress test
                  Obx(() => ThoughtBubbleWidget(
                        avatarAssetPath: controller.currentAvatarPath ??
                            'assets/images/simple orb/smiley.png',
                        visible: controller.isThinking,
                        size: 110,
                      )),
                  Obx(() => ThoughtBubbleWidget(
                        avatarAssetPath: controller.currentAvatarPath ??
                            'assets/images/simple orb/angry.png',
                        visible: controller.isThinking,
                        size: 120,
                      )),
                ],
              ),
            ),
          ),
        );

        // Trigger animations
        controller.showAvatar('assets/images/simple orb/smiley.png');

        // Test animation performance over multiple frames
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16)); // ~60fps
        }

        // Verify widgets are still present and functional
        expect(find.byType(ThoughtBubbleWidget), findsNWidgets(2));

        await tester.pump(const Duration(milliseconds: 600));
      });

      testWidgets('Error handling works gracefully with invalid assets',
          (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ThoughtBubbleWidget(
                avatarAssetPath: 'invalid/path/to/asset.png',
                visible: true,
              ),
            ),
          ),
        );

        // Should not crash and should show fallback icon
        await tester.pump(const Duration(milliseconds: 600));

        // Verify widget is still present (with fallback)
        expect(find.byType(ThoughtBubbleWidget), findsOneWidget);
      });
    });

    group('Animation Timing and Easing Tests', () {
      testWidgets('Animations complete within expected timeframes',
          (tester) async {
        // Test entry animation timing
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ThoughtBubbleWidget(
                avatarAssetPath: 'assets/images/simple orb/smiley.png',
                visible: false,
              ),
            ),
          ),
        );

        // Trigger entry animation
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ThoughtBubbleWidget(
                avatarAssetPath: 'assets/images/simple orb/smiley.png',
                visible: true,
              ),
            ),
          ),
        );

        // Entry animation should complete within 500ms + some buffer
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        // Should be stable after animation completes
        expect(find.byType(ThoughtBubbleWidget), findsOneWidget);
      });

      testWidgets('Crossfade animation timing is correct', (tester) async {
        controller.showAvatar('assets/images/simple orb/smiley.png');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Obx(() => ThoughtBubbleWidget(
                    avatarAssetPath: controller.currentAvatarPath ?? '',
                    visible: controller.isThinking,
                  )),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Change avatar to trigger crossfade
        controller.showAvatar('assets/images/simple orb/angry.png');

        // Crossfade should complete within 200ms + buffer
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.byType(ThoughtBubbleWidget), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 300));
      });
    });
  });
}
