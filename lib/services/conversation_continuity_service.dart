/// ═══════════════════════════════════════════════════════════════
/// Conversation Continuity Service  (Task 5.3)
/// ═══════════════════════════════════════════════════════════════
///
/// Provides cross-session and within-session memory continuity:
///
///   1. On session start, detects if the last session was < 48 hours
///      ago and injects an opening reference to the last topic.
///   2. Resolves implicit references ("it", "Why?") from a stack of
///      the last 5 mentioned entities.
///   3. Builds a context snippet to inject into the system prompt.
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConversationContinuityService extends GetxService {
  static const _prefsKey = 'conversation_continuity';
  static const _maxEntityStack = 5;

  /// Rolling stack of the last [_maxEntityStack] mentioned entities.
  final _entityStack = <String>[];

  /// When the previous session ended.
  DateTime? _lastSessionTime;

  /// The main topic of the last session.
  String? _lastSessionTopic;

  /// Whether we have shown the "earlier you asked about..." greeting.
  bool _continuityGreetingShown = false;

  @override
  void onInit() {
    super.onInit();
    _load();
    debugPrint('✅ [ConversationContinuity] Initialized');
  }

  @override
  void onClose() {
    _save();
    super.onClose();
  }

  // ── Public API ────────────────────────────────────────────────────────

  /// Returns an opening line if the last session was within 48 hours,
  /// otherwise returns null.
  String? buildContinuityGreeting() {
    if (_continuityGreetingShown) return null;
    if (_lastSessionTopic == null || _lastSessionTime == null) return null;

    final elapsed = DateTime.now().difference(_lastSessionTime!).inHours;

    if (elapsed <= 48) {
      _continuityGreetingShown = true;
      return 'Earlier you were asking about $_lastSessionTopic — '
          'want to continue, or something new?';
    }
    return null;
  }

  /// Track a query — extract entities and update the entity stack.
  void trackQuery(String query) {
    final entity = _extractPrimaryEntity(query);
    if (entity.isNotEmpty) {
      if (_entityStack.length >= _maxEntityStack) {
        _entityStack.removeAt(0);
      }
      _entityStack.add(entity);
    }

    // Update last session topic
    if (entity.isNotEmpty) {
      _lastSessionTopic = entity;
    }
    _lastSessionTime = DateTime.now();
  }

  /// Resolve implicit query references like "it", "Why?", "Tell me more".
  ///
  /// Returns the enriched query string with resolved references.
  String resolveImplicitReferences(String query) {
    final lower = query.trim().toLowerCase();
    final lastEntity = _entityStack.isNotEmpty ? _entityStack.last : null;

    if (lastEntity == null) return query;

    if (lower == 'why?' || lower == 'but why?' || lower == 'kyun?') {
      return 'Why does $lastEntity happen?';
    }

    if (lower == 'tell me more' ||
        lower == 'aur batao' ||
        lower == 'continue') {
      return 'Tell me more about $lastEntity.';
    }

    if (lower.contains(RegExp(r'\bit\b')) && !lower.contains(lastEntity)) {
      return query.replaceAll(RegExp(r'\bit\b'), lastEntity);
    }

    return query;
  }

  /// Build the top-2 entity context snippet for system prompt injection.
  String buildEntityContextSnippet() {
    if (_entityStack.isEmpty) return '';
    final top2 = _entityStack.reversed.take(2).toList();
    return 'Recent topics the user was discussing: ${top2.join(', ')}.';
  }

  // ── Private ───────────────────────────────────────────────────────────

  String _extractPrimaryEntity(String query) {
    // Simple heuristic: take 3–5 words after the question word
    final cleaned = query.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final words = cleaned.split(' ').where((w) => w.isNotEmpty).toList();

    // Skip leading question words
    const skipWords = {
      'what',
      'why',
      'how',
      'who',
      'where',
      'when',
      'is',
      'are',
      'does',
      'do',
      'tell',
      'me',
      'explain',
      'the',
      'a',
      'an',
    };
    final meaningful = words
        .where((w) => !skipWords.contains(w.toLowerCase()))
        .take(4)
        .toList();

    return meaningful.join(' ').trim();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey,
          jsonEncode({
            'entityStack': _entityStack,
            'lastSessionTime': _lastSessionTime?.toIso8601String(),
            'lastSessionTopic': _lastSessionTopic,
          }));
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final stack =
            (data['entityStack'] as List<dynamic>?)?.cast<String>() ?? [];
        _entityStack.addAll(stack);
        if (data['lastSessionTime'] != null) {
          _lastSessionTime = DateTime.parse(data['lastSessionTime'] as String);
        }
        _lastSessionTopic = data['lastSessionTopic'] as String?;
        debugPrint(
            '📂 [ConversationContinuity] Restored: topic=$_lastSessionTopic stack=${_entityStack.length}');
      }
    } catch (_) {}
  }
}
