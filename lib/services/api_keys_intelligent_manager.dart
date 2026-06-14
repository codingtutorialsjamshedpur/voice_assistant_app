/// ════════════════════════════════════════════════════════════════
/// API Keys Intelligent Manager — Test & Fallback System
/// ════════════════════════════════════════════════════════════════
///
/// Features:
/// 1. Test all API keys on startup and periodic intervals
/// 2. Track which keys/providers are working
/// 3. Intelligent fallback: If a model fails mid-query, switch to next
/// 4. Rate limiting detection and recovery
/// 5. Performance metrics tracking
/// ════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'api_keys_config.dart';

// ════════════════════════════════════════════════════════════════
// DATA MODELS
// ════════════════════════════════════════════════════════════════

class APIKeyStatus {
  final String provider;
  final String modelId;
  final String keyPreview; // First 20 chars of key
  final bool isWorking;
  final DateTime lastTestedAt;
  final int successCount;
  final int failureCount;
  final String? lastErrorMessage;
  final Duration? averageResponseTime;

  APIKeyStatus({
    required this.provider,
    required this.modelId,
    required this.keyPreview,
    required this.isWorking,
    required this.lastTestedAt,
    required this.successCount,
    required this.failureCount,
    this.lastErrorMessage,
    this.averageResponseTime,
  });

  double getSuccessRate() {
    final total = successCount + failureCount;
    if (total == 0) return 0;
    return (successCount / total) * 100;
  }

  @override
  String toString() {
    return '''
Provider: $provider
Model: $modelId
Status: ${isWorking ? '✅ Working' : '❌ Failed'}
Key: $keyPreview...
Success Rate: ${getSuccessRate().toStringAsFixed(1)}%
Success/Failures: $successCount/$failureCount
Last Error: ${lastErrorMessage ?? 'None'}
Avg Response: ${averageResponseTime?.inMilliseconds ?? 0}ms
Last Tested: $lastTestedAt
''';
  }
}

class ModelFallbackStrategy {
  final String primaryProvider;
  final List<String> fallbackProviders;
  final QueryType queryType;

  ModelFallbackStrategy({
    required this.primaryProvider,
    required this.fallbackProviders,
    required this.queryType,
  });
}

enum QueryType { chat, reasoning, translation, general }

// ════════════════════════════════════════════════════════════════
// INTELLIGENT API MANAGER
// ════════════════════════════════════════════════════════════════

class ApiKeysIntelligentManager extends GetxService {
  // Observable state
  final keyStatuses = <String, APIKeyStatus>{}.obs;
  final isInitialized = false.obs;
  final isTesting = false.obs;
  final workingProviders = <String>[].obs;
  final failedProviders = <String>[].obs;

  // Testing configuration
  static const Duration testInterval = Duration(hours: 1);
  static const Duration requestTimeout = Duration(seconds: 15);
  static const int maxRetries = 2;

  // Test queries for different scenarios
  static const String simpleQuery = 'What is 2+2?';
  static const String reasoningQuery =
      'Explain quantum entanglement in simple terms';
  static const String translationQuery = 'Translate "Hello" to French';

  // Tracking
  late Timer _testTimer;
  final _requestTimings = <String, List<Duration>>{};
  final _consecutiveFailures = <String, int>{};

  @override
  void onInit() {
    super.onInit();
    _initializeAllKeys();
    _startPeriodicTesting();
  }

  @override
  void onClose() {
    _testTimer.cancel();
    super.onClose();
  }

  /// Initialize all API keys with status tracking
  void _initializeAllKeys() {
    // Groq keys
    for (int i = 0; i < ApiKeysConfig.groqApiKeys.length; i++) {
      final key = ApiKeysConfig.groqApiKeys[i];
      final keyId = 'groq_key_${i + 1}';
      keyStatuses[keyId] = APIKeyStatus(
        provider: 'Groq',
        modelId: ApiKeysConfig.groqModel,
        keyPreview: key.substring(0, min(20, key.length)),
        isWorking: false,
        lastTestedAt: DateTime.now(),
        successCount: 0,
        failureCount: 0,
      );
      _requestTimings[keyId] = [];
      _consecutiveFailures[keyId] = 0;
    }

    // NVIDIA keys
    for (int i = 0; i < ApiKeysConfig.nvidiaAuthTokens.length; i++) {
      final token = ApiKeysConfig.nvidiaAuthTokens[i];
      final keyId = 'nvidia_key_${i + 1}';
      keyStatuses[keyId] = APIKeyStatus(
        provider: 'NVIDIA NIM',
        modelId: ApiKeysConfig.nvidiaModel,
        keyPreview: token.substring(0, min(20, token.length)),
        isWorking: false,
        lastTestedAt: DateTime.now(),
        successCount: 0,
        failureCount: 0,
      );
      _requestTimings[keyId] = [];
      _consecutiveFailures[keyId] = 0;
    }

    // OpenRouter keys
    for (final entry in ApiKeysConfig.openRouterModels.entries) {
      final config = entry.value;
      final keyId = 'openrouter_${entry.key}';
      keyStatuses[keyId] = APIKeyStatus(
        provider: 'OpenRouter',
        modelId: config.modelId,
        keyPreview: config.apiKey.substring(0, min(20, config.apiKey.length)),
        isWorking: false,
        lastTestedAt: DateTime.now(),
        successCount: 0,
        failureCount: 0,
      );
      _requestTimings[keyId] = [];
      _consecutiveFailures[keyId] = 0;
    }

    debugPrint(
        '✅ [ApiKeysIntelligentManager] Initialized ${keyStatuses.length} keys');
  }

  /// Start periodic testing of all API keys
  void _startPeriodicTesting() {
    // Test immediately on startup
    testAllKeysAsync();

    // Test periodically
    _testTimer = Timer.periodic(testInterval, (_) {
      testAllKeysAsync();
    });
  }

  /// Test all API keys (non-blocking)
  Future<void> testAllKeysAsync() async {
    await testAllKeys();
  }

  /// Test all API keys (blocking)
  Future<void> testAllKeys() async {
    if (isTesting.value) {
      debugPrint(
          '⚠️ [ApiKeysIntelligentManager] Test already in progress, skipping');
      return;
    }

    isTesting.value = true;
    debugPrint(
        '\n🔍 [ApiKeysIntelligentManager] Starting comprehensive test...');

    try {
      // Test Groq keys
      await _testGroqKeys();

      // Test NVIDIA keys
      await _testNvidiaKeys();

      // Test OpenRouter keys
      await _testOpenRouterKeys();

      _generateTestSummary();
      isInitialized.value = true;
    } catch (e) {
      debugPrint('❌ [ApiKeysIntelligentManager] Test error: $e');
    } finally {
      isTesting.value = false;
    }
  }

  /// Test all Groq API keys
  Future<void> _testGroqKeys() async {
    debugPrint('\n📌 Testing Groq API Keys...');

    for (int i = 0; i < ApiKeysConfig.groqApiKeys.length; i++) {
      final key = ApiKeysConfig.groqApiKeys[i];
      final keyId = 'groq_key_${i + 1}';

      final isWorking = await _testGroqKey(key, keyId);
      _updateKeyStatus(keyId, isWorking);
    }
  }

  /// Test a single Groq key
  Future<bool> _testGroqKey(String key, String keyId) async {
    try {
      final stopwatch = Stopwatch()..start();

      final response = await http
          .post(
            Uri.parse('${ApiKeysConfig.groqBaseUrl}/chat/completions'),
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': ApiKeysConfig.groqModel,
              'messages': [
                {
                  'role': 'user',
                  'content': simpleQuery,
                }
              ],
              'max_tokens': 100,
            }),
          )
          .timeout(requestTimeout);

      stopwatch.stop();
      final duration = stopwatch.elapsed;

      if (response.statusCode == 200) {
        _recordSuccess(keyId, duration);
        debugPrint('  ✅ $keyId: Success (${duration.inMilliseconds}ms)');
        return true;
      } else if (response.statusCode == 429) {
        _recordRateLimitError(keyId, 'Rate limit exceeded');
        debugPrint('  ⚠️ $keyId: Rate limited (HTTP 429)');
        return false;
      } else {
        _recordFailure(keyId, 'HTTP ${response.statusCode}');
        debugPrint('  ❌ $keyId: HTTP ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _recordFailure(keyId, e.toString());
      debugPrint('  ❌ $keyId: $e');
      return false;
    }
  }

  /// Test all NVIDIA keys
  Future<void> _testNvidiaKeys() async {
    debugPrint('\n📌 Testing NVIDIA NIM API Keys...');

    for (int i = 0; i < ApiKeysConfig.nvidiaAuthTokens.length; i++) {
      final token = ApiKeysConfig.nvidiaAuthTokens[i];
      final keyId = 'nvidia_key_${i + 1}';

      final isWorking = await _testNvidiaKey(token, keyId);
      _updateKeyStatus(keyId, isWorking);
    }
  }

  /// Test a single NVIDIA key
  Future<bool> _testNvidiaKey(String token, String keyId) async {
    try {
      final stopwatch = Stopwatch()..start();

      final response = await http
          .post(
            Uri.parse(ApiKeysConfig.nvidiaBaseUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': ApiKeysConfig.nvidiaModel,
              'messages': [
                {
                  'role': 'user',
                  'content': simpleQuery,
                }
              ],
              'temperature': 1,
              'top_p': 0.95,
              'max_tokens': 100,
            }),
          )
          .timeout(requestTimeout);

      stopwatch.stop();
      final duration = stopwatch.elapsed;

      if (response.statusCode == 200) {
        _recordSuccess(keyId, duration);
        debugPrint('  ✅ $keyId: Success (${duration.inMilliseconds}ms)');
        return true;
      } else if (response.statusCode == 429) {
        _recordRateLimitError(keyId, 'Rate limit exceeded');
        debugPrint('  ⚠️ $keyId: Rate limited (HTTP 429)');
        return false;
      } else {
        _recordFailure(keyId, 'HTTP ${response.statusCode}');
        debugPrint('  ❌ $keyId: HTTP ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _recordFailure(keyId, e.toString());
      debugPrint('  ❌ $keyId: $e');
      return false;
    }
  }

  /// Test all OpenRouter keys
  Future<void> _testOpenRouterKeys() async {
    debugPrint('\n📌 Testing OpenRouter API Keys...');

    for (final entry in ApiKeysConfig.openRouterModels.entries) {
      final config = entry.value;
      final keyId = 'openrouter_${entry.key}';

      final isWorking = await _testOpenRouterKey(config, keyId);
      _updateKeyStatus(keyId, isWorking);
    }
  }

  /// Test a single OpenRouter key
  Future<bool> _testOpenRouterKey(
      OpenRouterModelConfig config, String keyId) async {
    try {
      final stopwatch = Stopwatch()..start();

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
                  'role': 'user',
                  'content': simpleQuery,
                }
              ],
              'max_tokens': 100,
            }),
          )
          .timeout(requestTimeout);

      stopwatch.stop();
      final duration = stopwatch.elapsed;

      if (response.statusCode == 200) {
        _recordSuccess(keyId, duration);
        debugPrint(
            '  ✅ $keyId (${config.displayName}): Success (${duration.inMilliseconds}ms)');
        return true;
      } else if (response.statusCode == 429) {
        _recordRateLimitError(keyId, 'Rate limit exceeded');
        debugPrint(
            '  ⚠️ $keyId (${config.displayName}): Rate limited (HTTP 429)');
        return false;
      } else {
        _recordFailure(keyId, 'HTTP ${response.statusCode}');
        debugPrint(
            '  ❌ $keyId (${config.displayName}): HTTP ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _recordFailure(keyId, e.toString());
      debugPrint('  ❌ $keyId: $e');
      return false;
    }
  }

  /// Update key status after testing
  void _updateKeyStatus(String keyId, bool isWorking) {
    final status = keyStatuses[keyId];
    if (status != null) {
      keyStatuses[keyId] = APIKeyStatus(
        provider: status.provider,
        modelId: status.modelId,
        keyPreview: status.keyPreview,
        isWorking: isWorking,
        lastTestedAt: DateTime.now(),
        successCount: status.successCount,
        failureCount: status.failureCount,
        lastErrorMessage: status.lastErrorMessage,
        averageResponseTime: status.averageResponseTime,
      );

      // Update provider lists
      if (isWorking) {
        if (!workingProviders.contains(status.provider)) {
          workingProviders.add(status.provider);
        }
        if (failedProviders.contains(status.provider)) {
          failedProviders.remove(status.provider);
        }
      } else {
        if (!failedProviders.contains(status.provider)) {
          failedProviders.add(status.provider);
        }
      }
    }
  }

  /// Record a successful request
  void _recordSuccess(String keyId, Duration duration) {
    final status = keyStatuses[keyId];
    if (status != null) {
      _requestTimings[keyId]?.add(duration);
      if (_requestTimings[keyId]!.length > 10) {
        _requestTimings[keyId]!.removeAt(0);
      }

      final avgDuration = _requestTimings[keyId]!.isNotEmpty
          ? Duration(
              milliseconds: _requestTimings[keyId]!
                      .fold<int>(0, (a, b) => a + b.inMilliseconds) ~/
                  _requestTimings[keyId]!.length)
          : null;

      keyStatuses[keyId] = APIKeyStatus(
        provider: status.provider,
        modelId: status.modelId,
        keyPreview: status.keyPreview,
        isWorking: true,
        lastTestedAt: DateTime.now(),
        successCount: status.successCount + 1,
        failureCount: status.failureCount,
        lastErrorMessage: null,
        averageResponseTime: avgDuration,
      );

      _consecutiveFailures[keyId] = 0;
    }
  }

  /// Record a failed request
  void _recordFailure(String keyId, String errorMessage) {
    final status = keyStatuses[keyId];
    if (status != null) {
      _consecutiveFailures[keyId] = (_consecutiveFailures[keyId] ?? 0) + 1;

      keyStatuses[keyId] = APIKeyStatus(
        provider: status.provider,
        modelId: status.modelId,
        keyPreview: status.keyPreview,
        isWorking: false,
        lastTestedAt: DateTime.now(),
        successCount: status.successCount,
        failureCount: status.failureCount + 1,
        lastErrorMessage: errorMessage,
        averageResponseTime: status.averageResponseTime,
      );
    }
  }

  /// Record rate limit error
  void _recordRateLimitError(String keyId, String errorMessage) {
    _recordFailure(keyId, errorMessage);
  }

  /// Generate test summary
  void _generateTestSummary() {
    debugPrint('\n');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('API KEYS INTELLIGENT TEST SUMMARY');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('');

    debugPrint('✅ Working Providers (${workingProviders.length}):');
    for (final provider in workingProviders) {
      debugPrint('  • $provider');
    }

    debugPrint('');
    debugPrint('❌ Failed Providers (${failedProviders.length}):');
    for (final provider in failedProviders) {
      debugPrint('  • $provider');
    }

    debugPrint('');
    debugPrint('📊 Detailed Key Status:');
    for (final entry in keyStatuses.entries) {
      final status = entry.value;
      debugPrint('');
      debugPrint(status.toString());
    }

    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');

    if (workingProviders.isEmpty) {
      debugPrint('');
      debugPrint(
          '🚨 CRITICAL: No working API providers found! System cannot process queries.');
      debugPrint('');
    }
  }

  // ════════════════════════════════════════════════════════════════
  // FALLBACK & ROUTING LOGIC
  // ════════════════════════════════════════════════════════════════

  /// Get the best working provider for a query type
  String? getBestProvider(QueryType queryType) {
    // Filter by working providers
    final working =
        keyStatuses.entries.where((e) => e.value.isWorking).toList();

    if (working.isEmpty) {
      return null;
    }

    // Sort by success rate and average response time
    working.sort((a, b) {
      final rateA = a.value.getSuccessRate();
      final rateB = b.value.getSuccessRate();

      if ((rateA - rateB).abs() > 5) {
        return rateB.compareTo(rateA); // Higher success rate first
      }

      // If rates are similar, prefer faster response time
      final timeA = a.value.averageResponseTime?.inMilliseconds ?? 0;
      final timeB = b.value.averageResponseTime?.inMilliseconds ?? 0;
      return timeA.compareTo(timeB);
    });

    return working.first.key;
  }

  /// Get fallback providers for a query type
  List<String> getFallbackProviders(String primaryKeyId, QueryType queryType) {
    final primaryStatus = keyStatuses[primaryKeyId];
    if (primaryStatus == null) return [];

    // Get all other working keys from different providers
    final fallbacks = keyStatuses.entries
        .where((e) =>
            e.key != primaryKeyId &&
            e.value.isWorking &&
            e.value.provider != primaryStatus.provider)
        .map((e) => e.key)
        .toList();

    // Sort by success rate
    fallbacks.sort((a, b) {
      final rateA = keyStatuses[a]?.getSuccessRate() ?? 0;
      final rateB = keyStatuses[b]?.getSuccessRate() ?? 0;
      return rateB.compareTo(rateA);
    });

    return fallbacks;
  }

  /// Get fallback strategy for different query types
  ModelFallbackStrategy getStrategyForQueryType(QueryType queryType) {
    final primary = getBestProvider(queryType);

    if (primary == null) {
      throw Exception('No working API providers available');
    }

    final fallbacks = getFallbackProviders(primary, queryType);

    return ModelFallbackStrategy(
      primaryProvider: primary,
      fallbackProviders: fallbacks,
      queryType: queryType,
    );
  }

  /// Check if system can handle queries
  bool canHandleQueries() {
    return workingProviders.isNotEmpty;
  }

  /// Get health status as percentage
  int getHealthStatus() {
    if (keyStatuses.isEmpty) return 0;

    final workingCount =
        keyStatuses.values.where((status) => status.isWorking).length;

    return ((workingCount / keyStatuses.length) * 100).toInt();
  }

  /// Get comprehensive status report
  String getStatusReport() {
    final buffer = StringBuffer();
    buffer
        .writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('API KEYS INTELLIGENT MANAGER — STATUS REPORT');
    buffer
        .writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('');

    buffer.writeln('Health Status: ${getHealthStatus()}%');
    buffer.writeln('Working Providers: ${workingProviders.length}');
    buffer.writeln('Failed Providers: ${failedProviders.length}');
    buffer.writeln('Total Keys: ${keyStatuses.length}');
    buffer.writeln(
        'Can Handle Queries: ${canHandleQueries() ? 'Yes ✅' : 'No ❌'}');
    buffer.writeln('');

    buffer.writeln('Working Providers:');
    for (final provider in workingProviders) {
      buffer.writeln('  ✅ $provider');
    }

    buffer.writeln('');
    buffer.writeln('Failed Providers:');
    for (final provider in failedProviders) {
      buffer.writeln('  ❌ $provider');
    }

    buffer
        .writeln('═══════════════════════════════════════════════════════════');

    return buffer.toString();
  }
}

/// Helper function
int min(int a, int b) => a < b ? a : b;
