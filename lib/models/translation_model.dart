class TranslationRequest {
  final String sourceText;
  final String fromLanguage;
  final String toLanguage;
  final String? context;
  final bool preserveMeaning;

  const TranslationRequest({
    required this.sourceText,
    required this.fromLanguage,
    required this.toLanguage,
    this.context,
    this.preserveMeaning = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'sourceText': sourceText,
      'fromLanguage': fromLanguage,
      'toLanguage': toLanguage,
      'context': context,
      'preserveMeaning': preserveMeaning,
    };
  }

  factory TranslationRequest.fromJson(Map<String, dynamic> json) {
    return TranslationRequest(
      sourceText: json['sourceText'] as String,
      fromLanguage: json['fromLanguage'] as String,
      toLanguage: json['toLanguage'] as String,
      context: json['context'] as String?,
      preserveMeaning: json['preserveMeaning'] as bool? ?? true,
    );
  }

  String get cacheKey => '$sourceText|$fromLanguage|$toLanguage';

  @override
  String toString() {
    return 'TranslationRequest(from: $fromLanguage, to: $toLanguage, text: ${sourceText.substring(0, sourceText.length > 20 ? 20 : sourceText.length)}...)';
  }
}

class TranslationResponse {
  final String translatedText;
  final String fromLanguage;
  final String toLanguage;
  final double confidence;
  final List<String>? alternatives;
  final DateTime timestamp;

  const TranslationResponse({
    required this.translatedText,
    required this.fromLanguage,
    required this.toLanguage,
    required this.confidence,
    this.alternatives,
    required this.timestamp,
  });

  factory TranslationResponse.empty() {
    return TranslationResponse(
      translatedText: '',
      fromLanguage: '',
      toLanguage: '',
      confidence: 0.0,
      timestamp: DateTime.now(),
    );
  }

  bool get isEmpty => translatedText.isEmpty;
  bool get isNotEmpty => translatedText.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'translatedText': translatedText,
      'fromLanguage': fromLanguage,
      'toLanguage': toLanguage,
      'confidence': confidence,
      'alternatives': alternatives,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TranslationResponse.fromJson(Map<String, dynamic> json) {
    return TranslationResponse(
      translatedText: json['translatedText'] as String,
      fromLanguage: json['fromLanguage'] as String,
      toLanguage: json['toLanguage'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      alternatives: json['alternatives'] != null
          ? List<String>.from(json['alternatives'])
          : null,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  TranslationResponse copyWith({
    String? translatedText,
    String? fromLanguage,
    String? toLanguage,
    double? confidence,
    List<String>? alternatives,
    DateTime? timestamp,
  }) {
    return TranslationResponse(
      translatedText: translatedText ?? this.translatedText,
      fromLanguage: fromLanguage ?? this.fromLanguage,
      toLanguage: toLanguage ?? this.toLanguage,
      confidence: confidence ?? this.confidence,
      alternatives: alternatives ?? this.alternatives,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'TranslationResponse(translatedText: ${translatedText.substring(0, translatedText.length > 30 ? 30 : translatedText.length)}..., '
        'from: $fromLanguage, to: $toLanguage, confidence: $confidence)';
  }
}

class BatchTranslationRequest {
  final List<String> texts;
  final String fromLanguage;
  final String toLanguage;
  final String? context;

  const BatchTranslationRequest({
    required this.texts,
    required this.fromLanguage,
    required this.toLanguage,
    this.context,
  });

  Map<String, dynamic> toJson() {
    return {
      'texts': texts,
      'fromLanguage': fromLanguage,
      'toLanguage': toLanguage,
      'context': context,
    };
  }

  factory BatchTranslationRequest.fromJson(Map<String, dynamic> json) {
    return BatchTranslationRequest(
      texts: List<String>.from(json['texts']),
      fromLanguage: json['fromLanguage'] as String,
      toLanguage: json['toLanguage'] as String,
      context: json['context'] as String?,
    );
  }
}

class BatchTranslationResponse {
  final List<String> translatedTexts;
  final String fromLanguage;
  final String toLanguage;
  final List<double> confidences;
  final DateTime timestamp;

  const BatchTranslationResponse({
    required this.translatedTexts,
    required this.fromLanguage,
    required this.toLanguage,
    required this.confidences,
    required this.timestamp,
  });

  factory BatchTranslationResponse.empty() {
    return BatchTranslationResponse(
      translatedTexts: [],
      fromLanguage: '',
      toLanguage: '',
      confidences: [],
      timestamp: DateTime.now(),
    );
  }

  bool get isEmpty => translatedTexts.isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'translatedTexts': translatedTexts,
      'fromLanguage': fromLanguage,
      'toLanguage': toLanguage,
      'confidences': confidences,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory BatchTranslationResponse.fromJson(Map<String, dynamic> json) {
    return BatchTranslationResponse(
      translatedTexts: List<String>.from(json['translatedTexts']),
      fromLanguage: json['fromLanguage'] as String,
      toLanguage: json['toLanguage'] as String,
      confidences: (json['confidences'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
