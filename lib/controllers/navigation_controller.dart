library navigation_controller;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../services/voice_navigation_service.dart';
import '../shared/controllers/top_panel_controller.dart';
import 'voice_controller.dart';

class NavigationController extends GetxController {
  final VoiceNavigationService _navService = Get.find<VoiceNavigationService>();

  final currentScreen = ''.obs;
  final navigationHistory = <String>[].obs;
  final isNavigating = false.obs;

  final enableNavigationFeedback = true.obs;
  final preferredLanguage = 'en'.obs;

  Function(NavigationIntent)? onNavigationIntentDetected;
  Function(String, String)? onNavigationConfirmed;
  Function(String)? onNavigationFailed;

  @override
  void onInit() {
    super.onInit();
    _setupScreenTracking();
    debugPrint('✅ [NavController] NavigationController initialized');
  }

  void _setupScreenTracking() {
    try {
      final topPanel = Get.find<TopPanelController>();
      ever(topPanel.currentRoute, (String route) {
        _updateCurrentScreen(route);
      });
      _updateCurrentScreen(topPanel.currentRoute.value);
    } catch (e) {
      debugPrint('⚠️ [NavController] TopPanelController not available: $e');
    }
  }

  Future<void> processNavigationQuery(
    String userInput, {
    String? language,
  }) async {
    isNavigating.value = true;

    try {
      final intent = await _navService.detectNavigationIntentMultilingual(
        userInput,
        currentRoute: currentScreen.value,
        preferredLanguage: language ?? preferredLanguage.value,
      );

      debugPrint('🎯 [NavController] Intent: $intent');
      onNavigationIntentDetected?.call(intent);

      if (!intent.isNavigationIntent) {
        debugPrint('❌ [NavController] Not a navigation query');
        return;
      }

      if (intent.targetRoute == currentScreen.value) {
        _speakFeedback(
          'You are already on ${intent.targetScreenName ?? "that"} screen',
          language,
        );
        onNavigationFailed?.call('Already on this screen');
        return;
      }

      if (intent.targetRoute == null) {
        _handleUnknownNavigation(intent, language);
        return;
      }

      if (intent.confidence >= 0.75) {
        await _navigateToScreen(
          intent.targetRoute!,
          intent.targetScreenName ?? 'screen',
          language,
        );
      } else if (intent.confidence >= 0.5) {
        _askForConfirmation(intent, language);
      } else {
        _handleUnknownNavigation(intent, language);
      }
    } catch (e) {
      debugPrint('❌ [NavController] Error: $e');
      _speakFeedback('Sorry, I could not process your navigation request', language);
    } finally {
      isNavigating.value = false;
    }
  }

  Future<void> navigateToScreen(
    String route, {
    String? screenName,
    String? language,
  }) async {
    if (!_isValidRoute(route)) {
      debugPrint('❌ [NavController] Invalid route: $route');
      return;
    }

    if (route == currentScreen.value) return;

    await _navigateToScreen(
      route,
      screenName ?? _navService.getDisplayName(route) ?? route,
      language,
    );
  }

  List<String> getAvailableScreens() {
    return _navService.getAllScreenNames();
  }

  bool isNavigationQuery(String userInput, {String? language}) {
    final intent = _navService.detectNavigationIntent(
      userInput,
      currentRoute: currentScreen.value,
      preferredLanguage: language ?? preferredLanguage.value,
    );
    return intent.isNavigationIntent;
  }

  void _updateCurrentScreen(String route) {
    final oldScreen = currentScreen.value;
    currentScreen.value = route;

    if (oldScreen.isNotEmpty && oldScreen != route) {
      navigationHistory.add(route);
      if (navigationHistory.length > 50) {
        navigationHistory.removeAt(0);
      }
      debugPrint('📍 [NavController] Screen: $oldScreen → $route');
    }
  }

  Future<void> _navigateToScreen(
    String route,
    String screenName,
    String? language,
  ) async {
    try {
      debugPrint('🚀 [NavController] → $route ($screenName)');

      _speakFeedback('Navigating to $screenName', language);

      await Get.offNamed(route);

      onNavigationConfirmed?.call(route, screenName);
      debugPrint('✅ [NavController] Done: $route');
    } catch (e) {
      debugPrint('❌ [NavController] Error: $e');
      _speakFeedback('Failed to navigate. Please try again.', language);
      onNavigationFailed?.call(e.toString());
    }
  }

  void _handleUnknownNavigation(NavigationIntent intent, String? language) {
    debugPrint('❓ [NavController] Unknown: ${intent.reason}');

    String feedback;
    if (intent.targetScreenName != null) {
      feedback =
          'I could not find a screen called "${intent.targetScreenName}". '
          'Would you like to try a different screen?';
    } else {
      feedback =
          'I did not understand which screen you want. '
          'Try saying a screen name like "Game", "Settings", or "Voice Chat".';
    }

    _speakFeedback(feedback, language);
    onNavigationFailed?.call('Could not identify target screen');
  }

  void _askForConfirmation(NavigationIntent intent, String? language) {
    final screenName = intent.targetScreenName ?? 'Unknown';
    _speakFeedback(
      'Did you mean $screenName? Say yes to go there, or no to cancel.',
      language,
    );
    onNavigationIntentDetected?.call(intent);
  }

  void _speakFeedback(String message, String? language) {
    if (!enableNavigationFeedback.value) return;
    try {
      if (Get.isRegistered<VoiceController>()) {
        Get.find<VoiceController>().ttsService.speak(message);
      }
    } catch (e) {
      debugPrint('⚠️ [NavController] TTS error: $e');
    }
  }

  bool _isValidRoute(String route) {
    return _navService.getAllRoutes().contains(route);
  }
}
