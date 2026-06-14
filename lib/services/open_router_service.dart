/// ═══════════════════════════════════════════════════════════════
/// OpenRouter Service — Multi-provider API gateway
/// ═══════════════════════════════════════════════════════════════
/// Routes API calls to: Groq, NVIDIA, OpenRouter.
/// Each provider has its own request format.
///
/// INTELLIGENT FALLBACK ALGORITHM:
///   1. Try primary model (1 attempt only — fail fast)
///   2. Silently switch to next provider in fallback chain
///   3. Exhaust up to [maxTotalAttempts] across all providers
///   4. If ALL providers fail → return null (caller shows user message)
///
/// The user NEVER sees an error message from a single model failure.
/// Fallbacks happen transparently in the background.
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'ai_model_manager.dart';

class OpenRouterService extends GetxService {
  final isProcessing = false.obs;

  /// Convenience getter — returns the currently active model route.
  ModelRoute get defaultRoute {
    try {
      final manager = Get.find<AIModelManager>();
      return manager.routeQuery('');
    } catch (_) {
      throw StateError(
          '[OpenRouterService] AIModelManager not available for defaultRoute');
    }
  }

  /// Generate a response from the routed model.
  ///
  /// ALGORITHM — Zero-fallback-visible strategy:
  ///   • Try primary route (1 attempt)
  ///   • On failure: silently blacklist + try next provider
  ///   • Exhausts up to [maxTotalAttempts] (default = ALL available providers)
  ///   • If all fail → returns null → caller shows exactly ONE user message
  Future<String?> generateResponse({
    required ModelRoute route,
    required String systemPrompt,
    required String userMessage,
    List<Map<String, String>>? history,
    String? realTimeContext,
  }) async {
    isProcessing.value = true;

    try {
      // Build full system prompt with optional real-time context
      String fullSystemPrompt = systemPrompt;
      if (realTimeContext != null && realTimeContext.isNotEmpty) {
        fullSystemPrompt += '''

REAL-TIME DATA (from Google Search — use this to answer accurately):
$realTimeContext

IMPORTANT: Base your answer on this real-time data. Cite the source when possible.
''';
      }

      final aiManager = Get.find<AIModelManager>();

      // Build exhaustive provider rotation list starting from the primary route
      final trialProviders = _buildExhaustiveProviderList(route, aiManager);

      debugPrint(
          '🔄 [OpenRouterService] Starting ${trialProviders.length}-provider trial chain for "${userMessage.substring(0, userMessage.length.clamp(0, 40))}..."');

      for (int i = 0; i < trialProviders.length; i++) {
        final currentRoute = trialProviders[i];

        // Skip if this provider was already blacklisted before we started
        if (aiManager.isBlacklisted(currentRoute.provider) && i > 0) {
          debugPrint(
              '⏭️ [OpenRouterService] Skipping blacklisted ${currentRoute.displayName}');
          continue;
        }

        debugPrint(
            '🤖 [OpenRouterService] Attempt ${i + 1}/${trialProviders.length}: ${currentRoute.displayName}');

        // Update UI to show the model being tried
        try {
          aiManager.activeModelName.value = currentRoute.displayName;
        } catch (_) {}

        String? response;
        try {
          response = await makeProviderRequest(
            route: currentRoute,
            systemPrompt: fullSystemPrompt,
            userMessage: userMessage,
            history: history,
          );
        } catch (providerErr) {
          // Per-provider exception (e.g. 429 rethrow) — blacklist and move on
          debugPrint(
              '⚠️ [OpenRouterService] ${currentRoute.displayName} threw: $providerErr — switching to next...');
          try {
            aiManager.blacklistProvider(currentRoute.provider);
          } catch (_) {}
          await Future.delayed(const Duration(milliseconds: 200));
          continue;
        }

        if (response != null && response.isNotEmpty) {
          // ✅ SUCCESS — report and return
          try {
            aiManager.reportSuccess(currentRoute.provider);
          } catch (_) {}
          debugPrint(
              '✅ [OpenRouterService] Response received from ${currentRoute.displayName}');
          return response;
        }

        // ❌ NULL response — blacklist and move on silently
        debugPrint(
            '⚠️ [OpenRouterService] ${currentRoute.displayName} returned null, switching to next...');
        try {
          aiManager.blacklistProvider(currentRoute.provider);
        } catch (_) {}

        // Small delay before next attempt to avoid hammering
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // All providers exhausted — return null so caller shows one friendly message
      debugPrint(
          '🚨 [OpenRouterService] All ${trialProviders.length} providers exhausted. Returning null.');
      return null;
    } catch (e) {
      debugPrint('❌ OpenRouterService Error: $e');
      return null;
    } finally {
      isProcessing.value = false;
    }
  }

  /// Build an exhaustive, ordered list of providers to try.
  /// Order: primary → primary's fallback chain → all remaining providers.
  List<ModelRoute> _buildExhaustiveProviderList(
    ModelRoute primaryRoute,
    AIModelManager aiManager,
  ) {
    final seen = <AIProvider>{};
    final result = <ModelRoute>[];

    void addIfNew(ModelRoute r) {
      if (!seen.contains(r.provider)) {
        seen.add(r.provider);
        result.add(r);
      }
    }

    // 1. Primary provider
    addIfNew(primaryRoute);

    // 2. Primary's fallback chain
    final fallbacks =
        aiManager.getFallbackChainForProvider(primaryRoute.provider);
    for (final fb in fallbacks) {
      if (!seen.contains(fb)) {
        addIfNew(aiManager.buildRouteForProvider(fb, primaryRoute.category));
      }
    }

    // 3. Any remaining providers not yet covered
    for (final provider in AIProvider.values) {
      if (!seen.contains(provider)) {
        addIfNew(
            aiManager.buildRouteForProvider(provider, primaryRoute.category));
      }
    }

    return result;
  }

  /// Route to the correct provider API
  Future<String?> makeProviderRequest({
    required ModelRoute route,
    required String systemPrompt,
    required String userMessage,
    List<Map<String, String>>? history,
  }) async {
    switch (route.provider) {
      // All Groq models use the same OpenAI-compatible Groq endpoint
      case AIProvider.groq:
      case AIProvider.groqLlama4Scout:
      case AIProvider.groqGptOss:
      case AIProvider.groqQwen:
      // NVIDIA NIM uses OpenAI-compatible endpoint
      case AIProvider.nvidia:
      // GitHub (deprecated but same API shape)
      case AIProvider.github:
      // Mistral direct API is also OpenAI-compatible
      case AIProvider.mistralDirect:
        return _callOpenAICompatibleAPI(
          route,
          systemPrompt,
          userMessage,
          history,
          authHeader: 'Bearer ${route.apiKey}',
        );

      // Google Gemini Direct API
      case AIProvider.googleGeminiFlashLite:
      case AIProvider.googleGeminiProPreview:
      case AIProvider.googleGemini35Flash:
      case AIProvider.googleGemma4A4B:
        return _callGeminiAPI(route, systemPrompt, userMessage, history);

      // All OpenRouter models use the OpenRouter endpoint
      default:
        return _callOpenRouterAPI(route, systemPrompt, userMessage, history);
    }
  }

  // ─── GOOGLE GEMINI API ──────────────────────────────────────
  Future<String?> _callGeminiAPI(
    ModelRoute route,
    String systemPrompt,
    String userMessage,
    List<Map<String, String>>? history,
  ) async {
    try {
      final url = '${route.baseUrl}?key=${route.apiKey}';

      final contents = <Map<String, dynamic>>[];

      // In Gemini, user/model messages are 'user' and 'model'
      if (history != null) {
        for (final msg in history) {
          contents.add({
            'role': msg['role'] == 'user' ? 'user' : 'model',
            'parts': [
              {'text': msg['content']}
            ]
          });
        }
      }

      contents.add({
        'role': 'user',
        'parts': [
          {'text': userMessage}
        ]
      });

      final body = {
        'contents': contents,
        'system_instruction': {
          'parts': [
            {'text': systemPrompt}
          ]
        },
        'tools': route.category == QueryCategory.realTimeData
            ? [
                {'google_search': {}}
              ]
            : null,
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 1024,
        },
      };

      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 45)); // Gemma 4 26B needs extra time

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          if (content != null) {
            final parts = content['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final contentStr = parts[0]['text'] as String?;
              return _stripThinkTags(contentStr);
            }
          }
        }
        return null;
      } else if (response.statusCode == 429) {
        // Throw so health checks can detect quota-exceeded as degraded (not failing)
        throw Exception('HTTP 429 quota exceeded: ${route.displayName}');
      } else {
        debugPrint(
            '❌ Gemini(${route.displayName}) HTTP ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Gemini(${route.displayName}) Exception: $e');
      rethrow;
    }
  }

  // ─── OPENAI-COMPATIBLE API (Groq, NVIDIA, GitHub) ──────────
  Future<String?> _callOpenAICompatibleAPI(
    ModelRoute route,
    String systemPrompt,
    String userMessage,
    List<Map<String, String>>? history, {
    required String authHeader,
  }) async {
    try {
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': systemPrompt},
      ];

      if (history != null) {
        messages.addAll(history);
      }

      messages.add({'role': 'user', 'content': userMessage});

      final response = await http
          .post(
            Uri.parse(route.baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': authHeader,
            },
            body: jsonEncode({
              'model': route.modelId,
              'messages': messages,
              'max_tokens': 1024,
              'temperature': 0.7,
            }),
          )
          .timeout(const Duration(
              seconds: 30)); // Reduced timeout for faster fallback

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['choices']?[0]?['message']?['content'] as String?;
        return _stripThinkTags(raw);
      } else if (response.statusCode == 429) {
        throw Exception('HTTP 429 quota exceeded: ${route.displayName}');
      } else {
        debugPrint(
            '❌ ${route.displayName} HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 200))}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ ${route.displayName} Exception: $e');
      rethrow;
    }
  }

  // ─── OPENROUTER API ────────────────────────────────────────
  Future<String?> _callOpenRouterAPI(
    ModelRoute route,
    String systemPrompt,
    String userMessage,
    List<Map<String, String>>? history,
  ) async {
    try {
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': systemPrompt},
      ];
      if (history != null) {
        messages.addAll(history);
      }
      messages.add({'role': 'user', 'content': userMessage});

      final response = await http
          .post(
            Uri.parse(route.baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${route.apiKey}',
              'HTTP-Referer': 'https://ctjchat.app',
              'X-Title': 'CTJ Chat',
            },
            body: jsonEncode({
              'model': route.modelId,
              'messages': messages,
              'max_tokens': 1024,
              'temperature': 0.7,
            }),
          )
          .timeout(const Duration(
              seconds: 30)); // Reduced timeout for faster fallback

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final raw = data['choices']?[0]?['message']?['content'] as String?;
        return _stripThinkTags(raw);
      } else if (response.statusCode == 429) {
        throw Exception('HTTP 429 quota exceeded: ${route.displayName}');
      } else {
        debugPrint(
            '❌ OpenRouter(${route.displayName}) HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 200))}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ OpenRouter(${route.displayName}) Exception: $e');
      rethrow;
    }
  }

  /// Strip <think>...</think> reasoning blocks returned by models like
  /// Qwen3, DeepSeek R1-style, NVIDIA Minimax M2.5, and Groq GPT-OSS.
  /// Also aggressively strips prompt-leaking Chain of Thought from Gemma/local models.
  String? _stripThinkTags(String? raw) {
    if (raw == null || raw.isEmpty) return raw;
    String stripped = raw;

    // 1. Strip formal <think> tags (handles nested content via dotAll)
    stripped = stripped.replaceAll(
      RegExp(r'<think>.*?</think>', dotAll: true, caseSensitive: false),
      '',
    );

    // 2. Aggressively strip Gemma 4 / Local model prompt leakage (CoT before response)
    final lowerStr = stripped.toLowerCase();
    final isLeaking = lowerStr.contains('* user asks:') ||
        lowerStr.contains('* language:') ||
        lowerStr.contains('wait, the instruction');

    if (isLeaking) {
      // If returning the EduChain format, the real answer almost ALWAYS starts with `1. `
      final eduStartMatch =
          RegExp(r'\b1\.\s+(?:📖|🗂️|⚖️|✅|⭐|🔗|[a-zA-Z])').firstMatch(stripped);
      if (eduStartMatch != null) {
        stripped = stripped.substring(eduStartMatch.start).trim();
      } else {
        // Iterative fallback to chomp off individual reasoning statements
        bool madeChanges = true;
        while (madeChanges) {
          madeChanges = false;

          final reasoningPattern = RegExp(
              r'^\s*(?:\*)?\s*(?:User asks:|Language:|Personality:|User Profile:|Response Format:|Tone/Style:|Complexity:|Definition:|Categories:|Pros/Cons:|Real Example:|Structure:|Constraint Check:|Target Language:|Refined Plan:|EduChain Content|Wait|Let.*?s|Looking at|However).*?(?=\s*\*|$|(?:\b\d+\. [^\n]*\b))',
              caseSensitive: false,
              dotAll: true);

          final match = reasoningPattern.firstMatch(stripped);
          if (match != null) {
            stripped = stripped.substring(match.end).trim();
            madeChanges = true;
          }
        }
      }
    }

    // Remove any leftover leading parentheses blobs like "(thinking...)"
    stripped =
        stripped.replaceFirst(RegExp(r'^\s*\(.*?\)\s*', dotAll: true), '');

    return stripped.isNotEmpty ? stripped : raw.trim();
  }
}
