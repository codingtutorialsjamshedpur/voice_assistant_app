import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/query_prediction_controller.dart';
import '../controllers/voice_controller.dart';

class SuggestionBubble extends StatelessWidget {
  const SuggestionBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<QueryPredictionController>();

    return Obx(() {
      final suggestions = ctrl.currentSuggestions;

      // Show nothing until at least one suggestion exists
      if (suggestions.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'You might also like 💡',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                ),
              ),
            ),

            // One card per suggestion
            ...suggestions.map((s) => _SuggestionCard(suggestion: s)),
          ],
        ),
      );
    });
  }
}

class _SuggestionCard extends StatelessWidget {
  final SuggestionResult suggestion;
  const _SuggestionCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<QueryPredictionController>();
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        // When user taps a suggestion, treat it as a new query.
        // This feeds the algorithm and drives the next prediction cycle.
        ctrl.onUserQuery(suggestion.text);

        // Send the suggestion text to the voice controller as if user typed it
        try {
          final voiceController = Get.find<VoiceController>();
          voiceController.textController.text = suggestion.text;
          voiceController.sendMessage();
        } catch (e) {
          debugPrint('Voice controller error for suggestion tap: $e');
        }
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                suggestion.text,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}
