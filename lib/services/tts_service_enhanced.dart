import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import '../services/sound_service.dart';

/// Speaking modes for TTS pacing control
enum SpeakingMode { utility, story }

/// TTS Language options with enhanced support
enum TTSLanguage {
  englishUS,
  englishUK,
  hindi,
  hinglish,
}

/// Enhanced TTS Service with multi-language support
/// Handles English, Hindi, and Hinglish text-to-speech with normalization
class TTSService extends GetxService {
  final FlutterTts _tts = FlutterTts();

  // Observable states
  final isSpeaking = false.obs;
  final isInitialized = false.obs;
  final currentLanguage = TTSLanguage.hinglish.obs;
  final voiceSpeed = 1.0.obs;
  final voicePitch = 1.0.obs;
  final voices = <Map<String, String>>[].obs;
  final selectedVoice = Rxn<Map<String, String>>();

  // Language locale mapping
  final Map<TTSLanguage, String> languageLocales = {
    TTSLanguage.englishUS: 'en-US',
    TTSLanguage.englishUK: 'en-GB',
    TTSLanguage.hindi: 'hi-IN',
    TTSLanguage.hinglish: 'hi-IN', // Hinglish uses Hindi locale
  };

  // Persona voice configurations
  final Map<String, Map<String, dynamic>> personaVoiceConfigs = {
    'Fun: Dog': {
      'pitch': 1.05,
      'speed': 1.15,
      'description': 'Enthusiastic, fast, excited',
    },
    'Fun: Cat': {
      'pitch': 1.25,
      'speed': 0.95,
      'description': 'Aloof, slow, occasional',
    },
    'Fun: Lion': {
      'pitch': 0.55,
      'speed': 0.85,
      'description': 'Deep, commanding, dramatic pauses',
    },
    'Fun: Monkey': {
      'pitch': 1.40,
      'speed': 1.30,
      'description': 'High energy, fast, playful',
    },
    'Fun: Pig': {
      'pitch': 0.85,
      'speed': 1.0,
      'description': 'Content, satisfied',
    },
    'Straight Forward': {
      'pitch': 1.0,
      'speed': 1.0,
      'description': 'Normal speaking',
    },
    'Therapist Mode': {
      'pitch': 0.95,
      'speed': 0.85,
      'description': 'Calm, soothing, slow',
    },
    'Gen-Z': {
      'pitch': 1.15,
      'speed': 1.1,
      'description': 'Energetic, casual',
    },
  };

  // Gen-Z Slang Dictionary
  final Map<String, String> genZSlang = {
    'good': 'bussin',
    'great': 'goated',
    'bad': 'mid',
    'yes': 'bet',
    'no': 'nah fam',
    'friend': 'bestie',
    'funny': 'dead',
    'laughing': 'dying',
    'love': 'stan',
    'money': 'bag',
    'rich': 'boujee',
    'style': 'drip',
    'cool': 'valid',
    'excited': 'hyped',
    'lie': 'cap',
    'truth': 'no cap',
    'really': 'highkey',
    'kind of': 'lowkey',
    'suspicious': 'sus',
    'excellent': 'fire',
    'win': 'W',
    'loss': 'L',
  };

  // Critical Hindi words that need exact transformations
  final Map<String, String> criticalHindiWords = {
    'main': 'mai',
    'hain': 'hai',
    'kahin': 'kaheen',
    'tumhein': 'tumhe',
    'rahein': 'rahe',
    'chahein': 'chahe',
    'jayein': 'jaye',
    'aayein': 'aaye',
  };

  // Common Indian names
  final Map<String, String> commonIndianNames = {
    'S H O U R A V': 'SHOURAV',
    'S-H-O-U-R-A-V': 'SHOURAV',
    'K U M A R': 'KUMAR',
    'K-U-M-A-R': 'KUMAR',
    'S I N G H': 'SINGH',
    'S-I-N-G-H': 'SINGH',
    'S H A R M A': 'SHARMA',
    'S-H-A-R-M-A': 'SHARMA',
    'P A T E L': 'PATEL',
    'P-A-T-E-L': 'PATEL',
    'G U P T A': 'GUPTA',
    'G-U-P-T-A': 'GUPTA',
    'V E R M A': 'VERMA',
    'V-E-R-M-A': 'VERMA',
    'M I S H R A': 'MISHRA',
    'M-I-S-H-R-A': 'MISHRA',
  };

  // Festival calendar
  final Map<String, List<String>> indianFestivals = {
    '01-01': ['Happy New Year', 'Naya Saal Mubarak'],
    '01-14': ['Happy Makar Sankranti', 'Uttarayan ki Shubhkamnayein'],
    '03-17': ['Happy Holi', 'Holi ki hardik shubhkamnayein'],
    '01-26': ['Happy Republic Day', 'Gantantra Diwas ki Shubhkamnayein'],
    '08-15': ['Happy Independence Day', 'Swatantrata Diwas ki Shubhkamnayein'],
    '10-02': ['Happy Gandhi Jayanti'],
    '10-31': ['Happy Diwali', 'Deepavali ki Hardik Shubhkamnayein'],
    '12-25': ['Merry Christmas', 'Christmas ki Shubhkamnayein'],
  };

  String currentPersona = 'Straight Forward';

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeTTS();
  }

  /// Initialize TTS
  Future<void> _initializeTTS() async {
    try {
      // Set default configuration
      await _tts.setLanguage('hi-IN');
      await _tts.setSpeechRate(1.0);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      // Get available voices
      final availableVoices = await _tts.getVoices;
      if (availableVoices is List) {
        voices.value = availableVoices
            .map((v) => {
                  'name': v['name']?.toString() ?? '',
                  'locale': v['locale']?.toString() ?? '',
                })
            .toList();
      }

      // Set completion handler
      _tts.setCompletionHandler(() {
        isSpeaking.value = false;
      });

      isInitialized.value = true;
      debugPrint('✅ TTS Service Initialized');
    } catch (e) {
      debugPrint('❌ TTS Initialization Error: $e');
    }
  }

  /// Detect speaking mode based on text content
  SpeakingMode detectSpeakingMode(String text) {
    // Check text length - long content is likely narrative
    if (text.length > 150) {
      return SpeakingMode.story;
    }

    // Check for story keywords
    final lowerText = text.toLowerCase();
    final storyKeywords = [
      'kahani',
      'story',
      'sunao',
      'ek baar',
      'once upon',
      'long ago',
      'there was',
      'tale',
      'katha',
      'dastan',
      'baad mein',
      'phir',
      'morning',
      'evening',
      'night',
      'festival',
      'celebration'
    ];

    for (var keyword in storyKeywords) {
      if (lowerText.contains(keyword)) {
        return SpeakingMode.story;
      }
    }

    // Check for festival messages
    final String? festival = getTodaysFestival();
    if (festival != null && text.contains(festival)) {
      return SpeakingMode.story;
    }

    // Check for storytelling personas
    if (currentPersona == 'Therapist Mode' ||
        currentPersona.contains('Story') ||
        currentPersona == 'Teacher Mode') {
      return SpeakingMode.story;
    }

    return SpeakingMode.utility;
  }

  /// Normalize Hindi text for TTS
  String normalizeHindiForTTS(String text) {
    // Skip normalization for non-Hindi voices
    final String voiceName = selectedVoice.value?['name'] ?? '';
    if (!voiceName.toLowerCase().contains('hindi') &&
        !voiceName.toLowerCase().contains('hinglish')) {
      // Still apply basic rules if language is set to Hindi/Hinglish
      if (currentLanguage.value != TTSLanguage.hindi &&
          currentLanguage.value != TTSLanguage.hinglish) {
        return text;
      }
    }

    String result = text;

    // RULE 1: Critical Hindi words
    criticalHindiWords.forEach((hindiWord, replacement) {
      result = result.replaceAll(
        RegExp(r'\b' + hindiWord + r'\b', caseSensitive: false),
        replacement,
      );
    });

    // RULE 2: ein/ain → e (Respectful/Plural verb forms)
    result = result.replaceAllMapped(
      RegExp(r'\b([\w]*)(ein|ain)\b', caseSensitive: false),
      (match) {
        final String word = match.group(1) ?? '';
        final String fullWord = '$word${match.group(2)}';
        if (criticalHindiWords.keys
            .any((k) => k.toLowerCase() == fullWord.toLowerCase())) {
          return fullWord;
        }
        return '${word}e';
      },
    );

    // RULE 3: en → e (Plural nouns & verbs)
    result = result.replaceAllMapped(
      RegExp(r'\b([\w]*?)en\b', caseSensitive: false),
      (match) {
        final String word = match.group(1) ?? '';
        final List<String> englishWords = [
          'men',
          'pen',
          'then',
          'when',
          'often',
          'ten',
          'been',
          'seen',
          'green',
          'screen',
          'between',
          'given',
          'open',
          'broken',
          'token',
          'spoken',
          'children',
          'chicken'
        ];
        final String fullWord = '${word}en';
        if (englishWords.contains(fullWord.toLowerCase())) {
          return fullWord;
        }
        return '${word}e';
      },
    );

    // RULE 4: on → o (Oblique plural forms)
    result = result.replaceAllMapped(
      RegExp(r'\b([\w]*?)on\b', caseSensitive: false),
      (match) {
        final String word = match.group(1) ?? '';
        final List<String> englishWords = [
          'on',
          'upon',
          'reason',
          'person',
          'season',
          'lesson',
          'common',
          'button',
          'cotton',
          'prison',
          'dragon',
          'wagon'
        ];
        final String fullWord = '${word}on';
        if (englishWords.contains(fullWord.toLowerCase())) {
          return fullWord;
        }
        return '${word}o';
      },
    );

    // RULE 5: Nasal sounds (un/oon/uun → oo or o)
    result = result.replaceAllMapped(
      RegExp(r'\b([\w]*?)(un|oon|uun)\b', caseSensitive: false),
      (match) {
        final String word = match.group(1) ?? '';
        final String ending = match.group(2)!.toLowerCase();
        final List<String> englishWords = [
          'run',
          'sun',
          'fun',
          'gun',
          'bun',
          'done',
          'one',
          'none',
          'soon',
          'moon',
          'noon',
          'spoon',
          'cartoon',
          'balloon'
        ];
        final String fullWord = '$word${match.group(2)}';
        if (englishWords.contains(fullWord.toLowerCase())) {
          return fullWord;
        }
        if (ending == 'oon' || ending == 'uun') {
          return '${word}oo';
        } else {
          return '${word}o';
        }
      },
    );

    debugPrint('🎤 Hindi TTS Normalized: $text → $result');
    return result.trim();
  }

  /// Fix spelled-out names
  String fixSpelledOutNames(String text) {
    String result = text;

    // 1. Condense words that are spelled out with hyphens (e.g. "S-H-O-U-R-A-V" -> "Shourav")
    final hyphenSpellingPattern = RegExp(r'\b([A-Za-z])(?:-([A-Za-z]))+\b');
    result = result.replaceAllMapped(hyphenSpellingPattern, (match) {
      final String condensed = match.group(0)!.replaceAll('-', '');
      if (condensed.length > 2) {
        return condensed[0].toUpperCase() +
            condensed.substring(1).toLowerCase();
      }
      return match.group(0)!;
    });

    // 2. Condense words spelled with spaces (must be at least 3 letters) (e.g. "S H O U R A V" -> "Shourav")
    final spaceSpellingPattern = RegExp(r'\b([A-Za-z])(?:\s+([A-Za-z])){2,}\b');
    result = result.replaceAllMapped(spaceSpellingPattern, (match) {
      final String condensed = match.group(0)!.replaceAll(RegExp(r'\s+'), '');
      return condensed[0].toUpperCase() + condensed.substring(1).toLowerCase();
    });

    // 3. Replace common names from dictionary (and ensure title case)
    commonIndianNames.forEach((spelled, complete) {
      // Normalize 'SHOURAV' to 'Shourav' so TTS doesn't read it as an acronym
      final String titleCaseComplete = complete.length > 1
          ? complete[0].toUpperCase() + complete.substring(1).toLowerCase()
          : complete;
      result = result.replaceAll(spelled, titleCaseComplete);
    });

    // 4. Ensure known uppercase names are converted to Title Case in general text
    final capsNames = [
      'SHOURAV',
      'KUMAR',
      'SINGH',
      'SHARMA',
      'PATEL',
      'GUPTA',
      'VERMA',
      'MISHRA'
    ];
    for (String name in capsNames) {
      result = result.replaceAll(
          name, name[0].toUpperCase() + name.substring(1).toLowerCase());
    }

    return result;
  }

  /// Apply Gen-Z slang if persona is Gen-Z
  String applyGenZSlang(String text) {
    if (currentPersona != 'Gen-Z') return text;

    String result = text;
    genZSlang.forEach((normal, slang) {
      result = result.replaceAll(normal, slang);
    });

    return result;
  }

  /// Get today's festival
  String? getTodaysFestival() {
    final today = DateTime.now();
    final key =
        '${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final festivals = indianFestivals[key];
    if (festivals != null && festivals.isNotEmpty) {
      return festivals[Random().nextInt(festivals.length)];
    }
    return null;
  }

  /// Preprocess text for TTS
  String preprocessText(String text, {SpeakingMode? mode}) {
    String processed = text;

    // Fix spelled-out names
    processed = fixSpelledOutNames(processed);

    // Normalize Hindi
    processed = normalizeHindiForTTS(processed);

    // Apply Gen-Z slang if needed
    processed = applyGenZSlang(processed);

    // Apply speaking mode adjustments
    final detectedMode = mode ?? detectSpeakingMode(processed);
    if (detectedMode == SpeakingMode.story) {
      // Add strategic pauses for storytelling rhythm
      processed = processed.replaceAll('. ', '.,, ');
      processed = processed.replaceAll('... ', '...,,, ');
    }

    return processed;
  }

  /// Speak text with full preprocessing
  Future<void> speak(String text,
      {TTSLanguage? language, String? persona}) async {
    if (text.isEmpty) return;

    try {
      // Stop any current speech
      await stop();

      // Set language
      if (language != null) {
        currentLanguage.value = language;
      }

      // Set persona
      if (persona != null) {
        currentPersona = persona;
      }

      // Get voice configuration
      final config = personaVoiceConfigs[currentPersona] ??
          personaVoiceConfigs['Straight Forward']!;

      // Detect speaking mode
      final mode = detectSpeakingMode(text);

      // Preprocess text
      final String processedText = preprocessText(text, mode: mode);

      // Adjust speed based on mode
      double speed = config['speed'] ?? 1.0;
      if (mode == SpeakingMode.story) {
        speed *= 0.9; // Slower for stories
      }

      // Set TTS parameters
      await _tts.setLanguage(languageLocales[currentLanguage.value] ?? 'hi-IN');
      await _tts.setSpeechRate(speed.clamp(0.5, 1.5));
      await _tts.setPitch((config['pitch'] ?? 1.0).clamp(0.5, 2.0));

      // Play contextual sound before speaking
      await _playContextualSound(mode);

      // Speak
      isSpeaking.value = true;
      await _tts.speak(processedText);

      debugPrint('🗣️ Speaking (${currentLanguage.value}): $processedText');
    } catch (e) {
      debugPrint('❌ TTS Speak Error: $e');
      isSpeaking.value = false;
    }
  }

  /// Play contextual sound
  Future<void> _playContextualSound(SpeakingMode mode) async {
    try {
      if (mode == SpeakingMode.story) {
        await SoundService.to.playDreamy();
      } else {
        await SoundService.to.playClick();
      }
    } catch (e) {
      debugPrint('Sound error: $e');
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    try {
      await _tts.stop();
      isSpeaking.value = false;
    } catch (e) {
      debugPrint('❌ TTS Stop Error: $e');
    }
  }

  /// Pause speaking
  Future<void> pause() async {
    try {
      await _tts.pause();
    } catch (e) {
      debugPrint('❌ TTS Pause Error: $e');
    }
  }

  /// Set voice speed
  Future<void> setSpeed(double speed) async {
    voiceSpeed.value = speed.clamp(0.5, 1.5);
    await _tts.setSpeechRate(voiceSpeed.value);
  }

  /// Set voice pitch
  Future<void> setPitch(double pitch) async {
    voicePitch.value = pitch.clamp(0.5, 2.0);
    await _tts.setPitch(voicePitch.value);
  }

  /// Set language
  void setLanguage(TTSLanguage language) {
    currentLanguage.value = language;
    _tts.setLanguage(languageLocales[language] ?? 'hi-IN');
    debugPrint('🎤 TTS Language set to: $language');
  }

  /// Get available voices for current language
  List<Map<String, String>> getVoicesForLanguage(TTSLanguage language) {
    final locale = languageLocales[language];
    return voices
        .where((v) => v['locale']?.startsWith(locale ?? '') ?? false)
        .toList();
  }

  /// Set voice
  Future<void> setVoice(Map<String, String> voice) async {
    selectedVoice.value = voice;
    await _tts.setVoice({
      'name': voice['name'] ?? '',
      'locale': voice['locale'] ?? '',
    });
  }

  /// Get language name
  String getLanguageName(TTSLanguage lang) {
    switch (lang) {
      case TTSLanguage.englishUS:
        return 'English (US)';
      case TTSLanguage.englishUK:
        return 'English (UK)';
      case TTSLanguage.hindi:
        return 'Hindi';
      case TTSLanguage.hinglish:
        return 'Hinglish';
    }
  }

  @override
  void onClose() {
    _tts.stop();
    super.onClose();
  }
}
