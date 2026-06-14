// lib/models/mood_state_model.dart
// Phase 2 - Sprint 1 - Task 1.2: MoodState model

/// Enum representing the detected mood type
enum MoodType {
  happy, // 😊 Positive, joyful
  sad, // 😢 Sad, low energy
  stressed, // 😰 Stressed, tense
  neutral, // 😐 Normal baseline
  anxious, // 😟 Worried, unsure
  excited, // 🎉 Very enthusiastic
  tired, // 😴 Fatigued, low energy
  angry, // 😠 Frustrated, angry
}

extension MoodTypeExtension on MoodType {
  String get emoji {
    switch (this) {
      case MoodType.happy:
        return '😊';
      case MoodType.sad:
        return '😢';
      case MoodType.stressed:
        return '😰';
      case MoodType.neutral:
        return '😐';
      case MoodType.anxious:
        return '😟';
      case MoodType.excited:
        return '🎉';
      case MoodType.tired:
        return '😴';
      case MoodType.angry:
        return '😠';
    }
  }

  String get label {
    switch (this) {
      case MoodType.happy:
        return 'Happy';
      case MoodType.sad:
        return 'Sad';
      case MoodType.stressed:
        return 'Stressed';
      case MoodType.neutral:
        return 'Neutral';
      case MoodType.anxious:
        return 'Anxious';
      case MoodType.excited:
        return 'Excited';
      case MoodType.tired:
        return 'Tired';
      case MoodType.angry:
        return 'Angry';
    }
  }

  String get hindiLabel {
    switch (this) {
      case MoodType.happy:
        return 'Khush';
      case MoodType.sad:
        return 'Udaas';
      case MoodType.stressed:
        return 'Stress mein';
      case MoodType.neutral:
        return 'Normal';
      case MoodType.anxious:
        return 'Pareshaan';
      case MoodType.excited:
        return 'Excited';
      case MoodType.tired:
        return 'Thaka hua';
      case MoodType.angry:
        return 'Gussa';
    }
  }
}

/// Immutable model representing a mood analysis result
class MoodState {
  final MoodType type;
  final double confidence; // 0.0 - 1.0
  final DateTime detectedAt;
  final List<String> indicators;

  const MoodState({
    required this.type,
    required this.confidence,
    required this.detectedAt,
    required this.indicators,
  });

  /// Returns true if this mood state was detected more than 30 minutes ago
  bool isStale() {
    return DateTime.now().difference(detectedAt).inMinutes > 30;
  }

  /// Returns the mood emoji
  String getEmoji() => type.emoji;

  /// Returns confidence as percentage string (e.g. "72%")
  String get confidencePercent =>
      '${(confidence * 100).clamp(0, 100).round()}%';

  /// JSON serialization
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'confidence': confidence,
        'detectedAt': detectedAt.toIso8601String(),
        'indicators': indicators,
      };

  factory MoodState.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? 'neutral';
    final type = MoodType.values.firstWhere(
      (m) => m.name == typeName,
      orElse: () => MoodType.neutral,
    );
    return MoodState(
      type: type,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      detectedAt: json['detectedAt'] != null
          ? DateTime.parse(json['detectedAt'] as String)
          : DateTime.now(),
      indicators: List<String>.from(
          (json['indicators'] as List<dynamic>?)?.cast<String>() ?? []),
    );
  }

  /// Neutral default state
  static MoodState get neutral => MoodState(
        type: MoodType.neutral,
        confidence: 0.5,
        detectedAt: DateTime.now(),
        indicators: [],
      );
}
