import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'open_router_service.dart';
import 'ai_model_manager.dart';

class VoiceCommandParser extends GetxService {
  static VoiceCommandParser get to => Get.find<VoiceCommandParser>();

  Future<Map<String, dynamic>> parseMultilingualIntent(String rawText) async {
    try {
      final aiManager = Get.find<AIModelManager>();
      final router = Get.find<OpenRouterService>();
      final route = aiManager.routeQuery(rawText);

      final prompt = '''
You are a highly intelligent JSON intent parser for a voice-controlled Tic-Tac-Toe game.
You must compensate for bad Speech-to-Text (STT) misspellings (e.g., "had" or "heart" = "hard", "easy" = "izzy/ez", "yes" = "yep/ya").
Input: "$rawText"
If user indicates a grid position (1-9 or top-left, etc), output: {"intent": "MOVE", "position": <0-8>} (where 1=0, 9=8).
If user selects difficulty (Easy, Medium, Hard), output: {"intent": "DIFFICULTY", "level": "easy|medium|hard"}.
If user says play again/yes/next/rematch, output: {"intent": "PLAY_AGAIN"}.
If user says no/exit/quit, output: {"intent": "EXIT"}.
Else: {"intent": "UNKNOWN"}.
OUTPUT ONLY JSON. DO NOT WRAP IN ```json.
''';

      final response = await router.generateResponse(
        route: route,
        systemPrompt: prompt,
        userMessage: rawText,
      );

      if (response == null || response.isEmpty) return {'intent': 'UNKNOWN'};

      final clean = response
          .replaceAll(RegExp(r'```(?:json)?\s*|\s*```', dotAll: true), '')
          .trim();
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('VoiceCommandParser Error: $e');
      return {'intent': 'UNKNOWN'};
    }
  }
}
