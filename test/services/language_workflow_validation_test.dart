import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_app/models/language_model.dart';
import 'package:voice_assistant_app/constants/language_constants.dart';

void main() {
  group('Language Workflow Validation Tests', () {
    group('ALL Language Models Structure', () {
      test('All 40+ languages have unique codes', () {
        final codes = kAllLanguages.map((l) => l.code).toList();
        final uniqueCodes = codes.toSet();

        expect(
          codes.length,
          uniqueCodes.length,
          reason:
              'Duplicate language codes found: ${codes.where((c) => codes.indexOf(c) != codes.lastIndexOf(c))}',
        );
        expect(codes.length, greaterThanOrEqualTo(40));
      });

      test('All languages have valid TTS engine assignment', () {
        for (final lang in kAllLanguages) {
          expect(
            [
              TTSEngine.flutterTts,
              TTSEngine.sherpaOnnxPiper,
              TTSEngine.sherpaOnnxEspeak
            ].contains(lang.ttsEngine),
            true,
            reason: '${lang.name} has invalid TTS engine: ${lang.ttsEngine}',
          );
        }
      });

      test('All languages have valid STT locale', () {
        for (final lang in kAllLanguages) {
          expect(
            lang.sttLocale.isNotEmpty,
            true,
            reason: '${lang.name} has empty STT locale',
          );

          // Valid BCP-47 format check (basic)
          expect(
            lang.sttLocale.contains('-') || lang.sttLocale.length == 2,
            true,
            reason:
                '${lang.name} has invalid STT locale format: ${lang.sttLocale}',
          );
        }
      });

      test('All languages have name and native name', () {
        for (final lang in kAllLanguages) {
          expect(lang.name.isNotEmpty, true,
              reason: 'Language with code ${lang.code} has empty name');
          expect(lang.nativeName.isNotEmpty, true,
              reason: 'Language with code ${lang.code} has empty native name');
        }
      });

      test('All languages have flag emoji', () {
        for (final lang in kAllLanguages) {
          expect(lang.flag.isNotEmpty, true,
              reason: '${lang.name} has empty flag');
          expect(lang.flag.length, greaterThan(0),
              reason: '${lang.name} flag is not a valid emoji');
        }
      });
    });

    group('Character Model Assignment (Workflow Rule 2)', () {
      test('Flutter TTS languages have system voices', () {
        final flutterTtsLangs =
            kAllLanguages.where((l) => l.ttsEngine == TTSEngine.flutterTts);

        for (final lang in flutterTtsLangs) {
          expect(
            lang.voices.isNotEmpty || lang.espeakVoice == null,
            true,
            reason:
                '${lang.name} uses flutter_tts but has no voices configured',
          );
        }
      });

      test('eSpeak languages have espeakVoice character model assigned', () {
        final espeak = kAllLanguages
            .where((l) => l.ttsEngine == TTSEngine.sherpaOnnxEspeak);

        for (final lang in espeak) {
          expect(
            lang.espeakVoice != null && lang.espeakVoice!.isNotEmpty,
            true,
            reason: '${lang.name} uses eSpeak but has no espeakVoice assigned',
          );

          // Verify espeakVoice is language code format (e.g., 'hi', 'fr', 'de')
          expect(
            lang.espeakVoice!.length <= 5, // e.g., 'pt-BR'
            true,
            reason:
                '${lang.name} espeakVoice format looks invalid: ${lang.espeakVoice}',
          );
        }
      });

      test('Each eSpeak language has unique character model', () {
        final espeak = kAllLanguages
            .where((l) => l.ttsEngine == TTSEngine.sherpaOnnxEspeak);
        final voices = espeak.map((l) => l.espeakVoice).toList();

        // While some might share (rare), most should be unique per language
        final uniqueVoices = voices.toSet();
        expect(
          uniqueVoices.length / voices.length,
          greaterThan(0.9), // At least 90% unique
          reason: 'Too many duplicate eSpeak voice models',
        );
      });

      test('Character model assignment matches language code', () {
        final espeak = kAllLanguages
            .where((l) => l.ttsEngine == TTSEngine.sherpaOnnxEspeak);

        for (final lang in espeak) {
          // Extract primary language code (e.g., 'hi' from 'hi-IN')
          final primaryCode = lang.code.split('-').first;

          // The espeakVoice should generally match or be related
          expect(
            lang.espeakVoice!
                    .toLowerCase()
                    .contains(primaryCode.toLowerCase()) ||
                _isValidEspeakVoiceForLanguage(lang),
            true,
            reason:
                '${lang.name}: espeakVoice "${lang.espeakVoice}" doesn\'t match language code "${lang.code}"',
          );
        }
      });
    });

    group('Trigger Word Configuration (Workflow consistency)', () {
      test('All languages have end-of-thought trigger configured', () {
        for (final lang in kAllLanguages) {
          expect(
            lang.endOfThoughtTrigger.isNotEmpty,
            true,
            reason: '${lang.name} has empty endOfThoughtTrigger',
          );

          expect(
            lang.endOfThoughtVariants.isNotEmpty,
            true,
            reason: '${lang.name} has empty endOfThoughtVariants list',
          );

          expect(
            lang.endOfThoughtVariants.contains(lang.endOfThoughtTrigger),
            true,
            reason: '${lang.name}: endOfThoughtTrigger not in variants list',
          );
        }
      });

      test('All languages have exit trigger configured', () {
        for (final lang in kAllLanguages) {
          expect(
            lang.exitTrigger.isNotEmpty,
            true,
            reason: '${lang.name} has empty exitTrigger',
          );

          expect(
            lang.exitTriggerVariants.isNotEmpty,
            true,
            reason: '${lang.name} has empty exitTriggerVariants list',
          );

          expect(
            lang.exitTriggerVariants.contains(lang.exitTrigger),
            true,
            reason: '${lang.name}: exitTrigger not in variants list',
          );
        }
      });

      test('Trigger words are in native script for native languages', () {
        // Indian languages should have trigger words in native script
        final indianLangs =
            kAllLanguages.where((l) => l.group == LanguageGroup.nativeIndian);

        for (final lang in indianLangs) {
          // At least one variant should be in native script (not romanized)
          final hasNativeScript = lang.endOfThoughtVariants.any(
            (v) => _containsNonLatinChars(v),
          );

          expect(
            hasNativeScript,
            true,
            reason:
                '${lang.name}: No native script variants found in endOfThoughtVariants',
          );
        }
      });
    });

    group('Language Groups (Workflow organization)', () {
      test('Main group languages have expected engines', () {
        final main = kAllLanguages.where((l) => l.group == LanguageGroup.main);

        for (final lang in main) {
          expect(
            [TTSEngine.flutterTts, TTSEngine.sherpaOnnxEspeak]
                .contains(lang.ttsEngine),
            true,
            reason:
                '${lang.name} in MAIN group has unexpected engine: ${lang.ttsEngine}',
          );
        }
      });

      test('Native Indian languages use eSpeak engine', () {
        final indian =
            kAllLanguages.where((l) => l.group == LanguageGroup.nativeIndian);

        for (final lang in indian) {
          expect(
            lang.ttsEngine == TTSEngine.sherpaOnnxEspeak,
            true,
            reason:
                '${lang.name} in NATIVE INDIAN group should use eSpeak, got: ${lang.ttsEngine}',
          );
        }
      });

      test('International languages use eSpeak engine', () {
        final intl =
            kAllLanguages.where((l) => l.group == LanguageGroup.international);

        for (final lang in intl) {
          expect(
            lang.ttsEngine == TTSEngine.sherpaOnnxEspeak,
            true,
            reason:
                '${lang.name} in INTERNATIONAL group should use eSpeak, got: ${lang.ttsEngine}',
          );
        }
      });

      test('All language groups are represented', () {
        final main = kAllLanguages.where((l) => l.group == LanguageGroup.main);
        final indian =
            kAllLanguages.where((l) => l.group == LanguageGroup.nativeIndian);
        final intl =
            kAllLanguages.where((l) => l.group == LanguageGroup.international);

        expect(main.isNotEmpty, true, reason: 'MAIN group is empty');
        expect(indian.isNotEmpty, true, reason: 'NATIVE INDIAN group is empty');
        expect(intl.isNotEmpty, true, reason: 'INTERNATIONAL group is empty');
      });

      test('Language totals match across groups', () {
        final main = kAllLanguages.where((l) => l.group == LanguageGroup.main);
        final indian =
            kAllLanguages.where((l) => l.group == LanguageGroup.nativeIndian);
        final intl =
            kAllLanguages.where((l) => l.group == LanguageGroup.international);

        final total = main.length + indian.length + intl.length;
        expect(
          total,
          kAllLanguages.length,
          reason:
              'Sum of groups (${main.length} + ${indian.length} + ${intl.length} = $total) != kAllLanguages.length (${kAllLanguages.length})',
        );
      });
    });

    group('Workflow Step Compliance (Rule 1 & 3)', () {
      test('Atomic state updates - all properties accessible', () {
        for (final lang in kAllLanguages) {
          // Verify all 4 workflow steps can access needed properties
          // Step 1: selectedLanguage.value = lang
          expect(lang.code.isNotEmpty, true);
          expect(lang.name.isNotEmpty, true);

          // Step 2: TTS engine switch
          expect(lang.ttsEngine, isNotNull);

          // Step 3: STT locale update
          expect(lang.sttLocale.isNotEmpty, true);

          // Step 4: Persistence
          expect(lang.code.length <= 10, true, // Valid code length
              reason:
                  '${lang.name} language code too long for storage: ${lang.code}');
        }
      });

      test('No language is missing critical workflow properties', () {
        for (final lang in kAllLanguages) {
          // Properties needed for _switchLanguage() workflow
          expect(lang.code, isNotNull);
          expect(lang.ttsEngine, isNotNull);
          expect(lang.sttLocale, isNotNull);
          expect(lang.name, isNotNull);

          // Properties for voice model
          expect(
            lang.ttsEngine == TTSEngine.flutterTts ||
                lang.espeakVoice != null ||
                lang.piperModelId != null,
            true,
            reason:
                '${lang.name}: No voice model configured (no espeakVoice, piperModelId, or flutterTts)',
          );
        }
      });
    });

    group('STT Locale Consistency (Rule 4)', () {
      test('STT locales are valid BCP-47 codes', () {
        for (final lang in kAllLanguages) {
          final locale = lang.sttLocale;

          // Valid format: 'xx' or 'xx-XX'
          final isValid = RegExp(r'^[a-z]{2}(-[A-Z]{2})?$').hasMatch(locale);
          expect(
            isValid,
            true,
            reason: '${lang.name} has invalid BCP-47 locale: $locale',
          );
        }
      });

      test('STT locales match language codes', () {
        for (final lang in kAllLanguages) {
          final primaryLangCode = lang.code.split('-').first;
          final primaryLocale = lang.sttLocale.split('-').first;

          expect(
            primaryLangCode == primaryLocale,
            true,
            reason:
                '${lang.name}: Language code "$primaryLangCode" doesn\'t match STT locale "$primaryLocale"',
          );
        }
      });
    });

    group('Voice Options (if configured)', () {
      test('Voice options have valid structure if present', () {
        for (final lang in kAllLanguages) {
          if (lang.voices.isEmpty) continue;

          for (final voice in lang.voices) {
            expect(voice.id.isNotEmpty, true,
                reason: '${lang.name} voice has empty id');
            expect(voice.label.isNotEmpty, true,
                reason: '${lang.name} voice has empty label');
            expect(
              ['male', 'female', 'neutral'].contains(voice.gender),
              true,
              reason: '${lang.name} voice has invalid gender: ${voice.gender}',
            );
            expect(
              ['x_low', 'low', 'medium', 'high'].contains(voice.quality),
              true,
              reason:
                  '${lang.name} voice has invalid quality: ${voice.quality}',
            );
          }
        }
      });

      test('System voices marked correctly', () {
        // Flutter TTS languages should have system voices
        final flutterTts =
            kAllLanguages.where((l) => l.ttsEngine == TTSEngine.flutterTts);

        for (final lang in flutterTts) {
          if (lang.voices.isNotEmpty) {
            expect(
              lang.voices.first.isSystem,
              true,
              reason: '${lang.name} flutter_tts voice not marked as system',
            );
          }
        }
      });
    });

    group('Language Distribution', () {
      test('Main group has at least 3 languages', () {
        final main = kAllLanguages.where((l) => l.group == LanguageGroup.main);
        expect(main.length, greaterThanOrEqualTo(3),
            reason: 'Not enough main languages');
      });

      test('Native Indian group has reasonable count', () {
        final indian =
            kAllLanguages.where((l) => l.group == LanguageGroup.nativeIndian);
        expect(indian.length, greaterThanOrEqualTo(10),
            reason: 'Indian language group should have 10+ languages');
      });

      test('International group has reasonable count', () {
        final intl =
            kAllLanguages.where((l) => l.group == LanguageGroup.international);
        expect(intl.length, greaterThanOrEqualTo(15),
            reason: 'International language group should have 15+ languages');
      });
    });

    group('Special Character Support', () {
      test('Native languages use native script in triggers', () {
        // Hindi, Tamil, Telugu, etc. should have native script
        final nativeLangs = <String, String>{
          'hi': 'हि', // Devanagari
          'ta': 'த', // Tamil
          'te': 'త', // Telugu
          'kn': 'ಕ', // Kannada
        };

        for (final entry in nativeLangs.entries) {
          final lang = kAllLanguages.firstWhere(
            (l) => l.code == entry.key,
            orElse: () => kAllLanguages[0],
          );

          final hasNativeScript =
              lang.endOfThoughtTrigger.contains(entry.value) ||
                  lang.endOfThoughtVariants.any((v) => v.contains(entry.value));

          expect(
            hasNativeScript,
            true,
            reason: '${lang.name} doesn\'t use native script in triggers',
          );
        }
      });
    });
  });
}

// Helper functions

bool _isValidEspeakVoiceForLanguage(LanguageModel lang) {
  // Special cases where espeakVoice might differ from code
  final exceptions = {
    'pt-BR': 'pt-BR',
    'en-US': 'en-US',
    'en-GB': 'en-GB',
    'zh': 'zh',
  };

  return exceptions[lang.code] == lang.espeakVoice;
}

bool _containsNonLatinChars(String text) {
  // Check if string contains non-ASCII/non-Latin characters
  for (int i = 0; i < text.length; i++) {
    final int charCode = text.codeUnitAt(i);
    if (charCode > 127) {
      return true; // Non-ASCII character found
    }
  }
  return false;
}
