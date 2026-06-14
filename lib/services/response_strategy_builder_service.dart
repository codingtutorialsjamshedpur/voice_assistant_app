import 'package:get/get.dart';
import 'intent_classifier_service.dart';
import 'user_profiling_engine_service.dart';
import 'ai_model_manager.dart';

class ResponseStrategy {
  final DepthLevel depth;
  final String tone;
  final int exampleCount;
  final bool useAnalogies;
  final bool includeEdgeCases;
  final bool addCuriosityHook;
  final int maxWords;
  final String instructions;

  ResponseStrategy({
    required this.depth,
    required this.tone,
    required this.exampleCount,
    required this.useAnalogies,
    required this.includeEdgeCases,
    required this.addCuriosityHook,
    required this.maxWords,
    required this.instructions,
  });
}

class ResponseStrategyBuilderService extends GetxService {
  ResponseStrategy buildStrategy({
    required ExpertiseLevel userLevel,
    required QueryIntent intent,
  }) {
    if (userLevel == ExpertiseLevel.beginner) {
      return _strategyForBeginner(intent);
    } else if (userLevel == ExpertiseLevel.intermediate) {
      return _strategyForIntermediate(intent);
    } else {
      return _strategyForAdvanced(intent);
    }
  }

  ResponseStrategy _strategyForBeginner(QueryIntent intent) {
    return ResponseStrategy(
      depth: DepthLevel.shallow,
      tone: 'friendly and encouraging',
      exampleCount: 2,
      useAnalogies: true,
      includeEdgeCases: false,
      addCuriosityHook: true,
      maxWords: 200,
      instructions: '''
You are explaining to a beginner who is new to this topic.
- Use simple, everyday words (no jargon)
- If you must use technical term, explain it immediately
- Use ONE relatable analogy (e.g., "Think of it like...")
- Give 1-2 concrete, real-world examples
- Structure: Simple definition → 1 analogy → 1-2 examples → encouragement
- Avoid: Multiple technical terms, edge cases, abstract concepts
- Add: A gentle question at the end to encourage curiosity
''',
    );
  }

  ResponseStrategy _strategyForIntermediate(QueryIntent intent) {
    return ResponseStrategy(
      depth: DepthLevel.medium,
      tone: 'balanced and informative',
      exampleCount: 2,
      useAnalogies: true,
      includeEdgeCases: false,
      addCuriosityHook: true,
      maxWords: 300,
      instructions: '''
You are explaining to someone with intermediate understanding.
- Use clear language but technical terms are OK (define uncommon ones)
- Provide structured explanation: Definition → mechanism → examples → application
- Give 2 relevant examples (one simple, one more complex)
- Structure: What it is → How it works → Why it matters → Examples
- You can use some technical language, but explain unfamiliar terms
- Add insight: "This concept connects to..."
- End with: "Would you like to explore [related topic]?"
''',
    );
  }

  ResponseStrategy _strategyForAdvanced(QueryIntent intent) {
    return ResponseStrategy(
      depth: DepthLevel.deep,
      tone: 'technical and precise',
      exampleCount: 1,
      useAnalogies: false,
      includeEdgeCases: true,
      addCuriosityHook: true,
      maxWords: 500,
      instructions: '''
You are explaining to an expert or advanced learner.
- Skip basic definitions; focus on mechanism, nuance, and advanced concepts
- Use appropriate technical jargon and terminology
- Include edge cases, special conditions, and limitations
- Mention research frontiers or open questions if relevant
- Structure: Direct answer → mechanism/proof → edge cases → implications
- If applicable, mention citations or references
- End with: "The frontier here is..." or "Current research explores..."
- Assume reader can understand code examples and mathematical notation
''',
    );
  }

  ResponseStrategy buildStrategyForIntent(
      ExpertiseLevel level, IntentType intentType) {
    if (intentType == IntentType.creative) {
      return _strategyForCreative(level);
    }
    if (intentType == IntentType.fix) {
      return _strategyForFix(level);
    }
    if (intentType == IntentType.compare) {
      return _strategyForCompare(level);
    }
    if (intentType == IntentType.calculate) {
      return _strategyForCalculate(level);
    }
    return buildStrategy(
      userLevel: level,
      intent: QueryIntent(
        type: intentType,
        depth: DepthLevel.medium,
        category: QueryCategory.generalKnowledge,
        needsRealTimeData: false,
        isMultiHop: false,
      ),
    );
  }

  ResponseStrategy _strategyForCreative(ExpertiseLevel level) {
    return ResponseStrategy(
      depth: DepthLevel.medium,
      tone: 'engaging and expressive',
      exampleCount: 0,
      useAnalogies: false,
      includeEdgeCases: false,
      addCuriosityHook: false,
      maxWords: level == ExpertiseLevel.beginner ? 300 : 600,
      instructions: '''
You are writing creatively.
- Create engaging, vivid content
- Use simple language for beginners, more sophisticated for advanced
- Structure your content clearly
- Make it interesting and memorable
- No technical jargon unless appropriate to the story
''',
    );
  }

  ResponseStrategy _strategyForFix(ExpertiseLevel level) {
    return ResponseStrategy(
      depth: level == ExpertiseLevel.advanced
          ? DepthLevel.deep
          : DepthLevel.medium,
      tone: 'helpful and precise',
      exampleCount: 1,
      useAnalogies: level == ExpertiseLevel.beginner,
      includeEdgeCases: level == ExpertiseLevel.advanced,
      addCuriosityHook: false,
      maxWords: 400,
      instructions: '''
You are helping fix a problem.
- For beginners: Explain steps simply, one at a time
- For intermediate: Provide clear steps with explanations
- For advanced: Focus on the root cause, best practices, edge cases
- Include code examples if relevant
- Be clear and concise
''',
    );
  }

  ResponseStrategy _strategyForCompare(ExpertiseLevel level) {
    return ResponseStrategy(
      depth: DepthLevel.medium,
      tone: 'analytical and balanced',
      exampleCount: 2,
      useAnalogies: level == ExpertiseLevel.beginner,
      includeEdgeCases: level == ExpertiseLevel.advanced,
      addCuriosityHook: true,
      maxWords: 350,
      instructions: '''
You are comparing two or more things.
- Present pros and cons clearly
- Use a structured format (table or bullet points if helpful)
- For beginners: Use simple comparisons with real-world examples
- For advanced: Include technical details and trade-offs
- End with a recommendation or summary
''',
    );
  }

  ResponseStrategy _strategyForCalculate(ExpertiseLevel level) {
    return ResponseStrategy(
      depth: DepthLevel.shallow,
      tone: 'clear and accurate',
      exampleCount: 1,
      useAnalogies: false,
      includeEdgeCases: false,
      addCuriosityHook: false,
      maxWords: 150,
      instructions: '''
You are solving a calculation or math problem.
- Show your work step by step
- Be precise and accurate
- Explain the solution clearly
- For beginners: Show each step simply
- For advanced: Can use formulas and shortcuts
''',
    );
  }

  String getStrategySummary(ResponseStrategy strategy) {
    return '''
Depth: ${strategy.depth.name}
Tone: ${strategy.tone}
Examples: ${strategy.exampleCount}
Analogies: ${strategy.useAnalogies ? 'Yes' : 'No'}
Edge Cases: ${strategy.includeEdgeCases ? 'Yes' : 'No'}
Max Words: ${strategy.maxWords}
''';
  }
}
