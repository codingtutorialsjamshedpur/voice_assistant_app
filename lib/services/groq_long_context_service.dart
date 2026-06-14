/// ═══════════════════════════════════════════════════════════════
/// Groq Long Context Service
/// ═══════════════════════════════════════════════════════════════
/// Key 4: ctj_chat_APRIL_2026_key_4
/// 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
///
/// Model: qwen/qwen3-32b
/// Purpose: Extended conversations with full history
/// Temperature: 0.6 (balanced, consistent)
/// Max tokens: 4096 (substantial responses)
/// Reasoning effort: default
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:http/http.dart' as http;
import 'dart:convert';

class GroqLongContextService {
  /// API Configuration
  static const String apiKey =
      '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';
  static const String baseUrl = 'https://api.groq.com/openai/v1';
  static const String model = 'qwen/qwen3-32b';

  /// Conversation history stored in memory
  final List<Map<String, String>> conversationHistory = [];

  /// Initialize with optional system prompt
  ///
  /// Parameters:
  /// - systemPrompt: System instruction for the conversation
  ///
  /// Example:
  /// ```dart
  /// final service = GroqLongContextService();
  /// await service.initialize('You are a helpful Indian assistant who speaks Hindi and English.');
  /// ```
  Future<void> initialize(String systemPrompt) async {
    conversationHistory.clear();
    if (systemPrompt.isNotEmpty) {
      conversationHistory.add({
        'role': 'system',
        'content': systemPrompt,
      });
    }
  }

  /// Continue a conversation with full history
  ///
  /// Automatically maintains conversation history
  /// Each message is added to history and available for next request
  ///
  /// Example:
  /// ```dart
  /// final service = GroqLongContextService();
  /// final response1 = await service.continueConversation('What is AI?');
  /// print(response1); // First response
  /// final response2 = await service.continueConversation('Tell me more');
  /// print(response2); // Response with context from first message
  /// ```
  Future<String> continueConversation(String userMessage) async {
    try {
      // Add user message to history
      conversationHistory.add({
        'role': 'user',
        'content': userMessage,
      });

      final response = await http
          .post(
            Uri.parse('$baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'messages': conversationHistory,
              'temperature': 0.6,
              'max_completion_tokens': 4096,
              'top_p': 0.95,
              'reasoning_effort': 'default',
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final assistantMessage = json['choices'][0]['message']['content'] ?? '';

        // Add assistant response to history
        conversationHistory.add({
          'role': 'assistant',
          'content': assistantMessage,
        });

        return assistantMessage;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid API key');
      } else if (response.statusCode == 400) {
        throw Exception('Bad request: ${response.body}');
      } else {
        throw Exception(
            'Failed (HTTP ${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('Error in conversation: $e');
      rethrow;
    }
  }

  /// Get only the user and assistant messages (without system prompt)
  ///
  /// Returns: List of user/assistant messages in order
  List<Map<String, String>> getConversationMessages() {
    return conversationHistory.where((msg) => msg['role'] != 'system').toList();
  }

  /// Get the full conversation history including system prompt
  ///
  /// Returns: All messages in conversation
  List<Map<String, String>> getFullHistory() {
    return List.from(conversationHistory);
  }

  /// Get conversation summary
  ///
  /// Returns: Brief summary of the conversation so far
  ///
  /// Example:
  /// ```dart
  /// final service = GroqLongContextService();
  /// await service.continueConversation('What is machine learning?');
  /// await service.continueConversation('How does it work?');
  /// final summary = await service.summarizeConversation();
  /// print(summary);
  /// ```
  Future<String> summarizeConversation() async {
    try {
      if (conversationHistory.length < 2) {
        return 'No conversation to summarize yet.';
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                ...conversationHistory,
                {
                  'role': 'user',
                  'content':
                      'Please summarize our conversation so far in 2-3 sentences.',
                }
              ],
              'temperature': 0.6,
              'max_completion_tokens': 500,
              'top_p': 0.95,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['choices'][0]['message']['content'] ?? '';
      } else {
        throw Exception('Failed (HTTP ${response.statusCode})');
      }
    } catch (e) {
      print('Error summarizing conversation: $e');
      rethrow;
    }
  }

  /// Clear conversation history but keep system prompt if set
  ///
  /// Example:
  /// ```dart
  /// final service = GroqLongContextService();
  /// await service.initialize('You are helpful');
  /// final response = await service.continueConversation('Hello');
  /// service.clearHistory(); // Clears conversation but keeps system prompt
  /// ```
  void clearHistory() {
    final systemMessage = conversationHistory.firstWhere(
      (msg) => msg['role'] == 'system',
      orElse: () => {},
    );

    conversationHistory.clear();

    if (systemMessage.isNotEmpty) {
      conversationHistory.add(systemMessage);
    }
  }

  /// Reset to completely clean state
  ///
  /// Removes all history including system prompt
  void reset() {
    conversationHistory.clear();
  }

  /// Get the last N messages
  ///
  /// Useful for context window management
  List<Map<String, String>> getLastMessages(int count) {
    if (conversationHistory.isEmpty) return [];
    return conversationHistory.sublist(
      (conversationHistory.length - count).clamp(0, conversationHistory.length),
    );
  }

  /// Verify the API key is valid
  Future<bool> isKeyValid() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'user', 'content': 'test'}
              ],
              'max_completion_tokens': 10,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 400;
    } catch (e) {
      return false;
    }
  }

  /// Get conversation statistics
  ///
  /// Returns: Message count, token estimate, etc.
  Map<String, dynamic> getStats() {
    final userMessages =
        conversationHistory.where((msg) => msg['role'] == 'user').toList();
    final assistantMessages =
        conversationHistory.where((msg) => msg['role'] == 'assistant').toList();

    return {
      'totalMessages': conversationHistory.length,
      'userMessages': userMessages.length,
      'assistantMessages': assistantMessages.length,
      'estimatedTokens': _estimateTokens(),
      'averageMessageLength': conversationHistory.isEmpty
          ? 0
          : conversationHistory.fold<int>(
                  0, (sum, msg) => sum + (msg['content']?.length ?? 0)) ~/
              conversationHistory.length,
    };
  }

  /// Estimate token count for conversation
  ///
  /// Note: This is a rough estimate. Actual count may vary.
  int _estimateTokens() {
    int totalChars = 0;
    for (final msg in conversationHistory) {
      totalChars += msg['content']?.length ?? 0;
    }
    // Rough estimate: 1 token ≈ 4 characters
    return (totalChars / 4).ceil();
  }

  /// Get service metadata
  Map<String, dynamic> getMetadata() {
    return {
      'service': 'Groq Long Context',
      'key': '${apiKey.substring(0, 20)}...',
      'model': model,
      'baseUrl': baseUrl,
      'temperature': 0.6,
      'maxTokens': 4096,
      'topP': 0.95,
      'reasoningEffort': 'default',
      'responseSpeed': 'Medium (2-4 seconds)',
      'bestFor': [
        'Extended conversations',
        'Multi-turn dialogue',
        'Context retention',
        'Story writing',
        'Interview simulation'
      ],
      'currentHistorySize': conversationHistory.length,
    };
  }
}
