import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Reminder model representing a single reminder
class Reminder {
  final String id;
  final String title;
  final TimeOfDay time;
  final String category;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt;
  final bool isEnabled;
  final int intervalMinutes; // For repeating reminders (e.g., every 30 minutes)

  Reminder({
    String? id,
    required this.title,
    required this.time,
    required this.category,
    this.isCompleted = false,
    DateTime? createdAt,
    this.completedAt,
    this.isEnabled = true,
    this.intervalMinutes = 30,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'time': '${time.hour}:${time.minute}',
      'category': category,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'isEnabled': isEnabled,
      'intervalMinutes': intervalMinutes,
    };
  }

  /// Create from JSON
  factory Reminder.fromJson(Map<String, dynamic> json) {
    final timeParts = (json['time'] as String).split(':');
    return Reminder(
      id: json['id'],
      title: json['title'],
      time: TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      ),
      category: json['category'],
      isCompleted: json['isCompleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      isEnabled: json['isEnabled'] ?? true,
      intervalMinutes: json['intervalMinutes'] ?? 30,
    );
  }

  /// Create a copy with updated fields
  Reminder copyWith({
    String? title,
    TimeOfDay? time,
    String? category,
    bool? isCompleted,
    DateTime? completedAt,
    bool? isEnabled,
    int? intervalMinutes,
  }) {
    return Reminder(
      id: id,
      title: title ?? this.title,
      time: time ?? this.time,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      isEnabled: isEnabled ?? this.isEnabled,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
    );
  }

  /// Get formatted time string (e.g., "09:00 AM")
  String get formattedTime {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Get color for category
  Color get categoryColor {
    switch (category.toLowerCase()) {
      case 'spiritual':
        return Colors.purple;
      case 'health':
        return Colors.green;
      case 'learning':
        return Colors.blue;
      case 'work':
        return Colors.orange;
      case 'personal':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  /// Check if reminder is for today and not completed
  bool get isActiveToday {
    if (!isEnabled || isCompleted) return false;
    return true;
  }

  /// Get next occurrence time for today
  DateTime get nextOccurrence {
    final now = DateTime.now();
    var nextTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If the time has passed, calculate next interval
    if (nextTime.isBefore(now)) {
      final minutesSinceMidnight = now.hour * 60 + now.minute;
      final reminderMinutes = time.hour * 60 + time.minute;
      final intervalsPassed =
          ((minutesSinceMidnight - reminderMinutes) / intervalMinutes).ceil();
      final nextMinutes = reminderMinutes + (intervalsPassed * intervalMinutes);

      if (nextMinutes < 24 * 60) {
        nextTime = DateTime(
          now.year,
          now.month,
          now.day,
          nextMinutes ~/ 60,
          nextMinutes % 60,
        );
      } else {
        // Next occurrence is tomorrow
        nextTime = DateTime(
          now.year,
          now.month,
          now.day + 1,
          time.hour,
          time.minute,
        );
      }
    }

    return nextTime;
  }

  /// Get voice announcement message
  String get voiceAnnouncement {
    final hour = time.hour;
    String timeGreeting;

    if (hour >= 5 && hour < 12) {
      timeGreeting = 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      timeGreeting = 'Good afternoon';
    } else if (hour >= 17 && hour < 21) {
      timeGreeting = 'Good evening';
    } else {
      timeGreeting = 'Hello';
    }

    return '$timeGreeting! It\'s time for $title. This is your $category reminder.';
  }

  /// Check if this reminder should trigger now (within last minute)
  bool shouldTriggerNow() {
    if (!isEnabled || isCompleted) return false;

    final now = DateTime.now();
    final next = nextOccurrence;
    final diff = now.difference(next).inMinutes.abs();

    return diff <= 1;
  }
}
