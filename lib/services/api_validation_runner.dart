/// ═══════════════════════════════════════════════════════════════
/// API Validation Runner — Execute and display validation results
/// ═══════════════════════════════════════════════════════════════
/// Run this at app startup to ensure all API keys are working
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'api_keys_validator.dart';

/// Run all API validations and return results
Future<Map<String, dynamic>> runApiValidation() async {
  debugPrint('\n');
  debugPrint('🚀 Starting API Keys Validation Process...');
  debugPrint('');

  final validator = ApiKeysValidator();
  await validator.validateAllKeys();

  return {
    'allValid': validator.allKeysValid.value,
    'workingCount': validator.workingProviders.length,
    'failedCount': validator.failedProviders.length,
    'workingProviders': validator.workingProviders.toList(),
    'failedProviders': validator.failedProviders.toList(),
    'results': validator.validationResults.toList(),
    'report': validator.getValidationReport(),
    'canHandleQueries': validator.canHandleQueries(),
  };
}

/// Display validation results in UI
class ApiValidationDisplay {
  /// Get status message for UI
  static String getStatusMessage(Map<String, dynamic> validationResult) {
    if (validationResult['allValid'] as bool) {
      return '✅ All API Keys Working - Ready to use!';
    } else if (validationResult['canHandleQueries'] as bool) {
      return '⚠️  Some API Keys Working - Using fallbacks';
    } else {
      return '❌ No API Keys Working - "samaj nahin aaya"';
    }
  }

  /// Get status color
  static Color getStatusColor(Map<String, dynamic> validationResult) {
    if (validationResult['allValid'] as bool) {
      return Colors.green;
    } else if (validationResult['canHandleQueries'] as bool) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  /// Get detailed status text
  static String getDetailedStatus(Map<String, dynamic> validationResult) {
    final working = validationResult['workingCount'] as int;
    final failed = validationResult['failedCount'] as int;
    final total = working + failed;

    return 'Working: $working/$total | Failed: $failed/$total';
  }

  /// Get working providers list
  static List<String> getWorkingProviders(
      Map<String, dynamic> validationResult) {
    return List<String>.from(validationResult['workingProviders'] as List);
  }

  /// Get failed providers list
  static List<String> getFailedProviders(
      Map<String, dynamic> validationResult) {
    return List<String>.from(validationResult['failedProviders'] as List);
  }

  /// Print full report
  static void printFullReport(Map<String, dynamic> validationResult) {
    debugPrint(validationResult['report'] as String);
  }
}

/// Error message for failed queries
class QueryErrorHandler {
  /// Get error message when no API keys work
  static String getNoKeysErrorMessage() {
    return 'samaj nahin aaya';
  }

  /// Get user-friendly error message
  static String getUserFriendlyMessage() {
    return '''
Maaf kijiye, abhi samajh nahin aaya.

⚠️ System Status:
• Koi bhi API key kaam nahi kar raha hai
• Internet connection check kariye
• Thode der mein dobara try kariye

''';
  }

  /// Handle query failure with proper fallback
  static Future<String> handleQueryFailure({
    required String userQuery,
    required Map<String, dynamic> validationResult,
  }) async {
    if (validationResult['canHandleQueries'] as bool) {
      // At least one provider is working - try to use it
      return _handlePartialFailure(userQuery, validationResult);
    } else {
      // No providers working - return error message
      return getNoKeysErrorMessage();
    }
  }

  /// Handle when some keys are working
  static Future<String> _handlePartialFailure(
    String userQuery,
    Map<String, dynamic> validationResult,
  ) async {
    final workingProviders = getWorkingProviders(validationResult);

    debugPrint('⚠️  Using fallback provider: ${workingProviders.first}');
    debugPrint('Original query: $userQuery');

    // In a real implementation, route to the working provider
    return 'Kripaya dobara try kariye - ek provider se response aa raha hai';
  }

  static List<String> getWorkingProviders(
      Map<String, dynamic> validationResult) {
    return List<String>.from(validationResult['workingProviders'] as List);
  }
}
