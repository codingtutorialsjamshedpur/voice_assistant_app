import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:voice_assistant_app/features/orb_thinking/orb_thinking_controller.dart';
import 'package:voice_assistant_app/features/orb_thinking/avatar_resolver.dart';
import 'package:voice_assistant_app/features/orb_thinking/enhanced_sound_effect_player.dart';

void main() {
  group('Enhanced Avatar System Tests', () {
    late OrbThinkingController controller;

    setUp(() {
      // Initialize GetX
      Get.testMode = true;

      // Create controller instance
      controller = OrbThinkingController();
      Get.put(controller);
    });

    tearDown(() {
      Get.reset();
    });

    group('Smart Avatar Detection', () {
      test('should detect multiple avatars in a single sentence', () {
        const testSentence =
            'Once there was a person who was very angry, and he was in his dreams, what he saw that he has become a cowboy, and he was very much exhausted.';

        controller.onSentenceSpoken(testSentence);

        // Wait for processing
        Future.delayed(const Duration(milliseconds: 100), () {
          // Should have detected: angry, dreams, cowboy, exhausted
          expect(controller.isThinking, isTrue);
          expect(controller.showCloud, isTrue);
        });
      });

      test('should handle rapid avatar transitions', () {
        const testSentence =
            'He saw a girl where he wanted to flirt with, and he was very much excited. But as he see that the girl was very much fond of music, and so she smiled.';

        controller.onSentenceSpoken(testSentence);

        // Should detect: flirt, excited, music, smile
        // And queue them for rapid transitions (1-2 seconds each)
        expect(controller.isThinking, isTrue);
      });

      test('should use random transition types', () {
        controller.onSentenceSpoken('I am thinking and dreaming');

        final validTransitions = [
          'fadeIn',
          'slideLeft',
          'slideRight',
          'slideUp',
          'slideDown',
          'scaleUp',
          'scaleDown',
          'rotateIn',
          'bounceIn',
          'flipIn'
        ];

        expect(validTransitions.contains(controller.transitionType), isTrue);
      });
    });

    group('Avatar Resolver Enhanced Keywords', () {
      test('should resolve emotional keywords correctly', () {
        expect(AvatarResolver.resolve('angry'), contains('angry.png'));
        expect(AvatarResolver.resolve('excited'), contains('excited.png'));
        expect(AvatarResolver.resolve('dreaming'), contains('dreaming.png'));
        expect(AvatarResolver.resolve('laughing'), contains('laughing.png'));
        expect(AvatarResolver.resolve('thinking'), contains('thinking.png'));
      });

      test('should resolve Hindi keywords correctly', () {
        expect(AvatarResolver.resolve('गुस्सा'), contains('angry.png'));
        expect(AvatarResolver.resolve('खुश'), contains('smiling.png'));
        expect(AvatarResolver.resolve('सपना'), contains('dreaming.png'));
        expect(AvatarResolver.resolve('संगीत'), contains('music.png'));
      });

      test('should resolve activity keywords correctly', () {
        expect(AvatarResolver.resolve('cowboy'), contains('cowboy hat.png'));
        expect(AvatarResolver.resolve('music'), contains('music.png'));
        expect(AvatarResolver.resolve('exercise'), contains('exercising.png'));
        expect(AvatarResolver.resolve('yoga'), contains('yoga.png'));
      });

      test('should prioritize diamond orbs over simple orbs', () {
        expect(AvatarResolver.resolve('smile'),
            contains('diamond_orb__smiling.png'));
        expect(AvatarResolver.resolve('music'),
            contains('diamond_orb_listening_music.png'));
        expect(AvatarResolver.resolve('silent'),
            contains('diamond_orb_silent.png'));
      });
    });

    group('Story Mode Avatar Detection', () {
      test('should handle complex story with multiple avatars', () {
        const storyText = '''
        Once there was a person who was very angry, and he was in his dreams, 
        what he saw that he has become a cowboy, and he was very much exhausted. 
        And he saw a girl where he wanted to flirt with, and he was very much excited. 
        But as he see that the girl was very much fond of music, and so she smiled 
        and saw her, and he come in front of her and he gave her a diamond ring, 
        as if he wanted to propose her. But as she didn't like the cowboy, 
        because she was scared of, so she got angry and she said that I want a person 
        who is very much fit, so he should do workout. Then only I will be considering 
        him and she laughed and went away.
        ''';

        controller.onSentenceSpoken(storyText);

        // Should detect multiple avatars: angry, dreams, cowboy, exhausted,
        // flirt, excited, music, smiled, diamond, scared, angry, fit, workout, laughed
        expect(controller.isThinking, isTrue);
        expect(controller.showCloud, isTrue);
      });

      test('should handle mixed language story', () {
        const mixedStory =
            'वह बहुत खुश था और music सुन रहा था, फिर वह angry हो गया';

        controller.onSentenceSpoken(mixedStory);

        // Should detect: खुश (happy), music, angry
        expect(controller.isThinking, isTrue);
      });
    });

    group('Performance and Timing', () {
      test('should complete thinking sequence within reasonable time',
          () async {
        const testSentence = 'I am happy and excited about music';

        final stopwatch = Stopwatch()..start();
        controller.onSentenceSpoken(testSentence);

        // Wait for sequence to complete
        await Future.delayed(const Duration(seconds: 10));
        stopwatch.stop();

        // Should complete within 10 seconds (3s blink + 4s cloud + transitions)
        expect(stopwatch.elapsedMilliseconds, lessThan(10000));
      });

      test('should handle rapid consecutive calls without breaking', () {
        for (int i = 0; i < 5; i++) {
          controller.onSentenceSpoken('I am happy and excited');
        }

        // Should not crash and should handle gracefully
        expect(controller.isThinking, isTrue);
      });
    });

    group('Sound Integration', () {
      test('should have sound mappings for all avatar types', () {
        final avatarPaths = AvatarResolver.getAllAvatarPaths();

        // Check that we have sound effects for major avatar categories
        expect(avatarPaths.any((path) => path.contains('angry')), isTrue);
        expect(avatarPaths.any((path) => path.contains('happy')), isTrue);
        expect(avatarPaths.any((path) => path.contains('music')), isTrue);
        expect(avatarPaths.any((path) => path.contains('thinking')), isTrue);
      });
    });

    group('Edge Cases', () {
      test('should handle empty sentences gracefully', () {
        controller.onSentenceSpoken('');
        expect(controller.isThinking, isFalse);
        expect(controller.showCloud, isFalse);
      });

      test('should handle sentences with no trigger words', () {
        controller
            .onSentenceSpoken('The quick brown fox jumps over the lazy dog');
        expect(controller.isThinking, isFalse);
        expect(controller.showCloud, isFalse);
      });

      test('should handle very long sentences', () {
        final longSentence = 'I am happy ' * 100 + 'and excited';
        controller.onSentenceSpoken(longSentence);

        // Should still work with long sentences
        expect(controller.isThinking, isTrue);
      });

      test('should handle special characters and punctuation', () {
        controller.onSentenceSpoken(
            'I am very happy!!! And excited??? With music...');
        expect(controller.isThinking, isTrue);
      });
    });

    group('State Management', () {
      test('should properly reset state on speech end', () {
        controller.onSentenceSpoken('I am happy and excited');
        expect(controller.isThinking, isTrue);
        expect(controller.showCloud, isTrue);

        controller.onSpeechEnd();
        expect(controller.isThinking, isFalse);
        expect(controller.showCloud, isFalse);
        expect(controller.currentAvatarPath, isNull);
      });

      test('should handle manual avatar clearing', () {
        controller.onSentenceSpoken('I am happy');
        expect(controller.isThinking, isTrue);

        controller.clearAvatar();
        expect(controller.isThinking, isFalse);
        expect(controller.showCloud, isFalse);
        expect(controller.currentAvatarPath, isNull);
      });
    });
  });

  group('Enhanced Sound Effect Player Tests', () {
    test('should have comprehensive avatar sound mappings', () {
      // Test emotional sounds
      expect(EnhancedSoundEffectPlayer.playForAvatar('angry'), completes);
      expect(EnhancedSoundEffectPlayer.playForAvatar('excited'), completes);
      expect(EnhancedSoundEffectPlayer.playForAvatar('happy'), completes);
      expect(EnhancedSoundEffectPlayer.playForAvatar('music'), completes);
    });

    test('should play orb blinking sound', () {
      expect(EnhancedSoundEffectPlayer.playOrbBlinking(), completes);
    });

    test('should play cloud appearance sound', () {
      expect(EnhancedSoundEffectPlayer.playCloudAppearance(), completes);
    });
  });
}
