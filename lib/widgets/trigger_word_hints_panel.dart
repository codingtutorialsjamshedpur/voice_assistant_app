import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/language_model.dart';
import '../../shared/theme/responsive.dart';

class TriggerWordHintsPanel extends StatelessWidget {
  final LanguageModel? preferredLanguage;
  final VoidCallback? onEndOfThoughtPlay;
  final VoidCallback? onExitPlay;

  const TriggerWordHintsPanel({
    super.key,
    this.preferredLanguage,
    this.onEndOfThoughtPlay,
    this.onExitPlay,
  });

  @override
  Widget build(BuildContext context) {
    if (preferredLanguage == null) {
      return const SizedBox.shrink();
    }

    const String genericEnd = 'Palak stop';
    const String genericExit = 'Palak close';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.r.scale(16), vertical: context.r.scale(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTriggerCard(context,
                  triggerWord: genericEnd,
                  hint: 'End Conversation',
                  description: 'Stops listening & processes query',
                  color: Colors.blueAccent,
                  onPlay: onEndOfThoughtPlay,
                ),
              ),
              SizedBox(width: context.r.scale(12)),
              Expanded(
                child: _buildTriggerCard(context,
                  triggerWord: genericExit,
                  hint: 'Close App',
                  description: 'Exits the application completely',
                  color: Colors.red.shade400,
                  onPlay: onExitPlay,
                ),
              ),
            ],
          ),
          SizedBox(height: context.r.scale(12)),
          Text(
            'Tip: Say "Palak stop" to finish your query or "Palak close" to exit.',
            style: TextStyle(
              color: Colors.white.withAlpha(120),
              fontSize: context.r.sp(10),
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTriggerCard(BuildContext context, {
    required String triggerWord,
    required String hint,
    required String description,
    required Color color,
    VoidCallback? onPlay,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            onPlay?.call();
          },
          child: Padding(
            padding: EdgeInsets.all(context.r.scale(12)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        triggerWord,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: context.r.sp(18),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: context.r.scale(8)),
                    Icon(
                      Icons.volume_up,
                      color: color.withValues(alpha: 0.8),
                      size: context.r.scale(20),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  hint,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: context.r.sp(12),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: context.r.sp(10),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TriggerWordHintCard extends StatelessWidget {
  final String triggerWord;
  final String? phonetic;
  final String hint;
  final String description;
  final Color color;
  final VoidCallback? onPlay;

  const TriggerWordHintCard({
    super.key,
    required this.triggerWord,
    this.phonetic,
    required this.hint,
    required this.description,
    required this.color,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            onPlay?.call();
          },
          child: Padding(
            padding: EdgeInsets.all(context.r.scale(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        triggerWord,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: context.r.sp(20),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.volume_up,
                        color: color,
                        size: context.r.scale(24),
                      ),
                      onPressed: onPlay,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                if (phonetic != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    phonetic!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: context.r.sp(14),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  hint,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: context.r.sp(13),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: context.r.sp(11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
