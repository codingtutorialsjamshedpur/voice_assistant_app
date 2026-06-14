// lib/services/greeting_service.dart
// Phase 2 - Three-Part Greeting System
// Manages initial welcome messages on chat screen load

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/voice_controller.dart';
import '../controllers/profile_controller.dart';
import '../shared/controllers/top_panel_controller.dart';

/// Service to manage the three-part greeting system:
/// Message 1: Immediate greeting (0 seconds)
/// Message 2: Contextual with weather/location (30-40 seconds)
/// Message 3+: Smart poking every 20-30 seconds after
class GreetingService extends GetxService {
  static GreetingService get to => Get.find();

  VoiceController? _voiceController;
  Timer? _message2Timer;
  Timer? _message3Timer;

  final hasShownInitialGreeting = false.obs;

  @override
  void onClose() {
    _message2Timer?.cancel();
    _message3Timer?.cancel();
    super.onClose();
  }

  /// Initialize greeting system when voice chat screen is loaded
  Future<void> initializeGreetings() async {
    if (hasShownInitialGreeting.value) return;

    try {
      _voiceController = Get.find<VoiceController>();
      final profileController = Get.find<ProfileController>();
      final profile = profileController.userProfile.value;

      // Message 1: Immediate greeting
      await _sendMessage1Greeting(profile);

      // Message 2: Contextual greeting (delayed by 30-40 seconds)
      _message2Timer = Timer(const Duration(seconds: 35), () async {
        await _sendMessage2Contextual(profile);
      });

      hasShownInitialGreeting.value = true;
    } catch (e) {
      debugPrint('Error in GreetingService.initializeGreetings: $e');
    }
  }

  /// Message 1: Immediate welcome with festival wishes
  Future<void> _sendMessage1Greeting(dynamic profile) async {
    try {
      final name = profile.name ?? 'Friend';
      final timeOfDay = _getTimeOfDay();
      final festival = _getCurrentFestival();

      String greeting = 'Namaste $name, $timeOfDay. ';

      if (festival.isNotEmpty) {
        greeting += 'Aapko $festival ki hardik shubhkamnayein. ';
      }

      greeting += 'CTJ Voice app mein aapka swagat hai! 🙏';

      // Add as AI message and speak
      await _addMessageAndSpeak(greeting);
    } catch (e) {
      debugPrint('Error sending Message 1: $e');
    }
  }

  /// Message 2: Contextual greeting with weather/location/AQI
  Future<void> _sendMessage2Contextual(dynamic profile) async {
    try {
      final topPanel = Get.find<TopPanelController>();
      final name = profile.name ?? 'Friend';

      // Get weather and AQI data from top panel
      final temperature = topPanel.temperature.value;
      final aqi = topPanel.aqi.value;
      final city = profile.city ?? 'aapke city';

      String message = '$name, aapke $city ka temperature $temperature hai. ';

      if (aqi != '--') {
        message += 'AQI $aqi hai. ';
        // Check if AQI is high
        final aqiNum = topPanel.aqiNum.value;
        if (aqiNum > 150) {
          message += 'Bahar jaate waqt mask laga lijiye. 😷 ';
        }
      }

      // Get user's field of interest from profile
      final interest = profile.anticipation ?? '';
      if (interest.isNotEmpty) {
        message += 'Aap $interest improve karne ke liye kuch poochna chahenge?';
      } else {
        message += 'Mein aapki madad ke liye yaha hoon. Kya poochna hai?';
      }

      await _addMessageAndSpeak(message);
    } catch (e) {
      debugPrint('Error sending Message 2: $e');
    }
  }

  /// Get current time period (Morning, Afternoon, Evening, Night)
  String _getTimeOfDay() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Good Evening';
    } else {
      return 'Good Night';
    }
  }

  /// Get current festival (simplified - can be extended)
  String _getCurrentFestival() {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;

    // Add major festivals - this is a simplified version
    // In production, fetch from Google Calendar API or similar
    final festivals = {
      (1, 26): 'Republic Day',
      (3, 8): 'Maha Shivaratri',
      (3, 25): 'Holi',
      (4, 14): 'Baisakhi',
      (8, 15): 'Independence Day',
      (8, 26): 'Janmashtami',
      (9, 16): 'Milad-un-Nabi',
      (10, 2): 'Gandhi Jayanti',
      (10, 12): 'Dussehra',
      (10, 31): 'Diwali',
      (11, 1): 'Diwali',
      (12, 25): 'Christmas',
    };

    final key = (month, day);
    return festivals[key] ?? '';
  }

  /// Add message to chat and speak it
  Future<void> _addMessageAndSpeak(String text) async {
    if (_voiceController == null) return;

    try {
      // Create assistant message
      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'assistant',
        content: text,
        timestamp: DateTime.now(),
        modelName: 'CTJ Greeting',
      );

      // Add to messages list
      _voiceController!.messages.add(message);

      // Speak the message
      _voiceController!.speakMessage(message);
    } catch (e) {
      debugPrint('Error adding and speaking message: $e');
    }
  }

  /// Reset greeting for testing
  void resetGreeting() {
    hasShownInitialGreeting.value = false;
    _message2Timer?.cancel();
    _message3Timer?.cancel();
  }
}
