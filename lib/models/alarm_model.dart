import 'dart:convert';

class AlarmModel {
  final String id;
  final String time;
  final String label;
  final bool isEnabled;
  final List<String> repeatDays;
  final String sound;
  final String? customVoicePath;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AlarmModel({
    required this.id,
    required this.time,
    required this.label,
    this.isEnabled = true,
    this.repeatDays = const [],
    this.sound = 'Bell Ring',
    this.customVoicePath,
    required this.createdAt,
    this.updatedAt,
  });

  factory AlarmModel.fromJson(Map<String, dynamic> json) {
    return AlarmModel(
      id: json['id'] as String,
      time: json['time'] as String,
      label: json['label'] as String,
      isEnabled: json['isEnabled'] as bool? ?? true,
      repeatDays: List<String>.from(json['repeatDays'] ?? []),
      sound: json['sound'] as String? ?? 'Bell Ring',
      customVoicePath: json['customVoicePath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'time': time,
      'label': label,
      'isEnabled': isEnabled,
      'repeatDays': repeatDays,
      'sound': sound,
      'customVoicePath': customVoicePath,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  AlarmModel copyWith({
    String? id,
    String? time,
    String? label,
    bool? isEnabled,
    List<String>? repeatDays,
    String? sound,
    String? customVoicePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AlarmModel(
      id: id ?? this.id,
      time: time ?? this.time,
      label: label ?? this.label,
      isEnabled: isEnabled ?? this.isEnabled,
      repeatDays: repeatDays ?? this.repeatDays,
      sound: sound ?? this.sound,
      customVoicePath: customVoicePath ?? this.customVoicePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  DateTime? getNextAlarmTime() {
    try {
      final parts = time.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);
      final isPM = parts[1] == 'PM';

      if (isPM && hour != 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;

      final now = DateTime.now();
      var nextAlarm = DateTime(now.year, now.month, now.day, hour, minute);

      if (repeatDays.isEmpty) {
        // One-time alarm
        if (nextAlarm.isBefore(now)) {
          nextAlarm = nextAlarm.add(const Duration(days: 1));
        }
        return nextAlarm;
      }

      // Find next occurrence
      final dayMapping = {
        'Mon': 1,
        'Tue': 2,
        'Wed': 3,
        'Thu': 4,
        'Fri': 5,
        'Sat': 6,
        'Sun': 7
      };
      final selectedDays = repeatDays.map((d) => dayMapping[d]!).toList()
        ..sort();

      final int currentDayOfWeek = now.weekday;
      int daysToAdd = -1;

      // Check if alarm time has passed for today
      if (selectedDays.contains(currentDayOfWeek) && nextAlarm.isAfter(now)) {
        return nextAlarm;
      }

      // Find next day
      for (int i = 1; i <= 7; i++) {
        final int checkDay = ((currentDayOfWeek - 1 + i) % 7) + 1;
        if (selectedDays.contains(checkDay)) {
          daysToAdd = i;
          break;
        }
      }

      if (daysToAdd > 0) {
        return nextAlarm.add(Duration(days: daysToAdd));
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  String toJsonString() => jsonEncode(toJson());

  static AlarmModel fromJsonString(String jsonString) {
    return AlarmModel.fromJson(jsonDecode(jsonString));
  }
}

class VoiceRecording {
  final String id;
  final String name;
  final String path;
  final int durationMs;
  final DateTime createdAt;

  VoiceRecording({
    required this.id,
    required this.name,
    required this.path,
    required this.durationMs,
    required this.createdAt,
  });

  factory VoiceRecording.fromJson(Map<String, dynamic> json) {
    return VoiceRecording(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      durationMs: json['durationMs'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'durationMs': durationMs,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String get durationFormatted {
    final seconds = durationMs ~/ 1000;
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}
