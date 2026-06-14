// lib/controllers/interstitial_ad_controller.dart

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

class InterstitialAdController extends GetxController {
  InterstitialAd? _interstitialAd;
  final RxBool isReady = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadAd();
  }

  void loadAd() {
    InterstitialAd.load(
      adUnitId: AdService.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          isReady.value = true;

          // Set full-screen callback to reload after dismiss
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              isReady.value = false;
              loadAd(); // Pre-load next ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              isReady.value = false;
              loadAd();
            },
          );

          if (kDebugMode) print('✅ Interstitial loaded.');
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode) print('❌ Interstitial failed: ${error.message}');
          isReady.value = false;
        },
      ),
    );
  }

  /// Call this to show the ad. Returns true if shown.
  bool showAd() {
    if (_interstitialAd != null && isReady.value) {
      _interstitialAd!.show();
      return true;
    }
    if (kDebugMode) print('ℹ️ Interstitial not ready yet.');
    return false;
  }

  @override
  void onClose() {
    _interstitialAd?.dispose();
    super.onClose();
  }
}
