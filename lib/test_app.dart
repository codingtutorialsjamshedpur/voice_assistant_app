/// ════════════════════════════════════════════════════════════════
/// API Keys Comprehensive Testing Application
/// ════════════════════════════════════════════════════════════════
///
/// This is a standalone test application to validate all API keys
/// and demonstrate the fallback system in action.
///
/// Run with: flutter run -t lib/test_app.dart
/// ════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'services/api_keys_intelligent_manager.dart';
import 'services/intelligent_fallback_query_handler.dart';

import 'services/supabase_service.dart';
import 'services/api_keys_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Supabase
  await Get.putAsync(() => SupabaseService().init());

  // 2. Initialize Config (Syncs from Supabase)
  await ApiKeysConfig.init();

  // 3. Initialize Intelligent Managers
  Get.put(ApiKeysIntelligentManager());
  Get.put(IntelligentFallbackQueryHandler());

  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'API Keys Testing Suite',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ApiKeysTestScreen(),
    );
  }
}

class ApiKeysTestScreen extends StatefulWidget {
  const ApiKeysTestScreen({super.key});

  @override
  State<ApiKeysTestScreen> createState() => _ApiKeysTestScreenState();
}

class _ApiKeysTestScreenState extends State<ApiKeysTestScreen> {
  late ApiKeysIntelligentManager _keyManager;
  late IntelligentFallbackQueryHandler _fallbackHandler;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() async {
    _keyManager = Get.find<ApiKeysIntelligentManager>();
    _fallbackHandler = Get.find<IntelligentFallbackQueryHandler>();

    // Start testing
    await _keyManager.testAllKeys();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Keys Testing Suite'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Overview
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Obx(() => _buildStatusRow(
                        'Health', '${_keyManager.getHealthStatus()}%')),
                    const SizedBox(height: 12),
                    Obx(() => _buildStatusRow(
                          'Can Handle Queries',
                          _keyManager.canHandleQueries() ? '✅ Yes' : '❌ No',
                        )),
                    const SizedBox(height: 12),
                    Obx(() => _buildStatusRow('Working Providers',
                        '${_keyManager.workingProviders.length}')),
                    const SizedBox(height: 12),
                    Obx(() => _buildStatusRow('Failed Providers',
                        '${_keyManager.failedProviders.length}')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Working Providers
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Working Providers ✅',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Obx(() {
                      if (_keyManager.workingProviders.isEmpty) {
                        return const Text('No working providers',
                            style: TextStyle(color: Colors.grey));
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _keyManager.workingProviders
                            .map((p) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Text('• $p',
                                      style:
                                          const TextStyle(color: Colors.green)),
                                ))
                            .toList(),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Failed Providers
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Failed Providers ❌',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Obx(() {
                      if (_keyManager.failedProviders.isEmpty) {
                        return const Text('No failed providers',
                            style: TextStyle(color: Colors.grey));
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _keyManager.failedProviders
                            .map((p) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Text('• $p',
                                      style:
                                          const TextStyle(color: Colors.red)),
                                ))
                            .toList(),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Key Details
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detailed Key Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Obx(() {
                      if (_keyManager.keyStatuses.isEmpty) {
                        return const Text('No keys initialized',
                            style: TextStyle(color: Colors.grey));
                      }
                      return Column(
                        children: _keyManager.keyStatuses.entries
                            .map((entry) =>
                                _buildKeyStatusTile(entry.key, entry.value))
                            .toList(),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Test Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _keyManager.testAllKeys();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tests completed!')),
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Re-Test All Keys'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showStatusReport(),
                    icon: const Icon(Icons.info),
                    label: const Text('Status Report'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Test Query Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Query with Fallback',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _executeTestQuery(),
                      icon: const Icon(Icons.send),
                      label: const Text('Execute Test Query'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildKeyStatusTile(String keyId, APIKeyStatus status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: status.isWorking ? Colors.green.shade50 : Colors.red.shade50,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '$keyId (${status.provider})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  status.isWorking ? '✅' : '❌',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Success: ${status.successCount}',
                    style: const TextStyle(fontSize: 11)),
                Text('Failure: ${status.failureCount}',
                    style: const TextStyle(fontSize: 11)),
                Text('Rate: ${status.getSuccessRate().toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 11)),
              ],
            ),
            if (status.lastErrorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Error: ${status.lastErrorMessage}',
                  style: const TextStyle(fontSize: 10, color: Colors.red),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showStatusReport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Status Report'),
        content: SingleChildScrollView(
          child: Text(_keyManager.getStatusReport()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _executeTestQuery() async {
    if (!_keyManager.canHandleQueries()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No working API providers. Cannot execute query.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('Executing Test Query...'),
        content: SizedBox(
          height: 100,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );

    try {
      final result = await _fallbackHandler.executeWithFallback(
        query: 'What is 2+2?',
        systemPrompt: 'You are a helpful assistant.',
        queryType: QueryType.general,
      );

      if (!mounted) return;
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Query Result'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Status: ${result.success ? '✅ Success' : '❌ Failed'}'),
                const SizedBox(height: 12),
                Text('Provider: ${result.usedProvider} (${result.usedKeyId})'),
                const SizedBox(height: 12),
                Text('Attempts: ${result.attemptCount}'),
                const SizedBox(height: 12),
                Text(
                    'Execution Time: ${result.executionTime.inMilliseconds}ms'),
                const SizedBox(height: 12),
                if (result.response != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Response:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(result.response!),
                    ],
                  ),
                if (result.errorMessage != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Error:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(result.errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
