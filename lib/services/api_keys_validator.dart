/// ═══════════════════════════════════════════════════════════════
/// API Keys Validator — Test all API keys for functionality
/// ═══════════════════════════════════════════════════════════════
/// This service validates all API keys to ensure they work
/// If any key fails, the system provides a fallback mechanism
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_keys_config.dart';

class ApiKeyValidationResult {
  final String provider;
  final String key;
  final bool isValid;
  final String message;
  final int? statusCode;
  final String? errorDetails;

  ApiKeyValidationResult({
    required this.provider,
    required this.key,
    required this.isValid,
    required this.message,
    this.statusCode,
    this.errorDetails,
  });

  @override
  String toString() {
    return '[$provider] ${isValid ? '✅' : '❌'} ${key.substring(0, 15)}... - $message';
  }
}

class ApiKeysValidator extends GetxService {
  final validationResults = <ApiKeyValidationResult>[].obs;
  final isValidating = false.obs;
  final allKeysValid = false.obs;
  final failedProviders = <String>[].obs;
  final workingProviders = <String>[].obs;

  // ═══════════════════════════════════════════════════════════
  // TEST QUERIES
  // ═══════════════════════════════════════════════════════════
  static const String groqTestQuery = 'What is 2+2?';
  static const String nvidiaTestQuery = 'What is 2+2?';
  static const String openRouterTestQuery = 'What is 2+2?';
  static const String githubTestQuery = 'What is 2+2?';

  /// Validate all API keys
  Future<void> validateAllKeys() async {
    isValidating.value = true;
    validationResults.clear();
    failedProviders.clear();
    workingProviders.clear();

    debugPrint('🔍 Starting API Keys Validation...');

    // Test Groq keys
    await _validateGroqKeys();

    // Test NVIDIA keys
    await _validateNvidiaKeys();

    // Test OpenRouter keys
    await _validateOpenRouterKeys();

    // GitHub PAT removed - unauthorized (HTTP 401)
    // await _validateGithubPat();

    // Summary
    _generateSummary();

    isValidating.value = false;
    debugPrint('✅ Validation Complete!');
  }

  /// Validate Groq API keys
  Future<void> _validateGroqKeys() async {
    debugPrint('\n📌 Testing Groq API Keys...');

    for (final key in ApiKeysConfig.groqApiKeys) {
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
                    'content': groqTestQuery,
                  }
                ],
                'max_tokens': 100,
              }),
            )
            .timeout(const Duration(seconds: 15));

        final isValid = response.statusCode == 200;
        final result = ApiKeyValidationResult(
          provider: 'Groq',
          key: key,
          isValid: isValid,
          message: isValid
              ? 'Response received successfully'
              : 'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          errorDetails: !isValid ? response.body.substring(0, 100) : null,
        );

        validationResults.add(result);
        debugPrint('  $result');

        if (isValid && !workingProviders.contains('Groq')) {
          workingProviders.add('Groq');
        } else if (!isValid && !failedProviders.contains('Groq')) {
          failedProviders.add('Groq');
        }
      } catch (e) {
        final result = ApiKeyValidationResult(
          provider: 'Groq',
          key: key,
          isValid: false,
          message: 'Connection error',
          errorDetails: e.toString(),
        );

        validationResults.add(result);
        debugPrint('  $result');

        if (!failedProviders.contains('Groq')) {
          failedProviders.add('Groq');
        }
      }
    }
  }

  /// Validate NVIDIA NIM API keys
  Future<void> _validateNvidiaKeys() async {
    debugPrint('\n📌 Testing NVIDIA NIM API Keys...');

    for (final token in ApiKeysConfig.nvidiaAuthTokens) {
      try {
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
                    'content': nvidiaTestQuery,
                  }
                ],
                'temperature': 1,
                'top_p': 0.95,
                'max_tokens': 100,
              }),
            )
            .timeout(const Duration(seconds: 15));

        final isValid = response.statusCode == 200;
        final result = ApiKeyValidationResult(
          provider: 'NVIDIA NIM',
          key: token,
          isValid: isValid,
          message: isValid
              ? 'Response received successfully'
              : 'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          errorDetails: !isValid ? response.body.substring(0, 100) : null,
        );

        validationResults.add(result);
        debugPrint('  $result');

        if (isValid && !workingProviders.contains('NVIDIA NIM')) {
          workingProviders.add('NVIDIA NIM');
        } else if (!isValid && !failedProviders.contains('NVIDIA NIM')) {
          failedProviders.add('NVIDIA NIM');
        }
      } catch (e) {
        final result = ApiKeyValidationResult(
          provider: 'NVIDIA NIM',
          key: token,
          isValid: false,
          message: 'Connection error',
          errorDetails: e.toString(),
        );

        validationResults.add(result);
        debugPrint('  $result');

        if (!failedProviders.contains('NVIDIA NIM')) {
          failedProviders.add('NVIDIA NIM');
        }
      }
    }
  }

  /// Validate OpenRouter API keys
  Future<void> _validateOpenRouterKeys() async {
    debugPrint('\n📌 Testing OpenRouter API Keys...');

    for (final entry in ApiKeysConfig.openRouterModels.entries) {
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
                    'content': openRouterTestQuery,
                  }
                ],
                'max_tokens': 100,
              }),
            )
            .timeout(const Duration(seconds: 15));

        final isValid = response.statusCode == 200;
        final result = ApiKeyValidationResult(
          provider: 'OpenRouter - ${config.displayName}',
          key: config.apiKey,
          isValid: isValid,
          message: isValid
              ? 'Response received successfully'
              : 'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          errorDetails: !isValid ? response.body.substring(0, 100) : null,
        );

        validationResults.add(result);
        debugPrint('  $result');

        if (isValid &&
            !workingProviders.contains('OpenRouter - ${config.displayName}')) {
          workingProviders.add('OpenRouter - ${config.displayName}');
        } else if (!isValid &&
            !failedProviders.contains('OpenRouter - ${config.displayName}')) {
          failedProviders.add('OpenRouter - ${config.displayName}');
        }
      } catch (e) {
        final result = ApiKeyValidationResult(
          provider: 'OpenRouter - ${config.displayName}',
          key: config.apiKey,
          isValid: false,
          message: 'Connection error',
          errorDetails: e.toString(),
        );

        validationResults.add(result);
        debugPrint('  $result');

        if (!failedProviders.contains('OpenRouter - ${config.displayName}')) {
          failedProviders.add('OpenRouter - ${config.displayName}');
        }
      }
    }
  }

  /// GitHub PAT Validation - DISABLED (GitHub PAT requires "models" permission scope)
  /// Removed due to HTTP 401 Unauthorized error
  /*
  Future<void> _validateGithubPat() async {
    debugPrint('\n📌 Testing GitHub PAT...');

    try {
      final response = await http
          .post(
            Uri.parse('${ApiKeysConfig.githubBaseUrl}'),
            headers: {
              'Authorization': 'Bearer ${ApiKeysConfig.githubPat}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': ApiKeysConfig.githubModel,
              'messages': [
                {
                  'role': 'user',
                  'content': githubTestQuery,
                }
              ],
              'max_tokens': 100,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final isValid = response.statusCode == 200;
      final result = ApiKeyValidationResult(
        provider: 'GitHub/Azure',
        key: ApiKeysConfig.githubPat,
        isValid: isValid,
        message: isValid
            ? 'Response received successfully'
            : 'HTTP ${response.statusCode} - ${response.body}',
        statusCode: response.statusCode,
        errorDetails: !isValid ? response.body.substring(0, 100) : null,
      );

      validationResults.add(result);
      debugPrint('  $result');

      if (isValid && !workingProviders.contains('GitHub/Azure')) {
        workingProviders.add('GitHub/Azure');
      } else if (!isValid && !failedProviders.contains('GitHub/Azure')) {
        failedProviders.add('GitHub/Azure');
      }
    } catch (e) {
      final result = ApiKeyValidationResult(
        provider: 'GitHub/Azure',
        key: ApiKeysConfig.githubPat,
        isValid: false,
        message: 'Connection error',
        errorDetails: e.toString(),
      );

      validationResults.add(result);
      debugPrint('  $result');

      if (!failedProviders.contains('GitHub/Azure')) {
        failedProviders.add('GitHub/Azure');
      }
    }
  }
  */

  /// Generate validation summary
  void _generateSummary() {
    final hasAtLeastOneWorking = workingProviders.isNotEmpty;
    allKeysValid.value = failedProviders.isEmpty && workingProviders.isNotEmpty;

    debugPrint('\n');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('API KEYS VALIDATION SUMMARY');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('');

    if (allKeysValid.value) {
      debugPrint('✅ ALL API KEYS ARE WORKING!');
    } else if (hasAtLeastOneWorking) {
      debugPrint('⚠️  SOME API KEYS ARE WORKING (Fallbacks available)');
    } else {
      debugPrint('❌ NO API KEYS ARE WORKING! (CRITICAL)');
    }

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
    debugPrint('📊 Detailed Results:');
    for (final result in validationResults) {
      debugPrint('  $result');
    }

    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');

    if (!hasAtLeastOneWorking) {
      debugPrint('');
      debugPrint('🚨 CRITICAL: No working API keys found!');
      debugPrint('User will see: "samaj nahin aaya"');
      debugPrint('');
      debugPrint('Actions to take:');
      debugPrint('1. Check internet connection');
      debugPrint('2. Verify API keys are correct');
      debugPrint('3. Check if rate limits exceeded');
      debugPrint('4. Verify API service status');
      debugPrint('');
    }
  }

  /// Get validation report as string
  String getValidationReport() {
    final buffer = StringBuffer();
    buffer
        .writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('API VALIDATION REPORT — ${DateTime.now()}');
    buffer
        .writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('');

    buffer.writeln(
        'Status: ${allKeysValid.value ? '✅ All Working' : '⚠️  Some Failed'}');
    buffer.writeln('Working Providers: ${workingProviders.length}');
    buffer.writeln('Failed Providers: ${failedProviders.length}');
    buffer.writeln('Total Tests: ${validationResults.length}');
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

    buffer.writeln('');
    buffer
        .writeln('═══════════════════════════════════════════════════════════');

    return buffer.toString();
  }

  /// Check if at least one provider is working (can handle queries)
  bool canHandleQueries() {
    return workingProviders.isNotEmpty;
  }

  /// Get first working provider
  String? getFirstWorkingProvider() {
    return workingProviders.isNotEmpty ? workingProviders.first : null;
  }
}
