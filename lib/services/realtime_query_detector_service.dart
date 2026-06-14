/// ═══════════════════════════════════════════════════════════════
/// Real-Time Query Detector Service
/// ═══════════════════════════════════════════════════════════════
///
/// Detects when users ask for real-time data and provides appropriate
/// privacy-focused responses as per CTJ team design requirements.
///
/// Features:
/// - Detects real-time queries (news, weather, stocks, etc.)
/// - Provides privacy-focused responses
/// - Handles developer inquiry with navigation to about screen
/// - Different behavior for voice chat vs game screens
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../routes/app_routes.dart';

class RealtimeQueryDetectorService extends GetxService {
  /// Standard privacy response for real-time queries
  static const String privacyResponse =
      "I can't access real-time data due to strict privacy design by the CTJ team. "
      "Your data stays safe — I'll help using my trained knowledge 😊";

  /// Developer inquiry response
  static const String developerResponse =
      'The creator is Er. Shourav Kumar. He does A.I assisted developments and '
      'loves to build out of the box projects. Contact him!';

  /// Real-time query patterns (Now excluding News and Weather as they are supported)
  static const List<String> realtimePatterns = [
    // Sports scores and live matches
    'live score', 'current score', 'match score', 'game score', 'sports score',
    'who is winning', 'match result', 'live match', 'cricket score',
    'football score',
    'match update', 'sports update', 'live sports',

    // Stock market and crypto
    'stock price', 'share price', 'market price', 'stock market',
    'crypto price',
    'bitcoin price', 'ethereum price', 'live trading', 'market update',
    'stock update', 'crypto update', 'currency rate', 'exchange rate',

    // Traffic and transportation
    'traffic now', 'live traffic', 'traffic update', 'road condition',
    'traffic jam', 'route status', 'transport update',

    // Social media and trending
    'trending now', 'viral now', 'trending topics', 'what\'s trending',
    'social media update', 'twitter trending', 'instagram trending',

    // Live data requests
    'real time', 'live data', 'current data', 'up to date', 'latest update',
    'right now', 'at this moment', 'currently happening',

    // Hindi/Hinglish patterns
    'live score kya hai',
    'match ka score', 'abhi kya chal raha hai',
  ];

  /// Developer inquiry patterns (REMOVED as per user request)
  static const List<String> developerPatterns = [];

  /// Check if the query is asking for real-time data
  bool isRealtimeQuery(String query) {
    final lowerQuery = query.toLowerCase().trim();

    return realtimePatterns
        .any((pattern) => lowerQuery.contains(pattern.toLowerCase()));
  }

  /// Check if the query is asking about the developer
  bool isDeveloperInquiry(String query) {
    // Disabled as per user request to no longer trigger on creator/developer patterns
    return false;
  }

  /// Handle real-time query based on current screen context
  String? handleRealtimeQuery(String query, {String? currentScreen}) {
    if (isDeveloperInquiry(query)) {
      return _handleDeveloperInquiry(currentScreen);
    }

    if (isRealtimeQuery(query)) {
      return privacyResponse;
    }

    return null; // Not a real-time query
  }

  /// Handle developer inquiry with conditional navigation
  String _handleDeveloperInquiry(String? currentScreen) {
    debugPrint(
        '🔍 [RealtimeDetector] Developer inquiry detected from screen: $currentScreen');

    // For voice chat screen: provide response and navigate to about screen
    if (currentScreen == AppRoutes.voiceChat) {
      // Navigate to about screen after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        debugPrint('🧭 [RealtimeDetector] Navigating to about screen');
        Get.toNamed(AppRoutes.about);
      });

      return developerResponse;
    }

    // For game screen: only provide response, no navigation
    if (currentScreen == AppRoutes.game) {
      return developerResponse;
    }

    // Default behavior for other screens
    return developerResponse;
  }

  /// Get detailed analysis of the query type
  Map<String, dynamic> analyzeQuery(String query) {
    return {
      'isRealtime': isRealtimeQuery(query),
      'isDeveloperInquiry': isDeveloperInquiry(query),
      'query': query,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
