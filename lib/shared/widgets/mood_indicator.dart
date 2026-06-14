// lib/shared/widgets/mood_indicator.dart
// Phase 2 - Mood Indicator Widget
// Displays detected user mood with emoji and animation

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/mood_state_model.dart';
import '../../controllers/voice_controller.dart';

/// Mood indicator widget showing current detected mood
/// Displays emoji, mood name, and updates reactively
class MoodIndicator extends StatefulWidget {
  final double size;
  final Duration animationDuration;

  const MoodIndicator({
    super.key,
    this.size = 48,
    this.animationDuration = const Duration(milliseconds: 500),
  });

  @override
  State<MoodIndicator> createState() => _MoodIndicatorState();
}

class _MoodIndicatorState extends State<MoodIndicator>
    with SingleTickerProviderStateMixin {
  late VoiceController _voiceController;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _voiceController = Get.find<VoiceController>();

    // Setup animations
    _animController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );

    _rotateAnimation = Tween<double>(begin: 0, end: 0.1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Listen to mood changes
    ever(_voiceController.currentMood, (_) {
      // Restart animation when mood changes
      _animController.forward(from: 0.0);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final mood = _voiceController.currentMood.value;

      if (mood == null || mood == MoodType.neutral) {
        return const SizedBox.shrink();
      }

      return Tooltip(
        message: _getMoodDescription(mood),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: RotationTransition(
            turns: _rotateAnimation,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _getMoodColors(mood),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _getMoodColors(mood).first.withAlpha(128),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _getMoodEmoji(mood),
                  style: TextStyle(fontSize: widget.size * 0.6),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  /// Get emoji for mood type
  String _getMoodEmoji(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return '😊';
      case MoodType.excited:
        return '🎉';
      case MoodType.sad:
        return '😢';
      case MoodType.stressed:
        return '😰';
      case MoodType.anxious:
        return '😟';
      case MoodType.tired:
        return '😴';
      case MoodType.angry:
        return '😠';
      case MoodType.neutral:
        return '😐';
    }
  }

  /// Get gradient colors for mood
  List<Color> _getMoodColors(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return [Colors.amber.shade300, Colors.orange.shade400];
      case MoodType.excited:
        return [Colors.pink.shade300, Colors.purple.shade400];
      case MoodType.sad:
        return [Colors.blue.shade300, Colors.cyan.shade400];
      case MoodType.stressed:
        return [Colors.red.shade300, Colors.orange.shade400];
      case MoodType.anxious:
        return [Colors.indigo.shade300, Colors.purple.shade400];
      case MoodType.tired:
        return [Colors.grey.shade300, Colors.blueGrey.shade400];
      case MoodType.angry:
        return [Colors.red.shade400, Colors.deepOrange.shade500];
      case MoodType.neutral:
        return [Colors.grey.shade300, Colors.grey.shade400];
    }
  }

  /// Get mood description
  String _getMoodDescription(MoodType mood) {
    switch (mood) {
      case MoodType.happy:
        return 'Happy 😊 - You seem cheerful!';
      case MoodType.excited:
        return 'Excited 🎉 - You\'re very enthusiastic!';
      case MoodType.sad:
        return 'Sad 😢 - I\'m here if you need to talk';
      case MoodType.stressed:
        return 'Stressed 😰 - Let\'s work through this together';
      case MoodType.anxious:
        return 'Anxious 😟 - You seem worried';
      case MoodType.tired:
        return 'Tired 😴 - You need some rest';
      case MoodType.angry:
        return 'Angry 😠 - I understand your frustration';
      case MoodType.neutral:
        return 'Neutral 😐 - How are you feeling?';
    }
  }
}
