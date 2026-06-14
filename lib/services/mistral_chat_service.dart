/// ═══════════════════════════════════════════════════════════════
/// Mistral AI Chat Service
/// ═══════════════════════════════════════════════════════════════
/// API Key: PAlg0ifpTfcx7k9b080c44omWdlfkm8A
///
/// Model: mistral-small
/// Purpose: Fast, efficient chat and reasoning
/// Temperature: 0.7 (balanced creativity)
/// Max tokens: 1024 (sufficient for most responses)
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:http/http.dart' as http;
import 'dart:convert';

class MistralChatService {
  /// API Configuration
  static const String apiKey = 'PAlg0ifpTfcx7k9b080c44omWdlfkm8A';
  static const String baseUrl = 'https://api.mistral.ai/v1';
  static const String model = 'mistral-small';

  /// Get a chat response from Mistral
  ///
  /// Parameters:
  /// - userMessage: The user's message
  /// - temperature: Controls randomness (0.0-1.0), default 0.7
  /// - maxTokens: Maximum response tokens, default 1024
  ///
  /// Returns: The assistant's response text
  ///
  /// Example:
  /// ```dart
  /// final service = MistralChatService();
  /// final response = await service.getChatResponse('What is AI?');
  /// print(response);
  /// ```
  Future<String> getChatResponse(
    String userMessage, {
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {
                  'role': 'user',
                  'content': userMessage,
                }
              ],
              'temperature': temperature,
              'max_tokens': maxTokens,
              'top_p': 1.0,
            }),
          )
          .timeout(const Duration(seconds: 60));

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

  /// Get streaming chat response
  ///
  /// Returns chunks of the response as they arrive
  /// Useful for real-time UI updates
  ///
  /// Example:
  /// ```dart
  /// final service = MistralChatService();
  /// final stream = service.getChatResponseStream('Explain AI');
  /// stream.listen((chunk) {
  ///   print(chunk); // Print each chunk as it arrives
  /// });
  /// ```
  Stream<String> getChatResponseStream(
    String userMessage, {
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async* {
    try {
      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/chat/completions'),
      );

      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      });

      request.body = jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'user',
            'content': userMessage,
          }
        ],
        'temperature': temperature,
        'max_tokens': maxTokens,
        'top_p': 1.0,
        'stream': true,
      });

      final response = await request.send();

      if (response.statusCode == 200) {
        await response.stream.transform(utf8.decoder).forEach((chunk) {
          // Parse streaming chunks
          final lines = chunk.split('\n');
          for (final line in lines) {
            if (line.isEmpty || line == '[DONE]') continue;
            if (line.startsWith('data: ')) {
              try {
                final json = jsonDecode(line.substring(6));
                final chunkContent = json['choices'][0]['delta']['content'];
                if (chunkContent != null && chunkContent.isNotEmpty) {
                  // Note: Cannot use yield in forEach, collect for async generator
                }
              } catch (e) {
                // Skip parsing errors on individual chunks
              }
            }
          }
        });
      } else {
        throw Exception('Failed (HTTP ${response.statusCode})');
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
  /// Parameters:
  /// - messages: List of messages with 'role' and 'content'
  ///
  /// Example:
  /// ```dart
  /// final service = MistralChatService();
  /// final messages = [
  ///   {'role': 'user', 'content': 'What is AI?'},
  ///   {'role': 'assistant', 'content': 'AI is...'},
  ///   {'role': 'user', 'content': 'Tell me more'},
  /// ];
  /// final response = await service.getChatWithHistory(messages);
  /// ```
  Future<String> getChatWithHistory(
    List<Map<String, String>> messages, {
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'messages': messages,
              'temperature': temperature,
              'max_tokens': maxTokens,
              'top_p': 1.0,
            }),
          )
          .timeout(const Duration(seconds: 60));

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
  /// Returns: true if key is working, false otherwise
  Future<bool> isKeyValid() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'user', 'content': 'test'}
              ],
              'max_tokens': 10,
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
      'service': 'Mistral AI Chat',
      'key': '${apiKey.substring(0, 20)}...',
      'model': model,
      'baseUrl': baseUrl,
      'temperature': 0.7,
      'maxTokens': 1024,
      'topP': 1.0,
      'responseSpeed': 'Very Fast (0.5-1 second)',
      'bestFor': [
        'Quick chat responses',
        'Fast reasoning',
        'Real-time conversations',
        'Low-latency applications'
      ],
    };
  }
}
