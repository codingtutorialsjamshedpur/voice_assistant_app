import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:voice_assistant_app/services/ai_model_manager.dart';
import 'package:voice_assistant_app/services/open_router_service.dart';
import 'package:voice_assistant_app/services/api_keys_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voice_assistant_app/services/supabase_service.dart';

void main() {
  test('Health Checks Test', () async {
    WidgetsFlutterBinding.ensureInitialized();
    final supabaseService = await SupabaseService().init();

    await ApiKeysConfig.init();

    Get.put(OpenRouterService());
    final manager = Get.put(AIModelManager());

    print("Testing health...");
    manager.initializeHealthChecks();

    // wait for health checks to finish
    await Future.delayed(Duration(seconds: 40));

    print("Health Checks complete:");
    manager.providerHealth.forEach((provider, health) {
      print("${provider.name}: ${health.name}");
    });
  });
}
