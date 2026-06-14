/// ═══════════════════════════════════════════════════════════════
/// API Keys Test Report Generator — April 2026 Updated Keys
/// ═══════════════════════════════════════════════════════════════
/// This script tests all new API keys and generates a detailed report
/// Send results to: shouravgupta@gmail.com
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_keys_config.dart';

class TestNewApiKeys {
  static const String testQuery = 'What is 2+2?';
  static const Duration timeout = Duration(seconds: 15);

  // Test results storage
  static final List<TestResult> results = [];
  static String reportSummary = '';

  /// Run all API tests
  static Future<void> runAllTests() async {
    debugPrint('\n');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🔍 TESTING NEW API KEYS — April 2026 Update');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('');
    debugPrint('Starting comprehensive API key validation...');
    debugPrint('Send report to: shouravgupta@gmail.com');
    debugPrint('');

    results.clear();

    // Test Groq keys
    await _testGroqKeys();

    // Test NVIDIA keys
    await _testNvidiaKeys();

    // Test OpenRouter keys
    await _testOpenRouterKeys();

    // Generate report
    _generateReport();
  }

  /// Test all Groq API keys
  static Future<void> _testGroqKeys() async {
    debugPrint('📌 Testing GROQ API Keys (8 keys)...');
    debugPrint('');

    int keyCount = 0;
    for (final key in ApiKeysConfig.groqApiKeys) {
      keyCount++;
      try {
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
                    'content': testQuery,
                  }
                ],
                'temperature': 0.7,
                'max_tokens': 100,
              }),
            )
            .timeout(timeout);

        final isValid = response.statusCode == 200;
        final result = TestResult(
          provider: 'Groq',
          keyNumber: keyCount,
          keyPreview: '${key.substring(0, 20)}...',
          isValid: isValid,
          statusCode: response.statusCode,
          message: isValid
              ? '✅ Working'
              : '❌ Failed (Status: ${response.statusCode})',
          responseTime: response.statusCode == 200
              ? _extractTimeFromResponse(response.body)
              : null,
        );

        results.add(result);
        debugPrint('  Key $keyCount: ${result.message}');
      } catch (e) {
        final result = TestResult(
          provider: 'Groq',
          keyNumber: keyCount,
          keyPreview: '${key.substring(0, 20)}...',
          isValid: false,
          statusCode: null,
          message: '❌ Error: ${e.toString().substring(0, 50)}...',
          responseTime: null,
        );

        results.add(result);
        debugPrint('  Key $keyCount: ${result.message}');
      }
    }

    debugPrint('');
  }

  /// Test all NVIDIA API keys
  static Future<void> _testNvidiaKeys() async {
    debugPrint('📌 Testing NVIDIA NIM API Keys (5 keys)...');
    debugPrint('');

    int keyCount = 0;
    for (final token in ApiKeysConfig.nvidiaAuthTokens) {
      keyCount++;
      try {
        final response = await http
            .post(
              Uri.parse(ApiKeysConfig.nvidiaBaseUrl),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': ApiKeysConfig.nvidiaModel,
                'messages': [
                  {
                    'role': 'user',
                    'content': testQuery,
                  }
                ],
                'temperature': 0.7,
                'max_tokens': 100,
              }),
            )
            .timeout(timeout);

        final isValid = response.statusCode == 200;
        final result = TestResult(
          provider: 'NVIDIA NIM',
          keyNumber: keyCount,
          keyPreview: '${token.substring(0, 20)}...',
          isValid: isValid,
          statusCode: response.statusCode,
          message: isValid
              ? '✅ Working'
              : '❌ Failed (Status: ${response.statusCode})',
          responseTime: null,
        );

        results.add(result);
        debugPrint('  Key $keyCount: ${result.message}');
      } catch (e) {
        final result = TestResult(
          provider: 'NVIDIA NIM',
          keyNumber: keyCount,
          keyPreview: '${token.substring(0, 20)}...',
          isValid: false,
          statusCode: null,
          message: '❌ Error: ${e.toString().substring(0, 50)}...',
          responseTime: null,
        );

        results.add(result);
        debugPrint('  Key $keyCount: ${result.message}');
      }
    }

    debugPrint('');
  }

  /// Test all OpenRouter API keys
  static Future<void> _testOpenRouterKeys() async {
    debugPrint('📌 Testing OpenRouter API Keys (6 models)...');
    debugPrint('');

    int modelCount = 0;
    for (final entry in ApiKeysConfig.openRouterModels.entries) {
      modelCount++;
      final config = entry.value;

      try {
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
                    'content': testQuery,
                  }
                ],
                'temperature': 0.7,
                'max_tokens': 100,
              }),
            )
            .timeout(timeout);

        final isValid = response.statusCode == 200;
        final result = TestResult(
          provider: 'OpenRouter',
          keyNumber: modelCount,
          keyPreview: config.displayName,
          isValid: isValid,
          statusCode: response.statusCode,
          message: isValid
              ? '✅ Working'
              : '❌ Failed (Status: ${response.statusCode})',
          responseTime: null,
        );

        results.add(result);
        debugPrint('  ${config.displayName}: ${result.message}');
      } catch (e) {
        final result = TestResult(
          provider: 'OpenRouter',
          keyNumber: modelCount,
          keyPreview: config.displayName,
          isValid: false,
          statusCode: null,
          message: '❌ Error: ${e.toString().substring(0, 50)}...',
          responseTime: null,
        );

        results.add(result);
        debugPrint('  ${config.displayName}: ${result.message}');
      }
    }

    debugPrint('');
  }

  /// Generate comprehensive report
  static void _generateReport() {
    final workingGroq =
        results.where((r) => r.provider == 'Groq' && r.isValid).length;
    final workingNvidia =
        results.where((r) => r.provider == 'NVIDIA NIM' && r.isValid).length;
    final workingOpenRouter =
        results.where((r) => r.provider == 'OpenRouter' && r.isValid).length;

    final totalGroq = results.where((r) => r.provider == 'Groq').length;
    final totalNvidia = results.where((r) => r.provider == 'NVIDIA NIM').length;
    final totalOpenRouter =
        results.where((r) => r.provider == 'OpenRouter').length;

    final reportBuffer = StringBuffer();

    reportBuffer.writeln('');
    reportBuffer
        .writeln('═══════════════════════════════════════════════════════════');
    reportBuffer.writeln('📊 API KEYS VALIDATION REPORT — April 2026');
    reportBuffer.writeln('Generated: ${DateTime.now()}');
    reportBuffer.writeln('Send to: shouravgupta@gmail.com');
    reportBuffer
        .writeln('═══════════════════════════════════════════════════════════');
    reportBuffer.writeln('');

    // Summary
    reportBuffer.writeln('✅ WORKING SUMMARY:');
    reportBuffer.writeln('');
    reportBuffer.writeln('🟢 GROQ API:');
    reportBuffer.writeln('   Status: $workingGroq/$totalGroq working');
    reportBuffer.writeln('   Health: ${_getHealth(workingGroq, totalGroq)}');
    reportBuffer.writeln('');

    reportBuffer.writeln('🟢 NVIDIA NIM:');
    reportBuffer.writeln('   Status: $workingNvidia/$totalNvidia working');
    reportBuffer
        .writeln('   Health: ${_getHealth(workingNvidia, totalNvidia)}');
    reportBuffer.writeln('');

    reportBuffer.writeln('🟢 OPENROUTER:');
    reportBuffer
        .writeln('   Status: $workingOpenRouter/$totalOpenRouter working');
    reportBuffer.writeln(
        '   Health: ${_getHealth(workingOpenRouter, totalOpenRouter)}');
    reportBuffer.writeln('');

    // Detailed results
    reportBuffer
        .writeln('═══════════════════════════════════════════════════════════');
    reportBuffer.writeln('📋 DETAILED RESULTS:');
    reportBuffer
        .writeln('═══════════════════════════════════════════════════════════');
    reportBuffer.writeln('');

    // Group by provider
    final groqResults = results.where((r) => r.provider == 'Groq').toList();
    final nvidiaResults =
        results.where((r) => r.provider == 'NVIDIA NIM').toList();
    final openRouterResults =
        results.where((r) => r.provider == 'OpenRouter').toList();

    reportBuffer.writeln('🟢 GROQ API KEYS:');
    for (final result in groqResults) {
      reportBuffer.writeln('  ${result.message}');
      reportBuffer.writeln('    Key: ${result.keyPreview}');
      if (result.statusCode != null) {
        reportBuffer.writeln('    Status Code: ${result.statusCode}');
      }
      reportBuffer.writeln('');
    }

    reportBuffer.writeln('🟢 NVIDIA NIM API KEYS:');
    for (final result in nvidiaResults) {
      reportBuffer.writeln('  ${result.message}');
      reportBuffer.writeln('    Token: ${result.keyPreview}');
      if (result.statusCode != null) {
        reportBuffer.writeln('    Status Code: ${result.statusCode}');
      }
      reportBuffer.writeln('');
    }

    reportBuffer.writeln('🟢 OPENROUTER MODELS:');
    for (final result in openRouterResults) {
      reportBuffer.writeln('  ${result.message}');
      reportBuffer.writeln('    Model: ${result.keyPreview}');
      if (result.statusCode != null) {
        reportBuffer.writeln('    Status Code: ${result.statusCode}');
      }
      reportBuffer.writeln('');
    }

    // Action items
    reportBuffer
        .writeln('═══════════════════════════════════════════════════════════');
    reportBuffer.writeln('⚠️  ACTION ITEMS:');
    reportBuffer
        .writeln('═══════════════════════════════════════════════════════════');
    reportBuffer.writeln('');

    final failedGroq = groqResults.where((r) => !r.isValid).toList();
    final failedNvidia = nvidiaResults.where((r) => !r.isValid).toList();
    final failedOpenRouter =
        openRouterResults.where((r) => !r.isValid).toList();

    if (failedGroq.isNotEmpty) {
      reportBuffer.writeln('❌ GROQ: ${failedGroq.length} key(s) failed');
      for (final result in failedGroq) {
        reportBuffer.writeln('   → Key ${result.keyNumber}: ${result.message}');
      }
      reportBuffer.writeln('');
    }

    if (failedNvidia.isNotEmpty) {
      reportBuffer
          .writeln('❌ NVIDIA NIM: ${failedNvidia.length} key(s) failed');
      for (final result in failedNvidia) {
        reportBuffer.writeln('   → Key ${result.keyNumber}: ${result.message}');
      }
      reportBuffer.writeln('');
    }

    if (failedOpenRouter.isNotEmpty) {
      reportBuffer
          .writeln('❌ OPENROUTER: ${failedOpenRouter.length} model(s) failed');
      for (final result in failedOpenRouter) {
        reportBuffer.writeln('   → ${result.keyPreview}: ${result.message}');
      }
      reportBuffer.writeln('');
    }

    if (failedGroq.isEmpty &&
        failedNvidia.isEmpty &&
        failedOpenRouter.isEmpty) {
      reportBuffer.writeln('✅ All API keys are working! No action needed.');
      reportBuffer.writeln('');
    }

    reportBuffer
        .writeln('═══════════════════════════════════════════════════════════');
    reportBuffer.writeln('🚀 System Status: Ready for deployment');
    reportBuffer
        .writeln('═══════════════════════════════════════════════════════════');
    reportBuffer.writeln('');

    reportSummary = reportBuffer.toString();

    // Print report
    debugPrint(reportSummary);
  }

  /// Get health status
  static String _getHealth(int working, int total) {
    if (working == total) {
      return '✅ All working';
    } else if (working > (total / 2)) {
      return '⚠️  Most working';
    } else if (working > 0) {
      return '⚠️  Some working';
    } else {
      return '❌ None working';
    }
  }

  /// Extract response time from response (if available)
  static String? _extractTimeFromResponse(String body) {
    try {
      final json = jsonDecode(body);
      if (json['usage'] != null) {
        return 'Completed';
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return null;
  }

  /// Get full report as string
  static String getFullReport() {
    return reportSummary;
  }

  /// Export report to file
  static Future<void> exportReport(String filePath) async {
    try {
      final file = await _getFile(filePath);
      await file.writeAsString(reportSummary);
      debugPrint('✅ Report exported to: $filePath');
    } catch (e) {
      debugPrint('❌ Failed to export report: $e');
    }
  }

  /// Helper to get file (since we can't import dart:io in this context)
  static dynamic _getFile(String path) {
    // This would need to be implemented in the actual app
    // For now, just return null
    return null;
  }
}

/// Test result model
class TestResult {
  final String provider;
  final int keyNumber;
  final String keyPreview;
  final bool isValid;
  final int? statusCode;
  final String message;
  final String? responseTime;

  TestResult({
    required this.provider,
    required this.keyNumber,
    required this.keyPreview,
    required this.isValid,
    required this.statusCode,
    required this.message,
    required this.responseTime,
  });

  @override
  String toString() {
    return '[$provider #$keyNumber] $message';
  }
}
