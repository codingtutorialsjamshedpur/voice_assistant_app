import 'package:flutter/services.dart';

enum HapticPattern {
  chipSelect,
  buttonConfirm,
  destructiveConfirm,
  milestoneAchieved,
  invalidInput,
  toggle,
  navigation,
}

class AppHaptic {
  static void light() {
    HapticFeedback.lightImpact();
  }

  static void medium() {
    HapticFeedback.mediumImpact();
  }

  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  static void selection() {
    HapticFeedback.selectionClick();
  }

  static void success() {
    HapticFeedback.mediumImpact();
  }

  static void error() {
    HapticFeedback.heavyImpact();
  }

  static void toggleOn() {
    HapticFeedback.lightImpact();
  }

  static void toggleOff() {
    HapticFeedback.lightImpact();
  }

  static void play(HapticPattern pattern) {
    switch (pattern) {
      case HapticPattern.chipSelect:
        HapticFeedback.selectionClick();
        break;
      case HapticPattern.buttonConfirm:
        HapticFeedback.mediumImpact();
        break;
      case HapticPattern.destructiveConfirm:
        HapticFeedback.heavyImpact();
        break;
      case HapticPattern.milestoneAchieved:
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 100), () {
          HapticFeedback.heavyImpact();
        });
        break;
      case HapticPattern.invalidInput:
        HapticFeedback.heavyImpact();
        break;
      case HapticPattern.toggle:
        HapticFeedback.lightImpact();
        break;
      case HapticPattern.navigation:
        HapticFeedback.lightImpact();
        break;
    }
  }
}
