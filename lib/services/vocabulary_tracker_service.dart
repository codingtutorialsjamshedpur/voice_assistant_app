/// ═══════════════════════════════════════════════════════════════
/// Vocabulary Tracker Service  (Task 3.4)
/// ═══════════════════════════════════════════════════════════════
///
/// Maintains a sliding window of unique words the user has used,
/// after stripping stopwords. Calculates vocabulary sophistication
/// and exposes the rolling query list for grade detection.
///
/// Hard limit: 2000 unique words (drops oldest on overflow).
/// ═══════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class VocabularyTrackerService extends GetxService {
  static const _maxWords = 2000;
  static const _recentQueryWindow = 20;
  static const _prefsKey = 'vocabulary_tracker_words';

  /// All unique words seen (capped at [_maxWords]).
  final _vocabulary = <String>[];

  /// Rolling window of last 20 raw queries.
  final _recentQueries = <String>[];

  /// Rx observable for vocabulary count (for UI binding if needed).
  final RxInt knownWordCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
    debugPrint('✅ [VocabularyTracker] Initialized');
  }

  // ── Stopwords ─────────────────────────────────────────────────────────

  static const _stopwords = {
    'a',
    'an',
    'the',
    'is',
    'are',
    'was',
    'were',
    'be',
    'been',
    'being',
    'have',
    'has',
    'had',
    'do',
    'does',
    'did',
    'will',
    'would',
    'could',
    'should',
    'may',
    'might',
    'shall',
    'can',
    'need',
    'dare',
    'ought',
    'used',
    'to',
    'of',
    'in',
    'for',
    'on',
    'with',
    'at',
    'by',
    'from',
    'up',
    'about',
    'into',
    'through',
    'during',
    'before',
    'after',
    'above',
    'below',
    'between',
    'each',
    'but',
    'and',
    'or',
    'nor',
    'so',
    'yet',
    'both',
    'either',
    'neither',
    'not',
    'only',
    'own',
    'same',
    'than',
    'too',
    'very',
    'just',
    'that',
    'this',
    'these',
    'those',
    'it',
    'its',
    'i',
    'me',
    'my',
    'myself',
    'we',
    'our',
    'ours',
    'you',
    'your',
    'he',
    'she',
    'they',
    'them',
    'what',
    'which',
    'who',
    'whom',
    'how',
    'when',
    'where',
    'why',
    'all',
    'any',
    'few',
    'more',
    'most',
    'other',
    'some',
    'such',
    'no',
  };

  // ── Public API ────────────────────────────────────────────────────────

  /// Track a new query — extracts words and adds to vocabulary.
  void trackQuery(String query) {
    // Maintain rolling query window
    if (_recentQueries.length >= _recentQueryWindow) {
      _recentQueries.removeAt(0);
    }
    _recentQueries.add(query);

    // Extract meaningful words
    final words = _extractWords(query);
    for (final word in words) {
      if (!_vocabulary.contains(word)) {
        if (_vocabulary.length >= _maxWords) {
          _vocabulary.removeAt(0); // drop oldest
        }
        _vocabulary.add(word);
      }
    }

    knownWordCount.value = _vocabulary.length;
    _save();
  }

  /// Check if a word is already known (used before).
  bool isWordKnown(String word) =>
      _vocabulary.contains(word.toLowerCase().trim());

  /// Vocabulary sophistication score 0.0–1.0.
  double get vocabularyLevel {
    if (_vocabulary.isEmpty) return 0.0;
    // Proxy: average word length of known vocabulary
    final avgLen = _vocabulary.fold<double>(0, (s, w) => s + w.length) /
        _vocabulary.length;
    return ((avgLen - 3) / 10).clamp(0.0, 1.0);
  }

  /// Get recent meaningful words (last query).
  Set<String> get recentWords {
    if (_recentQueries.isEmpty) return {};
    return Set<String>.from(_extractWords(_recentQueries.last));
  }

  /// Expose rolling query window for grade detection.
  List<String> get recentQueries => List.unmodifiable(_recentQueries);

  // ── Private ───────────────────────────────────────────────────────────

  List<String> _extractWords(String query) {
    return query
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(' ')
        .where((w) => w.isNotEmpty && w.length > 2 && !_stopwords.contains(w))
        .toList();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_vocabulary));
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final list = (jsonDecode(raw) as List<dynamic>).cast<String>();
        _vocabulary.addAll(list);
        knownWordCount.value = _vocabulary.length;
        debugPrint(
            '📂 [VocabularyTracker] Restored ${_vocabulary.length} words');
      }
    } catch (_) {}
  }
}
