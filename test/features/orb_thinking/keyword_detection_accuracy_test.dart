import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_app/features/orb_thinking/avatar_resolver.dart';

void main() {
  group('Keyword Detection Accuracy Tests', () {
    group('Emotion Keywords', () {
      test('should detect happy emotion keywords', () {
        expect(AvatarResolver.resolve('happy'),
            'assets/images/diamond orb/diamond_orb__smiling.png');
        expect(AvatarResolver.resolve('joy'),
            'assets/images/diamond orb/diamond_orb__smiling.png');
        expect(AvatarResolver.resolve('smile'),
            'assets/images/diamond orb/diamond_orb__smiling.png');
        expect(AvatarResolver.resolve('wonderful'),
            'assets/images/diamond orb/diamond_orb__smiling.png');
        expect(AvatarResolver.resolve('great'),
            'assets/images/diamond orb/diamond_orb__smiling.png');
        expect(AvatarResolver.resolve('love'),
            'assets/images/diamond orb/diamond_orb__smiling.png');
        expect(AvatarResolver.resolve('delight'),
            'assets/images/diamond orb/diamond_orb__smiling.png');
      });

      test('should detect sad/negative emotion keywords', () {
        expect(AvatarResolver.resolve('angry'),
            'assets/images/simple orb/angry.png');
        expect(AvatarResolver.resolve('furious'),
            'assets/images/simple orb/angry.png');
        expect(AvatarResolver.resolve('rage'),
            'assets/images/simple orb/angry.png');
        expect(
            AvatarResolver.resolve('mad'), 'assets/images/simple orb/angry.png');
        expect(AvatarResolver.resolve('frustrated'),
            'assets/images/simple orb/angry.png');
        expect(AvatarResolver.resolve('upset'),
            'assets/images/simple orb/angry.png');
      });

      test('should detect excited emotion keywords', () {
        expect(AvatarResolver.resolve('excited'),
            'assets/images/simple orb/excited.png');
        expect(AvatarResolver.resolve('amazing'),
            'assets/images/simple orb/excited.png');
        expect(AvatarResolver.resolve('wow'),
            'assets/images/simple orb/excited.png');
        expect(AvatarResolver.resolve('incredible'),
            'assets/images/simple orb/excited.png');
        expect(AvatarResolver.resolve('fantastic'),
            'assets/images/simple orb/excited.png');
      });

      test('should detect calm/peaceful emotion keywords', () {
        expect(AvatarResolver.resolve('silent'),
            'assets/images/diamond orb/diamond_orb_silent.png');
        expect(AvatarResolver.resolve('quiet'),
            'assets/images/diamond orb/diamond_orb_silent.png');
        expect(AvatarResolver.resolve('peace'),
            'assets/images/diamond orb/diamond_orb_silent.png');
        expect(AvatarResolver.resolve('calm'),
            'assets/images/diamond orb/diamond_orb_silent.png');
      });

      test('should detect nervous/anxious emotion keywords', () {
        expect(AvatarResolver.resolve('nervous'),
            'assets/images/simple orb/nervous.png');
        expect(AvatarResolver.resolve('anxious'),
            'assets/images/simple orb/nervous.png');
        expect(AvatarResolver.resolve('worried'),
            'assets/images/simple orb/nervous.png');
        expect(AvatarResolver.resolve('stress'),
            'assets/images/simple orb/nervous.png');
        expect(AvatarResolver.resolve('fear'),
            'assets/images/simple orb/nervous.png');
      });

      test('should detect tired/exhausted emotion keywords', () {
        expect(AvatarResolver.resolve('tired'),
            'assets/images/simple orb/exhausted.png');
        expect(AvatarResolver.resolve('exhausted'),
            'assets/images/simple orb/exhausted.png');
        expect(AvatarResolver.resolve('sleepy'),
            'assets/images/simple orb/exhausted.png');
        expect(AvatarResolver.resolve('worn'),
            'assets/images/simple orb/exhausted.png');
        expect(AvatarResolver.resolve('fatigue'),
            'assets/images/simple orb/exhausted.png');
      });
    });

    group('Activity Keywords', () {
      test('should detect yoga/meditation activity keywords', () {
        expect(
            AvatarResolver.resolve('yoga'), 'assets/images/simple orb/yoga.png');
        expect(AvatarResolver.resolve('meditate'),
            'assets/images/simple orb/yoga.png');
        expect(AvatarResolver.resolve('spiritual'),
            'assets/images/simple orb/yoga.png');
        expect(
            AvatarResolver.resolve('zen'), 'assets/images/simple orb/yoga.png');
        expect(AvatarResolver.resolve('balance'),
            'assets/images/simple orb/yoga.png');
        expect(AvatarResolver.resolve('breathe'),
            'assets/images/simple orb/yoga.png');
      });

      test('should detect exercise/fitness activity keywords', () {
        expect(AvatarResolver.resolve('exercise'),
            'assets/images/simple orb/exercising.png');
        expect(AvatarResolver.resolve('workout'),
            'assets/images/simple orb/exercising.png');
        expect(AvatarResolver.resolve('fitness'),
            'assets/images/simple orb/exercising.png');
        expect(AvatarResolver.resolve('running'),
            'assets/images/simple orb/exercising.png');
        expect(AvatarResolver.resolve('sport'),
            'assets/images/simple orb/exercising.png');
        expect(AvatarResolver.resolve('active'),
            'assets/images/simple orb/exercising.png');
      });

      test('should detect reading activity keywords', () {
        expect(AvatarResolver.resolve('read'),
            'assets/images/simple orb/reading_newspaper.png');
        expect(AvatarResolver.resolve('newspaper'),
            'assets/images/simple orb/reading_newspaper.png');
        expect(AvatarResolver.resolve('news'),
            'assets/images/simple orb/reading_newspaper.png');
        expect(AvatarResolver.resolve('article'),
            'assets/images/simple orb/reading_newspaper.png');
        expect(AvatarResolver.resolve('journal'),
            'assets/images/simple orb/reading_newspaper.png');
      });

      test('should detect music activity keywords', () {
        expect(AvatarResolver.resolve('music'),
            'assets/images/diamond orb/diamond_orb_listening_music.png');
        expect(AvatarResolver.resolve('song'),
            'assets/images/diamond orb/diamond_orb_listening_music.png');
        expect(AvatarResolver.resolve('melody'),
            'assets/images/diamond orb/diamond_orb_listening_music.png');
        expect(AvatarResolver.resolve('rhythm'),
            'assets/images/diamond orb/diamond_orb_listening_music.png');
        expect(AvatarResolver.resolve('dance'),
            'assets/images/diamond orb/diamond_orb_listening_music.png');
        expect(AvatarResolver.resolve('singing'),
            'assets/images/diamond orb/diamond_orb_listening_music.png');
      });

      test('should detect thinking activity keywords', () {
        expect(AvatarResolver.resolve('think'),
            'assets/images/simple orb/thinking.png');
        expect(AvatarResolver.resolve('consider'),
            'assets/images/simple orb/thinking.png');
        expect(AvatarResolver.resolve('ponder'),
            'assets/images/simple orb/thinking.png');
        expect(AvatarResolver.resolve('reflect'),
            'assets/images/simple orb/thinking.png');
        expect(AvatarResolver.resolve('wondering'),
            'assets/images/simple orb/thinking.png');
      });

      test('should detect teaching/learning activity keywords', () {
        expect(AvatarResolver.resolve('teach'),
            'assets/images/simple orb/teaching.png');
        expect(AvatarResolver.resolve('learn'),
            'assets/images/simple orb/teaching.png');
        expect(AvatarResolver.resolve('educate'),
            'assets/images/simple orb/teaching.png');
        expect(AvatarResolver.resolve('lesson'),
            'assets/images/simple orb/teaching.png');
        expect(AvatarResolver.resolve('guide'),
            'assets/images/simple orb/teaching.png');
      });

      test('should detect game activity keywords', () {
        expect(AvatarResolver.resolve('cards'),
            'assets/images/simple orb/playing_cards.png');
        expect(AvatarResolver.resolve('game'),
            'assets/images/simple orb/playing_cards.png');
        expect(AvatarResolver.resolve('play'),
            'assets/images/simple orb/playing_cards.png');
        expect(AvatarResolver.resolve('poker'),
            'assets/images/simple orb/playing_cards.png');
        expect(AvatarResolver.resolve('chess'),
            'assets/images/simple orb/playing_chess.png');
      });
    });

    group('Premium Keywords with Diamond Orb Priority', () {
      test('should detect premium/luxury keywords with diamond orbs', () {
        expect(AvatarResolver.resolve('royal'),
            'assets/images/diamond orb/diamond_orb.png');
        expect(AvatarResolver.resolve('luxury'),
            'assets/images/diamond orb/diamond_orb.png');
        expect(AvatarResolver.resolve('diamond'),
            'assets/images/diamond orb/diamond_orb.png');
        expect(AvatarResolver.resolve('premium'),
            'assets/images/diamond orb/diamond_orb.png');
        expect(AvatarResolver.resolve('grand'),
            'assets/images/diamond orb/diamond_orb.png');
        expect(AvatarResolver.resolve('majestic'),
            'assets/images/diamond orb/diamond_orb.png');
      });

      test(
          'should prioritize diamond orbs over simple orbs for overlapping keywords',
          () {
        // 'happy' should return diamond orb (smiling) not simple orb
        expect(AvatarResolver.resolve('happy'),
            'assets/images/diamond orb/diamond_orb__smiling.png');

        // 'music' should return diamond orb (listening music) not simple orb
        expect(AvatarResolver.resolve('music'),
            'assets/images/diamond orb/diamond_orb_listening_music.png');

        // 'calm' should return diamond orb (silent) not simple orb
        expect(AvatarResolver.resolve('calm'),
            'assets/images/diamond orb/diamond_orb_silent.png');
      });

      test('should detect Hindi premium keywords', () {
        expect(AvatarResolver.resolve('राजसी'),
            'assets/images/diamond orb/diamond_orb.png');
        expect(AvatarResolver.resolve('शाही'),
            'assets/images/diamond orb/diamond_orb.png');
        expect(AvatarResolver.resolve('हीरा'),
            'assets/images/diamond orb/diamond_orb.png');
        expect(AvatarResolver.resolve('प्रीमियम'),
            'assets/images/diamond orb/diamond_orb.png');
        expect(AvatarResolver.resolve('महान'),
            'assets/images/diamond orb/diamond_orb.png');
      });
    });

    group('Sentence Processing with Multiple Keywords', () {
      test('should return first matching keyword in sentence', () {
        // First keyword should win
        expect(AvatarResolver.resolveFromSentence('I am happy and angry today'),
            'assets/images/diamond orb/diamond_orb__smiling.png'); // happy comes first

        expect(
            AvatarResolver.resolveFromSentence(
                'Let me think and then exercise'),
            'assets/images/simple orb/thinking.png'); // think comes first

        expect(AvatarResolver.resolveFromSentence('I love music and yoga'),
            'assets/images/diamond orb/diamond_orb__smiling.png'); // love comes first
      });

      test('should prioritize diamond orbs when they appear first', () {
        expect(AvatarResolver.resolveFromSentence('This is royal and angry'),
            'assets/images/diamond orb/diamond_orb.png'); // royal (diamond) comes first

        expect(AvatarResolver.resolveFromSentence('I feel calm and nervous'),
            'assets/images/diamond orb/diamond_orb_silent.png'); // calm (diamond) comes first

        expect(
            AvatarResolver.resolveFromSentence('Listen to music while angry'),
            'assets/images/diamond orb/diamond_orb_listening_music.png'); // music (diamond) comes first
      });

      test('should handle complex sentences with punctuation', () {
        expect(
            AvatarResolver.resolveFromSentence(
                'Hello! I am very happy, excited, and ready to dance.'),
            'assets/images/diamond orb/diamond_orb__smiling.png'); // happy comes first

        expect(
            AvatarResolver.resolveFromSentence(
                'Are you angry? No, I am calm and peaceful.'),
            'assets/images/simple orb/angry.png'); // angry comes first

        expect(
            AvatarResolver.resolveFromSentence(
                'Let\'s exercise, then do yoga, and finally read.'),
            'assets/images/simple orb/exercising.png'); // exercise comes first
      });

      test('should handle mixed language sentences', () {
        expect(AvatarResolver.resolveFromSentence('I am खुश and excited'),
            'assets/images/diamond orb/diamond_orb__smiling.png'); // खुश (happy in Hindi) comes first

        expect(
            AvatarResolver.resolveFromSentence(
                'Let me सोचना about this problem'),
            'assets/images/simple orb/thinking.png'); // सोचना (think in Hindi) comes first

        expect(
            AvatarResolver.resolveFromSentence('Listen संगीत while I exercise'),
            'assets/images/diamond orb/diamond_orb_listening_music.png'); // संगीत (music in Hindi) comes first
      });
    });

    group('No Keywords Scenarios', () {
      test('should return null for sentences with no keywords', () {
        expect(AvatarResolver.resolveFromSentence('Hello there how are you'),
            null);
        expect(AvatarResolver.resolveFromSentence('What is the weather today'),
            null);
        expect(AvatarResolver.resolveFromSentence('Can you help me with this'),
            null);
        expect(AvatarResolver.resolveFromSentence('The quick brown fox jumps'),
            null);
        expect(AvatarResolver.resolveFromSentence('Programming is interesting'),
            null);
      });

      test('should return null for empty or whitespace strings', () {
        expect(AvatarResolver.resolveFromSentence(''), null);
        expect(AvatarResolver.resolveFromSentence('   '), null);
        expect(AvatarResolver.resolveFromSentence('\n\t'), null);
      });

      test('should return null for single words that are not keywords', () {
        expect(AvatarResolver.resolve('hello'), null);
        expect(AvatarResolver.resolve('computer'), null);
        expect(AvatarResolver.resolve('water'), null);
        expect(AvatarResolver.resolve('table'), null);
        expect(AvatarResolver.resolve('programming'), null);
      });

      test('should return null for numbers and special characters', () {
        expect(AvatarResolver.resolve('123'), null);
        expect(AvatarResolver.resolve('!@#'), null);
        expect(AvatarResolver.resolve('\$%^'), null);
        expect(AvatarResolver.resolveFromSentence('The price is \$100'), null);
        expect(AvatarResolver.resolveFromSentence('Call me at 555-1234'), null);
      });
    });

    group('Edge Cases and Word Boundaries', () {
      test('should handle punctuation and capitalization', () {
        expect(AvatarResolver.resolve('Happy!'),
            'assets/images/diamond orb/diamond_orb__smiling.png');
        expect(AvatarResolver.resolve('ANGRY'),
            'assets/images/simple orb/angry.png');
        expect(AvatarResolver.resolve('Excited?'),
            'assets/images/simple orb/excited.png');
        expect(AvatarResolver.resolve('yoga.'),
            'assets/images/simple orb/yoga.png');
      });

      test('should not match partial words', () {
        // These should not match because they contain the keyword as substring
        expect(AvatarResolver.resolve('unhappy'),
            null); // contains 'happy' but not exact match
        expect(AvatarResolver.resolve('angrily'),
            null); // contains 'angry' but not exact match
        expect(AvatarResolver.resolve('musical'),
            null); // contains 'music' but not exact match

        // But exact keywords should match
        expect(AvatarResolver.resolve('thinking'),
            'assets/images/simple orb/thinking.png'); // this is an exact keyword match
      });

      test('should handle words with different cases', () {
        expect(AvatarResolver.resolve('HAPPY'),
            'assets/images/diamond orb/diamond_orb__smiling.png');
        expect(AvatarResolver.resolve('Happy'),
            'assets/images/diamond orb/diamond_orb__smiling.png');
        expect(AvatarResolver.resolve('hApPy'),
            'assets/images/diamond orb/diamond_orb__smiling.png');
        expect(
            AvatarResolver.resolve('YOGA'), 'assets/images/simple orb/yoga.png');
      });
    });

    group('Hindi Language Support', () {
      test('should detect Hindi emotion keywords', () {
        expect(AvatarResolver.resolve('खुश'),
            'assets/images/diamond orb/diamond_orb__smiling.png'); // happy
        expect(AvatarResolver.resolve('गुस्सा'),
            'assets/images/simple orb/angry.png'); // angry
        expect(AvatarResolver.resolve('उत्साहित'),
            'assets/images/simple orb/excited.png'); // excited
        expect(AvatarResolver.resolve('शांत'),
            'assets/images/diamond orb/diamond_orb_silent.png'); // calm
      });

      test('should detect Hindi activity keywords', () {
        expect(AvatarResolver.resolve('संगीत'),
            'assets/images/diamond orb/diamond_orb_listening_music.png'); // music
        expect(AvatarResolver.resolve('व्यायाम'),
            'assets/images/simple orb/exercising.png'); // exercise
        expect(AvatarResolver.resolve('सोचना'),
            'assets/images/simple orb/thinking.png'); // think
      });

      test('should handle Hindi punctuation', () {
        expect(AvatarResolver.resolve('खुश।'),
            'assets/images/diamond orb/diamond_orb__smiling.png'); // with Hindi punctuation
        expect(AvatarResolver.resolve('संगीत॥'),
            'assets/images/diamond orb/diamond_orb_listening_music.png'); // with Hindi punctuation
      });
    });

    group('Performance and Coverage', () {
      test('should have comprehensive keyword coverage', () {
        final allPaths = AvatarResolver.getAllAvatarPaths();

        // Should have both diamond and simple orb paths
        expect(allPaths.any((path) => path.contains('diamond orb')), true);
        expect(allPaths.any((path) => path.contains('simple orb')), true);

        // Should have reasonable number of unique avatars
        expect(allPaths.length, greaterThan(30)); // At least 30 unique avatars
        expect(
            allPaths.length, lessThan(50)); // But not too many for performance
      });

      test('should handle rapid keyword detection', () {
        // Test that multiple rapid calls don't cause issues
        for (int i = 0; i < 100; i++) {
          expect(AvatarResolver.resolve('happy'), isNotNull);
          expect(AvatarResolver.resolve('angry'), isNotNull);
          expect(AvatarResolver.resolve('yoga'), isNotNull);
        }
      });

      test('should validate all mapped paths are consistent', () {
        // All diamond orb paths should contain 'diamond orb'
        final diamondKeywords = [
          'royal',
          'luxury',
          'diamond',
          'premium',
          'happy',
          'music',
          'calm'
        ];
        for (final keyword in diamondKeywords) {
          final path = AvatarResolver.resolve(keyword);
          expect(path, isNotNull);
          expect(path!, contains('diamond orb'));
        }

        // All simple orb paths should contain 'simple orb'
        final simpleKeywords = [
          'angry',
          'excited',
          'yoga',
          'exercise',
          'think'
        ];
        for (final keyword in simpleKeywords) {
          final path = AvatarResolver.resolve(keyword);
          expect(path, isNotNull);
          expect(path!, contains('simple orb'));
        }
      });
    });
  });
}
