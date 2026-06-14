import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import '../../controllers/voice_controller.dart';
import '../../services/god_mode_intelligence_service.dart';

class TopPanelController extends GetxController {
  final RxBool isExpanded = false.obs;
  final RxBool isHovering = false.obs;

  // Shared color state for both panels
  final RxInt currentColorIndex = 0.obs;
  final _random = Random();

  // Weather & AQI State
  final RxString placeName = 'Detecting...'.obs;
  final RxString temperature = '--'.obs;
  final RxString aqi = '--'.obs;
  final RxDouble temperatureNum = 0.0.obs;
  final RxInt aqiNum = 0.obs;
  final RxString error = ''.obs;
  final RxBool isLoadingWeather = false.obs;

  // Screen awareness state
  final RxString currentRoute = '/splash'.obs;
  final RxString currentScreenContext = 'Splash screen (loading).'.obs;

  static const Map<String, String> _screenFeatures = {
    '/splash': 'Splash screen (loading).',
    '/welcome': 'Welcome screen where users get an introduction to the app.',
    '/authentication':
        'Login or Signup page for users to authenticate themselves.',
    '/profile': 'User profile page to edit name and title.',
    '/voice-chat':
        'Standard Voice Chat page where users can chat with the AI Orb.',
    '/voice-chat-v2': 'Advanced Voice Chat interface v2 with more options.',
    '/extended-voice-chat': 'Extended Voice Chat for longer conversations.',
    '/unified-voice': 'Unified Voice interface bringing all modes together.',
    '/game': 'Game Hub screen to select various voice-controlled games.',
    '/game-play': 'Active game play screen where the user is playing a game.',
    '/voice-studio': 'Voice Studio to record custom voice models.',
    '/alarm': 'Alarms list screen.',
    '/alarm-edit': 'Screen to edit or create a new alarm.',
    '/alarm-ringing': 'Screen showing an actively ringing alarm.',
    '/naam-jaap':
        'Naam Jaap screen for spiritual chanting and mantra repetitions.',
    '/history': 'History screen showing past conversations and activities.',
    '/about': 'About screen containing app information.',
    '/settings': 'Settings screen to configure preferences.',
    '/wallpaper':
        'Wallpaper screen to browse available live/static wallpapers.',
    '/wallpaper-set': 'Screen to preview and apply a selected wallpaper.',
    '/reminder': 'Reminders list screen.',
    '/reminder-edit': 'Screen to add or edit a reminder.',
    '/pdf-viewer': 'PDF Viewer screen to read documents.',
    '/privacy': 'Privacy settings screen.',
    '/notifications': 'Notification settings screen.',
    '/language-coach':
        'Language Coach screen where users can learn and practice pronunciation in various languages.',
  };

  void updateScreenContext(String route) {
    if (route.isEmpty) return;
    currentRoute.value = route;
    currentScreenContext.value =
        _screenFeatures[route] ?? 'Custom or unknown screen ($route).';

    // Notify AIContextController about the screen change (if registered)
    try {
      // Import is avoided here to prevent circular dependency;
      // AIContextController observes TopPanelController.currentRoute via ever()
      debugPrint('📍 [TopPanel] Screen context updated → $route');
    } catch (_) {}
  }

  // Timer for color cycling
  Timer? _colorTimer;

  // 15 distinct vibrant color shades - completely independent of theme
  final List<Color> glassColors = [
    const Color(0xFF00FFFF), // Cyan
    const Color(0xFFFF00FF), // Magenta
    const Color(0xFFFF1493), // Deep Pink
    const Color(0xFF00CED1), // Dark Turquoise
    const Color(0xFFFF4500), // Orange Red
    const Color(0xFF7B68EE), // Medium Slate Blue
    const Color(0xFFFFD700), // Gold
    const Color(0xFFFF6347), // Tomato
    const Color(0xFF1E90FF), // Dodger Blue
    const Color(0xFFFFA500), // Orange
    const Color(0xFF20B2AA), // Light Sea Green
    const Color(0xFFFF6B6B), // Light Red
    const Color(0xFF4ECDC4), // Medium Aquamarine
    const Color(0xFFF7DC6F), // Soft Yellow
    const Color(0xFFBB8FCE), // Soft Purple
  ];

  Color get currentColor => glassColors[currentColorIndex.value];

  @override
  void onInit() {
    super.onInit();
    // Start with random color
    currentColorIndex.value = _random.nextInt(glassColors.length);
    _startColorTimer();
    checkServicesAndFetch();
  }

  Future<void> checkServicesAndFetch({bool forceRefresh = false}) async {
    // Check GPS
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (Get.isRegistered<VoiceController>()) {
        Get.find<VoiceController>()
            .ttsService
            .speak('Please turn on GPS Location');
      }
      _showErrorDialog('GPS Disabled', 'Please turn on GPS Location.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorDialog(
          'Permission Denied',
          'Location permission is required.',
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorDialog(
        'Permission Denied',
        'Location permission is permanently denied. Please enable it in settings.',
      );
      return;
    }

    // Fetch Data
    await fetchWeatherAndAqi(forceRefresh: forceRefresh);
  }

  void _showErrorDialog(String title, String message) {
    if (Get.isDialogOpen == true) return;
    Get.defaultDialog(
      title: title,
      middleText: message,
      backgroundColor: Colors.black87,
      titleStyle: const TextStyle(color: Colors.white),
      middleTextStyle: const TextStyle(color: Colors.white70),
      confirm: TextButton(
        onPressed: () {
          Get.back();
          checkServicesAndFetch(forceRefresh: true); // Retry
        },
        child: const Text('Retry', style: TextStyle(color: Colors.cyanAccent)),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> fetchWeatherAndAqi({bool forceRefresh = false}) async {
    try {
      isLoadingWeather.value = true;
      debugPrint('🌍 Starting GPS fetch...');

      // Get current position with proper error handling
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      debugPrint(
          '📍 Got position: ${position.latitude}, ${position.longitude}');

      // Delegate all complex fetching to GodModeIntelligenceService
      final godModeService = Get.find<GodModeIntelligenceService>();
      await godModeService.fetchAllIntelligence(
          lat: position.latitude,
          lon: position.longitude,
          forceRefresh: forceRefresh);

      final godData = godModeService.data.value;
      if (godData != null) {
        placeName.value = godData.local.city;
        temperatureNum.value = godData.weather.temperature;
        temperature.value = '${godData.weather.temperature}°C';
        aqiNum.value = godData.environment.aqi;
        aqi.value = godData.environment.aqi.toString();
        error.value = '';
        debugPrint('✅ God Mode payload fetched successfully');
      } else {
        throw Exception('Failed to load God Mode intelligence data');
      }

      error.value = '';
    } catch (e) {
      error.value = 'Failed to load data: $e';
      debugPrint('❌ Weather Error: $e');
      temperature.value = '--';
      aqi.value = '--';
      placeName.value = 'your area';
    } finally {
      isLoadingWeather.value = false;
    }
  }

  /// Refresh weather data (called when user taps on weather pills)
  Future<void> refreshWeather() async {
    debugPrint('🔄 Manual refresh triggered');
    await checkServicesAndFetch();
  }

  @override
  void onClose() {
    _colorTimer?.cancel();
    super.onClose();
  }

  void _startColorTimer() {
    _colorTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _cycleColor();
    });
  }

  void _cycleColor() {
    int newIndex;
    do {
      newIndex = _random.nextInt(glassColors.length);
    } while (newIndex == currentColorIndex.value && glassColors.length > 1);
    currentColorIndex.value = newIndex;
  }

  // Calculate dark variant of current color for selected icon highlight
  Color getDarkVariant([Color? color]) {
    final baseColor = color ?? currentColor;
    final hsl = HSLColor.fromColor(baseColor);
    // Darken by reducing lightness by 30-40%
    final darkenedLightness = (hsl.lightness - 0.35).clamp(0.0, 1.0);
    // Slightly increase saturation for more vibrancy
    final increasedSaturation = (hsl.saturation * 1.2).clamp(0.0, 1.0);
    return hsl
        .withLightness(darkenedLightness)
        .withSaturation(increasedSaturation)
        .toColor();
  }

  void expand() {
    isExpanded.value = true;
  }

  void collapse() {
    isExpanded.value = false;
  }

  void toggle() {
    isExpanded.value = !isExpanded.value;
  }

  void setHovering(bool hovering) {
    isHovering.value = hovering;
    if (hovering) {
      expand();
    } else {
      collapse();
    }
  }

  bool get isDesktop => !kIsWeb && (GetPlatform.isDesktop || GetPlatform.isWeb);
}
