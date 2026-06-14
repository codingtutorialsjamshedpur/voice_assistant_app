import 'dart:async';
import 'package:get/get.dart';
import '../services/tts_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// TTS Chunk Controller
/// ═══════════════════════════════════════════════════════════════
/// Manages chunked playback of long messages.
///
/// Strategy:
/// - Messages ≤ 50 words: single chunk (no chunking)
/// - Messages 51–150 words: 2 chunks of ~equal size
/// - Messages > 150 words: chunks of ~40 words each
///
/// Always splits on sentence boundaries (., !, ?) to maintain naturalness.
///
/// Features:
/// - visibleChunks observable: UI shows only this many chunks
/// - playAll(): sequentially plays each chunk, waiting for completion
/// - cancel(): stops playback and cleanup
/// ═══════════════════════════════════════════════════════════════

class TtsChunkController {
  /// The full text split into chunks
  final List<String> chunks;

  /// Reference to TTS service
  final TTSService tts;

  /// How many chunks are currently visible in the UI
  final RxInt visibleChunks = 1.obs;

  /// Flag to signal cancellation
  bool _cancelled = false;

  /// The language code to override flutter_tts
  final String? languageCode;

  // Streaming TTS state
  // ignore: unused_field
  double _speakingRate = 1.0;
  // ignore: unused_field
  double _pitch = 0.0;

  void setSpeakingRate(double rate) => _speakingRate = rate;
  void setPitch(double pitch) => _pitch = pitch;
  void resetToOptimized() {
    _speakingRate = 1.0;
    _pitch = 0.0;
  }

  TtsChunkController({
    required String fullText,
    required this.tts,
    this.languageCode,
  }) : chunks = _splitIntoChunks(fullText);

  /// Play all chunks sequentially
  ///
  /// Each chunk:
  /// 1. Increments visibleChunks (UI updates to show new text)
  /// 2. Sets the chunk word offset on TTS service
  /// 3. Calls tts.speakChunk() and waits for completion
  /// 4. Accumulates word offset for next chunk
  /// 5. Checks _cancelled flag between chunks
  Future<void> playAll() async {
    _cancelled = false;
    int cumulativeWordOffset = 0;
    // Cache for preprocessed chunk texts to allow background prep
    final Map<int, String> preprocessedCache = {};

    for (int i = 0; i < chunks.length; i++) {
      if (_cancelled) break;

      visibleChunks.value = i + 1;

      // Tell TTS service where this chunk's words start in the global index
      tts.setChunkWordOffset(cumulativeWordOffset);

      try {
        // If next chunk exists, start preprocessing it in background so it's
        // ready by the time we need to speak it.
        if (i + 1 < chunks.length && !preprocessedCache.containsKey(i + 1)) {
          // Start preprocessing but don't await
          () async {
            try {
              final pre = tts.preprocessText(chunks[i + 1]);
              preprocessedCache[i + 1] = pre;
            } catch (_) {}
          }();
        }

        // Use preprocessed text for this chunk if available
        final preprocessedForThis = preprocessedCache[i];
        final wordCount = await tts.speakChunk(
          chunks[i],
          languageCode: languageCode,
          preprocessedText: preprocessedForThis,
        );
        cumulativeWordOffset += wordCount;
      } catch (e) {
        // If a chunk fails, stop playback
        break;
      }

      if (_cancelled) break;
    }

    // Final cleanup
    visibleChunks.value = chunks.length;
  }

  Future<void> speakStreaming(Stream<String> textStream) async {
    final buffer = StringBuffer();
    bool firstChunkSpoken = false;

    await for (final chunk in textStream) {
      buffer.write(chunk);
      final text = buffer.toString();

      if (!firstChunkSpoken) {
        final firstBreak = _findNaturalBreak(text);
        if (firstBreak > 0) {
          final firstChunk = text.substring(0, firstBreak);
          await tts.speak(firstChunk);
          buffer.clear();
          buffer.write(text.substring(firstBreak));
          firstChunkSpoken = true;
        }
      }
    }

    if (buffer.isNotEmpty) {
      await tts.speak(buffer.toString());
    }
  }

  int _findNaturalBreak(String text) {
    const minChars = 40;
    if (text.length < minChars) return -1;
    for (final pattern in ['. ', '! ', '? ', ', ', '। ', '॥ ']) {
      final idx = text.indexOf(pattern, minChars);
      if (idx > 0) return idx + pattern.length;
    }
    return -1;
  }

  /// Cancel playback and cleanup
  void cancel() {
    _cancelled = true;
    tts.stop();
    visibleChunks.value = chunks.length;
  }

  /// Split text into chunks based on word count and sentence boundaries
  ///
  /// Rules:
  /// - ≤ 50 words: [fullText] (no chunking)
  /// - 51–150 words: 2 chunks
  /// - > 150 words: chunks of ~40 words
  ///
  /// Always split on sentence boundaries (., !, ?)
  static List<String> _splitIntoChunks(String text) {
    final words =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wordCount = words.length;

    // Rule 1: ≤ 50 words → no chunking
    if (wordCount <= 50) {
      return [text];
    }

    // Rule 2: 51–150 words → 2 chunks
    if (wordCount <= 150) {
      return _splitIntoNChunks(text, 2);
    }

    // Rule 3: > 150 words → ~40 word chunks
    final numChunks = (wordCount / 40).ceil();
    return _splitIntoNChunks(text, numChunks);
  }

  /// Split text into roughly N equal chunks, always at sentence boundaries
  static List<String> _splitIntoNChunks(String text, int numChunks) {
    if (numChunks <= 1) {
      return [text];
    }

    final words =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final wordsPerChunk = (words.length / numChunks).ceil();

    final chunks = <String>[];
    var currentChunk = <String>[];

    for (int i = 0; i < words.length; i++) {
      currentChunk.add(words[i]);

      // Check if we've reached a sentence boundary and hit the target word count
      final word = words[i];
      final isSentenceEnd =
          word.endsWith('.') || word.endsWith('!') || word.endsWith('?');
      final hasEnoughWords = currentChunk.length >= (wordsPerChunk * 0.8);

      if (isSentenceEnd && hasEnoughWords && chunks.length < numChunks - 1) {
        // Create a chunk at sentence boundary
        chunks.add(currentChunk.join(' '));
        currentChunk = [];
      }
    }

    // Add remaining words as final chunk
    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.join(' '));
    }

    // If chunking created too many chunks, merge some
    while (chunks.length > numChunks) {
      // Merge the two smallest chunks
      chunks[0] = '${chunks[0]} ${chunks[1]}';
      chunks.removeAt(1);
    }

    // If not enough chunks, try again (edge case)
    if (chunks.length < numChunks && chunks.length > 1) {
      // Split the largest chunk further
      // For now, just return what we have
    }

    return chunks;
  }
}
