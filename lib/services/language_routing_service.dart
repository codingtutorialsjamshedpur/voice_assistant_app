import 'package:get/get.dart';
import 'ruflo_service.dart';
import '../controllers/language_controller.dart';

class LanguageRoutingDecision {
  final List<String> detectedLanguages;
  final String primaryLanguage;
  final String sttHandler;
  final String llmModel;
  final bool isMixed;
  final double confidence;

  const LanguageRoutingDecision({
    required this.detectedLanguages,
    required this.primaryLanguage,
    required this.sttHandler,
    required this.llmModel,
    required this.isMixed,
    required this.confidence,
  });

  factory LanguageRoutingDecision.defaultEnglish() => const LanguageRoutingDecision(
    detectedLanguages: ['en'],
    primaryLanguage: 'en',
    sttHandler: 'google-stt-en-us-latest',
    llmModel: 'groq/llama3-70b',
    isMixed: false,
    confidence: 1.0,
  );
}

class LanguageRoutingService extends GetxService {
  final _ruflo = RuFloService();

  Future<LanguageRoutingDecision> analyzeAndRoute(
    String input,
    String userId,
  ) async {
    try {
      final result = await _ruflo.swarmQuery(
        input: input,
        agents: ['language_router'],
        context: {
          'userId': userId,
          'previousLanguage': Get.find<LanguageController>().selectedLanguage.value.code,
        },
      );

      return LanguageRoutingDecision(
        detectedLanguages: List<String>.from(result['languages'] ?? ['en']),
        primaryLanguage: result['primary'] as String? ?? 'en',
        sttHandler: result['sttRoute'] as String? ?? 'google-stt-en-us-latest',
        llmModel: result['llmRoute'] as String? ?? 'groq/llama3-70b',
        isMixed: result['isMixed'] as bool? ?? false,
        confidence: (result['confidence'] as num?)?.toDouble() ?? 0.8,
      );
    } catch (_) {
      return LanguageRoutingDecision.defaultEnglish();
    }
  }
}
