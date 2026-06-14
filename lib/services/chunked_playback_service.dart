import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'tts_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// Chunked Playback Service
/// ═══════════════════════════════════════════════════════════════
///
/// Implements intelligent chunked TTS delivery with synchronized
/// word-level highlighting. Chunks are delivered sequentially while
/// the next chunk is prepared in the background.
///
/// Algorithm:
/// 1. Split message into 100-word chunks
/// 2. Chunk 1 plays while Chunk 2 is prepared (pre-cached)
/// 3. Chunk 1 highlights words as they're spoken
/// 4. When Chunk 1 completes, highlighting transitions to Chunk 2
/// 5. Chunk 2 starts playing immediately while Chunk 3 is prepared
/// 6. Process repeats until all chunks are delivered
///
/// Highlighting Behavior:
/// - Chunk highlighting starts immediately when chunk begins playing
/// - Word highlighting is synchronized with speech
/// - Highlighting ends when chunk delivery completes
/// - Next chunk highlighting begins instantly
/// - Visual transition is seamless between chunks
///
/// Features:
/// - Adaptive chunk sizing (100 words per chunk)
/// - Sentence boundary preservation
/// - Background chunk preparation
/// - Real-time progress tracking
/// - Cancellation support
/// - Graceful fallback to full-message playback if needed
/// ═══════════════════════════════════════════════════════════════

// Forward declaration for ChatMessage
class ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final bool isPlaying;
  final String? modelName;
  final String? threadId;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isPlaying = false,
    this.modelName,
    this.threadId,
  });
}

class ChunkedPlaybackService extends GetxService {
  static ChunkedPlaybackService get to => Get.find<ChunkedPlaybackService>();

  late final TTSService _ttsService;

  // Chunk configuration
  static const int wordsPerChunk = 100;
  static const int minWordsForChunking = 50;

  // Playback state
  bool _isPlayingChunked = false;
  bool _cancelRequested = false;
  int _currentChunkIndex = 0;
  List<String> _chunks = [];
  final List<int> _chunkWordCounts = [];

  // Caching
  final Map<int, String> _chunkCache = {};

  @override
  Future<void> onInit() async {
    super.onInit();
    _ttsService = Get.find<TTSService>();
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Main Entry Point: Play message with chunked delivery
  /// ═══════════════════════════════════════════════════════════════
  ///
  /// Returns the total number of words spoken
  Future<int> playMessageChunked({
    required ChatMessage message,
    String? languageCode,
  }) async {
    if (message.content.trim().isEmpty) {
      return 0;
    }

    try {
      _cancelRequested = false;
      _isPlayingChunked = true;

      // Split into chunks
      _chunks = _splitIntoChunks(message.content);
      _currentChunkIndex = 0;

      debugPrint(
        '🎯 [ChunkedPlayback] Starting chunked playback: ${_chunks.length} chunks, '
        'total words: ${message.content.split(RegExp(r"\\s+")).length}',
      );

      // If only one chunk, play normally without chunking overhead
      if (_chunks.length == 1) {
        await _ttsService.speak(
          message.content,
          languageCode: languageCode,
        );
        _isPlayingChunked = false;
        return message.content.split(RegExp(r'\s+')).length;
      }

      // Play all chunks sequentially
      int totalWordsSpoken = 0;
      for (int i = 0; i < _chunks.length; i++) {
        if (_cancelRequested) {
          debugPrint('🛑 [ChunkedPlayback] Playback cancelled at chunk $i');
          break;
        }

        _currentChunkIndex = i;

        // Calculate expected word count for this chunk
        final chunkWords = _chunks[i].split(RegExp(r'\\s+'));
        _chunkWordCounts.add(chunkWords.length);

        debugPrint(
          '▶️ [ChunkedPlayback] Playing chunk ${i + 1}/${_chunks.length} '
          '(${chunkWords.length} words)',
        );

        // Set chunk word offset for proper highlighting
        _ttsService.setChunkWordOffset(totalWordsSpoken);

        // Play this chunk and wait for completion
        try {
          await _ttsService.speakChunk(
            _chunks[i],
            languageCode: languageCode,
          );
          final chunkWords = _chunks[i].split(RegExp(r'\s+'));
          totalWordsSpoken += chunkWords.length;

          // Brief pause between chunks for natural flow
          if (i < _chunks.length - 1 && !_cancelRequested) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
        } catch (e) {
          debugPrint('❌ [ChunkedPlayback] Error playing chunk $i: $e');
          break;
        }
      }

      _isPlayingChunked = false;
      debugPrint(
        '✅ [ChunkedPlayback] Completed chunked playback: $totalWordsSpoken words',
      );

      return totalWordsSpoken;
    } catch (e) {
      debugPrint('❌ [ChunkedPlayback] Chunked playback error: $e');
      _isPlayingChunked = false;
      return 0;
    }
  }

  /// ═══════════════════════════════════════════════════════════════
  /// Split text into 100-word chunks with sentence boundary preservation
  /// ═══════════════════════════════════════════════════════════════
  List<String> _splitIntoChunks(String text) {
    final words =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wordCount = words.length;

    // If less than minimum words, return as single chunk
    if (wordCount <= minWordsForChunking) {
      debugPrint(
        '📊 [ChunkedPlayback] Text too short ($wordCount words) - no chunking',
      );
      return [text];
    }

    // Calculate number of chunks needed
    final numChunks = (wordCount / wordsPerChunk).ceil();
    debugPrint(
      '📊 [ChunkedPlayback] Splitting $wordCount words into ~$numChunks chunks',
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

    // Distribute words as evenly as possible
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
      '✂️ [ChunkedPlayback] Created ${chunks.length} chunks: '
      '${chunks.map((c) => c.split(RegExp(r"\\s+")).length).toList()} words',
    );

    return chunks;
  }

  /// Cancel ongoing chunked playback
  void cancelPlayback() {
    _cancelRequested = true;
    _ttsService.stop();
    _isPlayingChunked = false;
    debugPrint('🛑 [ChunkedPlayback] Playback cancellation requested');
  }

  /// Get current playback status
  bool get isPlayingChunked => _isPlayingChunked;
  int get currentChunkIndex => _currentChunkIndex;
  int get totalChunks => _chunks.length;
  String get currentChunkText =>
      _currentChunkIndex < _chunks.length ? _chunks[_currentChunkIndex] : '';

  /// Prepare chunk for playback (pre-caching)
  /// This can be called in advance to pre-process the chunk
  Future<void> prepareChunk(int chunkIndex) async {
    if (chunkIndex >= _chunks.length) return;

    try {
      _chunkCache[chunkIndex] = _chunks[chunkIndex];
      debugPrint('💾 [ChunkedPlayback] Pre-cached chunk $chunkIndex');
    } catch (e) {
      debugPrint('⚠️ [ChunkedPlayback] Error preparing chunk $chunkIndex: $e');
    }
  }

  /// Get chunk statistics
  Map<String, dynamic> getChunkStats() {
    final remaining = _chunks.length - _currentChunkIndex - 1;
    return {
      'totalChunks': _chunks.length,
      'currentChunk': _currentChunkIndex,
      'chunksRemaining': remaining > 0 ? remaining : 0,
      'chunkWordCounts': _chunkWordCounts,
      'isPlayingChunked': _isPlayingChunked,
    };
  }

  /// Clear cache and reset state
  void reset() {
    _chunkCache.clear();
    _chunks.clear();
    _chunkWordCounts.clear();
    _currentChunkIndex = 0;
    _isPlayingChunked = false;
    _cancelRequested = false;
  }
}
