// lib/services/ad_service.dart

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService extends GetxService {
  // ─── Toggle this to switch between test and production ───────────────────
  static const bool _useTestAds =
      true; // ← Set to FALSE before Play Store release
  // ─────────────────────────────────────────────────────────────────────────

  // ── Test IDs (Google's official test ad units) ──────────────────────────
  static const String _testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';

  // ── Your Production IDs ─────────────────────────────────────────────────
  static const String _prodBannerId = 'ca-app-pub-8879732453847966/8610148608';
  static const String _prodInterstitialId =
      'ca-app-pub-8879732453847966/1633676712';

  // ── Resolved IDs (auto-selected based on _useTestAds) ───────────────────
  static String get bannerId => _useTestAds ? _testBannerId : _prodBannerId;
  static String get interstitialId =>
      _useTestAds ? _testInterstitialId : _prodInterstitialId;

  // ── Observables ─────────────────────────────────────────────────────────
  final RxBool isInitialized = false.obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeMobileAds();
  }

  Future<void> _initializeMobileAds() async {
    try {
      await MobileAds.instance.initialize();
      isInitialized.value = true;

      // Enable test device for physical device debugging
      // Find your test device ID from logcat output (search "Use RequestConfiguration")
      MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: [
            // Add your physical device test ID here after first run
            // Example: 'ABCDEF1234567890ABCDEF1234567890'
          ],
        ),
      );

      if (kDebugMode) {
        print(
            '✅ AdMob initialized. Using ${_useTestAds ? "TEST" : "PRODUCTION"} ads.');
      }
    } catch (e) {
      if (kDebugMode) print('❌ AdMob init failed: $e');
    }
  }
}
