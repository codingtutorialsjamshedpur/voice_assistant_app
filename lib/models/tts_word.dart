import '../services/tts_sanitizer.dart';

/// ═══════════════════════════════════════════════════════════════
/// TtsWord Model
/// ═══════════════════════════════════════════════════════════════
/// Represents a single word with its display text, TTS-sanitized text,
/// line index, and character offsets in the sanitized string.
///
/// This model bridges the gap between:
/// - Original unsanitized text (for display)
/// - Sanitized TTS text (with character offsets from flutter_tts)
/// - Line-by-line rendering (for blur effect)
/// ═══════════════════════════════════════════════════════════════

class TtsWord {
  /// The word as it appears in the original unsanitized text (for display)
  final String display;

  /// The word as it appears in the sanitized TTS text (from flutter_tts offsets)
  final String tts;

  /// Which line this word belongs to (0-indexed)
  /// Lines are split by '\n' and soft-wrapped at ~60 chars
  final int lineIndex;

  /// Global sequential word index (0, 1, 2, ...) across the full message
  /// This is the PRIMARY matching key for TTS progress highlighting
  final int wordIndex;

  /// Start character offset in the sanitized TTS string (kept for blur logic)
  final int charStart;

  /// End character offset in the sanitized TTS string (kept for blur logic)
  final int charEnd;

  TtsWord({
    required this.display,
    required this.tts,
    required this.lineIndex,
    required this.wordIndex,
    required this.charStart,
    required this.charEnd,
  });

  /// Check if this word overlaps with a character range
  bool overlapsWithRange(int rangeStart, int rangeEnd) {
    return charStart <= rangeEnd && charEnd >= rangeStart;
  }

  @override
  String toString() =>
      'TtsWord(display: "$display", tts: "$tts", line: $lineIndex, idx: $wordIndex, chars: $charStart–$charEnd)';
}

/// ═══════════════════════════════════════════════════════════════
/// TTS Text Segmenter
/// ═══════════════════════════════════════════════════════════════
/// Segments text into display lines and maps each word to:
/// - Line index
/// - Character offsets in the sanitized string
///
/// This allows the UI to:
/// 1. Match setProgressHandler(start, end) to specific words
/// 2. Apply line-by-line blur effect
/// 3. Highlight words as they're spoken
/// ═══════════════════════════════════════════════════════════════

class TtsTextSegmenter {
  /// Segments original text into TtsWord list.
  ///
  /// Process:
  /// 1. Sanitize original → `sanitized`  (or use [preprocessedText] directly
  ///    when the caller has already run the full TTSService preprocessing pipeline)
  /// 2. Split original by '\n' and soft-wrap at ~60 chars → display lines
  /// 3. Split sanitized by whitespace → TTS words
  /// 4. Match words by index (preserving alignment)
  /// 5. Compute character offsets in sanitized string
  ///
  /// Pass [preprocessedText] = `TTSService.instance.preprocessText(original)`
  /// so that the TTS word list matches exactly what the engine will speak,
  /// guaranteeing that `progressWordIndex` events map to the correct display words.
  static List<TtsWord> segment(String original, {String? preprocessedText}) {
    // Use fully-preprocessed text when available (aligns with TTSService word list)
    final sanitized = preprocessedText ?? TtsSanitizer.sanitize(original);

    // Split original into display lines (preserving structure for UI)
    final displayLines = _splitIntoDisplayLines(original);

    // Get all display words (flat list for matching)
    final displayWords = _extractWordsFromLines(displayLines);

    // Get all TTS words (from sanitized/preprocessed text)
    final ttsWords =
        sanitized.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    // If counts don't match (aggressive sanitization), fall back to best-effort
    if (displayWords.length != ttsWords.length) {
      // Try to match by prefix-matching or index-limit
      return _fallbackSegmentation(original, sanitized, displayLines, ttsWords);
    }

    // Build TtsWord list with character offsets
    final result = <TtsWord>[];
    var charOffset = 0;

    for (int i = 0; i < ttsWords.length; i++) {
      final ttsWord = ttsWords[i];
      final displayWord = displayWords[i];

      // Find which line this word belongs to
      var lineIndex = 0;
      var cumulativeWordIndex = 0;
      for (int li = 0; li < displayLines.length; li++) {
        final lineWords = _extractWordsFromLines([displayLines[li]]);
        if (cumulativeWordIndex + lineWords.length > i) {
          lineIndex = li;
          break;
        }
        cumulativeWordIndex += lineWords.length;
      }

      // Compute character offsets in sanitized string
      // Skip leading whitespace to find actual word start
      while (charOffset < sanitized.length &&
          sanitized[charOffset].replaceAll(RegExp(r'\s'), '').isEmpty) {
        charOffset++;
      }

      final charStart = charOffset;
      final charEnd = charStart + ttsWord.length;
      charOffset = charEnd;

      result.add(TtsWord(
        display: displayWord,
        tts: ttsWord,
        lineIndex: lineIndex,
        wordIndex: i,
        charStart: charStart,
        charEnd: charEnd,
      ));
    }

    return result;
  }

  /// Fallback segmentation when word counts don't match
  static List<TtsWord> _fallbackSegmentation(
    String original,
    String sanitized,
    List<String> displayLines,
    List<String> ttsWords,
  ) {
    final result = <TtsWord>[];
    var charOffset = 0;

    // Use ttsWords length as primary source
    for (int i = 0; i < ttsWords.length; i++) {
      final ttsWord = ttsWords[i];

      // Find corresponding display word (best-effort by position)
      final displayWords = _extractWordsFromLines(displayLines);
      final displayWord = i < displayWords.length ? displayWords[i] : ttsWord;

      // Find line by index
      var lineIndex = 0;
      var cumulativeWords = 0;
      for (int li = 0; li < displayLines.length; li++) {
        final lineWords = _extractWordsFromLines([displayLines[li]]);
        if (cumulativeWords + lineWords.length > i) {
          lineIndex = li;
          break;
        }
        cumulativeWords += lineWords.length;
      }

      // Skip whitespace
      while (charOffset < sanitized.length &&
          sanitized[charOffset].replaceAll(RegExp(r'\s'), '').isEmpty) {
        charOffset++;
      }

      final charStart = charOffset;
      final charEnd = charStart + ttsWord.length;
      charOffset = charEnd;

      result.add(TtsWord(
        display: displayWord,
        tts: ttsWord,
        lineIndex: lineIndex,
        wordIndex: i,
        charStart: charStart,
        charEnd: charEnd,
      ));
    }

    return result;
  }

  /// Split text into display lines (by '\n' and soft-wrap at ~60 chars)
  static List<String> _splitIntoDisplayLines(String text) {
    final hardLines = text.split('\n');
    final displayLines = <String>[];

    for (final hardLine in hardLines) {
      final softLines = _softWrapLine(hardLine, maxCharsPerLine: 60);
      displayLines.addAll(softLines);
    }

    return displayLines;
  }

  /// Soft-wrap a single line at max character count
  static List<String> _softWrapLine(String line, {int maxCharsPerLine = 60}) {
    if (line.length <= maxCharsPerLine) {
      return [line];
    }

    final result = <String>[];
    var currentLine = '';

    for (final word in line.split(' ')) {
      if (currentLine.isEmpty) {
        currentLine = word;
      } else if ((currentLine.length + 1 + word.length) <= maxCharsPerLine) {
        currentLine += ' $word';
      } else {
        result.add(currentLine);
        currentLine = word;
      }
    }

    if (currentLine.isNotEmpty) {
      result.add(currentLine);
    }

    return result;
  }

  /// Extract all words from a list of display lines
  static List<String> _extractWordsFromLines(List<String> lines) {
    final words = <String>[];
    for (final line in lines) {
      words.addAll(line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty));
    }
    return words;
  }
}
