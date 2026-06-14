/// ═══════════════════════════════════════════════════════════════
/// Groq Advanced Reasoning Service
/// ═══════════════════════════════════════════════════════════════
/// Key 3: ctj_chat_APRIL_2026_key_3
/// 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
///
/// Model: openai/gpt-oss-120b
/// Purpose: Complex problem solving, reasoning, analysis
/// Temperature: 1 (creative reasoning)
/// Max tokens: 8192 (detailed responses)
/// Reasoning effort: medium
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:http/http.dart' as http;
import 'dart:convert';

class GroqAdvancedReasoningService {
  /// API Configuration
  static const String apiKey =
      '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';
  static const String baseUrl = 'https://api.groq.com/openai/v1';
  static const String model = 'openai/gpt-oss-120b';

  /// Solve a complex problem with detailed reasoning
  ///
  /// Best for: Math, logic, science, deep analysis
  /// Returns: Detailed explanation with reasoning steps
  ///
  /// Example:
  /// ```dart
  /// final service = GroqAdvancedReasoningService();
  /// final response = await service.solveComplex(
  ///   'Explain quantum entanglement in simple terms'
  /// );
  /// print(response);
  /// ```
  Future<String> solveComplex(
    String problem, {
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
        'content': problem,
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
              'max_completion_tokens': 8192,
              'top_p': 1,
              'reasoning_effort': 'medium',
              'stream': false,
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
      print('Error solving complex problem: $e');
      rethrow;
    }
  }

  /// Stream complex reasoning response
  ///
  /// Yields reasoning steps as they're computed
  /// Useful for showing reasoning progress to user
  ///
  /// Example:
  /// ```dart
  /// final service = GroqAdvancedReasoningService();
  /// service.solveComplexStream('Why is the sky blue?').listen((chunk) {
  ///   print(chunk);
  /// });
  /// ```
  Stream<String> solveComplexStream(
    String problem, {
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
        'content': problem,
      });

      // Note: For simplicity, we'll fetch the full response and yield it
      // True streaming for reasoning might not be available on Groq's free tier
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
              'max_completion_tokens': 8192,
              'top_p': 1,
              'reasoning_effort': 'medium',
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final content = json['choices'][0]['message']['content'] ?? '';

        // Yield the response in chunks for streaming effect
        const chunkSize = 100;
        for (int i = 0; i < content.length; i += chunkSize) {
          final end =
              (i + chunkSize < content.length) ? i + chunkSize : content.length;
          yield content.substring(i, end);
        }
      } else {
        throw Exception('Stream failed (HTTP ${response.statusCode})');
      }
    } catch (e) {
      print('Error in reasoning stream: $e');
      rethrow;
    }
  }

  /// Analyze and explain a complex topic
  ///
  /// Parameters:
  /// - topic: The topic to analyze
  /// - depth: 'brief' (500 tokens), 'detailed' (2000 tokens), or 'comprehensive' (8000 tokens)
  ///
  /// Returns: Analysis with multiple perspectives
  Future<String> analyzeComplex(
    String topic, {
    String depth = 'detailed',
  }) async {
    try {
      final depthPrompt = switch (depth) {
        'brief' => 'Provide a brief analysis (200-300 words)',
        'comprehensive' =>
          'Provide a comprehensive analysis (2000+ words) with multiple perspectives',
        _ => 'Provide a detailed analysis (800-1200 words)',
      };

      return await solveComplex(
        '$depthPrompt:\n\n$topic',
        systemPrompt:
            'You are an expert analyst. Provide deep, thorough analysis with clear structure.',
      );
    } catch (e) {
      print('Error analyzing complex topic: $e');
      rethrow;
    }
  }

  /// Solve a math problem step by step
  ///
  /// Returns: Solution with all steps explained
  ///
  /// Example:
  /// ```dart
  /// final service = GroqAdvancedReasoningService();
  /// final solution = await service.solveMath('What is the derivative of x^3 + 2x?');
  /// print(solution);
  /// ```
  Future<String> solveMath(String problem) async {
    try {
      return await solveComplex(
        'Solve this math problem step by step: $problem',
        systemPrompt: '''You are a mathematics expert. 
Solve the problem step by step with clear explanations.
Show all work and reasoning.''',
      );
    } catch (e) {
      print('Error solving math problem: $e');
      rethrow;
    }
  }

  /// Scientific explanation with technical depth
  ///
  /// Returns: Scientific explanation suitable for understanding
  Future<String> explainScience(String concept) async {
    try {
      return await solveComplex(
        'Explain $concept in scientific detail',
        systemPrompt: '''You are a science educator and researcher.
Provide a detailed, technically accurate explanation.
Include key concepts, theories, and practical applications.''',
      );
    } catch (e) {
      print('Error explaining science: $e');
      rethrow;
    }
  }

  /// Code review and optimization suggestions
  ///
  /// Analyzes code for:
  /// - Bugs and issues
  /// - Performance improvements
  /// - Best practices
  /// - Security concerns
  Future<String> reviewCode(String code, String language) async {
    try {
      return await solveComplex(
        'Review and optimize this $language code:\n\n```$language\n$code\n```\n\nProvide specific improvement suggestions.',
        systemPrompt:
            'You are an expert code reviewer. Analyze code for bugs, performance, best practices, and security.',
      );
    } catch (e) {
      print('Error reviewing code: $e');
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
      'service': 'Groq Advanced Reasoning',
      'key': '${apiKey.substring(0, 20)}...',
      'model': model,
      'baseUrl': baseUrl,
      'temperature': 1,
      'maxTokens': 8192,
      'topP': 1,
      'reasoningEffort': 'medium',
      'responseSpeed': 'Medium (2-4 seconds)',
      'bestFor': [
        'Complex problem solving',
        'Scientific analysis',
        'Math reasoning',
        'Code review',
        'Deep explanations'
      ],
    };
  }
}
