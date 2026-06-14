// lib/config/app_config.dart
import 'dart:io';

/// Application configuration constants
class AppConfig {
  // ─────────────────────────────────────────────────────────────────────────
  // Google Cloud TTS API Configuration
  // ─────────────────────────────────────────────────────────────────────────

  /// Google Cloud Text-to-Speech API Key
  ///
  /// Get your free API key:
  /// 1. Go to https://console.cloud.google.com/
  /// 2. Create new project "VoiceAssistantApp"
  /// 3. Enable "Cloud Text-to-Speech API"
  /// 4. Go to Credentials → Create API Key
  /// 5. Copy the key and paste here
  ///
  /// ⚠️ SECURITY: Never commit API keys to GitHub!
  /// Use environment variables instead:
  /// - For development: Set in .env file (ignored by git)
  /// - For production: Use Google Secret Manager
  static const String googleTtsApiKey = String.fromEnvironment(
    'GOOGLE_TTS_API_KEY',
    defaultValue: '', // Leave empty, provide via environment
  );

  /// Alternative: Load from environment variable at runtime
  static String? getGoogleTtsApiKey() {
    return Platform.environment['GOOGLE_TTS_API_KEY'];
  }

  /// Check if Google TTS is properly configured
  static bool isGoogleTtsConfigured() {
    final key =
        googleTtsApiKey.isNotEmpty ? googleTtsApiKey : getGoogleTtsApiKey();
    return key != null && key.isNotEmpty;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Feature Flags
  // ─────────────────────────────────────────────────────────────────────────

  /// Enable Google TTS for Indian languages
  static const bool enableGoogleTtsForIndianLanguages = true;

  /// Enable offline TTS (Sherpa/eSpeak) as fallback
  static const bool enableOfflineTtsFallback = true;

  /// Cache TTS responses to reduce API calls
  static const bool enableTtsCaching = true;

  /// Maximum cache size in MB
  static const int maxTtsCacheSize = 50;

  // ─────────────────────────────────────────────────────────────────────────
  // TTS Behavior
  // ─────────────────────────────────────────────────────────────────────────

  /// Default speech rate (0.5 to 2.0, where 1.0 is normal)
  static const double defaultSpeechRate = 1.0;

  /// Default pitch adjustment (0.0 to 20.0)
  static const double defaultPitch = 0.0;

  /// Preferred TTS engine priority
  /// 1. GoogleTts (if configured and initialized)
  /// 2. Sherpa/eSpeak (if models downloaded)
  /// 3. flutter_tts (system TTS)
  static const List<String> ttsPriority = [
    'google',
    'sherpa',
    'flutter_tts',
  ];
}
