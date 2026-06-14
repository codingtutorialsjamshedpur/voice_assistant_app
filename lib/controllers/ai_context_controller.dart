/// ════════════════════════════════════════════════════════════════
/// AI Context Controller — Real-time screen awareness for AI
/// ════════════════════════════════════════════════════════════════
///
/// Maintains awareness of the user's current screen and builds
/// context-injected system prompts for the AI assistant.
///
/// Integrates with:
///   - TopPanelController (receives route changes)
///   - ScreenKnowledgeBase (looks up screen metadata)
///   - QueryHandlerService (provides context-enriched prompts)
///
/// Mapped to task.md Task 1.1: Create Core Controllers Structure
/// ════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../data/screen_knowledge_base.dart';
import '../data/guidance_scripts.dart';
import '../data/language_strings.dart';
import '../models/screen_info.dart';
import '../shared/controllers/top_panel_controller.dart';
import '../services/ruflo_service.dart';
import '../services/god_mode_intelligence_service.dart';

class GoalPlan {
  final String goalTitle;
  final int totalDays;
  final List<String> milestones;
  final List<String> dailyTasks;

  const GoalPlan({
    required this.goalTitle,
    required this.totalDays,
    required this.milestones,
    required this.dailyTasks,
  });

  factory GoalPlan.fromJson(Map<String, dynamic> json) {
    return GoalPlan(
      goalTitle: json['goalTitle'] as String? ?? '',
      totalDays: (json['totalDays'] as num?)?.toInt() ?? 30,
      milestones: List<String>.from(json['milestones'] ?? []),
      dailyTasks: List<String>.from(json['dailyTasks'] ?? []),
    );
  }
}

class AIContextController extends GetxController {
  final _ruflo = RuFloService();

  // ── Observable State ──────────────────────────────────────────
  final RxString currentRoute = '/voice-chat'.obs;
  final RxString currentScreenName = 'Voice Chat'.obs;
  final RxString currentScreenContext = ''.obs;
  final RxString preferredLanguage = 'hinglish'.obs;

  // ── Date/Time awareness ────────────────────────────────────────
  DateTime get now => DateTime.now();

  // ── Lifecycle ─────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();

    // Sync with TopPanelController if already registered
    try {
      final topPanel = Get.find<TopPanelController>();
      // Observe route changes from the top panel
      ever(topPanel.currentRoute, (String route) {
        updateCurrentScreen(route);
      });
      // Initialize with the current route
      updateCurrentScreen(topPanel.currentRoute.value);
    } catch (e) {
      debugPrint('⚠️ [AIContext] TopPanelController not registered yet: $e');
    }

    debugPrint('✅ [AIContext] AIContextController initialized');
  }

  // ═══════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════

  /// Called whenever the user navigates to a new screen.
  void updateCurrentScreen(String route) {
    if (route.isEmpty) return;
    final info = ScreenKnowledgeBase.getScreenInfo(route);
    currentRoute.value = route;
    currentScreenName.value =
        info?.displayName ?? ScreenKnowledgeBase.getDisplayName(route);
    currentScreenContext.value =
        ScreenKnowledgeBase.buildSystemPromptSection(route);

    debugPrint(
        '📍 [AIContext] Screen updated → ${currentScreenName.value} ($route)');
  }

  /// Returns the ScreenInfo for the current screen (or null if unknown)
  ScreenInfo? getCurrentScreenInfo() {
    return ScreenKnowledgeBase.getScreenInfo(currentRoute.value);
  }

  /// Returns all available voice commands on the current screen
  List<String> getAvailableVoiceCommands() {
    return getCurrentScreenInfo()?.voiceCommands ?? [];
  }

  /// Returns all screen names this screen can navigate to
  List<String> getNavigationTargets() {
    return getCurrentScreenInfo()?.navigatesTo ?? [];
  }

  /// Returns description of all buttons on the current screen
  String getButtonDescriptions() {
    final info = getCurrentScreenInfo();
    if (info == null || info.buttons.isEmpty) return '';
    return info.buttons.map((b) => '${b.name}: ${b.description}').join('\n');
  }

  /// Returns description of all gestures on the current screen
  String getGestureDescriptions() {
    final info = getCurrentScreenInfo();
    if (info == null || info.gestures.isEmpty) return '';
    return info.gestures.map((g) => g.toString()).join('\n');
  }

  // ═══════════════════════════════════════════════════════════════
  // SYSTEM PROMPT BUILDING
  // ═══════════════════════════════════════════════════════════════

  /// Builds the full AI system prompt, injecting screen context,
  /// app overview, developer info, and language instructions.
  ///
  /// Use this as the system prompt for all voice-assistant queries.
  String buildFullSystemPrompt({
    AssistantLanguage language = AssistantLanguage.hinglish,
    bool includeFullAppSummary = false,
  }) {
    final langInstruction = LanguageStrings.buildLanguageInstruction(language);
    final screenContext = currentScreenContext.value.isNotEmpty
        ? currentScreenContext.value
        : ScreenKnowledgeBase.buildSystemPromptSection(currentRoute.value);

    final buffer = StringBuffer();

    buffer.writeln('═' * 60);
    buffer.writeln('AI VOICE ASSISTANT — SYSTEM PROMPT');
    buffer.writeln('═' * 60);
    buffer.writeln();

    buffer.writeln('YOU ARE: A friendly, helpful AI voice assistant built');
    buffer.writeln('into a Flutter app called "CTJ AI Voice Assistant".');
    buffer.writeln('Developer: Sourav Kumar');
    buffer.writeln('Current Date: ${_formatDate(now)}');
    buffer.writeln('Current Time: ${_formatTime(now)}');
    buffer.writeln();

    buffer.writeln('LANGUAGE INSTRUCTION:');
    buffer.writeln(langInstruction);
    buffer.writeln();

    buffer.writeln('─' * 60);
    buffer.writeln('CURRENT SCREEN CONTEXT:');
    buffer.writeln('─' * 60);
    buffer.writeln(screenContext);
    buffer.writeln();

    if (includeFullAppSummary) {
      buffer.writeln('─' * 60);
      buffer.writeln(ScreenKnowledgeBase.buildFullAppSummary());
      buffer.writeln();
    }

    try {
      if (Get.isRegistered<GodModeIntelligenceService>()) {
        final godService = Get.find<GodModeIntelligenceService>();
        if (godService.data.value != null) {
          final godData = godService.data.value!;
          buffer.writeln('─' * 60);
          buffer.writeln('GOD MODE INTELLIGENCE (ENVIRONMENTAL CONTEXT):');
          buffer.writeln('─' * 60);
          buffer.writeln(
              'Location: ${godData.local.city}, ${godData.local.state}');
          buffer.writeln(
              'Weather: ${godData.weather.temperature}°C, ${godData.weather.rainChance}% chance of precipitation. Wind: ${godData.weather.windSpeed}km/h');
          buffer.writeln(
              'Environment: Air Quality AQI is ${godData.environment.aqi}, UV Index is ${godData.health.uvIndex}, Pollen: ${godData.health.pollenInfo}');
          buffer.writeln(
              'Sun & Moon: Sunrise ${godData.sun.sunrise}, Sunset ${godData.sun.sunset}. Moon Phase is ${godData.moon.phase}');
          if (godData.local.festival != 'No major festival') {
            buffer.writeln('Local Events: ${godData.local.festival}');
          }
          if (godData.smartAlerts.isNotEmpty) {
            buffer.writeln('SMART ALERTS: ${godData.smartAlerts}');
          }
          buffer.writeln(
              "Proactively use this environmental data if it relates to the user's query.");
          buffer.writeln();
        }
      }
    } catch (_) {}

    buffer.writeln('─' * 60);
    buffer.writeln('BEHAVIOR RULES:');
    buffer.writeln('─' * 60);
    buffer.writeln(
        '1. Always be friendly, warm, and encouraging. You are talking to real users.');
    buffer.writeln(
        '2. Use simple, conversational language. Avoid technical jargon.');
    buffer.writeln(
        '3. Support Hindi, English, and Hinglish — match the user\'s language.');
    buffer
        .writeln('4. Be child-friendly and safe. No harmful or adult content.');
    buffer.writeln(
        '5. Answer questions about any screen, not just the current one.');
    buffer.writeln(
        '6. If asked about the developer, say it was built by Sourav Kumar.');
    buffer.writeln(
        '7. Guide users to the About screen for developer contact info.');
    buffer.writeln(
        '8. Never expose backend logic, API keys, or technical implementation details.');
    buffer.writeln(
        '9. For real-time data (weather, news) use the provided search context.');
    buffer.writeln(
        '10. Keep responses concise — this will be spoken aloud via TTS.');
    buffer
        .writeln('11. Do NOT use markdown, bullet points, or special symbols.');
    buffer.writeln(
        '12. Do NOT say "I\'m an AI" repeatedly — just be helpful directly.');
    buffer.writeln();

    buffer.writeln('═' * 60);

    return buffer.toString();
  }

  /// Builds a shorter context-only snippet for injection into existing prompts
  String buildContextSnippet() {
    final buffer = StringBuffer();
    buffer.writeln('SCREEN CONTEXT:');
    buffer.writeln(currentScreenContext.value);
    buffer.writeln();
    buffer.writeln('CURRENT TIME: ${_formatTime(now)}');
    buffer.writeln();

    try {
      if (Get.isRegistered<GodModeIntelligenceService>()) {
        final godService = Get.find<GodModeIntelligenceService>();
        if (godService.data.value != null) {
          final godData = godService.data.value!;
          buffer.writeln('GOD MODE INTELLIGENCE (LIVE ENVIRONMENTAL DATA):');
          buffer.writeln(
              'Location: ${godData.local.city}, ${godData.local.state}');
          buffer.writeln(
              'Weather: ${godData.weather.temperature}°C, ${godData.weather.rainChance}% chance of precipitation. Wind: ${godData.weather.windSpeed}km/h');
          buffer.writeln(
              'Air Quality AQI: ${godData.environment.aqi}, UV Index: ${godData.health.uvIndex}, Pollen: ${godData.health.pollenInfo}');
          buffer.writeln(
              'Sun/Moon: Sunrise ${godData.sun.sunrise}, Sunset ${godData.sun.sunset}. Moon Phase: ${godData.moon.phase}');
          if (godData.local.festival != 'No major festival') {
            buffer.writeln('Local Events: ${godData.local.festival}');
          }
          buffer.writeln(
              'Emergency Matrix: Police (${godData.emergency.police}), Fire (${godData.emergency.fire}), Ambulance (${godData.emergency.ambulance}), General (${godData.emergency.standardGeneral})');
          if (godData.smartAlerts.isNotEmpty) {
            buffer.writeln('SMART ALERTS: ${godData.smartAlerts}');
          }
          buffer.writeln(
              'IMPORTANT: Directly comment on, or proactively factor in this environmental intelligence into your response where applicable.');
        }
      }
    } catch (_) {}

    return buffer.toString();
  }

  Future<GoalPlan?> createGoalPlan(String goalStatement) async {
    try {
      final result = await _ruflo.swarmQuery(
        input: goalStatement,
        agents: ['goal_planner', 'conversation_memory'],
        context: {
          'userId': 'current',
        },
      );
      return GoalPlan.fromJson(result);
    } catch (e) {
      return null;
    }
  }

  Future<void> checkGoalProgress(String goalId) async {
    unawaited(_ruflo.callTool('goal_check_in', {
      'goalId': goalId,
      'userId': 'current',
      'today': DateTime.now().toIso8601String(),
    }));
  }

  // ═══════════════════════════════════════════════════════════════
  // GUIDANCE HELPERS
  // ═══════════════════════════════════════════════════════════════

  /// Returns the appropriate screen intro guidance script
  String getScreenIntroScript({String language = 'hinglish'}) {
    return GuidanceScripts.getScreenIntro(
      currentRoute.value,
      language: language,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}
