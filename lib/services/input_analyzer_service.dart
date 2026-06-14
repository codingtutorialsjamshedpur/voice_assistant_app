import 'package:get/get.dart';

enum LanguageType { hindi, english, hinglish, tamil, telugu, bengali, other }

enum ToneType { casual, formal, emotional, technical, curious }

enum QueryType {
  definition,
  explanation,
  howTo,
  whyQuestion,
  opinion,
  creative,
  other
}

/// Real-time query types for live data fetching
enum RealTimeQueryType {
  weather,
  geography,
  wikipedia,
  cryptocurrency,
  currency,
  news,
  spiritualGita,
  spiritualQuran,
  recipe,
  definition,
  space,
  music,
  worldDiscovery,
  nearbyPlaces,
  none
}

class InputSignals {
  final LanguageType language;
  final ToneType tone;
  final double vocabularyComplexity;
  final double sentenceComplexity;
  final QueryType queryType;
  final int wordCount;
  final List<String> technicalTerms;

  InputSignals({
    required this.language,
    required this.tone,
    required this.vocabularyComplexity,
    required this.sentenceComplexity,
    required this.queryType,
    required this.wordCount,
    required this.technicalTerms,
  });
}

class InputAnalyzerService extends GetxService {
  InputSignals analyzeQuery(String query) {
    return InputSignals(
      language: _detectLanguage(query),
      tone: _detectTone(query),
      vocabularyComplexity: _calculateVocabComplexity(query),
      sentenceComplexity: _calculateSentenceComplexity(query),
      queryType: _detectQueryType(query),
      wordCount: query.split(' ').length,
      technicalTerms: _extractTechnicalTerms(query),
    );
  }

  /// Detect if a query requires real-time data fetching
  RealTimeQueryType detectRealTimeQueryType(String query) {
    final lowerQuery = query.toLowerCase();

    // Weather queries
    if (_matchesPattern(lowerQuery, [
      'weather',
      'temperature',
      'rain',
      'thunderstorm',
      'मौसम',
      'तापमान',
      'बारिश',
      'forecast',
      'sunny',
      'cloudy',
      'windy',
      'humidity',
      'precipitation',
      'climate',
      'tomorrow weather',
      'अगले दिन का मौसम',
      'कल मौसम',
    ])) {
      return RealTimeQueryType.weather;
    }

    // Geography queries (countries, capitals, regions)
    if (_matchesPattern(lowerQuery, [
      'capital',
      'country',
      'geographical',
      'population',
      'राजधानी',
      'देश',
      'क्षेत्र',
      'currency',
      'language of',
      'about the country',
      'nation',
      'flag',
      'borders',
      'region',
      'continent',
    ])) {
      return RealTimeQueryType.geography;
    }

    // Wikipedia (general knowledge)
    if (_matchesPattern(lowerQuery, [
      'who is',
      'what is',
      'biography',
      'explain',
      'define',
      'about',
      'information',
      'बायोग्राफी',
      'कौन है',
      'क्या है',
      'जानकारी',
      'बताओ',
      'समझाओ',
      'history of',
      'famous',
      'invention',
      'discovery',
    ])) {
      return RealTimeQueryType.wikipedia;
    }

    // Dictionary (definitions)
    if (_matchesPattern(lowerQuery, [
      'define',
      'meaning of',
      'what does',
      'definition',
      'अर्थ',
      'मतलब',
      'शब्दकोश',
    ])) {
      return RealTimeQueryType.definition;
    }

    // Space / NASA queries
    if (_matchesPattern(lowerQuery, [
      'nasa',
      'astronomy',
      'space picture',
      'mars',
      'galaxy',
      'universe',
      'अंतरिक्ष',
      'ब्रह्मांड',
    ])) {
      return RealTimeQueryType.space;
    }

    // Music / Songs / Motivation
    if (_matchesPattern(lowerQuery, [
      'song',
      'music',
      'play something',
      'listen',
      'sing',
      'motivational',
      'depressed',
      'sad',
      'happy',
      'गाना',
      'संगीत',
      'सुनाओ',
    ])) {
      return RealTimeQueryType.music;
    }

    // Cryptocurrency queries
    if (_matchesPattern(lowerQuery, [
      'bitcoin',
      'ethereum',
      'crypto',
      'btc',
      'eth',
      'dogecoin',
      'ripple',
      'cardano',
      'polkadot',
      'xrp',
      'doge',
      'coin price',
      'cryptocurrency',
      'क्रिप्टो',
      'बिटकॉइन',
      'price of',
      'market cap',
    ])) {
      return RealTimeQueryType.cryptocurrency;
    }

    // Currency conversion
    if (_matchesPattern(lowerQuery, [
      'convert',
      'exchange rate',
      'rupee',
      'dollar',
      'euro',
      'pound',
      'yen',
      'currency',
      'how much',
      '₹',
      '\$',
      '€',
      'रुपये में',
      'डॉलर में',
      'दाम क्या है',
    ])) {
      return RealTimeQueryType.currency;
    }

    // News queries
    if (_matchesPattern(lowerQuery, [
      'news',
      'latest',
      'happening',
      'trending',
      'latest news',
      'current',
      'today',
      'breaking',
      'ताज़ा',
      'खबर',
      'समाचार',
      'क्या चल रहा है',
      'headline',
      'breaking news',
    ])) {
      return RealTimeQueryType.news;
    }

    // Bhagavad Gita (Spiritual)
    if (_matchesPattern(lowerQuery, [
      'gita',
      'bhagavad',
      'krishna',
      'verse',
      'श्लोक',
      'गीता',
      'कृष्ण',
      'भगवान',
      'spiritual',
      'chapter',
      'अध्याय',
      'wisdom',
      'philosophy',
    ])) {
      return RealTimeQueryType.spiritualGita;
    }

    // Quran (Spiritual)
    if (_matchesPattern(lowerQuery, [
      'quran',
      'islamic',
      'allah',
      'surat',
      'ayah',
      'hadith',
      'कुरान',
      'इस्लाम',
      'सूरह',
      'आयत',
      'verse',
      'islamic teaching',
      'prophet',
    ])) {
      return RealTimeQueryType.spiritualQuran;
    }

    // Recipe/Food queries
    if (_matchesPattern(lowerQuery, [
      'recipe',
      'cook',
      'prepare',
      'ingredients',
      'food',
      'dish',
      'make',
      'how to make',
      'खाना',
      'रेसिपी',
      'कैसे बनाएं',
      'सामग्री',
      'पकवान',
      'cuisine',
      'bake',
      'fry',
    ])) {
      return RealTimeQueryType.recipe;
    }

    // Definition/Dictionary
    if (_matchesPattern(lowerQuery, [
      'define',
      'meaning',
      'definition',
      'what does',
      'मतलब',
      'परिभाषा',
      'मीनिंग',
      'etymology',
      'pronunciation',
      'word meaning',
      'संज्ञा',
      'विशेषण',
    ])) {
      return RealTimeQueryType.definition;
    }

    // Nearby places
    if (_matchesPattern(lowerQuery, [
          'near me',
          'nearby',
          'around me',
          'closest',
          'nearest',
          'मेरे पास',
          'आसपास',
          'नज़दीक',
          'in my area',
        ]) ||
        _matchesPattern(lowerQuery, [
          'where is a temple',
          'where is a hospital',
          'find a restaurant',
          'find an atm',
        ])) {
      return RealTimeQueryType.nearbyPlaces;
    }

    return RealTimeQueryType.none;
  }

  /// Helper method to check if query matches any pattern
  bool _matchesPattern(String query, List<String> patterns) {
    for (var pattern in patterns) {
      if (query.contains(pattern.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  LanguageType _detectLanguage(String query) {
    final hindiPattern = RegExp(r'[\u0900-\u097F]');
    final hasHindi = hindiPattern.hasMatch(query);

    final englishPattern = RegExp(r'[a-zA-Z]');
    final hasEnglish = englishPattern.hasMatch(query);

    if (hasHindi && hasEnglish) {
      return LanguageType.hinglish;
    } else if (hasHindi) {
      return LanguageType.hindi;
    } else if (hasEnglish) {
      return LanguageType.english;
    } else {
      return LanguageType.other;
    }
  }

  ToneType _detectTone(String query) {
    final lowerQuery = query.toLowerCase();

    if (lowerQuery.contains('help') ||
        lowerQuery.contains('मदद') ||
        lowerQuery.contains('please') ||
        lowerQuery.contains('pls') ||
        lowerQuery.contains('कृपया')) {
      return ToneType.emotional;
    }

    if (lowerQuery.contains('api') ||
        lowerQuery.contains('algorithm') ||
        lowerQuery.contains('implement') ||
        lowerQuery.contains('code') ||
        lowerQuery.contains('function') ||
        lowerQuery.contains('data')) {
      return ToneType.technical;
    }

    if (lowerQuery.contains('why') ||
        lowerQuery.contains('क्यों') ||
        lowerQuery.contains('how') ||
        lowerQuery.contains('कैसे') ||
        lowerQuery.contains('explain')) {
      return ToneType.curious;
    }

    if (lowerQuery.contains('would you') ||
        lowerQuery.contains('could you') ||
        lowerQuery.contains('kindly')) {
      return ToneType.formal;
    }

    return ToneType.casual;
  }

  double _calculateVocabComplexity(String query) {
    final words = query.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 0.0;

    final avgWordLength =
        words.fold<double>(0, (sum, word) => sum + word.length) / words.length;

    final complexityScore = (avgWordLength - 3) / 10;
    return complexityScore.clamp(0.0, 1.0);
  }

  double _calculateSentenceComplexity(String query) {
    final int commaCount = ','.allMatches(query).length;
    final int questionMarkCount = '?'.allMatches(query).length;
    final int clauseWords = _countClauseMarkers(query);

    final score = (commaCount + questionMarkCount + clauseWords) / 5;
    return score.clamp(0.0, 1.0);
  }

  int _countClauseMarkers(String query) {
    final markers = [
      'because',
      'which',
      'that',
      'when',
      'if',
      'or',
      'क्योंकि',
      'जो',
      'जब',
      'अगर',
      'या'
    ];
    int count = 0;
    for (var marker in markers) {
      count += marker.allMatches(query.toLowerCase()).length;
    }
    return count;
  }

  QueryType _detectQueryType(String query) {
    final lower = query.toLowerCase();

    if (lower.startsWith('what') || lower.startsWith('क्या')) {
      return QueryType.definition;
    }
    if (lower.startsWith('how') ||
        lower.startsWith('कैसे') ||
        lower.startsWith('किस')) {
      return QueryType.howTo;
    }
    if (lower.startsWith('why') || lower.startsWith('क्यों')) {
      return QueryType.whyQuestion;
    }
    if (lower.startsWith('explain') ||
        lower.startsWith('समझाओ') ||
        lower.startsWith('बताओ')) {
      return QueryType.explanation;
    }
    if (lower.startsWith('write') ||
        lower.startsWith('create') ||
        lower.startsWith('compose') ||
        lower.startsWith('कहानी')) {
      return QueryType.creative;
    }
    if (lower.startsWith('opinion') || lower.startsWith('think')) {
      return QueryType.opinion;
    }

    return QueryType.other;
  }

  List<String> _extractTechnicalTerms(String query) {
    final technicalKeywords = {
      'AI',
      'machine learning',
      'neural network',
      'algorithm',
      'transformer',
      'GPT',
      'LSTM',
      'CNN',
      'backbone',
      'deep learning',
      'NLP',
      'API',
      'database',
      'async',
      'callback',
      'promise',
      'framework',
      'optimize',
      'refactor',
      'debug',
      'cache',
      'server',
      'client',
      'quantum',
      'entanglement',
      'photon',
      'singularity',
      'entropy',
      'lambda',
      'protocol',
      'middleware',
      'deployment',
      'microservice',
      'binary',
      'hexadecimal',
      'encryption',
      'authentication',
      'token',
      'React',
      'Flutter',
      'Dart',
      'Python',
      'JavaScript',
      'Java',
    };

    final List<String> found = [];
    final lowerQuery = query.toLowerCase();
    for (var term in technicalKeywords) {
      if (lowerQuery.contains(term.toLowerCase())) {
        found.add(term);
      }
    }
    return found;
  }

  String getLanguageName(LanguageType type) {
    switch (type) {
      case LanguageType.hindi:
        return 'Hindi';
      case LanguageType.english:
        return 'English';
      case LanguageType.hinglish:
        return 'Hinglish';
      case LanguageType.tamil:
        return 'Tamil';
      case LanguageType.telugu:
        return 'Telugu';
      case LanguageType.bengali:
        return 'Bengali';
      case LanguageType.other:
        return 'Other';
    }
  }

  String getToneName(ToneType type) {
    switch (type) {
      case ToneType.casual:
        return 'Casual';
      case ToneType.formal:
        return 'Formal';
      case ToneType.emotional:
        return 'Emotional';
      case ToneType.technical:
        return 'Technical';
      case ToneType.curious:
        return 'Curious';
    }
  }

  String getQueryTypeName(QueryType type) {
    switch (type) {
      case QueryType.definition:
        return 'Definition';
      case QueryType.explanation:
        return 'Explanation';
      case QueryType.howTo:
        return 'How-to';
      case QueryType.whyQuestion:
        return 'Why Question';
      case QueryType.opinion:
        return 'Opinion';
      case QueryType.creative:
        return 'Creative';
      case QueryType.other:
        return 'Other';
    }
  }

  String getRealTimeQueryTypeName(RealTimeQueryType type) {
    switch (type) {
      case RealTimeQueryType.weather:
        return 'Weather';
      case RealTimeQueryType.geography:
        return 'Geography';
      case RealTimeQueryType.wikipedia:
        return 'General Knowledge';
      case RealTimeQueryType.cryptocurrency:
        return 'Cryptocurrency';
      case RealTimeQueryType.currency:
        return 'Currency Exchange';
      case RealTimeQueryType.news:
        return 'News';
      case RealTimeQueryType.spiritualGita:
        return 'Bhagavad Gita';
      case RealTimeQueryType.spiritualQuran:
        return 'Quran';
      case RealTimeQueryType.recipe:
        return 'Recipe';
      case RealTimeQueryType.definition:
        return 'Definition';
      case RealTimeQueryType.space:
        return 'Space / NASA';
      case RealTimeQueryType.music:
        return 'Music';
      case RealTimeQueryType.worldDiscovery:
        return 'World Discovery';
      case RealTimeQueryType.nearbyPlaces:
        return 'Nearby Places';
      case RealTimeQueryType.none:
        return 'No Real-time Data';
    }
  }
}
