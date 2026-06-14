import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'routes/app_routes.dart';
import 'services/sound_service.dart';
import 'services/storage_service.dart';
import 'services/language_model_service.dart';
import 'controllers/wallpaper_controller.dart';
import 'bindings/initial_bindings.dart';
import 'shared/controllers/top_panel_controller.dart';
import 'services/theme_service.dart';
import 'services/api_keys_config.dart';
import 'services/supabase_service.dart';
import 'services/ruflo_service.dart';
import 'services/emotion_service.dart';
import 'services/language_routing_service.dart';
import 'services/federation_service.dart';
import 'services/analytics_service.dart';
import 'services/subscription_service.dart';
import 'controllers/wallpaper_controller.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/ad_service.dart';
import 'controllers/interstitial_ad_controller.dart';
import 'controllers/navigation_controller.dart';
import 'services/voice_navigation_service.dart';
import 'shared/widgets/shared_widgets.dart';
import 'bindings/initial_bindings.dart';

// 1. Create a global RouteObserver to track screen transitions
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  // 1. Core initialization must happen first
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  // Fix 3: Initialize MobileAds SDK FIRST, before everything else
  await MobileAds.instance.initialize();

  // 2. Start all basic services in parallel to save time
  await Future.wait([
    Get.putAsync(() => StorageService().init()),
    Get.putAsync(() => ThemeService().init()),
    Get.putAsync(() => SoundService().init()),
    Get.putAsync<AdService>(() async => AdService()),
  ]);

  // 3. Initialize Supabase with a timeout to prevent white screen hangs
  await Get.putAsync(() => SupabaseService().init());

  // 4. Run the app immediately (don't wait for cloud sync to finish)
  // This ensures the Splash screen is shown instantly!
  runApp(const MyApp());

  // 5. Initialize heavy data (API Keys, Models, etc.) in the background
  _initSecondaryServices();
}

/// Services initialized in the background to prevent UI lag
void _initSecondaryServices() {
  // Sync API Keys (has its own internal try-catch and timeout protection)
  ApiKeysConfig.init();

  // Initialize other controllers and background services
  Get.putAsync(() => LanguageModelService().init());
  Get.put(WallpaperController(), permanent: true);

  // RuFlo & ecosystem services
  Get.put(RuFloService(), permanent: true);
  Get.put(EmotionService(), permanent: true);
  Get.put(LanguageRoutingService(), permanent: true);
  Get.put(FederationService(), permanent: true);
  Get.put(AnalyticsService(), permanent: true);
  Get.put(SubscriptionService(), permanent: true);

  // Fix 4: Register InterstitialAdController globally
  Get.put(InterstitialAdController(), permanent: true);

  // Voice navigation system - persistent across all screens
  Get.put(VoiceNavigationService(), permanent: true);
  Get.put(NavigationController(), permanent: true);

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'CTJ Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB2EE),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.transparent,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB2EE),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.transparent,
      ),
      builder: (context, child) {
        return GlobalWallpaper(child: child!);
      },
      themeMode: ThemeService.to.themeMode,
      initialBinding: InitialBindings(),
      initialRoute: AppRoutes.splash,
      getPages: AppRoutes.routes,
      navigatorObservers: [routeObserver], // Add route observer here
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 100),
      routingCallback: (routing) {
        if (routing?.current != null &&
            Get.isRegistered<TopPanelController>()) {
          Get.find<TopPanelController>().updateScreenContext(routing!.current);
        }
      },
    );
  }
}
