/// ═══════════════════════════════════════════════════════════════
/// New API Keys Test Runner — Execute at app startup
/// ═══════════════════════════════════════════════════════════════
/// Run this in your main.dart to test all new API keys
/// Results will be printed to debug console
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'test_new_api_keys.dart';

/// Call this at app startup to test all new API keys
Future<void> testNewApiKeysAtStartup() async {
  debugPrint('\n');
  debugPrint('🚀 Starting API Keys Test at Startup...');
  debugPrint('');

  await TestNewApiKeys.runAllTests();

  debugPrint('');
  debugPrint('✅ Test Complete!');
  debugPrint('Report has been printed to debug console');
  debugPrint('Send the report to: shouravgupta@gmail.com');
  debugPrint('');
}

/// Alternative: Get report as string
Future<String> getApiKeysTestReport() async {
  await TestNewApiKeys.runAllTests();
  return TestNewApiKeys.getFullReport();
}

/// Example usage in main.dart:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   // Test new API keys
///   await testNewApiKeysAtStartup();
///
///   runApp(const MyApp());
/// }
/// ```
