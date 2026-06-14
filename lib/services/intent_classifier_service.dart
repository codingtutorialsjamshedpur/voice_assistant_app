import 'package:get/get.dart';
import 'input_analyzer_service.dart';
import 'ai_model_manager.dart';

enum IntentType {
  explain,
  fix,
  compare,
  explore,
  creative,
  calculate,
  translate,
  opinion,
  definition,
  unknown,
}

enum DepthLevel {
  shallow,
  medium,
  deep,
}

class QueryIntent {
  final IntentType type;
  final DepthLevel depth;
  final QueryCategory category;
  final bool needsRealTimeData;
  final bool isMultiHop;

  QueryIntent({
    required this.type,
    required this.depth,
    required this.category,
    required this.needsRealTimeData,
    required this.isMultiHop,
  });
}

class IntentClassifierService extends GetxService {
  late InputAnalyzerService analyzer;

  @override
  void onInit() {
    super.onInit();
    analyzer = Get.find<InputAnalyzerService>();
  }

  QueryIntent classifyQuery(String query) {
    final signals = analyzer.analyzeQuery(query);

    final intentType = _classifyIntentType(query, signals);
    final depth = _estimateDepth(query, signals);
    final category = _mapToQueryCategory(query);
    final needsRealTime = _checkRealTimeNeed(query);
    final isMultiHop = _detectMultiHop(query);

    return QueryIntent(
      type: intentType,
      depth: depth,
      category: category,
      needsRealTimeData: needsRealTime,
      isMultiHop: isMultiHop,
    );
  }

  IntentType _classifyIntentType(String query, InputSignals signals) {
    final lower = query.toLowerCase();

    if (lower.contains('explain') ||
        lower.contains('समझाओ') ||
        lower.contains('बताओ') ||
        lower.contains('kya hota hai')) {
      return IntentType.explain;
    }
    if (lower.contains('fix') ||
        lower.contains('solve') ||
        lower.contains('ठीक') ||
        lower.contains('error') ||
        lower.contains('bug')) {
      return IntentType.fix;
    }
    if (lower.contains('compare') ||
        lower.contains('vs') ||
        lower.contains('तुलना') ||
        lower.contains('difference')) {
      return IntentType.compare;
    }
    if (lower.contains('tell me more') ||
        lower.contains('explore') ||
        lower.contains('और जान') ||
        lower.contains('details')) {
      return IntentType.explore;
    }
    if (signals.queryType == QueryType.creative ||
        lower.contains('write') ||
        lower.contains('story') ||
        lower.contains('कहानी') ||
        lower.contains('poem')) {
      return IntentType.creative;
    }
    if (lower.contains('translate') || lower.contains('अनुवाद')) {
      return IntentType.translate;
    }
    if (lower.contains('calculate') ||
        lower.contains('solve') ||
        lower.contains('गणना') ||
        lower.contains('math')) {
      return IntentType.calculate;
    }
    if (lower.contains('opinion') ||
        lower.contains('think') ||
        lower.contains('राय')) {
      return IntentType.opinion;
    }
    if (signals.queryType == QueryType.definition ||
        lower.startsWith('what is') ||
        lower.startsWith('क्या है')) {
      return IntentType.definition;
    }

    return IntentType.explain;
  }

  DepthLevel _estimateDepth(String query, InputSignals signals) {
    final avgComplexity =
        (signals.vocabularyComplexity + signals.sentenceComplexity) / 2;

    if (avgComplexity < 0.35) {
      return DepthLevel.shallow;
    } else if (avgComplexity < 0.65) {
      return DepthLevel.medium;
    } else {
      return DepthLevel.deep;
    }
  }

  QueryCategory _mapToQueryCategory(String query) {
    final lower = query.toLowerCase();

    if (lower.contains('black hole') ||
        lower.contains('astrophysics') ||
        lower.contains('गुरुत्वाकर्षण') ||
        lower.contains('universe') ||
        lower.contains('quantum')) {
      return QueryCategory.scienceSubject;
    }
    if (lower.contains('code') ||
        lower.contains('programming') ||
        lower.contains('python') ||
        lower.contains('javascript') ||
        lower.contains('coding') ||
        lower.contains('function')) {
      return QueryCategory.codingProgramming;
    }
    if (lower.contains('ai') ||
        lower.contains('machine learning') ||
        lower.contains('neural') ||
        lower.contains('gpt') ||
        lower.contains('artificial intelligence')) {
      return QueryCategory.aiKnowledge;
    }
    if (lower.contains('भारत') ||
        lower.contains('india') ||
        lower.contains('indian')) {
      return QueryCategory.indiaInDetail;
    }
    if (lower.contains('real time') ||
        lower.contains('weather') ||
        lower.contains('news') ||
        lower.contains('मौसम') ||
        lower.contains('खबर')) {
      return QueryCategory.realTimeData;
    }
    if (lower.contains('god') ||
        lower.contains('hindu') ||
        lower.contains('krishna') ||
        lower.contains('shiv') ||
        lower.contains('देवी') ||
        lower.contains('देवता') ||
        lower.contains('mahabharat') ||
        lower.contains('ram')) {
      return QueryCategory.hinduGodsGoddesses;
    }
    if (lower.contains('history') ||
        lower.contains(' IAS ') ||
        lower.contains('इतिहास')) {
      return QueryCategory.indiaInDetail;
    }
    if (lower.contains('story') ||
        lower.contains('कहानी') ||
        lower.contains('kahani')) {
      return QueryCategory.storyTelling;
    }
    if (lower.contains('song') ||
        lower.contains('गाना') ||
        lower.contains('lyrics')) {
      return QueryCategory.songsLyricsKnowledge;
    }
    if (lower.contains('translate') || lower.contains('अनुवाद')) {
      return QueryCategory.languageTranslator;
    }
    if (lower.contains('calculate') ||
        lower.contains('math') ||
        lower.contains('गणना')) {
      return QueryCategory.mathCalculation;
    }
    if (lower.contains('science') || lower.contains('विज्ञान')) {
      return QueryCategory.scienceSubject;
    }

    return QueryCategory.generalKnowledge;
  }

  bool _checkRealTimeNeed(String query) {
    final lower = query.toLowerCase();

    final realTimeKeywords = [
      'today',
      'now',
      'current',
      'latest',
      'weather',
      'news',
      'आज',
      'अभी',
      'मौसम',
      'खबर',
      'वर्तमान',
      'live',
      'trending',
      'rate',
      'price',
      'stock',
      'cricket',
      'score',
      ' IPL ',
      'match',
      'election',
    ];

    for (var keyword in realTimeKeywords) {
      if (lower.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  bool _detectMultiHop(String query) {
    final lower = query.toLowerCase();

    final multiHopIndicators = [
      'and then',
      'because',
      'also',
      'therefore',
      'which',
      'that',
      'फिर',
      'क्योंकि',
      'साथ ही',
      'जो',
      'अतः',
      'so',
      'consequently',
      'as a result',
      'leads to',
    ];

    for (var indicator in multiHopIndicators) {
      if (lower.contains(indicator)) {
        return true;
      }
    }
    return false;
  }

  String getIntentName(IntentType type) {
    switch (type) {
      case IntentType.explain:
        return 'Explain';
      case IntentType.fix:
        return 'Fix/Solve';
      case IntentType.compare:
        return 'Compare';
      case IntentType.explore:
        return 'Explore';
      case IntentType.creative:
        return 'Creative';
      case IntentType.calculate:
        return 'Calculate';
      case IntentType.translate:
        return 'Translate';
      case IntentType.opinion:
        return 'Opinion';
      case IntentType.definition:
        return 'Definition';
      case IntentType.unknown:
        return 'Unknown';
    }
  }

  String getDepthName(DepthLevel level) {
    switch (level) {
      case DepthLevel.shallow:
        return 'Basic';
      case DepthLevel.medium:
        return 'Medium';
      case DepthLevel.deep:
        return 'Deep';
    }
  }
}
