import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_app/widgets/language_badge.dart';
import 'package:voice_assistant_app/models/language_model.dart';

void main() {
  const testLanguage = LanguageModel(
    code: 'hi',
    name: 'Hindi',
    nativeName: 'हिन्दी',
    flag: '🇮🇳',
    group: LanguageGroup.main,
    ttsEngine: TTSEngine.flutterTts,
    sttLocale: 'hi-IN',
    voices: [],
  );

  group('LanguageBadge', () {
    testWidgets('should display language flag and name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LanguageBadge(
              currentLanguage: testLanguage,
            ),
          ),
        ),
      );

      expect(find.text('🇮🇳'), findsOneWidget);
      expect(find.text('हिन्दी'), findsOneWidget);
    });

    testWidgets('should show arrow by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LanguageBadge(
              currentLanguage: testLanguage,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('should hide arrow when showArrow is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LanguageBadge(
              currentLanguage: testLanguage,
              showArrow: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    });

    testWidgets('should show default badge when language is null',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LanguageBadge(),
          ),
        ),
      );

      expect(find.text('Language'), findsOneWidget);
      expect(find.text('🌐'), findsOneWidget);
    });

    testWidgets('should trigger onTap callback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LanguageBadge(
              currentLanguage: testLanguage,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(LanguageBadge));
      await tester.pump();

      expect(tapped, true);
    });
  });

  group('LanguageBadgeCompact', () {
    testWidgets('should display compact badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LanguageBadgeCompact(
              currentLanguage: testLanguage,
            ),
          ),
        ),
      );

      expect(find.text('🇮🇳'), findsOneWidget);
      expect(find.text('HI'), findsOneWidget);
    });

    testWidgets('should return empty when language is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LanguageBadgeCompact(),
          ),
        ),
      );

      expect(find.byType(LanguageBadgeCompact), findsOneWidget);
    });

    testWidgets('should trigger onTap callback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LanguageBadgeCompact(
              currentLanguage: testLanguage,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(LanguageBadgeCompact));
      await tester.pump();

      expect(tapped, true);
    });
  });
}
