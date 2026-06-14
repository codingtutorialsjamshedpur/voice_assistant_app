import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_app/services/api_keys_config.dart';
import 'package:get/get.dart';
import 'package:voice_assistant_app/services/storage_service.dart';
import 'package:voice_assistant_app/services/supabase_service.dart';
import 'package:get_storage/get_storage.dart';

void main() {
  test(
      'ApiKeysConfig should initialize with fallbacks when Supabase is not configured',
      () async {
    // Mock GetStorage
    await GetStorage.init();
    Get.put(StorageService());

    // Initialize Supabase (it will fail to connect but should not crash)
    final supabase = SupabaseService();
    Get.put(supabase);

    // Try to init config
    await ApiKeysConfig.init();

    // Check if keys are non-empty (fallbacks should have kicked in)
    expect(ApiKeysConfig.groqApiKeys, isNotEmpty);
    expect(ApiKeysConfig.nvidiaAuthTokens, isNotEmpty);
    expect(ApiKeysConfig.mistralApiKey, isNotEmpty);
    expect(ApiKeysConfig.geminiApiKey, isNotEmpty);
    expect(ApiKeysConfig.openRouterModels, isNotEmpty);

    print('✅ App survived unconfigured Supabase and used fallbacks safely.');
  });
}
