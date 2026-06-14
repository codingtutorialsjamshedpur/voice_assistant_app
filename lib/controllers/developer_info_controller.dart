library developer_info_controller;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../services/developer_info_service.dart';
import '../routes/app_routes.dart';

class DeveloperInfoController extends GetxController {
  final DeveloperInfoService _developerService = DeveloperInfoService();

  final currentDeveloperQueryCount = 0.obs;
  final lastDeveloperQueryTime = Rx<DateTime?>(null);
  final isDeveloperQueryMode = false.obs;

  Function(String)? onDeveloperInfoProvided;
  Function(String)? onRedirectingToAbout;

  Future<void> processDeveloperQuery(
    String userInput, {
    String? language,
    Function(String)? onSpeakMessage,
  }) async {
    final result = _developerService.detectDeveloperQuery(
      userInput,
      preferredLanguage: language,
    );

    debugPrint('🎯 [DevInfo] $result');

    if (!result.isDeveloperQuery) return;

    isDeveloperQueryMode.value = true;

    try {
      final response = _developerService.getDeveloperResponse(language: language);

      debugPrint('📢 [DevInfo] Response: $response');
      onSpeakMessage?.call(response);
      _trackDeveloperQuery();
      onDeveloperInfoProvided?.call(response);

      await Future.delayed(const Duration(seconds: 3));
      _redirectToAboutScreen();
    } catch (e) {
      debugPrint('❌ [DevInfo] Error: $e');
    } finally {
      isDeveloperQueryMode.value = false;
    }
  }

  String getDeveloperInfo({String? language = 'en'}) {
    return _developerService.getDeveloperResponse(language: language);
  }

  String getMainResponse({String? language = 'en'}) {
    return _developerService.getDeveloperResponse(language: language);
  }

  String getContactInfo({String? language = 'en'}) {
    return _developerService.getContactResponse(language: language);
  }

  bool isDeveloperRelatedQuery(String userInput, {String? language}) {
    final result = _developerService.detectDeveloperQuery(
      userInput,
      preferredLanguage: language,
    );
    return result.isDeveloperQuery;
  }

  void _trackDeveloperQuery() {
    currentDeveloperQueryCount.value++;
    lastDeveloperQueryTime.value = DateTime.now();
    debugPrint('📊 [DevInfo] Total queries: ${currentDeveloperQueryCount.value}');
  }

  void _redirectToAboutScreen() {
    try {
      debugPrint('🔀 [DevInfo] Navigating to About screen');
      onRedirectingToAbout?.call('Navigating to About screen');
      Get.offNamed(AppRoutes.about);
    } catch (e) {
      debugPrint('❌ [DevInfo] Error: $e');
    }
  }
}
