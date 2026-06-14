import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../controllers/voice_assistant_game_controller.dart';
import '../../../shared/widgets/glassmorphic_dialog.dart';

class VoiceGameHelpHint extends StatelessWidget {
  final OrbState currentState;

  const VoiceGameHelpHint({
    super.key,
    required this.currentState,
  });

  static const Map<OrbState, String> hintMap = {
    OrbState.idle: '👂 Single tap to start listening',
    OrbState.listening: '🎤 Listen for triggers',
    OrbState.processing: '⏳ AI is thinking...\n⏸️ Double tap to cancel',
    OrbState.speaking: '👂 Listen to response\n🎤 Speak anytime to interrupt',
    OrbState.farewell: '👋 Thanks for playing!',
  };

  void _showHelpDialog() {
    HapticFeedback.mediumImpact();

    final stateHint = hintMap[currentState] ?? 'Tap for help';

    GlassmorphicDialogHelper.showInfo(
      title: 'How to use Palak',
      message: 'Status: $stateHint\n\n'
          '• Single Tap: Start listening\n'
          '• Double Tap: Reset session\n'
          '• Triple Tap: Clear mic & models\n'
          '• "Palak stop": End your query\n'
          '• "Palak close": Exit the app',
      subtitle: 'Talk naturally to Palak in your language!',
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showHelpDialog,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30),
        ),
        child: const Icon(
          Icons.help,
          color: Colors.white70,
          size: 20,
        ),
      ),
    );
  }
}
