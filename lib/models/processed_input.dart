import '../models/language_model.dart';
import '../models/trigger_word_configuration.dart';

class ProcessedInput {
  final String originalText;
  final String inputLanguage;
  final String? translatedText;
  final String preferredLanguage;
  final TriggerWordConfiguration? triggerWord;
  final String action;
  final DateTime timestamp;
  final double confidence;

  const ProcessedInput({
    required this.originalText,
    required this.inputLanguage,
    this.translatedText,
    required this.preferredLanguage,
    this.triggerWord,
    this.action = 'process',
    required this.timestamp,
    required this.confidence,
  });

  bool get isExit => action == 'exit';
  bool get hasTriggerWord => triggerWord != null;
  bool get isEndOfThought => triggerWord?.type == TriggerWordType.endOfThought;

  ProcessedInput copyWith({
    String? originalText,
    String? inputLanguage,
    String? translatedText,
    String? preferredLanguage,
    TriggerWordConfiguration? triggerWord,
    String? action,
    DateTime? timestamp,
    double? confidence,
  }) {
    return ProcessedInput(
      originalText: originalText ?? this.originalText,
      inputLanguage: inputLanguage ?? this.inputLanguage,
      translatedText: translatedText ?? this.translatedText,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      triggerWord: triggerWord ?? this.triggerWord,
      action: action ?? this.action,
      timestamp: timestamp ?? this.timestamp,
      confidence: confidence ?? this.confidence,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'originalText': originalText,
      'inputLanguage': inputLanguage,
      'translatedText': translatedText,
      'preferredLanguage': preferredLanguage,
      'triggerWord': triggerWord?.triggerWord,
      'triggerWordType': triggerWord?.type.name,
      'action': action,
      'timestamp': timestamp.toIso8601String(),
      'confidence': confidence,
    };
  }

  factory ProcessedInput.fromJson(Map<String, dynamic> json) {
    return ProcessedInput(
      originalText: json['originalText'] as String,
      inputLanguage: json['inputLanguage'] as String,
      translatedText: json['translatedText'] as String?,
      preferredLanguage: json['preferredLanguage'] as String,
      triggerWord: json['triggerWord'] != null
          ? TriggerWordConfiguration(
              triggerWord: json['triggerWord'] as String,
              variants: [],
              language: json['inputLanguage'] as String,
              type: TriggerWordType.values.firstWhere(
                (e) => e.name == json['triggerWordType'],
                orElse: () => TriggerWordType.endOfThought,
              ),
              description: '',
            )
          : null,
      action: json['action'] as String? ?? 'process',
      timestamp: DateTime.parse(json['timestamp'] as String),
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  @override
  String toString() {
    return 'ProcessedInput(originalText: $originalText, inputLanguage: $inputLanguage, '
        'preferredLanguage: $preferredLanguage, action: $action, hasTriggerWord: $hasTriggerWord)';
  }
}
