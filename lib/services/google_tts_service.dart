import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

/// Google Cloud Text-to-Speech Service
///
/// Provides native support for all Indian languages with proper pronunciation:
/// - Bengali (bn-IN)
/// - Tamil (ta-IN)
/// - Telugu (te-IN)
/// - Kannada (kn-IN)
/// - Malayalam (ml-IN)
/// - Gujarati (gu-IN)
/// - Marathi (mr-IN)
/// - Punjabi (pa-IN)
/// - Odia (or-IN)
/// - Assamese (as-IN)
/// - Maithili (mai-IN)
/// - Sanskrit (sa-IN)
/// - Urdu (ur-PK)
/// - Nepali (ne-NP)
/// - Sinhala (si-LK)
/// - Kashmiri (ks-IN)
/// - Hindi (hi-IN)
/// - English (en-US, en-GB, en-IN)
class GoogleTtsService extends GetxService {
  // Google Cloud Text-to-Speech API endpoint
  static const String _apiEndpoint =
      'https://texttospeech.googleapis.com/v1/text:synthesize';

  // API Key - should be loaded from secure storage or environment
  String? _apiKey;

  // Audio player for playback
  AudioPlayer? _audioPlayer;

  // Observable states
  final isSpeaking = false.obs;
  final isInitialized = false.obs;
  final currentLanguageCode = 'hi-IN'.obs; // Default to Hindi

  // Language to voice mapping with gender preference
  static const Map<String, Map<String, dynamic>> languageVoices = {
    'en-US': {
      'voices': [
        'en-US-Neural2-A',
        'en-US-Neural2-C',
        'en-US-Neural2-E',
        'en-US-Neural2-F'
      ],
      'preferred': 'en-US-Neural2-C', // Neutral
    },
    'en-GB': {
      'voices': [
        'en-GB-Neural2-A',
        'en-GB-Neural2-B',
        'en-GB-Neural2-C',
        'en-GB-Neural2-D'
      ],
      'preferred': 'en-GB-Neural2-A',
    },
    'en-IN': {
      'voices': ['en-IN-Neural2-A', 'en-IN-Neural2-B'],
      'preferred': 'en-IN-Neural2-A',
    },
    'hi-IN': {
      'voices': ['hi-IN-Neural2-A', 'hi-IN-Neural2-B', 'hi-IN-Neural2-C'],
      'preferred': 'hi-IN-Neural2-A', // Female voice for Hindi
    },
    'bn-IN': {
      // Bengali
      'voices': ['bn-IN-Standard-A', 'bn-IN-Standard-B'],
      'preferred': 'bn-IN-Standard-A',
    },
    'ta-IN': {
      // Tamil
      'voices': ['ta-IN-Standard-A', 'ta-IN-Standard-B'],
      'preferred': 'ta-IN-Standard-A',
    },
    'te-IN': {
      // Telugu
      'voices': ['te-IN-Standard-A', 'te-IN-Standard-B'],
      'preferred': 'te-IN-Standard-A',
    },
    'kn-IN': {
      // Kannada
      'voices': ['kn-IN-Standard-A', 'kn-IN-Standard-B'],
      'preferred': 'kn-IN-Standard-A',
    },
    'ml-IN': {
      // Malayalam
      'voices': ['ml-IN-Standard-A', 'ml-IN-Standard-B'],
      'preferred': 'ml-IN-Standard-A',
    },
    'gu-IN': {
      // Gujarati
      'voices': ['gu-IN-Standard-A', 'gu-IN-Standard-B'],
      'preferred': 'gu-IN-Standard-A',
    },
    'mr-IN': {
      // Marathi
      'voices': ['mr-IN-Standard-A', 'mr-IN-Standard-B'],
      'preferred': 'mr-IN-Standard-A',
    },
    'pa-IN': {
      // Punjabi
      'voices': ['pa-IN-Standard-A', 'pa-IN-Standard-B'],
      'preferred': 'pa-IN-Standard-A',
    },
    'or-IN': {
      // Odia
      'voices': ['or-IN-Standard-A', 'or-IN-Standard-B'],
      'preferred': 'or-IN-Standard-A',
    },
    'as-IN': {
      // Assamese
      'voices': ['as-IN-Standard-A', 'as-IN-Standard-B'],
      'preferred': 'as-IN-Standard-A',
    },
    'mai-IN': {
      // Maithili (Google TTS doesn't have a native identifier, but since it shares the Devanagari
      // script with Hindi, the Hindi engine perfectly synthesizes Maithili phonetics)
      'voices': ['hi-IN-Neural2-A', 'hi-IN-Neural2-B'],
      'preferred': 'hi-IN-Neural2-A',
    },
    'sa-IN': {
      // Sanskrit
      'voices': ['sa-IN-Standard-A'],
      'preferred': 'sa-IN-Standard-A',
    },
    'ur-PK': {
      // Urdu
      'voices': ['ur-PK-Standard-A', 'ur-PK-Standard-B'],
      'preferred': 'ur-PK-Standard-A',
    },
    'ne-NP': {
      // Nepali
      'voices': ['ne-NP-Standard-A', 'ne-NP-Standard-B'],
      'preferred': 'ne-NP-Standard-A',
    },
    'si-LK': {
      // Sinhala
      'voices': ['si-LK-Standard-A', 'si-LK-Standard-B'],
      'preferred': 'si-LK-Standard-A',
    },
    'ks-IN': {
      // Kashmiri
      'voices': ['ks-IN-Standard-A'],
      'preferred': 'ks-IN-Standard-A',
    },
  };

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initialize();
  }

  /// Initialize the Google TTS service
  Future<void> _initialize() async {
    try {
      // Load API key from environment or secure storage
      _apiKey = _getApiKey();

      if (_apiKey == null || _apiKey!.isEmpty) {
        debugPrint('⚠️ GoogleTtsService: API key not configured');
        isInitialized.value = false;
        return;
      }

      _audioPlayer = AudioPlayer();
      isInitialized.value = true;
      debugPrint('✅ GoogleTtsService initialized');
    } catch (e) {
      debugPrint('❌ GoogleTtsService initialization error: $e');
      isInitialized.value = false;
    }
  }

  /// Get API key from environment variables or secure storage
  String? _getApiKey() {
    // Try environment variable first
    final envKey = Platform.environment['GOOGLE_TTS_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }

    // TODO: Load from secure storage (e.g., flutter_secure_storage)
    // For now, this should be configured during app startup
    return null;
  }

  /// Set API key programmatically
  void setApiKey(String apiKey) {
    _apiKey = apiKey;
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      isInitialized.value = true;
    }
  }

  /// Set the language for TTS
  void setLanguage(String languageCode) {
    if (languageVoices.containsKey(languageCode)) {
      currentLanguageCode.value = languageCode;
      debugPrint('🌐 GoogleTtsService: Language set to $languageCode');
    } else {
      debugPrint('⚠️ GoogleTtsService: Language $languageCode not supported');
    }
  }

  /// Speak text using Google Cloud TTS
  Future<void> speak(String text, {String? languageCode}) async {
    if (!isInitialized.value || _apiKey == null) {
      debugPrint('❌ GoogleTtsService not initialized or API key missing');
      return;
    }

    if (text.isEmpty) {
      return;
    }

    try {
      // Stop any ongoing playback
      await stop();

      isSpeaking.value = true;

      // Use provided language or current default
      final lang = languageCode ?? currentLanguageCode.value;

      // Get voice for this language
      final voiceConfig = languageVoices[lang];
      if (voiceConfig == null) {
        debugPrint('❌ GoogleTtsService: Unsupported language $lang');
        isSpeaking.value = false;
        return;
      }

      final voiceName = voiceConfig['preferred'] as String;

      // Synthesize speech
      final audioContent = await _synthesize(text, lang, voiceName);
      if (audioContent.isEmpty) {
        debugPrint('❌ GoogleTtsService: Failed to synthesize audio');
        isSpeaking.value = false;
        return;
      }

      // Save audio to temporary file and play
      final audioFile = await _saveAudioFile(audioContent);
      await _audioPlayer?.setFilePath(audioFile);
      await _audioPlayer?.play();

      // Wait for playback to complete
      if (_audioPlayer != null) {
        // Create a completer to wait for playback completion
        final completer = Completer<void>();

        // Use duration of audio to estimate playback time
        final duration = _audioPlayer!.duration;
        if (duration != null && duration > Duration.zero) {
          Future.delayed(duration, () {
            if (!completer.isCompleted) {
              completer.complete();
            }
          });
        }

        await completer.future.timeout(
          const Duration(minutes: 5),
          onTimeout: () => debugPrint('GoogleTtsService: Playback timeout'),
        );
      }
    } catch (e) {
      debugPrint('❌ GoogleTtsService.speak error: $e');
    } finally {
      isSpeaking.value = false;
    }
  }

  /// Synthesize text using Google Cloud TTS API
  Future<String> _synthesize(
      String text, String languageCode, String voiceName) async {
    try {
      final request = {
        'input': {'text': text},
        'voice': {
          'languageCode': languageCode,
          'name': voiceName,
        },
        'audioConfig': {
          'audioEncoding': 'MP3',
          'pitch': 0.0,
          'speakingRate': 0.75, // Comfortable 1× pace (was 1.0)
        },
      };

      final response = await http.post(
        Uri.parse('$_apiEndpoint?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['audioContent'] ?? '';
      } else {
        debugPrint(
            '❌ Google TTS API error: ${response.statusCode} - ${response.body}');
        return '';
      }
    } catch (e) {
      debugPrint('❌ GoogleTtsService._synthesize error: $e');
      return '';
    }
  }

  /// Save base64 audio content to a temporary file
  Future<String> _saveAudioFile(String base64Audio) async {
    try {
      final decodedBytes = base64Decode(base64Audio);
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final audioFile = File('${tempDir.path}/google_tts_$timestamp.mp3');

      await audioFile.writeAsBytes(decodedBytes);
      return audioFile.path;
    } catch (e) {
      debugPrint('❌ GoogleTtsService._saveAudioFile error: $e');
      throw Exception('Failed to save audio file: $e');
    }
  }

  /// Stop current playback
  Future<void> stop() async {
    try {
      await _audioPlayer?.stop();
      isSpeaking.value = false;
    } catch (e) {
      debugPrint('❌ GoogleTtsService.stop error: $e');
    }
  }

  /// Pause current playback
  Future<void> pause() async {
    try {
      await _audioPlayer?.pause();
    } catch (e) {
      debugPrint('❌ GoogleTtsService.pause error: $e');
    }
  }

  /// Resume playback
  Future<void> resume() async {
    try {
      await _audioPlayer?.play();
    } catch (e) {
      debugPrint('❌ GoogleTtsService.resume error: $e');
    }
  }

  @override
  void onClose() {
    _audioPlayer?.dispose();
    super.onClose();
  }
}
