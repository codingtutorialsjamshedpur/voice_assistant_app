/// ═══════════════════════════════════════════════════════════════
/// Google Search Service — DISABLED
/// ═══════════════════════════════════════════════════════════════
/// Google Search / SerpAPI has been disabled (April 2026 update).
/// All queries now processed directly by AI models.
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class GoogleSearchService extends GetxService {
  final isSearching = false.obs;
  final lastSearchQuery = ''.obs;
  final lastSearchResults = ''.obs;

  /// Fetch real-time data for a query
  /// Returns null - SERP API disabled
  /// Note: Service disabled (April 2026 update - SERP API not configured)
  Future<String?> fetchRealTimeData(String query) async {
    if (query.trim().isEmpty) return null;

    isSearching.value = true;
    lastSearchQuery.value = query;

    try {
      // SERP API is no longer available - service disabled
      debugPrint('⚠️ SERP Search Service: Disabled (SERP API not configured)');
      debugPrint('   Using AI models only for response generation');
      return null;
    } finally {
      isSearching.value = false;
    }
  }
}
