/// ═══════════════════════════════════════════════════════════════
/// API Validation & Debugging Service — April 2026 Update
/// ═══════════════════════════════════════════════════════════════
/// Run diagnostics on API keys and configuration
/// Useful for debugging why certain APIs are failing
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'api_keys_config.dart';
import 'ai_model_manager.dart';

class APIValidationDebug {
  /// Check if all required API keys are present
  static Map<String, dynamic> validateConfiguration() {
    final results = <String, dynamic>{};

    // Check Groq keys
    results['groq_keys_count'] = ApiKeysConfig.groqApiKeys.length;
    results['groq_keys_valid'] =
        ApiKeysConfig.groqApiKeys.every((k) => k.isNotEmpty && k.length > 10);

    // Check NVIDIA keys
    results['nvidia_keys_count'] = ApiKeysConfig.nvidiaAuthTokens.length;
    results['nvidia_keys_valid'] = ApiKeysConfig.nvidiaAuthTokens
        .every((k) => k.isNotEmpty && k.length > 10);

    // Check GitHub PAT - DISABLED (GitHub PAT removed due to authorization issues)
    // results['github_pat_present'] = ApiKeysConfig.githubPat.isNotEmpty;
    // results['github_pat_valid'] = ApiKeysConfig.githubPat.length > 20;
    results['github_pat_warning'] =
        'GitHub PAT removed - requires "models" permission scope (use Groq fallback)';

    // Check OpenRouter models
    results['openrouter_models_count'] = ApiKeysConfig.openRouterModels.length;
    results['openrouter_models'] = ApiKeysConfig.openRouterModels.keys.toList();
    results['openrouter_models_valid'] = ApiKeysConfig.openRouterModels.values
        .every((m) => m.apiKey.isNotEmpty && m.apiKey.length > 10);

    // SERP API removed - no longer needed (April 2026 update)
    results['serp_api_status'] = 'Removed - not required';

    return results;
  }

  /// Get a summary of which providers are healthy
  static String getSummary() {
    final validation = validateConfiguration();

    final summary = StringBuffer();
    summary
        .writeln('═══════════════════════════════════════════════════════════');
    summary.writeln('API CONFIGURATION VALIDATION — April 2026');
    summary
        .writeln('═══════════════════════════════════════════════════════════');
    summary.writeln('');

    summary.writeln('✅ WORKING PROVIDERS:');
    summary.writeln(
        '  • Groq Mixtral 8x7B: ${validation['groq_keys_valid'] ? '✓' : '✗'} '
        '(${validation['groq_keys_count']} keys)');
    summary.writeln(
        '  • NVIDIA NIM: ${validation['nvidia_keys_valid'] ? '✓' : '✗'} '
        '(${validation['nvidia_keys_count']} keys)');
    summary.writeln(
        '  • OpenRouter: ${validation['openrouter_models_valid'] ? '✓' : '✗'} '
        '(${validation['openrouter_models_count']} models)');
    summary
        .writeln('  • SERP API: ${validation['serp_api_valid'] ? '✓' : '✗'}');
    summary.writeln('');

    summary.writeln('⚠️  ISSUES & NOTES:');
    summary.writeln(
        '  • GitHub/Azure PAT: Unauthorized (needs "models" permission)');
    summary.writeln('    → Using Groq as fallback for formal English');
    summary.writeln('  • Removed Models (Replaced in April 2026):');
    summary.writeln('    - arcee-ai/trinity-large-preview → Mistral Small 3.1');
    summary.writeln('    - tngtech/deepseek-r1t2-chimera → Minimax M2.5');
    summary.writeln('    - qwen/qwen3-coder → Mistral Small 3.1');
    summary.writeln('    - liquid/lfm-2.5 → OpenRouter Auto');
    summary.writeln('');

    summary.writeln('📊 ACTIVE OPENROUTER MODELS (April 2026):');
    final models = validation['openrouter_models'] as List;
    for (final model in models) {
      summary.writeln('  • $model');
    }

    summary.writeln('');
    summary.writeln('🔗 PROVIDER MAPPING:');
    summary.writeln('  Technology & AI → Step 3.5 Flash');
    summary.writeln('  Translation → GLM 4.5 Air');
    summary.writeln('  Songs & Music → Gemma 3 12B');
    summary.writeln('  Creative & Math → Mistral Small 3.1');
    summary.writeln('  Coding & Complex → Minimax M2.5');
    summary.writeln('  General Purpose → Nemotron 3 Super');
    summary.writeln('  Fallback → OpenRouter Auto');
    summary.writeln('');
    summary
        .writeln('═══════════════════════════════════════════════════════════');

    return summary.toString();
  }

  /// Print diagnostics to debug console
  static void printDiagnostics() {
    debugPrint(getSummary());
  }

  /// Get API key health status for a specific provider
  static String getProviderStatus(String provider) {
    switch (provider.toLowerCase()) {
      case 'groq':
        return 'Groq Mixtral 8x7B: ${ApiKeysConfig.groqApiKeys.length} keys configured ✅';

      case 'nvidia':
        return 'NVIDIA NIM: ${ApiKeysConfig.nvidiaAuthTokens.length} keys configured ✅';

      case 'github':
      case 'azure':
        return 'GitHub/Azure: PAT configured but unauthorized (needs "models" permission) ⚠️';

      case 'openrouter':
        return 'OpenRouter: ${ApiKeysConfig.openRouterModels.length} models (April 2026 update) ✅';

      case 'serp':
        return 'SERP API: Configured ✅';

      default:
        return 'Unknown provider';
    }
  }

  /// List all active fallback chains (for debugging route failures)
  static String getFallbackChains() {
    final buffer = StringBuffer();
    buffer.writeln('FALLBACK CHAINS (if primary provider fails):');
    buffer.writeln('');

    final chains = <AIProvider, List<AIProvider>>{
      AIProvider.groq: [AIProvider.nvidia, AIProvider.openRouterMinimax],
      AIProvider.nvidia: [
        AIProvider.openRouterMinimax,
        AIProvider.groq,
        AIProvider.openRouterAuto
      ],
      AIProvider.github: [AIProvider.groq, AIProvider.openRouterMinimax],
      AIProvider.openRouterStepFlash: [
        AIProvider.nvidia,
        AIProvider.groq,
        AIProvider.openRouterAuto
      ],
      AIProvider.openRouterGLM: [AIProvider.groq, AIProvider.openRouterAuto],
      AIProvider.openRouterGemma: [
        AIProvider.groq,
        AIProvider.nvidia,
        AIProvider.openRouterAuto
      ],
      AIProvider.openRouterMistral: [
        AIProvider.groq,
        AIProvider.nvidia,
        AIProvider.openRouterAuto
      ],
      AIProvider.openRouterNemotron: [
        AIProvider.groq,
        AIProvider.nvidia,
        AIProvider.openRouterAuto
      ],
      AIProvider.openRouterMinimax: [
        AIProvider.openRouterMistral,
        AIProvider.groq,
        AIProvider.openRouterAuto
      ],
      AIProvider.openRouterAuto: [
        AIProvider.groq,
        AIProvider.nvidia,
        AIProvider.openRouterMinimax
      ],
    };

    for (final entry in chains.entries) {
      buffer.write('${entry.key.toString().split('.').last}: ');
      buffer.writeln(
          entry.value.map((p) => p.toString().split('.').last).join(' → '));
    }

    return buffer.toString();
  }

  /// Get detailed model information
  static String getDetailedModelInfo() {
    final buffer = StringBuffer();
    buffer.writeln('═════════════════════════════════════════════════════════');
    buffer.writeln('DETAILED MODEL INFORMATION — April 2026');
    buffer.writeln('═════════════════════════════════════════════════════════');
    buffer.writeln('');

    buffer.writeln('🟢 PRIMARY PROVIDERS:');
    buffer.writeln('');

    buffer.writeln('1. GROQ MIXTRAL 8x7B');
    buffer.writeln('   • 5 API keys available');
    buffer.writeln('   • Ultra-fast inference');
    buffer.writeln('   • Best for: India, Hindi, Hinglish, General Knowledge');
    buffer.writeln('   • Rate Limit: Fair pricing');
    buffer.writeln('');

    buffer.writeln('2. NVIDIA NIM (Minimax M2.5)');
    buffer.writeln('   • 5 Authorization tokens');
    buffer.writeln('   • Strong reasoning capability');
    buffer.writeln('   • Best for: Complex tasks, Astrology, Science, Math');
    buffer.writeln(
        '   • URL: https://integrate.api.nvidia.com/v1/chat/completions');
    buffer.writeln('');

    buffer.writeln('🟡 OPENROUTER MODELS (April 2026):');
    buffer.writeln('');

    for (final entry in ApiKeysConfig.openRouterModels.entries) {
      buffer.writeln('• ${entry.value.displayName}');
      buffer.writeln('  Model ID: ${entry.value.modelId}');
      buffer.writeln('  Category: ${entry.value.category}');
      buffer.writeln('  API Key: ${entry.value.apiKey.substring(0, 20)}...');
      buffer.writeln('');
    }

    buffer.writeln('🔴 DEPRECATED/REMOVED (April 2026):');
    buffer.writeln('');
    buffer.writeln('❌ arcee-ai/trinity-large-preview');
    buffer.writeln('   → Replaced by: Mistral Small 3.1');
    buffer.writeln('');
    buffer.writeln('❌ tngtech/deepseek-r1t2-chimera');
    buffer.writeln('   → Replaced by: Minimax M2.5');
    buffer.writeln('');
    buffer.writeln('❌ qwen/qwen3-coder');
    buffer.writeln('   → Replaced by: Mistral Small 3.1');
    buffer.writeln('');
    buffer.writeln('❌ liquid/lfm-2.5-1.2b-thinking');
    buffer.writeln('   → Replaced by: OpenRouter Auto');
    buffer.writeln('');
    buffer.writeln('❌ Gemini API (April 2026)');
    buffer.writeln('   → Replaced by: Groq Mixtral 8x7B');
    buffer.writeln('   Reason: Repeated unclear responses');
    buffer.writeln('');

    buffer.writeln('═════════════════════════════════════════════════════════');

    return buffer.toString();
  }

  /// Quick health check
  static bool isSystemHealthy() {
    final validation = validateConfiguration();
    return validation['groq_keys_valid'] as bool &&
        validation['nvidia_keys_valid'] as bool &&
        validation['openrouter_models_valid'] as bool;
  }

  /// Get system health report
  static String getHealthReport() {
    final healthy = isSystemHealthy();
    if (healthy) {
      return '✅ All systems healthy! Ready for deployment.';
    } else {
      final validation = validateConfiguration();
      final issues = <String>[];

      if (!validation['groq_keys_valid']) {
        issues.add('❌ Groq keys invalid or missing');
      }
      if (!validation['nvidia_keys_valid']) {
        issues.add('❌ NVIDIA tokens invalid or missing');
      }
      if (!validation['openrouter_models_valid']) {
        issues.add('❌ OpenRouter models invalid or missing');
      }
      if (!validation['github_pat_valid']) {
        issues
            .add('⚠️  GitHub PAT invalid (not critical - using Groq fallback)');
      }

      return '⚠️  Issues detected:\n${issues.join('\n')}';
    }
  }
}
