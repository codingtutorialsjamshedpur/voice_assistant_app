import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_app/features/orb_thinking/avatar_resolver.dart';

void main() {
  group('AvatarResolver Multi-language Tests', () {
    test('should resolve Hindi keywords correctly', () {
      // Test Hindi diamond orb keywords
      expect(AvatarResolver.resolve('खुश'), isNotNull);
      expect(AvatarResolver.resolve('संगीत'), isNotNull);
      expect(AvatarResolver.resolve('शांत'), isNotNull);
      expect(AvatarResolver.resolve('हीरा'), isNotNull);

      // Test Hindi simple orb keywords
      expect(AvatarResolver.resolve('गुस्सा'), isNotNull);
      expect(AvatarResolver.resolve('सपना'), isNotNull);
      expect(AvatarResolver.resolve('उत्साहित'), isNotNull);
      expect(AvatarResolver.resolve('व्यायाम'), isNotNull);
    });

    test('should resolve mixed language sentences correctly', () {
      // Test mixed English-Hindi sentences
      expect(AvatarResolver.resolveFromSentence('I am खुश today'), isNotNull);
      expect(AvatarResolver.resolveFromSentence('Let me play some संगीत'),
          isNotNull);
      expect(AvatarResolver.resolveFromSentence('मैं बहुत excited हूं'),
          isNotNull);
    });

    test('should maintain priority system across languages', () {
      // Diamond orb keywords should take priority over simple orb keywords
      final result1 = AvatarResolver.resolveFromSentence('खुश and angry');
      final result2 = AvatarResolver.resolveFromSentence('happy and गुस्सा');

      expect(result1, contains('diamond_orb'));
      expect(result2, contains('diamond_orb'));
    });
  });
}
