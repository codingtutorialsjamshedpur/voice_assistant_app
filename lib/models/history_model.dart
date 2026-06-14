enum ActivityType {
  chat,
  naamJaap,
  game,
  alarm,
  voiceStudio,
  reminder,
  wallpaper,
  languageCoach,
  settings,
  other,
}

class HistoryActivity {
  final String id;
  final ActivityType type;
  final String title;
  final String? description;
  final DateTime timestamp;
  final String screenRoute;
  final bool isDeleted;
  final int? durationSeconds;
  final Map<String, dynamic>? metadata;

  const HistoryActivity({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    required this.timestamp,
    required this.screenRoute,
    this.isDeleted = false,
    this.durationSeconds,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toString().split('.').last,
        'title': title,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'screenRoute': screenRoute,
        'isDeleted': isDeleted,
        'durationSeconds': durationSeconds,
        'metadata': metadata,
      };

  factory HistoryActivity.fromJson(Map<String, dynamic> json) {
    return HistoryActivity(
      id: json['id'] as String? ?? '',
      type: _parseActivityType(json['type'] as String?),
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      screenRoute: json['screenRoute'] as String? ?? '',
      isDeleted: json['isDeleted'] as bool? ?? false,
      durationSeconds: json['durationSeconds'] as int?,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  HistoryActivity copyWith({
    String? id,
    ActivityType? type,
    String? title,
    String? description,
    DateTime? timestamp,
    String? screenRoute,
    bool? isDeleted,
    int? durationSeconds,
    Map<String, dynamic>? metadata,
  }) {
    return HistoryActivity(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      screenRoute: screenRoute ?? this.screenRoute,
      isDeleted: isDeleted ?? this.isDeleted,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      metadata: metadata ?? this.metadata,
    );
  }

  static ActivityType _parseActivityType(String? typeStr) {
    if (typeStr == null) return ActivityType.other;
    return ActivityType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => ActivityType.other,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is HistoryActivity && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

class GroupedHistoryActivities {
  final String period;
  final List<HistoryActivity> activities;

  const GroupedHistoryActivities({
    required this.period,
    required this.activities,
  });
}
