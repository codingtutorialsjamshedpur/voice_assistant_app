import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_app/widgets/trigger_word_hints_panel.dart';
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
    endOfThoughtTrigger: 'हो गया',
    endOfThoughtVariants: ['ho gaya'],
    exitTrigger: 'अलविदा',
    exitTriggerVariants: ['alvida'],
  );

  group('TriggerWordHintsPanel', () {
    testWidgets('should display trigger words', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TriggerWordHintsPanel(
              preferredLanguage: testLanguage,
            ),
          ),
        ),
      );

      expect(find.text('हो गया'), findsOneWidget);
      expect(find.text('अलविदा'), findsOneWidget);
    });

    testWidgets('should display hint texts', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TriggerWordHintsPanel(
              preferredLanguage: testLanguage,
            ),
          ),
        ),
      );

      expect(find.text('Say when done'), findsOneWidget);
      expect(find.text('Say to exit'), findsOneWidget);
    });

    testWidgets('should show volume icons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TriggerWordHintsPanel(
              preferredLanguage: testLanguage,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.volume_up), findsNWidgets(2));
    });

    testWidgets('should return empty when language is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TriggerWordHintsPanel(
              preferredLanguage: null,
            ),
          ),
        ),
      );

      expect(find.byType(TriggerWordHintsPanel), findsOneWidget);
      expect(find.text('हो गया'), findsNothing);
    });

    testWidgets('should trigger onEndOfThoughtPlay callback', (tester) async {
      var played = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TriggerWordHintsPanel(
              preferredLanguage: testLanguage,
              onEndOfThoughtPlay: () => played = true,
            ),
          ),
        ),
      );

      final volumeIcons = find.byIcon(Icons.volume_up);
      await tester.tap(volumeIcons.first);
      await tester.pump();

      expect(played, true);
    });

    testWidgets('should trigger onExitPlay callback', (tester) async {
      var played = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TriggerWordHintsPanel(
              preferredLanguage: testLanguage,
              onExitPlay: () => played = true,
            ),
          ),
        ),
      );

      final volumeIcons = find.byIcon(Icons.volume_up);
      await tester.tap(volumeIcons.last);
      await tester.pump();

      expect(played, true);
    });

    testWidgets('should display descriptions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TriggerWordHintsPanel(
              preferredLanguage: testLanguage,
            ),
          ),
        ),
      );

      expect(find.text('Finish speaking'), findsOneWidget);
      expect(find.text('Close app'), findsOneWidget);
    });
  });

  group('TriggerWordHintCard', () {
    testWidgets('should display all provided information', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TriggerWordHintCard(
              triggerWord: 'हो गया',
              phonetic: 'ho gaya',
              hint: 'Say when done',
              description: 'Finish speaking',
              color: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('हो गया'), findsOneWidget);
      expect(find.text('ho gaya'), findsOneWidget);
      expect(find.text('Say when done'), findsOneWidget);
      expect(find.text('Finish speaking'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
    });

    testWidgets('should work without phonetic', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TriggerWordHintCard(
              triggerWord: 'done',
              hint: 'Say when done',
              description: 'Finish speaking',
              color: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('done'), findsOneWidget);
      expect(find.text('Say when done'), findsOneWidget);
    });

    testWidgets('should trigger onPlay callback', (tester) async {
      var played = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TriggerWordHintCard(
              triggerWord: 'done',
              hint: 'Test',
              description: 'Test',
              color: Colors.blue,
              onPlay: () => played = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.volume_up));
      await tester.pump();

      expect(played, true);
    });
  });
}
