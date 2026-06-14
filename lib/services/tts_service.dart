import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';

import 'tts_sanitizer.dart';
import '../features/orb_thinking/orb_thinking_controller.dart';

/// Speaking modes for TTS pacing control
enum SpeakingMode { utility, story }

/// Language support enum
enum TTSLanguage { english, hindi, hinglish }

/// Enhanced TTS Service with comprehensive language support
/// Supports English, Hindi, and Hinglish (Hindi written in English script)
class TTSService extends GetxService {
  final FlutterTts _tts = FlutterTts();

  // Observable states
  final isSpeaking = false.obs;
  final currentLanguage = TTSLanguage.hinglish.obs;
  final voiceSpeed = 0.5.obs; // Default 1× comfortable pace
  final pitch = 1.0.obs;
  final isInitialized = false.obs;

  // Progress tracking for word-by-word highlighting (word-index based)
  final progressWordIndex = (-1).obs;

  // ── Lip-sync signals ─────────────────────────────────────────────────────
  // Toggles true/false on every new word spoken — AnimatedOrb listens to this
  // to fire a mouth-open pulse that is perfectly timed to speech.
  final speakingWordPulse = false.obs;

  // 0.0 → 1.0 intensity: set to 1.0 on each word, AnimatedOrb decays it
  // down to 0.0 between words. Useful for smooth amplitude-like animation.
  final speakingIntensity = 0.0.obs;

  // Internal: words of the text currently being spoken by flutter_tts
  List<String> _currentTtsWords = [];

  // Internal: cumulative word offset for chunked playback
  int _chunkWordOffset = 0;

  // Internal: pending completer for speakChunk — completed by stop() if called mid-chunk
  Completer<int>? _pendingChunkCompleter;

  // Cache for all system voices to support dynamic international languages
  List<dynamic> _allSystemVoices = [];

  // Voice configuration
  final Rx<Map<String, String>?> selectedVoice = Rxn<Map<String, String>>();
  final availableVoices = <Map<String, String>>[].obs;

  // Story mode configuration
  var speakingMode = SpeakingMode.utility.obs;

  // Emotion detection
  var currentEmotion = 'neutral'.obs;

  // Animal voice configurations for personas
  final Map<String, Map<String, dynamic>> animalVoiceConfigs = {
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
      'description': 'Deep, commanding, dramatic',
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
    'Fun: Donkey': {
      'pitch': 0.75,
      'speed': 0.85,
      'description': 'Slow, grumpy, stubborn',
    },
    'Fun: Toddler': {
      'pitch': 1.4,
      'speed': 1.1,
      'description': 'Cute, simple, curious',
    },
  };

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeTTS();
  }

  /// Initialize TTS with default settings
  Future<void> _initializeTTS() async {
    try {
      // Set default language to Hindi for Hinglish support
      await _tts.setLanguage('hi-IN');

      // Set default speech rate (0.5 for comfortable 1× listening)
      await _tts.setSpeechRate(0.5);

      // Set default pitch
      await _tts.setPitch(1.0);

      // Set volume
      await _tts.setVolume(1.0);

      // Wait for completion before returning from speak()
      await _tts.awaitSpeakCompletion(true);

      // Setup handlers with enhanced orb thinking integration
      _tts.setStartHandler(() {
        isSpeaking.value = true;
        // Trigger orb thinking system when TTS starts
        _triggerOrbThinking();
      });
      _tts.setCompletionHandler(() {
        isSpeaking.value = false;
        _resetProgress();
        // End orb thinking when TTS completes
        _endOrbThinking();
      });
      _tts.setCancelHandler(() {
        isSpeaking.value = false;
        _resetProgress();
        // End orb thinking when TTS is cancelled
        _endOrbThinking();
      });
      _tts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        isSpeaking.value = false;
        _resetProgress();
        // End orb thinking on error
        _endOrbThinking();
      });

      // Wire progress handler for word-by-word highlighting AND lip-sync
      // Maps character offsets from flutter_tts to a word index, and fires
      // lip-sync pulse signals so AnimatedOrb can react to real words.
      _tts.setProgressHandler((String text, int start, int end, String word) {
        // ── Lip-sync: pulse on every word boundary ──────────────────────
        speakingWordPulse.value = !speakingWordPulse.value;
        speakingIntensity.value = 1.0; // Reset to peak; orb decays this

        // Find which word in _currentTtsWords contains this character range
        int charPos = 0;
        for (int i = 0; i < _currentTtsWords.length; i++) {
          final w = _currentTtsWords[i];
          final wordStart = charPos;
          final wordEnd = charPos + w.length;
          // If the callback's start falls within this word
          if (start >= wordStart && start < wordEnd) {
            progressWordIndex.value = _chunkWordOffset + i;
            debugPrint(
                '🎙️ TTS Progress: word[$i]="${_currentTtsWords[i]}" at global index=${_chunkWordOffset + i}');
            return;
          }
          charPos = wordEnd + 1; // +1 for the space between words
        }
        // Fallback: if not found, try matching by word text
        for (int i = 0; i < _currentTtsWords.length; i++) {
          if (_currentTtsWords[i] == word) {
            progressWordIndex.value = _chunkWordOffset + i;
            debugPrint(
                '🎙️ TTS Progress (fallback): word[$i]="$word" at global index=${_chunkWordOffset + i}');
            return;
          }
        }
        debugPrint('⚠️ TTS Progress: word "$word" not found in current chunk');
      });

      // Load available voices
      await _loadVoices();

      // Set default Hinglish Female voice
      _setDefaultHinglishFemaleVoice();

      isInitialized.value = true;
      debugPrint('✅ TTS Service Initialized');
    } catch (e) {
      debugPrint('❌ TTS Initialization Error: $e');
    }
  }

  /// Load available voices from the system
  Future<void> _loadVoices() async {
    try {
      final List<dynamic>? voices = await _tts.getVoices;
      if (voices != null) {
        _allSystemVoices = voices;
        // Filter for English (US) and Hindi (India) voices only for the UI menu
        final filteredVoices = voices.where((v) {
          final String locale = v['locale'].toString().toLowerCase();
          return locale.startsWith('en-us') || locale.startsWith('hi-in');
        }).toList();

        // Map and categorize voices
        final mappedVoices = filteredVoices.map((v) {
          final String name = v['name'].toString();
          final String locale = v['locale'].toString();

          // Detect gender from voice name
          String gender = 'Unknown';
          final String lowerName = name.toLowerCase();
          if (lowerName.contains('female') ||
              lowerName.contains('woman') ||
              lowerName.contains('girl')) {
            gender = 'Female';
          } else if (lowerName.contains('male') ||
              lowerName.contains('man') ||
              lowerName.contains('boy')) {
            gender = 'Male';
          } else {
            // Default alternating pattern
            gender = (filteredVoices.indexOf(v) % 2 == 0) ? 'Male' : 'Female';
          }

          // Create display name
          final String language =
              locale.startsWith('en') ? 'English (US)' : 'Hinglish';
          final String displayName = '$language – $gender';

          return {
            'name': name,
            'locale': locale,
            'gender': gender,
            'language': language,
            'displayName': displayName
          };
        }).toList();

        // Remove duplicates - keep only 1 male and 1 female per language
        final Map<String, Map<String, String>> uniqueVoices = {};
        for (var voice in mappedVoices) {
          final String key = "${voice['language']}-${voice['gender']}";
          if (!uniqueVoices.containsKey(key)) {
            uniqueVoices[key] = voice;
          }
        }

        // Sort: Hinglish first, then by gender (Female first)
        final dedupedVoices = uniqueVoices.values.toList();
        dedupedVoices.sort((a, b) {
          if (a['language'] == 'Hinglish' && b['language'] != 'Hinglish') {
            return -1;
          }
          if (a['language'] != 'Hinglish' && b['language'] == 'Hinglish') {
            return 1;
          }
          final int langCompare = a['language']!.compareTo(b['language']!);
          if (langCompare != 0) return langCompare;
          if (a['gender'] == 'Female' && b['gender'] != 'Female') return -1;
          if (a['gender'] != 'Female' && b['gender'] == 'Female') return 1;
          return a['gender']!.compareTo(b['gender']!);
        });

        availableVoices.value = dedupedVoices;
      }
    } catch (e) {
      debugPrint('Error loading voices: $e');
    }
  }

  /// Set default voice to Hinglish Female
  void _setDefaultHinglishFemaleVoice() {
    if (availableVoices.isNotEmpty) {
      final hinglishFemale = availableVoices.firstWhere(
        (v) => v['language'] == 'Hinglish' && v['gender'] == 'Female',
        orElse: () => availableVoices.first,
      );
      setVoice(hinglishFemale);
    }
  }

  /// Set voice by voice map
  void setVoice(Map<String, String> voice) {
    selectedVoice.value = voice;
    _tts.setVoice({'name': voice['name']!, 'locale': voice['locale']!});

    // Set pitch based on gender
    final String gender = voice['gender'] ?? 'Unknown';
    if (gender == 'Male') {
      _tts.setPitch(0.75);
    } else if (gender == 'Female') {
      _tts.setPitch(1.2);
    } else {
      _tts.setPitch(1.0);
    }

    // Update current language
    if (voice['language'] == 'English (US)') {
      currentLanguage.value = TTSLanguage.english;
    } else {
      currentLanguage.value = TTSLanguage.hinglish;
    }

    debugPrint("🎤 Voice set to: ${voice['displayName']}");
  }

  /// Set TTS language and automatically select appropriate voice
  /// This ensures that the correct locale and voice are used for the selected language
  void setLanguage(TTSLanguage language) {
    currentLanguage.value = language;

    // Find and set appropriate voice for the language
    String targetLanguage = '';
    String targetLocale = 'hi-IN'; // Default

    switch (language) {
      case TTSLanguage.english:
        targetLanguage = 'English (US)';
        targetLocale = 'en-US';
        break;
      case TTSLanguage.hindi:
        targetLanguage = 'Hindi';
        targetLocale = 'hi-IN';
        break;
      case TTSLanguage.hinglish:
        targetLanguage = 'Hinglish';
        targetLocale = 'hi-IN';
        break;
    }

    // Find a voice matching the target language
    if (availableVoices.isNotEmpty) {
      final matchingVoice = availableVoices.firstWhere(
        (v) => v['language'] == targetLanguage,
        orElse: () {
          // Fallback: find female voice for the language
          return availableVoices.firstWhere(
            (v) =>
                v['gender'] == 'Female' &&
                v['language']?.contains(targetLanguage.split(' ')[0]) == true,
            orElse: () => availableVoices.first,
          );
        },
      );

      // Set voice and ensure correct locale
      setVoice(matchingVoice);
      _tts.setLanguage(targetLocale);
    }

    debugPrint(
        '🌍 TTS Language set to: ${language.toString()} (Locale: $targetLocale)');
  }

  /// Set speech speed
  void setSpeed(double speed) {
    voiceSpeed.value = speed;
    _tts.setSpeechRate(speed);
  }

  /// Alias for [setSpeed] — matches the standard TTS API name.
  void setSpeechRate(double speed) => setSpeed(speed);

  /// Set pitch
  void setPitch(double newPitch) {
    pitch.value = newPitch;
    _tts.setPitch(newPitch);
  }

  /// Apply persona-specific voice effects
  void applyPersonaEffects(String persona) {
    // Reset to defaults
    double newPitch = 1.0;
    double newSpeed = 0.5; // Default 1× comfortable pace

    // Check animal configs
    final animalConfig = animalVoiceConfigs[persona];
    if (animalConfig != null) {
      newPitch = (animalConfig['pitch'] as double?) ?? 1.0;
      newSpeed = (animalConfig['speed'] as double?) ?? 0.5;
    } else {
      // Handle non-animal personas
      switch (persona) {
        case 'Gen-Z: Slay Queen':
          newPitch = 1.1;
          newSpeed = 0.85;
          break;
        case 'Gen-Z: Bestie Mode':
          newPitch = 1.08;
          newSpeed = 0.9;
          break;
        case 'Coach Mode':
          newPitch = 1.02;
          newSpeed = 0.8;
          break;
        case 'Therapist Mode':
          newPitch = 0.98;
          newSpeed = 0.7;
          break;
        case 'Teacher Mode':
          newPitch = 1.0;
          newSpeed = 0.72;
          break;
        default:
          newPitch = 1.0;
          newSpeed = 0.5;
      }
    }

    // Apply if Fun persona
    if (persona.startsWith('Fun:')) {
      setPitch(newPitch);
      setSpeed(newSpeed);
    }

    // Clamp pitch for professional personas
    if (persona == 'Coach Mode' ||
        persona == 'Teacher Mode' ||
        persona.contains('Professional')) {
      setPitch(pitch.value.clamp(0.9, 1.1));
    }
  }

  /// 🔹 PUBLIC TEXT PREPROCESSING
  /// Applies all text processing rules (sanitization, spelling fixes, etc.)
  String preprocessText(String text) {
    if (text.isEmpty) return text;

    // Detect speaking mode
    speakingMode.value = _detectSpeakingMode(text);

    // Step 0: Run through TtsSanitizer first (handles ALL-CAPS names, markdown, emoji)
    String cleanText = TtsSanitizer.sanitize(text);

    // Step 1: Additional clean-up via _cleanText (handles remaining formatting)
    cleanText = _cleanText(cleanText);

    // Fix spelled-out names (e.g. "S H O U R A V" → "Shourav")
    cleanText = _fixSpelledOutNames(cleanText);

    // Ensure names are spoken as natural phrases, not spelled out
    cleanText = _ensureNaturalNamePronunciation(cleanText);

    // Apply Hindi normalization if needed
    cleanText = _normalizeHindiForTTS(cleanText);

    // Apply speaking mode preprocessing
    cleanText = _applySpeakingMode(cleanText);

    return cleanText;
  }

  static const Map<String, String> _ttsLocaleMap = {
    'en': 'en-US',
    'en-US': 'en-US',
    'en-GB': 'en-GB',
    'hi': 'hi-IN',
    'hinglish': 'hi-IN',
    'pa': 'pa-IN',
    'bn': 'bn-IN',
    'te': 'te-IN',
    'ta': 'ta-IN',
    'gu': 'gu-IN',
    'mr': 'mr-IN',
    'ur': 'ur-IN',
    'or': 'or-IN', // Odia
    'as': 'as-IN', // Assamese
    'mai': 'mai-IN', // Maithili
    'ml': 'ml-IN',
    'kn': 'kn-IN',
    'sa': 'sa-IN',
    'ks': 'ks-IN',
    'ne': 'ne-NP',
    'si': 'si-LK',
    'fr': 'fr-FR',
    'de': 'de-DE',
    'es': 'es-ES',
    'it': 'it-IT',
    'ru': 'ru-RU',
    'nl': 'nl-NL',
    'pl': 'pl-PL',
    'ja': 'ja-JP',
    'ko': 'ko-KR',
    'zh': 'zh-CN',
    'ar': 'ar-SA',
    'id': 'id-ID',
    'vi': 'vi-VN',
    'th': 'th-TH',
    'sv': 'sv-SE',
    'nb': 'nb-NO',
    'fi': 'fi-FI',
    'cs': 'cs-CZ',
    'tr': 'tr-TR',
    'uk': 'uk-UA',
  };

  /// 🔹 MAIN SPEAK METHOD
  /// Takes text, processes it, and speaks it
  Future<void> speak(String text, {String? languageCode}) async {
    if (text.isEmpty) return;

    final String cleanText = preprocessText(text);

    // Build the word list from the FINAL text for progress tracking
    _chunkWordOffset = 0;
    _currentTtsWords =
        cleanText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    // Set language locale based on override or currentLanguage
    String locale = languageCode ?? 'hi-IN'; // Default
    if (languageCode == null) {
      switch (currentLanguage.value) {
        case TTSLanguage.english:
          locale = 'en-US';
          break;
        case TTSLanguage.hindi:
          locale = 'hi-IN';
          break;
        case TTSLanguage.hinglish:
          locale = 'hi-IN';
          break;
      }
    } else {
      // VC-04 Fix: Map language codes correctly
      locale = _ttsLocaleMap[languageCode] ?? languageCode;
    }

    // Dynamic Voice Switching for Native Languages
    if (languageCode != null && _allSystemVoices.isNotEmpty) {
      try {
        final matchedVoices = _allSystemVoices
            .where((v) => v['locale']
                .toString()
                .toLowerCase()
                .contains(languageCode.toLowerCase()))
            .toList();
        if (matchedVoices.isNotEmpty) {
          final bestVoice = matchedVoices.firstWhere(
              (v) => v['name'].toString().toLowerCase().contains('female'),
              orElse: () => matchedVoices.first);
          await _tts.setVoice({
            'name': bestVoice['name']!.toString(),
            'locale': bestVoice['locale']!.toString()
          });
        }
      } catch (e) {
        debugPrint('Error switching voice: \$e');
      }
    } else if (languageCode == null && selectedVoice.value != null) {
      await _tts.setVoice({
        'name': selectedVoice.value!['name']!,
        'locale': selectedVoice.value!['locale']!
      });
    }

    await _tts.setLanguage(locale);
    debugPrint(
        '🗣️ TTS Speaking in: $locale (Override: ${languageCode != null})');

    // Calculate speed multiplier
    double speedMultiplier = voiceSpeed.value;
    if (speakingMode.value == SpeakingMode.story) {
      speedMultiplier *= 0.90;
    }

    // Calculate pitch multiplier
    double pitchMultiplier = pitch.value;
    final String gender = selectedVoice.value?['gender'] ?? 'Unknown';
    if (gender == 'Male') {
      pitchMultiplier *= 0.75;
    } else if (gender == 'Female') {
      pitchMultiplier *= 1.2;
    }

    // Apply Indian English tuning
    if (locale == 'en-US') {
      pitchMultiplier = pitchMultiplier.clamp(0.95, 1.05);
    }

    await _tts.setSpeechRate(speedMultiplier);
    await _tts.setPitch(pitchMultiplier);

    // Speak the text
    await _tts.speak(cleanText);
  }

  /// Reset progress tracking observables
  void _resetProgress() {
    progressWordIndex.value = -1;
    speakingWordPulse.value = false; // Reset lip-sync pulse so orb mouth closes
    speakingIntensity.value = 0.0;
    _currentTtsWords = [];
  }

  /// Set the chunk word offset for chunked playback.
  /// Call this before speakChunk() for each chunk.
  void setChunkWordOffset(int offset) {
    _chunkWordOffset = offset;
  }

  /// Speak a chunk of text and return a Future that completes when done.
  /// Used for chunked TTS playback of long messages.
  /// Returns the number of TTS words in the spoken text (for offset tracking).
  Future<int> speakChunk(String text,
      {String? languageCode, String? preprocessedText}) async {
    if (text.isEmpty) return 0;

    final completer = Completer<int>();
    // Track the pending completer so stop() can unblock it immediately
    _pendingChunkCompleter = completer;

    // Use provided preprocessed text when available to avoid duplicate work
    // and to allow background preparation of upcoming chunks.
    final String cleanText = preprocessedText ?? preprocessText(text);

    // Build the word list from the FINAL text that TTS will actually speak
    _currentTtsWords =
        cleanText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wordCount = _currentTtsWords.length;

    // ── Re-wire ALL three handlers for this chunk ──────────────────────────
    // Android TTS can fire cancelHandler OR errorHandler instead of
    // completionHandler (e.g. when the engine resets between long utterances).
    // All three MUST complete the Completer; otherwise playAll() blocks forever
    // — audio silences while the word-highlight timer keeps running.
    void completeChunk() {
      // NOTE: Do NOT set isSpeaking.value = false here.
      // Setting it false would trigger VoiceController's `ever(ttsService.isSpeaking)`
      // listener to set isTalking = false between chunks, causing the orb mouth to
      // stop mid-sentence during the inter-chunk gap.
      // VoiceController.speakMessage's finally block clears all state after ALL chunks.
      _endOrbThinking();
      if (!completer.isCompleted) {
        completer.complete(wordCount);
      }
      _restoreDefaultHandlers();
      _pendingChunkCompleter = null;
    }

    _tts.setCompletionHandler(completeChunk);
    _tts.setCancelHandler(completeChunk);
    _tts.setErrorHandler((msg) {
      debugPrint('⚠️ [TTSService] speakChunk error: $msg');
      completeChunk();
    });

    // Set language locale based on override or currentLanguage
    String locale = languageCode ?? 'hi-IN'; // Default
    if (languageCode == null) {
      switch (currentLanguage.value) {
        case TTSLanguage.english:
          locale = 'en-US';
          break;
        case TTSLanguage.hindi:
          locale = 'hi-IN';
          break;
        case TTSLanguage.hinglish:
          locale = 'hi-IN';
          break;
      }
    } else {
      locale = _ttsLocaleMap[languageCode] ?? languageCode;
    }

    // Dynamic Voice Switching for Native Languages
    if (languageCode != null && _allSystemVoices.isNotEmpty) {
      try {
        final matchedVoices = _allSystemVoices
            .where((v) => v['locale']
                .toString()
                .toLowerCase()
                .contains(languageCode.toLowerCase()))
            .toList();
        if (matchedVoices.isNotEmpty) {
          final bestVoice = matchedVoices.firstWhere(
              (v) => v['name'].toString().toLowerCase().contains('female'),
              orElse: () => matchedVoices.first);
          await _tts.setVoice({
            'name': bestVoice['name']!.toString(),
            'locale': bestVoice['locale']!.toString()
          });
        }
      } catch (e) {
        debugPrint('Error switching chunk voice: \$e');
      }
    } else if (languageCode == null && selectedVoice.value != null) {
      await _tts.setVoice({
        'name': selectedVoice.value!['name']!,
        'locale': selectedVoice.value!['locale']!
      });
    }

    await _tts.setLanguage(locale);

    // Calculate speed multiplier
    double speedMultiplier = voiceSpeed.value;
    if (speakingMode.value == SpeakingMode.story) {
      speedMultiplier *= 0.90;
    }

    // Calculate pitch multiplier
    double pitchMultiplier = pitch.value;
    final String gender = selectedVoice.value?['gender'] ?? 'Unknown';
    if (gender == 'Male') {
      pitchMultiplier *= 0.75;
    } else if (gender == 'Female') {
      pitchMultiplier *= 1.2;
    }

    // Apply Indian English tuning
    if (locale == 'en-US') {
      pitchMultiplier = pitchMultiplier.clamp(0.95, 1.05);
    }

    await _tts.setSpeechRate(speedMultiplier);
    await _tts.setPitch(pitchMultiplier);

    // Speak the chunk
    isSpeaking.value = true;
    await _tts.speak(cleanText);

    // ── Safety timeout ────────────────────────────────────────────────────
    // If the TTS engine starts speaking but none of the three handlers
    // (completion / cancel / error) ever fires — an edge case on some Android
    // builds — the completer would block playAll() indefinitely.
    // Estimate max speaking time: ~80 ms/word at rate=0.5 + 5 s buffer.
    final int timeoutMs = (wordCount * 600).clamp(8000, 120000);
    Future.delayed(Duration(milliseconds: timeoutMs), () {
      if (!completer.isCompleted) {
        debugPrint(
            '⏱️ [TTSService] speakChunk timeout ($timeoutMs ms) — unblocking completer');
        completer.complete(wordCount);
        _restoreDefaultHandlers();
        _pendingChunkCompleter = null;
      }
    });

    // Return the future that completes when TTS finishes (or when stop() unblocks it)
    return completer.future;
  }

  /// Restore the default TTS event handlers (completion, cancel, error).
  /// Called after speakChunk completes or stop() is called to ensure
  /// subsequent speak() calls work correctly without stale handlers.
  void _restoreDefaultHandlers() {
    _tts.setCompletionHandler(() {
      isSpeaking.value = false;
      _resetProgress();
      _endOrbThinking();
    });
    _tts.setCancelHandler(() {
      isSpeaking.value = false;
      _resetProgress();
      _endOrbThinking();
    });
    _tts.setErrorHandler((msg) {
      debugPrint('TTS Error: $msg');
      isSpeaking.value = false;
      _resetProgress();
      _endOrbThinking();
    });
    debugPrint('🔄 [TTSService] Default handlers restored');
  }

  /// Stop speaking
  Future<void> stop() async {
    debugPrint('🔇 [TTSService] stop() called');

    // Immediately set isSpeaking to false for instant UI feedback
    isSpeaking.value = false;

    // Unblock any pending speakChunk completer so TtsChunkController.playAll()
    // can detect cancellation and exit cleanly
    final pending = _pendingChunkCompleter;
    if (pending != null && !pending.isCompleted) {
      pending.complete(0); // Complete with 0 words (cancelled chunk)
      _pendingChunkCompleter = null;
    }

    try {
      await _tts.stop();
      debugPrint('✅ [TTSService] TTS engine stopped successfully');
    } catch (e) {
      debugPrint('⚠️ [TTSService] Error stopping TTS engine: $e');
    }

    // Reset progress tracking
    _resetProgress();

    // Restore default handlers so subsequent speak() calls work correctly
    _restoreDefaultHandlers();
  }

  /// Pause speaking (if supported)
  Future<void> pause() async {
    // Note: flutter_tts doesn't support true pause, only stop
    await stop();
  }

  /// 🔹 TEXT CLEANING METHODS

  /// Clean text for TTS - remove markdown, emojis, special chars
  String _cleanText(String text) {
    String cleanText = text;

    // Remove markdown
    cleanText = cleanText.replaceAll(RegExp(r'\*\*'), ''); // Bold
    cleanText = cleanText.replaceAll(RegExp(r'\*'), ''); // Italic
    cleanText = cleanText.replaceAll(RegExp(r'__'), ''); // Underline
    cleanText = cleanText.replaceAll(RegExp(r'`'), ''); // Code
    cleanText = cleanText.replaceAll(RegExp(r'#+ '), ''); // Headers
    cleanText =
        cleanText.replaceAll(RegExp(r'^- ', multiLine: true), ''); // Bullets
    cleanText = cleanText.replaceAll(
        RegExp(r'^\d+\. ', multiLine: true), ''); // Numbers

    // Remove emojis
    cleanText = cleanText.replaceAll(
        RegExp(r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
            unicode: true),
        '');

    // Remove excessive special characters but keep punctuation
    cleanText = cleanText.replaceAll(RegExp(r'[!@#$%^&*()_+=\[\]{}|\\<>]'), '');

    // Clean up spaces
    cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ');

    return cleanText.trim();
  }

  /// 🔹 HINDI TTS NORMALIZATION ENGINE
  /// Rewrites Hindi/Hinglish text for correct TTS pronunciation
  String _normalizeHindiForTTS(String text) {
    // Skip for non-Hindi voices
    final String voiceName = selectedVoice.value?['name'] ?? '';
    if (!voiceName.toLowerCase().contains('hindi') &&
        !voiceName.toLowerCase().contains('hinglish')) {
      return text;
    }

    String result = text;

    // RULE 1: Critical Hindi words that need exact transformations
    final Map<String, String> criticalWords = {
      'main': 'mai',
      'hain': 'hai',
      'kahin': 'kaheen',
      'tumhein': 'tumhe',
      'rahein': 'rahe',
      'chahein': 'chahe',
      'jayein': 'jaye',
      'aayein': 'aaye',
    };

    // Apply critical word transformations
    criticalWords.forEach((hindiWord, replacement) {
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
        if (criticalWords.keys
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

    // RULE 5: Nasal sound handling (un/oon/uun → oo or o)
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
        final String fullWord = '$word${match.group(2)!}';
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

    return result.trim();
  }

  /// 🔹 FIX SPELLED-OUT NAMES
  /// Converts "S H O U R A V" to "SHOURAV"
  /// Also handles full names - ensures they're spoken as phrases, not spelled
  String _fixSpelledOutNames(String text) {
    String result = text;

    // First, detect and preserve full names (like "Shourav Kumar")
    // to prevent letter-by-letter spelling in English
    // Match patterns like "First Last" where both start with capital letters
    final namePattern = RegExp(r'\b([A-Z][a-z]+)\s+([A-Z][a-z]+)\b');
    final nameMatches = namePattern.allMatches(result);

    final Map<String, String> namePlaceholders = {};
    int placeholderIndex = 0;
    for (final match in nameMatches) {
      final fullName = match.group(0)!;
      final placeholder = '___NAME${placeholderIndex}___';
      namePlaceholders[placeholder] = fullName;
      result = result.replaceAll(fullName, placeholder);
      placeholderIndex++;
    }

    final Map<String, String> commonNames = {
      'S H O U R A V': 'Shourav',
      'S-H-O-U-R-A-V': 'Shourav',
      's h o u r a v': 'Shourav',
      's-h-o-u-r-a-v': 'Shourav',
      'SHOURAV': 'Shourav',
      'K U M A R': 'Kumar',
      'K-U-M-A-R': 'Kumar',
      'KUMAR': 'Kumar',
      'S I N G H': 'Singh',
      'S-I-N-G-H': 'Singh',
      'SINGH': 'Singh',
      'S H A R M A': 'Sharma',
      'S-H-A-R-M-A': 'Sharma',
      'SHARMA': 'Sharma',
      'P A T E L': 'Patel',
      'P-A-T-E-L': 'Patel',
      'PATEL': 'Patel',
      'G U P T A': 'Gupta',
      'G-U-P-T-A': 'Gupta',
      'GUPTA': 'Gupta',
      'V E R M A': 'Verma',
      'V-E-R-M-A': 'Verma',
      'VERMA': 'Verma',
      'M I S H R A': 'Mishra',
      'M-I-S-H-R-A': 'Mishra',
      'MISHRA': 'Mishra',
      'C T J': 'CTJ',
      'C-T-J': 'CTJ',
    };

    commonNames.forEach((spelled, complete) {
      // Use RegExp with word boundaries to avoid replacing parts of other words
      result = result.replaceAll(
          RegExp(r'\b' + RegExp.escape(spelled) + r'\b'), complete);
    });

    // Restore full names
    namePlaceholders.forEach((placeholder, fullName) {
      result = result.replaceAll(placeholder, fullName);
    });

    // Fallback regex to condense words that are spelled out with hyphens (e.g. "S-H-O-U-R")
    final hyphenSpellingPattern = RegExp(r'\b([A-Za-z])(?:-([A-Za-z]))+\b');
    result = result.replaceAllMapped(hyphenSpellingPattern, (match) {
      final String condensed = match.group(0)!.replaceAll('-', '');
      if (condensed.length > 2) {
        return condensed[0].toUpperCase() +
            condensed.substring(1).toLowerCase();
      }
      return match.group(0)!;
    });

    // Fallback regex condense words spelled with spaces (must be at least 3 letters)
    final spaceSpellingPattern = RegExp(r'\b([A-Za-z])(?:\s+([A-Za-z])){2,}\b');
    result = result.replaceAllMapped(spaceSpellingPattern, (match) {
      final String condensed = match.group(0)!.replaceAll(RegExp(r'\s+'), '');
      return condensed[0].toUpperCase() + condensed.substring(1).toLowerCase();
    });

    return result;
  }

  /// Ensure natural name pronunciation
  /// Prevents letter-by-letter spelling of names in English TTS
  /// Uses ZERO-WIDTH spaces to signal to TTS engine that this is a single phrase
  String _ensureNaturalNamePronunciation(String text) {
    String result = text;

    // Common Indian name patterns - wrap with control sequences for natural pronunciation
    // Using Unicode character U+200B (zero-width space) which tells TTS engines
    // to treat the name as a single phonetic unit, not letter-by-letter
    final namePatterns = {
      RegExp(r'\bShourav\b', caseSensitive: false): 'Shourav',
      RegExp(r'\bKumar\b', caseSensitive: false): 'Kumar',
      RegExp(r'\bSingh\b', caseSensitive: false): 'Singh',
      RegExp(r'\bSharma\b', caseSensitive: false): 'Sharma',
      RegExp(r'\bPatel\b', caseSensitive: false): 'Patel',
      RegExp(r'\bGupta\b', caseSensitive: false): 'Gupta',
      RegExp(r'\bVerma\b', caseSensitive: false): 'Verma',
      RegExp(r'\bMishra\b', caseSensitive: false): 'Mishra',
      RegExp(r'\bAmit\b', caseSensitive: false): 'Amit',
      RegExp(r'\bRajesh\b', caseSensitive: false): 'Rajesh',
      RegExp(r'\bPriya\b', caseSensitive: false): 'Priya',
      RegExp(r'\bAnkit\b', caseSensitive: false): 'Ankit',
      RegExp(r'\bDeepak\b', caseSensitive: false): 'Deepak',
      RegExp(r'\bRahul\b', caseSensitive: false): 'Rahul',
      RegExp(r'\bSanjay\b', caseSensitive: false): 'Sanjay',
      RegExp(r'\bRavi\b', caseSensitive: false): 'Ravi',
      RegExp(r'\bPawan\b', caseSensitive: false): 'Pawan',
      RegExp(r'\bVikram\b', caseSensitive: false): 'Vikram',
      RegExp(r'\bAmar\b', caseSensitive: false): 'Amar',
    };

    // Replace each name pattern with zero-width space protected version
    // This prevents TTS from spelling out the name letter by letter
    namePatterns.forEach((pattern, replacement) {
      // Use ZERO-WIDTH SPACE (U+200B) as marker
      const zwsp = '\u200B'; // Zero-width space character
      result = result.replaceAllMapped(pattern, (match) {
        // Wrap name to prevent letter-by-letter reading
        // Adding zero-width spaces strategically helps TTS treat it as one word
        return '$zwsp$replacement$zwsp';
      });
    });

    // Remove any remaining single-letter patterns that might cause spelling
    // Pattern: "X Y" where X and Y are single capital letters (like "S K")
    result = result.replaceAllMapped(
      RegExp(r'\b([A-Z])\s+([A-Z])\b'),
      (match) => '${match.group(1)}${match.group(2)}',
    );

    // Also handle hyphenated single letters: "S-K" -> "SK"
    result = result.replaceAllMapped(
      RegExp(r'\b([A-Z])-([A-Z])\b'),
      (match) => '${match.group(1)}${match.group(2)}',
    );

    return result;
  }

  /// 🔹 DETECT SPEAKING MODE
  /// Story mode for long/narrative content, utility for short/factual
  SpeakingMode _detectSpeakingMode(String text) {
    // Check text length
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

    return SpeakingMode.utility;
  }

  /// 🔹 APPLY SPEAKING MODE
  /// Adds strategic pauses for story mode
  String _applySpeakingMode(String text) {
    if (speakingMode.value == SpeakingMode.story) {
      String processed = text;

      // Add pauses after sentences
      processed = processed.replaceAll('. ', '.,, ');

      // Add longer pauses after ellipses
      processed = processed.replaceAll('... ', '...,,, ');

      return processed;
    }
    return text;
  }

  /// Trigger orb thinking system when TTS starts
  void _triggerOrbThinking() {
    try {
      final orbController = Get.find<OrbThinkingController>();
      // Get the current text being spoken and trigger smart avatar detection
      final currentText = _currentTtsWords.join(' ');
      if (currentText.isNotEmpty) {
        orbController.onSentenceSpoken(currentText);
      }
    } catch (e) {
      debugPrint('⚠️ Orb thinking trigger error: $e');
    }
  }

  /// End orb thinking when TTS completes or stops
  void _endOrbThinking() {
    try {
      final orbController = Get.find<OrbThinkingController>();
      orbController.onSpeechEnd();
    } catch (e) {
      debugPrint('⚠️ Orb thinking end error: $e');
    }
  }

  /// Get language name
  String getLanguageName(TTSLanguage lang) {
    switch (lang) {
      case TTSLanguage.english:
        return 'English';
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
