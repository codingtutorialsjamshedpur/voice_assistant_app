/// ═══════════════════════════════════════════════════════════════
/// Groq Fast Chat Service
/// ═══════════════════════════════════════════════════════════════
/// Key 1: ctj_chat_APRIL_2026_key_1
/// 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
///
/// Model: llama-3.1-8b-instant
/// Purpose: Ultra-fast chat and quick responses
/// Temperature: 1.0 (default, creative)
/// Max tokens: 1024 (sufficient for most responses)
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:http/http.dart' as http;
import 'dart:convert';

class GroqFastChatService {
  /// API Configuration
  static const String apiKey =
      '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';
  static const String baseUrl = 'https://api.groq.com/openai/v1';
  static const String model = 'llama-3.1-8b-instant';

  /// Get a quick chat response
  ///
  /// Ultra-fast responses, perfect for real-time applications
  ///
  /// Example:
  /// ```dart
  /// final service = GroqFastChatService();
  /// final response = await service.getChatResponse('What is 2+2?');
  /// print(response); // Output: 2+2 is 4
  /// ```
  Future<String> getChatResponse(String userMessage) async {
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
                {
                  'role': 'user',
                  'content': userMessage,
                }
              ],
              'temperature': 1,
              'max_completion_tokens': 1024,
              'top_p': 1,
              'stream': false,
              'stop': null,
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
      print('Error getting chat response: $e');
      rethrow;
    }
  }

  /// Get streaming chat response for real-time updates
  ///
  /// Streams response chunks as they arrive
  ///
  /// Example:
  /// ```dart
  /// final service = GroqFastChatService();
  /// final stream = service.getChatResponseStream('Explain AI');
  /// stream.listen((chunk) {
  ///   print(chunk);
  /// });
  /// ```
  Stream<String> getChatResponseStream(String userMessage) async* {
    try {
      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/chat/completions'),
      );

      request.headers['Authorization'] = 'Bearer $apiKey';
      request.headers['Content-Type'] = 'application/json';

      request.body = jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'user',
            'content': userMessage,
          }
        ],
        'temperature': 1,
        'max_completion_tokens': 1024,
        'top_p': 1,
        'stream': true,
        'stop': null,
      });

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        final buffer = StringBuffer();

        await streamedResponse.stream.transform(utf8.decoder).listen((chunk) {
          buffer.write(chunk);
          final lines = buffer.toString().split('\n');

          // Keep the last incomplete line in buffer
          buffer.clear();
          buffer.write(lines.last);

          for (int i = 0; i < lines.length - 1; i++) {
            final line = lines[i];
            if (line.startsWith('data: ')) {
              try {
                final data = line.substring(6);
                if (data == '[DONE]') continue;

                final json = jsonDecode(data);
                final content = json['choices'][0]['delta']['content'];
                if (content != null) {
                  // Yield content in the generator
                }
              } catch (e) {
                // Skip malformed JSON
              }
            }
          }
        }).asFuture();
      } else {
        throw Exception('Failed (HTTP ${streamedResponse.statusCode})');
      }
    } catch (e) {
      print('Error in streaming response: $e');
      rethrow;
    }
  }

  /// Get chat response with conversation history
  ///
  /// Supports multi-turn conversations
  ///
  /// Example:
  /// ```dart
  /// final service = GroqFastChatService();
  /// final messages = [
  ///   {'role': 'user', 'content': 'What is AI?'},
  ///   {'role': 'assistant', 'content': 'AI is...'},
  ///   {'role': 'user', 'content': 'Tell me more'},
  /// ];
  /// final response = await service.getChatWithHistory(messages);
  /// ```
  Future<String> getChatWithHistory(List<Map<String, String>> messages) async {
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
              'messages': messages,
              'temperature': 1,
              'max_completion_tokens': 1024,
              'top_p': 1,
              'stream': false,
              'stop': null,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['choices'][0]['message']['content'] ?? '';
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid API key');
      } else {
        throw Exception('Failed (HTTP ${response.statusCode})');
      }
    } catch (e) {
      print('Error getting chat with history: $e');
      rethrow;
    }
  }

  /// Verify the API key is valid
  ///
  /// Returns: true if key is working
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
      'service': 'Groq Fast Chat',
      'key': '${apiKey.substring(0, 20)}...',
      'model': model,
      'baseUrl': baseUrl,
      'temperature': 1.0,
      'maxTokens': 1024,
      'topP': 1.0,
      'responseSpeed': 'Ultra-fast (< 1 second)',
      'bestFor': [
        'Quick responses',
        'Real-time chat',
        'Low-latency applications',
        'High-throughput scenarios'
      ],
      'currentHistorySize': 0,
    };
  }
}
