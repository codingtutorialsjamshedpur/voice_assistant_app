/// ════════════════════════════════════════════════════════════════
/// LLM Service Interface + Google implementation wrapper
/// ════════════════════════════════════════════════════════════════
///
/// Abstract interface for LLM operations. The Google implementation
/// delegates to the existing QueryHandlerService + OpenRouterService
/// pipeline which already handles model routing, SERP, and fallback.
///
/// This file satisfies task.md Tasks 2.1 (LLM Service).
/// ════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'query_handler_service.dart';

/// Abstract interface for LLM operations
abstract class LLMService {
  /// Complete a query given system prompt + user message + optional history
  Future<String?> complete({
    required String systemPrompt,
    required String userMessage,
    String screenContext,
    List<Map<String, String>>? history,
  });

  /// Enhance a response with additional real-time data
  Future<String?> enhanceResponse(String response, String additionalData);
}

/// Concrete implementation that delegates to the existing
/// QueryHandlerService pipeline (OpenRouter + AI Model Manager + SERP)
class GoogleLLMService extends LLMService {
  late final QueryHandlerService _queryHandler;

  GoogleLLMService() {
    _queryHandler = Get.find<QueryHandlerService>();
  }

  @override
  Future<String?> complete({
    required String systemPrompt,
    required String userMessage,
    String screenContext = '',
    List<Map<String, String>>? history,
  }) async {
    try {
      // Build context-enriched prompt
      final fullPrompt = screenContext.isNotEmpty
          ? '$systemPrompt\n\nCURRENT SCREEN:\n$screenContext'
          : systemPrompt;

      final response = await _queryHandler.processQueryWithStrategy(
        userText: userMessage,
        systemPrompt: fullPrompt,
        history: history,
        useProfileContext: true,
      );

      debugPrint(
          '🤖 [LLMService] Response: ${response?.length ?? 0} characters');
      return response;
    } catch (e) {
      debugPrint('❌ [LLMService] complete() error: $e');
      return null;
    }
  }

  @override
  Future<String?> enhanceResponse(
      String response, String additionalData) async {
    if (additionalData.isEmpty) return response;

    try {
      const enhancementPrompt = 'You are given an AI response and additional '
          'real-time data. Enhance the original response by incorporating '
          'the additional data naturally. Keep the same language and tone. '
          'Be concise — this will be read aloud.';

      final userMessage =
          'Original Response:\n$response\n\nAdditional Data:\n$additionalData';

      final enhanced = await _queryHandler.processQuery(
        userText: userMessage,
        systemPrompt: enhancementPrompt,
        useProfileContext: false,
      );

      return enhanced ?? response;
    } catch (e) {
      debugPrint('❌ [LLMService] enhanceResponse() error: $e');
      return response;
    }
  }
}
