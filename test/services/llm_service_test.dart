import 'package:flutter_test/flutter_test.dart';
import 'package:voice_assistant_app/services/llm_service.dart';

// Mock LLM implementation for testing
class MockLLMService extends LLMService {
  @override
  Future<String?> complete({
    required String systemPrompt,
    required String userMessage,
    String screenContext = '',
    List<Map<String, String>>? history,
  }) async {
    return 'Mock Response: \${userMessage}';
  }

  @override
  Future<String?> enhanceResponse(
      String response, String additionalData) async {
    return '\${response} with \${additionalData}';
  }
}

void main() {
  group('LLMService Tests', () {
    late LLMService llmService;

    setUp(() {
      llmService = MockLLMService();
    });

    test('Should return mock completion', () async {
      final res = await llmService.complete(
        systemPrompt: 'prompt',
        userMessage: 'Test Msg',
      );

      expect(res, 'Mock Response: Test Msg');
    });

    test('Should enhance response', () async {
      final res = await llmService.enhanceResponse('Original', 'Data');
      expect(res, 'Original with Data');
    });
  });
}
