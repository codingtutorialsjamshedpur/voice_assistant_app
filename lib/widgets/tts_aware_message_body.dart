import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/voice_controller.dart';
import '../models/tts_word.dart';
import '../services/tts_service.dart';
import '../shared/widgets/typewriter_text.dart';

/// ═══════════════════════════════════════════════════════════════
/// TTS-Aware Message Body Widget  (Progressive-Reveal Edition)
/// ═══════════════════════════════════════════════════════════════
///
/// During first-time auto-playback:
///   • Words appear one-by-one in sync with the TTS audio.
///   • The currently spoken word is highlighted with a purple tint.
///   • Words that have been revealed but are NOT the current word
///     are shown at full opacity with no highlight.
///   • Words not yet reached remain invisible (opacity 0).
///
/// After TTS finishes / is stopped / on "Read Aloud" replay:
///   • The full message is visible (progressive reveal is complete).
///   • During replay (manual "Read Aloud"), the currently spoken word
///     is highlighted in the same way — all other words are visible.
///
/// This widget observes:
///   • VoiceController.progressiveMessageId  — which message is being revealed
///   • VoiceController.progressiveWordCount  — how many words are visible now
///   • VoiceController.currentSpeakingMessageId — which message is "active" for highlight
///   • TTSService.progressWordIndex          — which word is currently highlighted
/// ═══════════════════════════════════════════════════════════════

class TtsAwareMessageBody extends StatefulWidget {
  /// The chat message to render
  final ChatMessage message;

  /// Background color for highlighted words (default: light yellow)
  final Color highlightColor;

  /// Base text style
  final TextStyle baseStyle;

  /// Whether this is a user message (affects highlight colour variant)
  final bool isUserMessage;

  const TtsAwareMessageBody({
    super.key,
    required this.message,
    this.highlightColor = const Color(0xFFFFE082),
    required this.baseStyle,
    this.isUserMessage = true,
  });

  @override
  State<TtsAwareMessageBody> createState() => _TtsAwareMessageBodyState();
}

class _TtsAwareMessageBodyState extends State<TtsAwareMessageBody> {
  late List<TtsWord> _wordList;
  late VoiceController _vc;
  late TTSService _tts;

  @override
  void initState() {
    super.initState();
    _vc = Get.find<VoiceController>();
    _tts = Get.find<TTSService>();

    // Strip AI-side tags before display / TTS:
    //   [OPTIONS:A:<q>|B:<q>|C:<q>]  → rendered as curiosity chips
    //   [MY_VERSION:<text>]           → rendered as "Hear my version" button
    // Neither tag should appear in chat bubble text or be spoken aloud.
    final rawContent = widget.message.content
        .replaceAll(
          RegExp(r'\[OPTIONS:A:.+?\|B:.+?\|C:.+?\]', dotAll: true),
          '',
        )
        .replaceAll(
          RegExp(r'\[MY_VERSION:[\s\S]+?\](?:\s*)$', multiLine: true),
          '',
        )
        .trim();

    // Segment message using same preprocessing pipeline as TTSService so that
    // progressWordIndex events map to the correct display words.
    String? preprocessed;
    try {
      preprocessed = _tts.preprocessText(rawContent);
    } catch (_) {}
    _wordList = TtsTextSegmenter.segment(
      rawContent,
      preprocessedText: preprocessed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final activeMessageId = _vc.currentSpeakingMessageId.value;
      final progressiveMsgId = _vc.progressiveMessageId.value;
      final progressiveCount = _vc.progressiveWordCount.value;
      final currentWordIdx = _tts.progressWordIndex.value;

      final bool isThisMessageBeingRevealed =
          progressiveMsgId == widget.message.id;

      // Determine how many words to show:
      // • If this message is being progressively revealed → show progressiveCount words
      // • Otherwise → show all words (reveal is done)
      final int visibleUpTo = isThisMessageBeingRevealed
          ? progressiveCount
          : _wordList.length; // all words visible

      // Is TTS currently reading THIS message (for highlighting)?
      final bool isActive = activeMessageId == widget.message.id;

      final bool isLatestRevealedWord =
          isThisMessageBeingRevealed && visibleUpTo > 0;
      final int latestWordIdx = visibleUpTo - 1;

      return Wrap(
        children: [
          for (int i = 0; i < _wordList.length; i++)
            _buildWord(
              word: _wordList[i],
              isVisible: i < visibleUpTo,
              isHighlighted: isActive &&
                  currentWordIdx >= 0 &&
                  _wordList[i].wordIndex == currentWordIdx,
              useTypewriter:
                  isLatestRevealedWord && i == latestWordIdx && isActive,
            ),
        ],
      );
    });
  }

  Widget _buildWord({
    required TtsWord word,
    required bool isVisible,
    required bool isHighlighted,
    required bool useTypewriter,
  }) {
    final wordStyle = widget.baseStyle.copyWith(
      color: isHighlighted
          ? widget.baseStyle.color?.withAlpha(255)
          : widget.baseStyle.color,
      fontWeight:
          isHighlighted ? FontWeight.w600 : widget.baseStyle.fontWeight,
    );

    final textWidget = useTypewriter
        ? TypewriterText(
            text: '${word.display} ',
            style: wordStyle,
            isActive: true,
          )
        : Text(
            '${word.display} ',
            style: wordStyle,
          );

    // Wrap in animated container for highlight background
    final Widget wordContent = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
      decoration: BoxDecoration(
        color: isHighlighted
            ? const Color(0xFFE1BEE7).withAlpha(180)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: isHighlighted
            ? Border.all(
                color: const Color(0xFFBA68C8).withAlpha(100),
                width: 1,
              )
            : null,
      ),
      child: textWidget,
    );

    // Animate visibility: fade in when word is first revealed
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 80),
      child: wordContent,
    );
  }
}
