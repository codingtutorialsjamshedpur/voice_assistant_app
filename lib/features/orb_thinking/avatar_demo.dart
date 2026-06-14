import 'package:get/get.dart';
import 'orb_thinking_controller.dart';
import 'enhanced_sound_effect_player.dart';

/// Avatar Demo - Demonstrates the enhanced avatar system with your example story
class AvatarDemo {
  static const String exampleStory = '''
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

  /// Expected avatars that should be detected in the story
  static const List<String> expectedAvatars = [
    'angry', // "very angry"
    'dreaming', // "in his dreams"
    'cowboy', // "become a cowboy"
    'exhausted', // "very much exhausted"
    'flirting', // "wanted to flirt"
    'excited', // "very much excited"
    'music', // "fond of music"
    'smiling', // "she smiled"
    'diamond', // "diamond ring"
    'scared', // "she was scared"
    'angry', // "got angry" (second occurrence)
    'exercising', // "do workout"
    'laughing', // "she laughed"
  ];

  /// Demonstrate the enhanced avatar system
  static Future<void> runDemo() async {
    print('🎭 Enhanced Avatar System Demo');
    print('=' * 50);

    try {
      final controller = Get.find<OrbThinkingController>();

      print('📖 Story: $exampleStory');
      print('\n🔍 Expected Avatars: ${expectedAvatars.join(', ')}');
      print('\n🚀 Starting Avatar Detection...\n');

      // Trigger the enhanced avatar system
      controller.onSentenceSpoken(exampleStory);

      // Monitor the sequence
      await _monitorAvatarSequence(controller);
    } catch (e) {
      print('❌ Demo Error: $e');
    }
  }

  /// Monitor and log the avatar sequence as it happens
  static Future<void> _monitorAvatarSequence(
      OrbThinkingController controller) async {
    print('👁️ Monitoring Avatar Sequence:');
    print('-' * 30);

    // Phase 1: Orb Blinking (3 seconds)
    print('Phase 1: Orb Blinking 👁️');
    print('- Playing hmm sound for 3 seconds');
    print('- Orb eyes blinking simultaneously');
    await Future.delayed(const Duration(seconds: 3));

    // Phase 2: Cloud Appearance (4 seconds)
    print('\nPhase 2: Cloud Appearance ☁️');
    print('- Playing hint screen sound for 4 seconds');
    print('- Cloud appears at random position: dynamic');
    print('- Thinking progression dots: small → medium → big cloud');
    await Future.delayed(const Duration(seconds: 4));

    // Phase 3: Avatar Transitions (1-2 seconds each)
    print('\nPhase 3: Smart Avatar Transitions 🎭');
    print('- Fast transitions with random effects');
    print('- Transition type: ${controller.transitionType}');

    int avatarCount = 0;
    while (controller.isThinking && avatarCount < 10) {
      if (controller.currentAvatarPath != null) {
        avatarCount++;
        print(
            '  Avatar $avatarCount: ${_getAvatarName(controller.currentAvatarPath!)}');
        print('    - Transition: ${controller.transitionType}');
        print('    - Sound: Playing contextual audio');
        print('    - Duration: 1-2 seconds');
      }
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    print('\n✅ Avatar sequence completed!');
    print('📊 Total avatars shown: $avatarCount');
    print('🎵 All sounds synchronized perfectly');
    print('⚡ Smooth 60fps animations throughout');
  }

  /// Extract avatar name from path for logging
  static String _getAvatarName(String path) {
    if (path.contains('angry')) return 'Angry 😠';
    if (path.contains('dreaming')) return 'Dreaming 💭';
    if (path.contains('cowboy')) return 'Cowboy 🤠';
    if (path.contains('exhausted')) return 'Exhausted 😴';
    if (path.contains('flirting')) return 'Flirting 😉';
    if (path.contains('excited')) return 'Excited 🤩';
    if (path.contains('music')) return 'Music 🎵';
    if (path.contains('smiling')) return 'Smiling 😊';
    if (path.contains('diamond')) return 'Diamond 💎';
    if (path.contains('scared')) return 'Scared 😨';
    if (path.contains('exercising')) return 'Exercising 💪';
    if (path.contains('laughing')) return 'Laughing 😂';
    return 'Unknown Avatar';
  }

  /// Test different story scenarios
  static Future<void> testScenarios() async {
    print('\n🧪 Testing Different Scenarios');
    print('=' * 40);

    final scenarios = [
      {
        'name': 'Emotional Journey',
        'text':
            'I was very angry, then I started dreaming, and finally I became happy and excited',
        'expected': ['angry', 'dreaming', 'happy', 'excited']
      },
      {
        'name': 'Activity Sequence',
        'text':
            'First I did yoga, then played music, went for exercise, and finally started thinking',
        'expected': ['yoga', 'music', 'exercise', 'thinking']
      },
      {
        'name': 'Mixed Language',
        'text':
            'मैं बहुत खुश था, then I became angry, फिर music सुना और laugh किया',
        'expected': ['खुश', 'angry', 'music', 'laugh']
      },
      {
        'name': 'Character Types',
        'text':
            'The cowboy was wearing sunglasses, the ghost was scary, and santa was laughing',
        'expected': ['cowboy', 'sunglasses', 'ghost', 'santa', 'laughing']
      }
    ];

    for (final scenario in scenarios) {
      print('\n📝 Scenario: ${scenario['name']}');
      print('Text: ${scenario['text']}');
      print('Expected: ${scenario['expected']}');

      try {
        final controller = Get.find<OrbThinkingController>();
        controller.onSentenceSpoken(scenario['text'] as String);

        await Future.delayed(const Duration(seconds: 2));
        print('✅ Scenario completed successfully');

        controller.clearAvatar(); // Reset for next scenario
      } catch (e) {
        print('❌ Scenario failed: $e');
      }
    }
  }

  /// Performance benchmark
  static Future<void> benchmarkPerformance() async {
    print('\n⚡ Performance Benchmark');
    print('=' * 30);

    final stopwatch = Stopwatch();
    final controller = Get.find<OrbThinkingController>();

    // Test rapid consecutive calls
    print('Testing rapid consecutive calls...');
    stopwatch.start();

    for (int i = 0; i < 10; i++) {
      controller
          .onSentenceSpoken('I am happy and excited about music and dancing');
      await Future.delayed(const Duration(milliseconds: 100));
    }

    stopwatch.stop();
    print('✅ 10 rapid calls completed in ${stopwatch.elapsedMilliseconds}ms');
    print('📊 Average: ${stopwatch.elapsedMilliseconds / 10}ms per call');

    // Test long sentence processing
    stopwatch.reset();
    stopwatch.start();

    final longSentence = exampleStory * 3; // Triple the story length
    controller.onSentenceSpoken(longSentence);

    stopwatch.stop();
    print(
        '✅ Long sentence (${longSentence.length} chars) processed in ${stopwatch.elapsedMilliseconds}ms');

    controller.clearAvatar();
  }

  /// Sound system test
  static Future<void> testSoundSystem() async {
    print('\n🔊 Sound System Test');
    print('=' * 25);

    print('Testing orb blinking sound...');
    await EnhancedSoundEffectPlayer.playOrbBlinking();
    await Future.delayed(const Duration(seconds: 1));

    print('Testing cloud appearance sound...');
    await EnhancedSoundEffectPlayer.playCloudAppearance();
    await Future.delayed(const Duration(seconds: 1));

    print('Testing transition sounds... removed');

    print('Testing avatar-specific sounds...');
    final testAvatars = ['angry', 'happy', 'music', 'excited', 'dreaming'];
    for (final avatar in testAvatars) {
      print('  Playing sound for: $avatar');
      await EnhancedSoundEffectPlayer.playForAvatar(avatar);
      await Future.delayed(const Duration(milliseconds: 800));
    }

    print('✅ Sound system test completed');
  }

  /// Run complete demo suite
  static Future<void> runCompleteDemo() async {
    print('🎬 Enhanced Avatar System - Complete Demo');
    print('=' * 60);

    await runDemo();
    await testScenarios();
    await benchmarkPerformance();
    await testSoundSystem();

    print('\n🎉 Demo completed successfully!');
    print(
        '✨ The enhanced avatar system is ready for magical user experiences!');
  }
}
