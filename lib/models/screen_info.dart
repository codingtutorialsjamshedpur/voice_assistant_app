/// ════════════════════════════════════════════════════════════════
/// Screen Info Models — Data models for screen knowledge base
/// ════════════════════════════════════════════════════════════════
///
/// These models hold structured metadata about each screen in the
/// app so that the AI voice assistant can answer context-aware
/// questions about the app, explain gestures, and guide navigation.
/// ════════════════════════════════════════════════════════════════
library;

/// Information about a gesture interaction on a screen
class GestureInfo {
  /// Type of gesture: 'tap', 'double_tap', 'long_press', 'swipe', 'drag'
  final String type;

  /// Human-readable description of the gesture
  final String description;

  /// What happens when this gesture is performed
  final String action;

  const GestureInfo({
    required this.type,
    required this.description,
    required this.action,
  });

  Map<String, dynamic> toMap() => {
        'type': type,
        'description': description,
        'action': action,
      };

  @override
  String toString() => '[$type] $description → $action';
}

/// Information about an interactive button on a screen
class ButtonInfo {
  /// Internal name/id of the button
  final String name;

  /// Human-readable description of the button's purpose
  final String description;

  /// What happens on a single tap
  final String onTap;

  /// What happens on a double tap (optional)
  final String? onDoubleTap;

  /// What happens on a long press (optional)
  final String? onLongPress;

  const ButtonInfo({
    required this.name,
    required this.description,
    required this.onTap,
    this.onDoubleTap,
    this.onLongPress,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'onTap': onTap,
        if (onDoubleTap != null) 'onDoubleTap': onDoubleTap,
        if (onLongPress != null) 'onLongPress': onLongPress,
      };

  @override
  String toString() => '$name: $description';
}

/// Complete metadata about a screen in the application
class ScreenInfo {
  /// Internal route name (e.g. 'voice_chat', 'game')
  final String name;

  /// User-facing display name (e.g. 'Voice Chat', 'Game Hub')
  final String displayName;

  /// Short description of what the screen does
  final String description;

  /// Detailed explanation of the screen's purpose
  final String purpose;

  /// List of key features available on this screen
  final List<String> features;

  /// All gesture interactions supported on this screen
  final List<GestureInfo> gestures;

  /// All buttons visible on this screen
  final List<ButtonInfo> buttons;

  /// Voice commands the user can say on this screen
  final List<String> voiceCommands;

  /// Whether this screen has AI/voice assistant interaction
  final bool hasAIInteraction;

  /// Optional: screens that this screen can navigate to
  final List<String> navigatesTo;

  /// Optional: tip or important note about the screen
  final String? tip;

  const ScreenInfo({
    required this.name,
    required this.displayName,
    required this.description,
    required this.purpose,
    required this.features,
    required this.gestures,
    required this.buttons,
    required this.voiceCommands,
    required this.hasAIInteraction,
    this.navigatesTo = const [],
    this.tip,
  });

  /// Build a short context summary for the AI system prompt
  String toContextString() {
    final sb = StringBuffer();
    sb.writeln('Screen: $displayName');
    sb.writeln('Purpose: $purpose');
    sb.writeln('Features: ${features.join(", ")}');
    if (gestures.isNotEmpty) {
      sb.writeln('Gestures: ${gestures.map((g) => g.toString()).join("; ")}');
    }
    if (buttons.isNotEmpty) {
      sb.writeln('Buttons: ${buttons.map((b) => b.name).join(", ")}');
    }
    if (voiceCommands.isNotEmpty) {
      sb.writeln('Voice Commands: ${voiceCommands.join(", ")}');
    }
    if (navigatesTo.isNotEmpty) {
      sb.writeln('Navigates To: ${navigatesTo.join(", ")}');
    }
    if (tip != null) {
      sb.writeln('Tip: $tip');
    }
    return sb.toString().trim();
  }

  @override
  String toString() => 'ScreenInfo($displayName)';
}
