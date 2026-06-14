import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/voice_controller.dart' hide ChatMessage;
import '../shared/theme/responsive.dart';
import '../services/tts_service.dart';
import '../services/chunked_playback_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// Chunked Message Display Widget
/// ═══════════════════════════════════════════════════════════════
///
/// Renders AI agent responses with intelligent chunked display
/// and synchronized word-level highlighting.
///
/// Features:
/// - Reveals chunks progressively as they're prepared
/// - Highlights words in real-time during playback
/// - Smooth transitions between chunks
/// - Blur effect on unread portions (optional)
/// - Graceful degradation for short messages
///
/// Visual Flow:
/// 1. Chunk 1 displays and starts speaking
/// 2. Words highlight in real-time as spoken
/// 3. Chunk 2 appears below when ready
/// 4. Chunk 1 highlighting ends, Chunk 2 begins
/// 5. Process repeats seamlessly
/// ═══════════════════════════════════════════════════════════════

class ChunkedMessageDisplay extends StatefulWidget {
  /// The message to display
  final ChatMessage message;

  /// Whether this is an AI message (affects styling)
  final bool isAIMessage;

  /// Base text style for the message
  final TextStyle baseTextStyle;

  /// Highlight color (default: yellow with transparency)
  final Color highlightColor;

  /// Whether to show blur on unread chunks
  final bool showBlurEffect;

  const ChunkedMessageDisplay({
    super.key,
    required this.message,
    this.isAIMessage = true,
    required this.baseTextStyle,
    this.highlightColor = const Color(0xFFFFE082),
    this.showBlurEffect = true,
  });

  @override
  State<ChunkedMessageDisplay> createState() => _ChunkedMessageDisplayState();
}

class _ChunkedMessageDisplayState extends State<ChunkedMessageDisplay>
    with TickerProviderStateMixin {
  late VoiceController _vc;
  late TTSService _tts;

  // Track word list for this message
  late List<String> _allWords;
  List<int> _chunkBoundaries = [];

  @override
  void initState() {
    super.initState();
    _vc = Get.find<VoiceController>();
    _tts = Get.find<TTSService>();

    // Preprocess the message text
    _preprocessMessage();
  }

  /// Preprocess message into words and track chunk boundaries
  void _preprocessMessage() {
    final wordRegex = RegExp(r'\s+');
    _allWords = widget.message.content
        .split(wordRegex)
        .where((w) => w.isNotEmpty)
        .toList();

    // Calculate chunk boundaries
    _chunkBoundaries = [];
    const int wordsPerChunk = ChunkedPlaybackService.wordsPerChunk;
    int wordCount = 0;
    while (wordCount < _allWords.length) {
      _chunkBoundaries.add(wordCount);
      wordCount += wordsPerChunk;
    }
    _chunkBoundaries.add(_allWords.length); // End boundary
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final isActive =
            _vc.currentSpeakingMessageId.value == widget.message.id;
        final gracePeriodOver = _vc.ttsGracePeriodOver.value;
        final currentWordIdx = _tts.progressWordIndex.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display all words with chunk-aware highlighting
            _buildChunkedText(
              isActive: isActive,
              gracePeriodOver: gracePeriodOver,
              currentWordIdx: currentWordIdx,
            ),
          ],
        );
      },
    );
  }

  /// Build the full message text with chunk highlighting
  Widget _buildChunkedText({
    required bool isActive,
    required bool gracePeriodOver,
    required int currentWordIdx,
  }) {
    final richSpans = <InlineSpan>[];

    for (int i = 0; i < _allWords.length; i++) {
      final word = _allWords[i];
      final isCurrentWord = isActive && gracePeriodOver && i <= currentWordIdx;
      final isNextWord = isActive && gracePeriodOver && i == currentWordIdx + 1;

      // Determine highlight state
      final shouldHighlight = isCurrentWord;
      final isUpcoming = isNextWord;

      richSpans.add(
        TextSpan(
          text: i < _allWords.length - 1 ? '$word ' : word,
          style: widget.baseTextStyle.copyWith(
            backgroundColor: shouldHighlight
                ? widget.highlightColor
                : (isUpcoming ? widget.highlightColor.withAlpha(100) : null),
            fontWeight: shouldHighlight ? FontWeight.w600 : FontWeight.normal,
            color: shouldHighlight
                ? Colors.black87
                : (isActive && gracePeriodOver && i > currentWordIdx
                    ? Colors.grey.shade600
                    : widget.baseTextStyle.color),
          ),
        ),
      );
    }

    // Apply blur to unread content if enabled
    final Widget content = RichText(
      text: TextSpan(children: richSpans),
    );

    if (widget.showBlurEffect && isActive && gracePeriodOver) {
      final unreadWordsStart = currentWordIdx + 1;
      if (unreadWordsStart < _allWords.length) {
        // Blur is applied via opacity in TtsAwareMessageBody
        // This widget focuses on highlighting coordination
      }
    }

    return AnimatedOpacity(
      opacity: isActive && gracePeriodOver ? 1.0 : 0.95,
      duration: const Duration(milliseconds: 300),
      child: content,
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// Chunk Progress Indicator Widget
/// ═══════════════════════════════════════════════════════════════
///
/// Shows progress through chunked message delivery
/// Displays which chunk is currently being played and total remaining
/// ═══════════════════════════════════════════════════════════════

class ChunkProgressIndicator extends StatelessWidget {
  const ChunkProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Get.find<ChunkedPlaybackService>();

    return Obx(() {
      if (!service.isPlayingChunked || service.totalChunks <= 1) {
        return const SizedBox.shrink();
      }

      final currentChunk = service.currentChunkIndex + 1;
      final totalChunks = service.totalChunks;
      final remaining = totalChunks - currentChunk;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Progress indicator
            SizedBox(
              width: context.r.scale(150),
              height: context.r.scale(6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(context.r.scale(3)),
                child: LinearProgressIndicator(
                  value: currentChunk / totalChunks,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.blue.shade400,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Text indicator
            Text(
              'Chunk $currentChunk/$totalChunks',
              style: TextStyle(
                fontSize: context.r.sp(12),
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            if (remaining > 0) ...[
              const SizedBox(width: 8),
              Chip(
                label: Text('$remaining more'),
                visualDensity: VisualDensity.compact,
                backgroundColor: Colors.blue.shade50,
                labelStyle: TextStyle(
                  fontSize: context.r.sp(11),
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

/// ═══════════════════════════════════════════════════════════════
/// Chunk Reveal Animation Widget
/// ═══════════════════════════════════════════════════════════════
///
/// Animates the reveal of new chunks as they become ready
/// ═══════════════════════════════════════════════════════════════

class ChunkRevealAnimation extends StatefulWidget {
  final Widget child;
  final bool isVisible;

  const ChunkRevealAnimation({
    super.key,
    required this.child,
    this.isVisible = true,
  });

  @override
  State<ChunkRevealAnimation> createState() => _ChunkRevealAnimationState();
}

class _ChunkRevealAnimationState extends State<ChunkRevealAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    if (widget.isVisible) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ChunkRevealAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
