import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'supabase_service.dart';

// ignore_for_file: constant_identifier_names

class ApiKeysConfig {
  static const _storage = FlutterSecureStorage();

  // Storage Keys
  static const String _groqKeysKey = 'SEC_GROQ_KEYS';
  static const String _nvidiaKeysKey = 'SEC_NVIDIA_KEYS';
  static const String _mistralKeyKey = 'SEC_MISTRAL_KEY';
  static const String _openRouterKeysKey = 'SEC_OPENROUTER_KEYS';
  static const String _geminiKeyKey = 'SEC_GEMINI_KEY';

  /// Ensure we init these before use!
  static List<String> groqApiKeys = [];
  static List<String> nvidiaAuthTokens = [];
  static String mistralApiKey = '';
  static String geminiApiKey = '';
  static Map<String, OpenRouterModelConfig> openRouterModels = {};

  static const String groqBaseUrl = 'https://api.groq.com/openai/v1';
  static const String groqModel = 'llama-3.1-8b-instant';

  static const String nvidiaBaseUrl =
      'https://integrate.api.nvidia.com/v1/chat/completions';
  static const String nvidiaModel = 'minimaxai/minimax-m2.5';

  static const String githubBaseUrl =
      'https://models.inference.ai.azure.com/chat/completions';
  static const String githubModel = 'gpt-4o-mini';

  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';

  static const String mistralBaseUrl = 'https://api.mistral.ai/v1';
  static const String mistralModel = 'mistral-small';

  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  /// **SEC-01 Setup:**
  /// API keys are now moved to Supabase for security.
  /// Hardcoded fallbacks have been removed to prevent leak in version control.
  static final List<String> _encodedGroq = [];

  static final List<String> _encodedNvidia = [];

  static const String _encodedMistral = '';

  static const String _encodedGemini = '';

  static final Map<String, List<String>> _encodedOpenRouter = {
    'nvidia-nemotron-3-super': [
      'nvidia/nemotron-3-super-120b-a12b',
      'NVIDIA Nemotron 3 Super',
      '', // Key moved to Supabase
      'General Purpose'
    ],
    'z-ai-glm-4.5-air': [
      'z-ai/glm-4.5-air',
      'GLM 4.5 Air',
      '', // Key moved to Supabase
      'Translation & Transcription'
    ],
    'openai-gpt-oss-120b': [
      'openai/gpt-oss-120b',
      'GPT OSS 120B',
      '', // Key moved to Supabase
      'Technology & AI'
    ],
    'minimax-m2.5': [
      'minimax/minimax-m2.5',
      'Minimax M2.5',
      '', // Key moved to Supabase
      'Coding & Complex Reasoning'
    ],
    'google-gemma-4-31b': [
      'google/gemma-4-31b-it',
      'Gemma 4 31B',
      '', // Key moved to Supabase
      'Songs & Music'
    ]
  };

  /// Initialize API keys — fetches from Supabase as primary source,
  /// falls back to embedded encoded source only if offline/error.
  static Future<void> init() async {
    try {
      final supabase = SupabaseService();

      // 1. Fetch Groq Keys
      final groqFromSupabase = await supabase
          .fetchSecretList('GROQ_KEYS')
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (groqFromSupabase != null && groqFromSupabase.isNotEmpty) {
        groqApiKeys = groqFromSupabase.map((e) => e.toString()).toList();
        debugPrint('✅ [ApiKeysConfig] Groq keys loaded from Supabase');
      } else {
        groqApiKeys =
            _encodedGroq.map((e) => utf8.decode(base64Decode(e))).toList();
        debugPrint(
            '⚠️ [ApiKeysConfig] Groq fallback used (network timeout or empty)');
      }
      await _storage.write(key: _groqKeysKey, value: jsonEncode(groqApiKeys));

      // 2. Fetch NVIDIA Tokens
      final nvidiaFromSupabase = await supabase
          .fetchSecretList('NVIDIA_KEYS')
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (nvidiaFromSupabase != null && nvidiaFromSupabase.isNotEmpty) {
        nvidiaAuthTokens = nvidiaFromSupabase.map((e) => e.toString()).toList();
        debugPrint('✅ [ApiKeysConfig] NVIDIA tokens loaded from Supabase');
      } else {
        nvidiaAuthTokens =
            _encodedNvidia.map((e) => utf8.decode(base64Decode(e))).toList();
        debugPrint(
            '⚠️ [ApiKeysConfig] NVIDIA fallback used (network timeout or empty)');
      }
      await _storage.write(
          key: _nvidiaKeysKey, value: jsonEncode(nvidiaAuthTokens));

      // 3. Fetch Mistral Key
      final mistralFromSupabase = await supabase
          .fetchSecretString('MISTRAL_KEY')
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (mistralFromSupabase != null) {
        mistralApiKey = mistralFromSupabase;
        debugPrint('✅ [ApiKeysConfig] Mistral key loaded from Supabase');
      } else {
        mistralApiKey = utf8.decode(base64Decode(_encodedMistral));
        debugPrint('⚠️ [ApiKeysConfig] Mistral fallback used');
      }
      await _storage.write(key: _mistralKeyKey, value: mistralApiKey);

      // 4. Fetch Gemini Key
      final geminiFromSupabase = await supabase
          .fetchSecretString('GEMINI_KEY')
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (geminiFromSupabase != null) {
        geminiApiKey = geminiFromSupabase;
        debugPrint('✅ [ApiKeysConfig] Gemini key loaded from Supabase');
      } else {
        geminiApiKey = utf8.decode(base64Decode(_encodedGemini));
        debugPrint('⚠️ [ApiKeysConfig] Gemini fallback used');
      }
      await _storage.write(key: _geminiKeyKey, value: geminiApiKey);

      // 5. Fetch OpenRouter Models
      final orFromSupabase = await supabase
          .fetchSecrets('OPENROUTER_KEYS')
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (orFromSupabase != null) {
        openRouterModels = {};
        orFromSupabase.forEach((key, val) {
          // OpenRouter keys are just strings in our Supabase table
          // but we need to map them back to the full config structure.
          // We'll use the IDs from our local map but the keys from Supabase.
          final localConfig = _encodedOpenRouter[key];
          if (localConfig != null) {
            openRouterModels[key] = OpenRouterModelConfig(
              modelId: localConfig[0],
              displayName: localConfig[1],
              apiKey: val.toString(),
              category: localConfig[3],
            );
          }
        });
        debugPrint('✅ [ApiKeysConfig] OpenRouter keys loaded from Supabase');
      } else {
        openRouterModels = {};
        _encodedOpenRouter.forEach((key, val) {
          openRouterModels[key] = OpenRouterModelConfig(
            modelId: val[0],
            displayName: val[1],
            apiKey: utf8.decode(base64Decode(val[2])),
            category: val[3],
          );
        });
        debugPrint(
            '⚠️ [ApiKeysConfig] OpenRouter fallback used (local encoded)');
      }
      await _storage.write(
          key: _openRouterKeysKey,
          value: jsonEncode(
              openRouterModels.map((k, v) => MapEntry(k, v.toJson()))));

      debugPrint('✅ [ApiKeysConfig] API keys sync complete');
    } catch (e) {
      debugPrint('❌ [ApiKeysConfig] Critical error sync keys: $e');
      // Final attempt to load at least local defaults if everything failed
      await _loadLocalDefaults();
    }
  }

  static Future<void> _loadLocalDefaults() async {
    groqApiKeys =
        _encodedGroq.map((e) => utf8.decode(base64Decode(e))).toList();
    nvidiaAuthTokens =
        _encodedNvidia.map((e) => utf8.decode(base64Decode(e))).toList();
    mistralApiKey = utf8.decode(base64Decode(_encodedMistral));
    geminiApiKey = utf8.decode(base64Decode(_encodedGemini));
    _encodedOpenRouter.forEach((key, val) {
      openRouterModels[key] = OpenRouterModelConfig(
        modelId: val[0],
        displayName: val[1],
        apiKey: utf8.decode(base64Decode(val[2])),
        category: val[3],
      );
    });
  }

  // ═══════════════════════════════════════════════════════════
  // HELPER: Get random API key for round-robin load balancing
  // ═══════════════════════════════════════════════════════════
  static String getRandomGroqKey() {
    if (groqApiKeys.isEmpty) throw Exception('No Groq API keys configured');
    final random =
        groqApiKeys[(DateTime.now().millisecond) % groqApiKeys.length];
    return random;
  }

  static String getRandomNvidiaToken() {
    if (nvidiaAuthTokens.isEmpty) {
      throw Exception('No NVIDIA tokens configured');
    }
    final random = nvidiaAuthTokens[
        (DateTime.now().millisecond) % nvidiaAuthTokens.length];
    return random;
  }
}

/// ═══════════════════════════════════════════════════════════
/// OpenRouter Model Configuration
/// ═══════════════════════════════════════════════════════════
class OpenRouterModelConfig {
  final String modelId;
  final String displayName;
  final String apiKey;
  final String category;

  const OpenRouterModelConfig({
    required this.modelId,
    required this.displayName,
    required this.apiKey,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'modelId': modelId,
        'displayName': displayName,
        'apiKey': apiKey,
        'category': category,
      };

  factory OpenRouterModelConfig.fromJson(Map<String, dynamic> json) =>
      OpenRouterModelConfig(
        modelId: json['modelId'],
        displayName: json['displayName'],
        apiKey: json['apiKey'],
        category: json['category'],
      );
}
