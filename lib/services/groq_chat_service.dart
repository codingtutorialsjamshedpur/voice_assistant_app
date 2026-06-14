/// ═══════════════════════════════════════════════════════════════
/// Groq Chat Service
/// ═══════════════════════════════════════════════════════════════
/// Key 2: ctj_chat_APRIL_2026_key_2
/// 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
///
/// Model: meta-llama/llama-4-scout-17b-16e-instruct
/// Purpose: Quick chat responses, conversational AI
/// Temperature: 1 (creative responses)
/// Max tokens: 1024 (fast responses)
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:http/http.dart' as http;
import 'dart:convert';

class GroqChatService {
  /// API Configuration
  static const String apiKey =
      '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';
  static const String baseUrl = 'https://api.groq.com/openai/v1';
  static const String model = 'meta-llama/llama-4-scout-17b-16e-instruct';

  /// Get a single chat response
  ///
  /// Parameters:
  /// - userMessage: The user's question or prompt
  /// - systemPrompt: Optional system instruction (defaults to helpful assistant)
  ///
  /// Returns: The assistant's response
  ///
  /// Example:
  /// ```dart
  /// final service = GroqChatService();
  /// final response = await service.getChatResponse('What is AI?');
  /// print(response);
  /// ```
  Future<String> getChatResponse(
    String userMessage, {
    String? systemPrompt,
  }) async {
    try {
      final messages = <Map<String, String>>[];

      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        messages.add({
          'role': 'system',
          'content': systemPrompt,
        });
      }

      messages.add({
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
              'messages': messages,
              'temperature': 1,
              'max_completion_tokens': 1024,
              'top_p': 1,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['choices'][0]['message']['content'] ?? '';
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid API key');
      } else if (response.statusCode == 400) {
        throw Exception('Bad request: ${response.body}');
      } else {
        throw Exception(
            'Failed (HTTP ${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('Error in chat response: $e');
      rethrow;
    }
  }

  /// Stream chat response for real-time display
  ///
  /// Yields chunks of text as they arrive from the API
  /// Useful for showing response in real-time to user
  ///
  /// Example:
  /// ```dart
  /// final service = GroqChatService();
  /// service.getChatResponseStream('Tell me a joke').listen((chunk) {
  ///   print(chunk); // Print as it arrives
  /// });
  /// ```
  Stream<String> getChatResponseStream(
    String userMessage, {
    String? systemPrompt,
  }) async* {
    try {
      final messages = <Map<String, String>>[];

      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        messages.add({
          'role': 'system',
          'content': systemPrompt,
        });
      }

      messages.add({
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
              'messages': messages,
              'temperature': 1,
              'max_completion_tokens': 1024,
              'top_p': 1,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final content = json['choices'][0]['message']['content'] ?? '';
        if (content.isNotEmpty) {
          yield content;
        }
      } else {
        throw Exception('Stream failed (HTTP ${response.statusCode})');
      }
    } catch (e) {
      print('Error in chat stream: $e');
      rethrow;
    }
  }

  /// Chat with conversation history
  /// Maintains message history for multi-turn conversations
  ///
  /// Example:
  /// ```dart
  /// final service = GroqChatService();
  /// final response1 = await service.getChatWithHistory(
  ///   messages: [{'role': 'user', 'content': 'What is AI?'}],
  /// );
  /// final response2 = await service.getChatWithHistory(
  ///   messages: [
  ///     {'role': 'user', 'content': 'What is AI?'},
  ///     {'role': 'assistant', 'content': response1},
  ///     {'role': 'user', 'content': 'Tell me more'},
  ///   ],
  /// );
  /// ```
  Future<String> getChatWithHistory({
    required List<Map<String, String>> messages,
    String? systemPrompt,
  }) async {
    try {
      final allMessages = <Map<String, String>>[];

      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        allMessages.add({
          'role': 'system',
          'content': systemPrompt,
        });
      }

      allMessages.addAll(messages);

      final response = await http
          .post(
            Uri.parse('$baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'messages': allMessages,
              'temperature': 1,
              'max_completion_tokens': 1024,
              'top_p': 1,
              'stream': false,
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
      print('Error in chat with history: $e');
      rethrow;
    }
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

  /// Get service metadata
  Map<String, dynamic> getMetadata() {
    return {
      'service': 'Groq Chat',
      'key': '${apiKey.substring(0, 20)}...',
      'model': model,
      'baseUrl': baseUrl,
      'temperature': 1,
      'maxTokens': 1024,
      'topP': 1,
      'responseSpeed': 'Fast (1-2 seconds)',
      'bestFor': ['Quick responses', 'Conversational AI', 'Gen-Z style'],
    };
  }
}
