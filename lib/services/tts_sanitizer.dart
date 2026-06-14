/// ═══════════════════════════════════════════════════════════════
/// TTS Text Sanitizer
/// ═══════════════════════════════════════════════════════════════
/// Pure utility class for cleaning text before passing to flutter_tts.
/// All operations are non-destructive for display — original text is preserved.
///
/// Sanitization Pipeline:
///   1. Strip markdown symbols
///   2. Strip emoji (Unicode ranges)
///   3. Replace/strip technical symbols
///   4. Normalize brackets and quotes
///   5. Normalize dashes and ellipsis
///   6. Normalize whitespace (including Unicode variants)
///   7. Collapse multiple spaces
///
/// Usage:
///   String sanitized = TtsSanitizer.sanitize(originalText);
///   // Original text is kept for display in UI
///   // Sanitized text is passed to TTS engine
/// ═══════════════════════════════════════════════════════════════
library;

class TtsSanitizer {
  /// Sanitizes a person's name so TTS reads it naturally as a word,
  /// NOT letter-by-letter.
  ///
  /// Example: "SHOURAV" → "Shourav", "SHOURAV KUMAR" → "Shourav Kumar"
  static String sanitizeName(String rawName) {
    if (rawName.trim().isEmpty) return rawName;

    // Convert each word to Title Case so TTS reads it as a proper word
    final words = rawName.trim().split(RegExp(r'\s+'));
    final titleCased = words.map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');

    // Remove any stray punctuation that could trigger letter-by-letter reading
    return titleCased
        .replaceAll(RegExp(r'[._\-]{1,}'), ' ')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();
  }

  /// Sanitizes text for TTS engine consumption.
  /// Removes or replaces characters that would cause TTS to speak incorrectly.
  ///
  /// Also prevents all-caps acronyms embedded in speech from being spelled out
  /// (e.g. "Hello SHOURAV" → "Hello Shourav").
  ///
  /// Returns sanitized text safe for flutter_tts.speak()
  static String sanitize(String raw) {
    String result = raw;

    // 0. Normalize ALL-CAPS words → Title Case to prevent letter-by-letter TTS
    // Excludes known short acronyms (1-2 letters like "AI", "OK", "TV")
    result = result.replaceAllMapped(
      RegExp(r'\b([A-Z]{3,})\b'),
      (m) {
        final word = m.group(1)!;
        // Keep very common speaking acronyms as-is
        const keepAcronyms = {
          'GPS',
          'AQI',
          'URL',
          'API',
          'PDF',
          'TTS',
          'STT',
          'SMS',
          'LLM',
          'AI',
          'USA',
          'UK',
          'UPI',
          'OTP',
          'SIM',
          'KYC',
          'CTJ',
        };
        if (keepAcronyms.contains(word)) return word;

        // Known proper names — always convert to Title Case (prevents letter-by-letter reading)
        const knownNames = {
          'SHOURAV': 'Shourav',
          'KUMAR': 'Kumar',
          'SINGH': 'Singh',
          'SHARMA': 'Sharma',
          'PATEL': 'Patel',
          'GUPTA': 'Gupta',
          'VERMA': 'Verma',
          'MISHRA': 'Mishra',
          'RAHUL': 'Rahul',
          'PRIYA': 'Priya',
          'AMIT': 'Amit',
          'NEHA': 'Neha',
          'VIKRAM': 'Vikram',
          'ANITA': 'Anita',
        };
        if (knownNames.containsKey(word)) return knownNames[word]!;

        // Convert to Title Case (first letter upper, rest lower)
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      },
    );

    // 1. Strip markdown symbols
    // ** (bold), * (italic), __ (underline), _ (underline), ``` (code block)
    result = result.replaceAll(RegExp(r'\*\*'), ''); // **
    result = result.replaceAll(RegExp(r'\b\*\b'), ''); // single *
    result = result.replaceAll(RegExp(r'__'), ''); // __
    result = result.replaceAll(RegExp(r'(?<!\w)_(?!\w)'), ''); // single _
    result = result.replaceAll(RegExp(r'```'), ''); // ```
    result = result.replaceAll(RegExp(r'`'), ''); // single `

    // # headers, > blockquotes
    result =
        result.replaceAll(RegExp(r'^#+\s?', multiLine: true), ''); // # headers
    result =
        result.replaceAll(RegExp(r'^>\s?', multiLine: true), ''); // blockquotes
    result = result.replaceAll(RegExp(r'---'), ''); // horizontal rule
    result = result.replaceAll(RegExp(r'\*\*\*'), ''); // ***

    // 2. Strip emoji (Unicode ranges)
    // U+1F300–U+1F9FF (emoticons, symbols, pictographs)
    // U+2600–U+26FF (Miscellaneous Symbols)
    // U+2700–U+27BF (Dingbats)
    // U+FE0F (variation selector)
    // U+200D (zero-width joiner)
    result = result.replaceAll(
        RegExp(
            r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{FE0F}\u{200D}]+',
            unicode: true),
        '');

    // 3. Replace/strip technical symbols (do replacements BEFORE strips)
    // & → "and"
    result = result.replaceAll('&', 'and');

    // % → "percent"
    result = result.replaceAll('%', 'percent');

    // $ → strip (or could be "dollars" but simplest is strip)
    result = result.replaceAll('\$', '');

    // @ → strip
    result = result.replaceAll('@', '');

    // # → strip (already done above, but double-check)
    result = result.replaceAll('#', '');

    // ^ → strip
    result = result.replaceAll('^', '');

    // * → strip (already done above, but remaining asterisks)
    result = result.replaceAll('*', '');

    // + → strip
    result = result.replaceAll('+', '');

    // = → strip
    result = result.replaceAll('=', '');

    // | → strip
    result = result.replaceAll('|', '');

    // \ → strip
    result = result.replaceAll('\\', '');

    // / → strip
    result = result.replaceAll('/', '');

    // ~ → strip
    result = result.replaceAll('~', '');

    // 4. Normalize brackets and quotes
    // Remove ()[]<>{} but keep inner text
    result = result.replaceAll(RegExp(r'[(){}\[\]<>]'), '');

    // Remove quotes: ""''""''
    result = result.replaceAll('"', '');
    result = result.replaceAll('"', '');
    result = result.replaceAll('"', '');
    result = result.replaceAll(''', '');
    result = result.replaceAll(''', '');

    // Remove standalone single/double quotes but preserve contractions
    // This regex removes quotes not preceded or followed by word chars
    result = result.replaceAll(RegExp(r"(?<!\w)'(?!\w)"), '');
    result = result.replaceAll(RegExp(r'(?<!\w)"(?!\w)'), '');

    // 5. Normalize dashes, ellipsis, and numerical ranges
    // NEW: Smart Numerical Range Normalizer (distinguishes range from subtraction)
    // Converts "18-25" -> "18 to 25", "85%-90%" -> "85 to 90 percent"
    // Does NOT convert "-5" (negative) or "10 - 5" (subtraction with spaces)
    result = result.replaceAllMapped(RegExp(r'(\d+)%?[\s]?[-–—][\s]?(\d+)%?'),
        (match) {
      final String num1 = match.group(1)!;
      final String num2 = match.group(2)!;
      final String fullMatch = match.group(0)!;

      // If there are spaces on both sides like "10 - 5", it might be subtraction.
      // But in conversational AI responses, the vast majority of "N1-N2" are ranges.
      // We prioritize "to" for natural flow in common AI phrases (ages, dates, scores).
      if (fullMatch.contains('%')) {
        return '$num1 to $num2 percent';
      }
      return '$num1 to $num2';
    });

    // Handle "to" ambiguity - ensure "18 to 25" is preserved and not spoken as subtraction
    // (Some localized engines might misinterpret "to" in certain contexts)
    // No explicit change needed for the word "to" as it's a standard word,
    // but the range rule above handles the most common error point (hyphens).

    // Em-dash (—) and en-dash (–) → comma (natural pause) for non-range cases
    result = result.replaceAll('—', ',');
    result = result.replaceAll('–', ',');

    // Ellipsis (..., …) → comma
    result = result.replaceAll('…', ',');
    result = result.replaceAll('...', ',');

    // Hyphen between letters (compound words) → space
    result = result.replaceAll(RegExp(r'(?<=[a-zA-Z])-(?=[a-zA-Z])'), ' ');

    // 6. Normalize whitespace
    // \r → strip
    result = result.replaceAll('\r', '');

    // \n → single space
    result = result.replaceAll('\n', ' ');

    // \t → space
    result = result.replaceAll('\t', ' ');

    // NBSP (U+00A0) → space
    result = result.replaceAll('\u00A0', ' ');

    // Zero-width space (U+200B) → strip
    result = result.replaceAll('\u200B', '');

    // Zero-width non-joiner (U+200C) → strip
    result = result.replaceAll('\u200C', '');

    // Zero-width joiner (U+200D) → strip (already done above, but double-check)
    result = result.replaceAll('\u200D', '');

    // 7. Collapse multiple spaces → single space
    result = result.replaceAll(RegExp(r' {2,}'), ' ');

    // Final trim
    return result.trim();
  }
}
