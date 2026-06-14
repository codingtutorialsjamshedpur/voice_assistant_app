/// ════════════════════════════════════════════════════════════════
/// Intelligent Fallback Query Handler
/// ════════════════════════════════════════════════════════════════
///
/// Handles queries with automatic fallback to alternate models if:
/// - Primary model is not responding
/// - Primary model times out
/// - Primary model returns an error
/// - Rate limit is reached on primary model
///
/// Features:
/// 1. Smart provider selection based on query type and health
/// 2. Automatic fallback chain execution
/// 3. Error recovery and retry logic
/// 4. Performance tracking for better future routing
/// ════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_keys_config.dart';
import 'api_keys_intelligent_manager.dart';

// ════════════════════════════════════════════════════════════════
// FALLBACK QUERY RESULT
// ════════════════════════════════════════════════════════════════

class FallbackQueryResult {
  final bool success;
  final String? response;
  final String usedProvider;
  final String usedKeyId;
  final int attemptCount;
  final List<String> failedAttempts;
  final String? errorMessage;
  final Duration executionTime;

  FallbackQueryResult({
    required this.success,
    required this.response,
    required this.usedProvider,
    required this.usedKeyId,
    required this.attemptCount,
    required this.failedAttempts,
    this.errorMessage,
    required this.executionTime,
  });

  @override
  String toString() {
    return '''
Fallback Query Result:
  Status: ${success ? '✅ Success' : '❌ Failed'}
  Provider: $usedProvider (Key: $usedKeyId)
  Attempts: $attemptCount
  Failed Attempts: ${failedAttempts.length}
  Execution Time: ${executionTime.inMilliseconds}ms
  Error: ${errorMessage ?? 'None'}
  Response Length: ${response?.length ?? 0} characters
''';
  }
}

// ════════════════════════════════════════════════════════════════
// INTELLIGENT FALLBACK HANDLER
// ════════════════════════════════════════════════════════════════

class IntelligentFallbackQueryHandler extends GetxService {
  late final ApiKeysIntelligentManager _keyManager;

  // Configuration
  static const int maxAttempts = 3;
  static const Duration singleTimeout = Duration(seconds: 15);
  static const Duration totalTimeout = Duration(seconds: 60);

  // Performance tracking
  final _queryPerformance = <String, List<Duration>>{}.obs;

  @override
  void onInit() {
    super.onInit();
    _keyManager = Get.find<ApiKeysIntelligentManager>();
  }

  /// Execute a query with automatic fallback
  Future<FallbackQueryResult> executeWithFallback({
    required String query,
    required String systemPrompt,
    QueryType queryType = QueryType.general,
    Map<String, dynamic>? additionalParams,
  }) async {
    debugPrint(
        '\n🚀 [IntelligentFallback] Starting query with fallback mechanism...');
    debugPrint('   Query: ${query.substring(0, min(50, query.length))}...');
    debugPrint('   Query Type: $queryType');

    final stopwatch = Stopwatch()..start();
    final failedAttempts = <String>[];

    try {
      // Check if system can handle queries
      if (!_keyManager.canHandleQueries()) {
        return FallbackQueryResult(
          success: false,
          response: null,
          usedProvider: 'None',
          usedKeyId: 'None',
          attemptCount: 0,
          failedAttempts: failedAttempts,
          errorMessage: 'No working API providers available',
          executionTime: stopwatch.elapsed,
        );
      }

      // Get strategy for this query type
      final strategy = _keyManager.getStrategyForQueryType(queryType);

      debugPrint('   Primary Provider: ${strategy.primaryProvider}');
      debugPrint('   Fallback Providers: ${strategy.fallbackProviders.length}');

      // Try primary provider first
      final primaryResult = await _executeQuery(
        keyId: strategy.primaryProvider,
        query: query,
        systemPrompt: systemPrompt,
        additionalParams: additionalParams,
      );

      if (primaryResult != null) {
        stopwatch.stop();
        _recordPerformance(strategy.primaryProvider, stopwatch.elapsed);

        return FallbackQueryResult(
          success: true,
          response: primaryResult,
          usedProvider:
              _keyManager.keyStatuses[strategy.primaryProvider]?.provider ??
                  'Unknown',
          usedKeyId: strategy.primaryProvider,
          attemptCount: 1,
          failedAttempts: failedAttempts,
          errorMessage: null,
          executionTime: stopwatch.elapsed,
        );
      }

      failedAttempts.add(strategy.primaryProvider);
      debugPrint('   ⚠️ Primary provider failed, trying fallbacks...');

      // Try fallback providers
      for (int attempt = 0;
          attempt < strategy.fallbackProviders.length &&
              failedAttempts.length < maxAttempts;
          attempt++) {
        final fallbackKeyId = strategy.fallbackProviders[attempt];

        debugPrint(
            '   Attempt ${failedAttempts.length + 1}: Trying $fallbackKeyId');

        final fallbackResult = await _executeQuery(
          keyId: fallbackKeyId,
          query: query,
          systemPrompt: systemPrompt,
          additionalParams: additionalParams,
        );

        if (fallbackResult != null) {
          stopwatch.stop();
          _recordPerformance(fallbackKeyId, stopwatch.elapsed);

          debugPrint('   ✅ Fallback succeeded with $fallbackKeyId');

          return FallbackQueryResult(
            success: true,
            response: fallbackResult,
            usedProvider:
                _keyManager.keyStatuses[fallbackKeyId]?.provider ?? 'Unknown',
            usedKeyId: fallbackKeyId,
            attemptCount: failedAttempts.length + 1,
            failedAttempts: failedAttempts,
            errorMessage: null,
            executionTime: stopwatch.elapsed,
          );
        }

        failedAttempts.add(fallbackKeyId);
      }

      // All attempts failed
      stopwatch.stop();

      debugPrint('   ❌ All ${failedAttempts.length} providers failed');

      return FallbackQueryResult(
        success: false,
        response: null,
        usedProvider: 'None',
        usedKeyId: 'None',
        attemptCount: failedAttempts.length,
        failedAttempts: failedAttempts,
        errorMessage:
            'All ${failedAttempts.length} providers failed after $maxAttempts attempts',
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('   ❌ Exception during fallback: $e');

      return FallbackQueryResult(
        success: false,
        response: null,
        usedProvider: 'Error',
        usedKeyId: 'Error',
        attemptCount: failedAttempts.length,
        failedAttempts: failedAttempts,
        errorMessage: e.toString(),
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Execute a query with a specific key
  Future<String?> _executeQuery({
    required String keyId,
    required String query,
    required String systemPrompt,
    Map<String, dynamic>? additionalParams,
  }) async {
    try {
      final keyStatus = _keyManager.keyStatuses[keyId];
      if (keyStatus == null) {
        debugPrint('   ❌ Key $keyId not found');
        return null;
      }

      // Route based on provider
      if (keyStatus.provider == 'Groq') {
        return await _executeGroqQuery(
            keyId, query, systemPrompt, additionalParams);
      } else if (keyStatus.provider == 'NVIDIA NIM') {
        return await _executeNvidiaQuery(
            keyId, query, systemPrompt, additionalParams);
      } else if (keyStatus.provider == 'OpenRouter') {
        return await _executeOpenRouterQuery(
            keyId, query, systemPrompt, additionalParams);
      }

      return null;
    } catch (e) {
      debugPrint('   ❌ Exception in _executeQuery: $e');
      return null;
    }
  }

  /// Execute Groq query
  Future<String?> _executeGroqQuery(
    String keyId,
    String query,
    String systemPrompt,
    Map<String, dynamic>? additionalParams,
  ) async {
    try {
      final keyIndex = int.parse(keyId.split('_').last) - 1;
      if (keyIndex < 0 || keyIndex >= ApiKeysConfig.groqApiKeys.length) {
        return null;
      }

      final apiKey = ApiKeysConfig.groqApiKeys[keyIndex];

      final response = await http
          .post(
            Uri.parse('${ApiKeysConfig.groqBaseUrl}/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': ApiKeysConfig.groqModel,
              'messages': [
                {
                  'role': 'system',
                  'content': systemPrompt,
                },
                {
                  'role': 'user',
                  'content': query,
                }
              ],
              'max_tokens': additionalParams?['max_tokens'] ?? 500,
              'temperature': additionalParams?['temperature'] ?? 0.7,
            }),
          )
          .timeout(singleTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String?;
      } else if (response.statusCode == 429) {
        debugPrint('   ⚠️ Groq rate limit (429)');
        return null;
      }

      return null;
    } catch (e) {
      debugPrint('   ❌ Groq error: $e');
      return null;
    }
  }

  /// Execute NVIDIA query
  Future<String?> _executeNvidiaQuery(
    String keyId,
    String query,
    String systemPrompt,
    Map<String, dynamic>? additionalParams,
  ) async {
    try {
      final keyIndex = int.parse(keyId.split('_').last) - 1;
      if (keyIndex < 0 || keyIndex >= ApiKeysConfig.nvidiaAuthTokens.length) {
        return null;
      }

      final apiKey = ApiKeysConfig.nvidiaAuthTokens[keyIndex];

      final response = await http
          .post(
            Uri.parse(ApiKeysConfig.nvidiaBaseUrl),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': ApiKeysConfig.nvidiaModel,
              'messages': [
                {
                  'role': 'system',
                  'content': systemPrompt,
                },
                {
                  'role': 'user',
                  'content': query,
                }
              ],
              'temperature': additionalParams?['temperature'] ?? 1,
              'top_p': additionalParams?['top_p'] ?? 0.95,
              'max_tokens': additionalParams?['max_tokens'] ?? 500,
            }),
          )
          .timeout(singleTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String?;
      } else if (response.statusCode == 429) {
        debugPrint('   ⚠️ NVIDIA rate limit (429)');
        return null;
      }

      return null;
    } catch (e) {
      debugPrint('   ❌ NVIDIA error: $e');
      return null;
    }
  }

  /// Execute OpenRouter query
  Future<String?> _executeOpenRouterQuery(
    String keyId,
    String query,
    String systemPrompt,
    Map<String, dynamic>? additionalParams,
  ) async {
    try {
      // Extract model key from keyId (e.g., 'openrouter_nvidia-nemotron-3-super')
      final modelKey = keyId.replaceFirst('openrouter_', '');
      final config = ApiKeysConfig.openRouterModels[modelKey];

      if (config == null) {
        return null;
      }

      final response = await http
          .post(
            Uri.parse('${ApiKeysConfig.openRouterBaseUrl}/chat/completions'),
            headers: {
              'Authorization': 'Bearer ${config.apiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': config.modelId,
              'messages': [
                {
                  'role': 'system',
                  'content': systemPrompt,
                },
                {
                  'role': 'user',
                  'content': query,
                }
              ],
              'max_tokens': additionalParams?['max_tokens'] ?? 500,
              'temperature': additionalParams?['temperature'] ?? 0.7,
            }),
          )
          .timeout(singleTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String?;
      } else if (response.statusCode == 429) {
        debugPrint('   ⚠️ OpenRouter rate limit (429)');
        return null;
      }

      return null;
    } catch (e) {
      debugPrint('   ❌ OpenRouter error: $e');
      return null;
    }
  }

  /// Record performance metrics
  void _recordPerformance(String keyId, Duration duration) {
    if (!_queryPerformance.containsKey(keyId)) {
      _queryPerformance[keyId] = [];
    }

    _queryPerformance[keyId]!.add(duration);

    // Keep last 10 measurements
    if (_queryPerformance[keyId]!.length > 10) {
      _queryPerformance[keyId]!.removeAt(0);
    }
  }

  /// Get average performance for a key
  Duration? getAveragePerformance(String keyId) {
    final measurements = _queryPerformance[keyId];
    if (measurements == null || measurements.isEmpty) {
      return null;
    }

    final totalMs = measurements.fold<int>(0, (a, b) => a + b.inMilliseconds);
    return Duration(milliseconds: totalMs ~/ measurements.length);
  }

  /// Get performance report
  String getPerformanceReport() {
    final buffer = StringBuffer();
    buffer
        .writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('FALLBACK QUERY HANDLER — PERFORMANCE REPORT');
    buffer
        .writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('');

    for (final entry in _queryPerformance.entries) {
      final avgPerf = getAveragePerformance(entry.key);
      buffer.writeln(
          '  ${entry.key}: ${avgPerf?.inMilliseconds ?? 0}ms avg (${entry.value.length} queries)');
    }

    buffer
        .writeln('═══════════════════════════════════════════════════════════');

    return buffer.toString();
  }
}

/// Helper function
int min(int a, int b) => a < b ? a : b;
