import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'tts_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// Chunked Highlight Service
/// ═══════════════════════════════════════════════════════════════
///
/// Implements intelligent chunked TTS delivery with synchronized
/// chunk-level highlighting and word-by-word synchronization.
///
/// Algorithm:
/// ─────────
/// 1. Split message into 2000-word chunks
///    Example: 1000-word message → 1 chunk (no chunking needed)
///             2000-word message → 1 chunk (exactly fits)
///             3000-word message → 2 chunks (1500 words each)
///
/// 2. Chunk 1 plays (read aloud / delivering) ~600 seconds for 1000 words
///    Simultaneously, Chunk 2 is prepared in background
///
/// 3. Word-by-word highlighting happens in real-time:
///    - Chunk 1 highlighting starts when chunk starts playing
///    - Each word highlights as it's spoken
///    - Chunk 1 highlighting ends when chunk playback completes
///    - Chunk 2 highlighting begins instantly when Chunk 2 starts playing
///
/// 4. This process repeats for all chunks seamlessly
///
/// Visual Flow:
/// ───────────
/// Stage 1: Chunk 1 Active
///   ┌─────────────────────┐
///   │ [Word 1 highlighted]│  ← Currently being spoken
///   │ [Word 2]            │  ← Ready to highlight
///   │ [Word 3]            │
///   │ ...                 │
///   │ [Word 1000]         │
///   └─────────────────────┘
///   Chunk 2 (background): Being prepared
///
/// Stage 2: Chunk 1 Complete → Chunk 2 Active
///   Chunk 1 highlighting ends ──┐
///                               ├─→ Seamless transition
///   Chunk 2 highlighting starts ┘
///
/// Features:
/// ─────────
/// - Adaptive chunk sizing (2000 words per chunk)
/// - Sentence boundary preservation
/// - Background chunk preparation
/// - Real-time word-by-word highlighting
/// - Chunk progress tracking
/// - Cancellation support
/// - Graceful degradation for short messages
/// ═══════════════════════════════════════════════════════════════

class ChunkedHighlightService extends GetxService {
  static ChunkedHighlightService get to => Get.find<ChunkedHighlightService>();

  late final TTSService _ttsService;

  // Chunk configuration
  static const int wordsPerChunk = 2000; // 2000-word chunks as requested
  static const int minWordsForChunking = 100; // Minimum to trigger chunking

  // Playback state
  final isPlayingChunked = false.obs;
  final currentChunkIndex = 0.obs;
  final totalChunks = 1.obs;
  final currentChunkText = ''.obs;
  final chunksRemaining = 0.obs;

  // Chunk management
  List<String> _chunks = [];
  List<int> _chunkWordCounts = [];
  int _cumulativeWordOffset = 0;
  bool _cancelRequested = false;

  // Chunk preparation cache
  final Map<int, String> _preprocessedCache = {};

  @override
  Future<void> onInit() async {
    super.onInit();
    _ttsService = Get.find<TTSService>();
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Main Entry Point: Play message with chunked delivery & highlighting
  /// ═══════════════════════════════════════════════════════════════
  Future<void> playMessageChunkedWithHighlighting({
    required String messageText,
    required String messageId,
    String? languageCode,
  }) async {
    if (messageText.trim().isEmpty) {
      return;
    }

    try {
      _cancelRequested = false;
      isPlayingChunked.value = true;
      _cumulativeWordOffset = 0;

      // Split into chunks
      _chunks = _splitIntoChunks(messageText);
      _chunkWordCounts = [];
      currentChunkIndex.value = 0;
      totalChunks.value = _chunks.length;

      debugPrint(
        '🎯 [ChunkedHighlight] Starting: ${_chunks.length} chunks, '
        'total words: ${messageText.split(RegExp(r"\s+")).length}',
      );

      // If only one chunk, play normally without overhead
      if (_chunks.length == 1) {
        await _playSingleChunk(
          text: _chunks[0],
          messageId: messageId,
          languageCode: languageCode,
        );
        isPlayingChunked.value = false;
        return;
      }

      // Play all chunks sequentially with background prep
      for (int i = 0; i < _chunks.length; i++) {
        if (_cancelRequested) {
          debugPrint('🛑 [ChunkedHighlight] Playback cancelled at chunk $i');
          break;
        }

        currentChunkIndex.value = i;
        chunksRemaining.value =
            _chunks.length - i - 1; // Remaining chunks after this

        // Start background preparation of next chunk
        if (i + 1 < _chunks.length) {
          _prepareNextChunkInBackground(i + 1);
        }

        // Play this chunk with highlighting
        await _playChunkWithHighlighting(
          chunkIndex: i,
          messageId: messageId,
          languageCode: languageCode,
        );

        if (_cancelRequested) break;
      }

      isPlayingChunked.value = false;
      debugPrint('✅ [ChunkedHighlight] Completed all chunks');
    } catch (e) {
      debugPrint('❌ [ChunkedHighlight] Error: $e');
      isPlayingChunked.value = false;
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Play a single chunk with word-by-word highlighting
  /// ═══════════════════════════════════════════════════════════════
  Future<void> _playChunkWithHighlighting({
    required int chunkIndex,
    required String messageId,
    String? languageCode,
  }) async {
    if (chunkIndex >= _chunks.length) return;

    final chunkText = _chunks[chunkIndex];
    final preprocessedText =
        _preprocessedCache[chunkIndex] ?? _ttsService.preprocessText(chunkText);

    debugPrint(
      '▶️ [ChunkedHighlight] Playing chunk ${chunkIndex + 1}/${_chunks.length}',
    );

    // Set the word offset so highlighting starts from the right word index
    _ttsService.setChunkWordOffset(_cumulativeWordOffset);

    try {
      // Speak the chunk
      final wordCount = await _ttsService.speakChunk(
        chunkText,
        languageCode: languageCode,
        preprocessedText: preprocessedText,
      );

      // Track word count for this chunk
      _chunkWordCounts.add(wordCount);
      _cumulativeWordOffset += wordCount;

      // Brief pause between chunks for natural flow
      if (chunkIndex < _chunks.length - 1 && !_cancelRequested) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } catch (e) {
      debugPrint('❌ [ChunkedHighlight] Error playing chunk $chunkIndex: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Play a single chunk (no multi-chunk overhead)
  /// ═══════════════════════════════════════════════════════════════
  Future<void> _playSingleChunk({
    required String text,
    required String messageId,
    String? languageCode,
  }) async {
    debugPrint('📊 [ChunkedHighlight] Single chunk (no splitting needed)');

    _ttsService.setChunkWordOffset(0);

    try {
      await _ttsService.speakChunk(
        text,
        languageCode: languageCode,
      );
    } catch (e) {
      debugPrint('❌ [ChunkedHighlight] Error playing single chunk: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Background preparation of next chunk
  /// ═══════════════════════════════════════════════════════════════
  void _prepareNextChunkInBackground(int nextChunkIndex) {
    if (nextChunkIndex >= _chunks.length ||
        _preprocessedCache.containsKey(nextChunkIndex)) {
      return;
    }

    // Start preprocessing but don't await (non-blocking)
    Future.microtask(() {
      try {
        final preprocessed =
            _ttsService.preprocessText(_chunks[nextChunkIndex]);
        _preprocessedCache[nextChunkIndex] = preprocessed;
        debugPrint('💾 [ChunkedHighlight] Pre-cached chunk $nextChunkIndex');
      } catch (e) {
        debugPrint(
            '⚠️ [ChunkedHighlight] Error preparing chunk $nextChunkIndex: $e');
      }
    });
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Split text into 2000-word chunks with sentence boundary preservation
  /// ═══════════════════════════════════════════════════════════════
  List<String> _splitIntoChunks(String text) {
    final words =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wordCount = words.length;

    // If less than minimum words, return as single chunk
    if (wordCount <= minWordsForChunking) {
      debugPrint(
        '📊 [ChunkedHighlight] Text too short ($wordCount words) - no chunking',
      );
      return [text];
    }

    // Calculate number of chunks needed for 2000-word chunks
    final numChunks = (wordCount / wordsPerChunk).ceil();
    debugPrint(
      '📊 [ChunkedHighlight] Splitting $wordCount words into ~$numChunks chunks '
      '($wordsPerChunk words per chunk)',
    );

    return _splitIntoNChunks(text, numChunks);
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Split text into N chunks on sentence boundaries
  /// ═══════════════════════════════════════════════════════════════
  List<String> _splitIntoNChunks(String text, int targetChunks) {
    if (targetChunks <= 1) {
      return [text];
    }

    final words =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final chunks = <String>[];
    var currentChunk = <String>[];

    // Distribute words as evenly as possible across target chunks
    final wordsPerChunk = (words.length / targetChunks).ceil();

    for (int i = 0; i < words.length; i++) {
      currentChunk.add(words[i]);

      final word = words[i];
      final isSentenceEnd =
          word.endsWith('.') || word.endsWith('!') || word.endsWith('?');
      final hasEnoughWords = currentChunk.length >= wordsPerChunk;
      final isLastWord = i == words.length - 1;

      // Create chunk at sentence boundary when we have enough words
      if ((isSentenceEnd && hasEnoughWords) ||
          (isLastWord && currentChunk.isNotEmpty)) {
        chunks.add(currentChunk.join(' '));
        currentChunk = [];
      }
    }

    // Add remaining words if any
    if (currentChunk.isNotEmpty) {
      if (chunks.isNotEmpty) {
        // Merge with previous chunk to avoid tiny last chunks
        chunks[chunks.length - 1] += ' ${currentChunk.join(' ')}';
      } else {
        chunks.add(currentChunk.join(' '));
      }
    }

    debugPrint(
      '✂️ [ChunkedHighlight] Created ${chunks.length} chunks: '
      '${chunks.map((c) => c.split(RegExp(r"\s+")).length).toList()} words',
    );

    return chunks;
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Cancel ongoing playback
  /// ═══════════════════════════════════════════════════════════════
  void cancelPlayback() {
    _cancelRequested = true;
    _ttsService.stop();
    isPlayingChunked.value = false;
    _preprocessedCache.clear();
    _chunks.clear();
    _chunkWordCounts.clear();
    _cumulativeWordOffset = 0;
    debugPrint('🛑 [ChunkedHighlight] Playback cancelled');
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Get chunk statistics
  /// ═══════════════════════════════════════════════════════════════
  Map<String, dynamic> getChunkStats() {
    return {
      'totalChunks': totalChunks.value,
      'currentChunk': currentChunkIndex.value,
      'chunksRemaining': chunksRemaining.value,
      'chunkWordCounts': _chunkWordCounts,
      'isPlayingChunked': isPlayingChunked.value,
      'cumulativeWordOffset': _cumulativeWordOffset,
    };
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Reset state
  /// ═══════════════════════════════════════════════════════════════
  void reset() {
    _preprocessedCache.clear();
    _chunks.clear();
    _chunkWordCounts.clear();
    _cumulativeWordOffset = 0;
    currentChunkIndex.value = 0;
    totalChunks.value = 1;
    isPlayingChunked.value = false;
    _cancelRequested = false;
  }
}
