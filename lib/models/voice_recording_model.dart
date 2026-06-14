import 'dart:io';
import 'voice_effect_model.dart';

class VoiceRecording {
  final String id;
  final String title;
  final String filePath;
  final String? effectId;
  final VoiceEffectType? effectType;
  final DateTime createdAt;
  final Duration duration;
  final int fileSize;
  final bool isFavorite;
  final String? tags;
  final String languageCode;
  final String languageName;

  VoiceRecording({
    required this.id,
    required this.title,
    required this.filePath,
    this.effectId,
    this.effectType,
    required this.createdAt,
    required this.duration,
    required this.fileSize,
    this.isFavorite = false,
    this.tags,
    this.languageCode = 'en-US',
    this.languageName = 'English',
  });

  String get fileName => filePath.split(Platform.pathSeparator).last;

  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedFileSize {
    if (fileSize < 1024) {
      return '${fileSize}B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recordingDate =
        DateTime(createdAt.year, createdAt.month, createdAt.day);

    if (recordingDate == today) {
      return 'Today';
    } else if (recordingDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (recordingDate.isAfter(today.subtract(const Duration(days: 7)))) {
      final daysAgo = today.difference(recordingDate).inDays;
      return '$daysAgo days ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  VoiceRecording copyWith({
    String? id,
    String? title,
    String? filePath,
    String? effectId,
    VoiceEffectType? effectType,
    DateTime? createdAt,
    Duration? duration,
    int? fileSize,
    bool? isFavorite,
    String? tags,
    String? languageCode,
    String? languageName,
  }) {
    return VoiceRecording(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      effectId: effectId ?? this.effectId,
      effectType: effectType ?? this.effectType,
      createdAt: createdAt ?? this.createdAt,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      languageCode: languageCode ?? this.languageCode,
      languageName: languageName ?? this.languageName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'filePath': filePath,
        'effectId': effectId,
        'effectType': effectType?.toString(),
        'createdAt': createdAt.toIso8601String(),
        'duration': duration.inMilliseconds,
        'fileSize': fileSize,
        'isFavorite': isFavorite,
        'tags': tags,
        'languageCode': languageCode,
        'languageName': languageName,
      };

  factory VoiceRecording.fromJson(Map<String, dynamic> json) {
    return VoiceRecording(
      id: json['id'],
      title: json['title'],
      filePath: json['filePath'],
      effectId: json['effectId'],
      effectType: json['effectType'] != null
          ? VoiceEffectType.values.firstWhere(
              (e) => e.toString() == json['effectType'],
              orElse: () => VoiceEffectType.caveEcho,
            )
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      duration: Duration(milliseconds: json['duration']),
      fileSize: json['fileSize'],
      isFavorite: json['isFavorite'] ?? false,
      tags: json['tags'],
      languageCode: json['languageCode'] ?? 'en-US',
      languageName: json['languageName'] ?? 'English',
    );
  }
}
