import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'translation_service.dart';

class ScreenMatch {
  final String screenName;
  final double confidence;

  ScreenMatch(this.screenName, this.confidence);
}

class NavigationIntent {
  final bool isNavigationIntent;
  final String? targetRoute;
  final String? targetScreenName;
  final double confidence;
  final String? reason;

  NavigationIntent({
    required this.isNavigationIntent,
    this.targetRoute,
    this.targetScreenName,
    this.confidence = 0.0,
    this.reason,
  });

  @override
  String toString() =>
      'NavigationIntent(isNav: $isNavigationIntent, target: $targetScreenName, route: $targetRoute, confidence: $confidence)';
}

class VoiceNavigationService extends GetxService {
  static final Map<String, List<String>> screenAliases = {
    '/voice-chat': [
      'voice chat', 'chat', 'voice chat screen', 'chat screen',
      'ai chat', 'talk to ai', 'chat with ai', 'voice',
    ],
    '/voice-chat-v2': [
      'voice chat v2', 'voice chat version 2', 'advanced chat',
      'new voice chat', 'v2 chat', 'voice chat 2',
    ],
    '/extended-voice-chat': [
      'extended voice chat', 'extended chat', 'long chat',
      'extended conversation', 'long conversation',
    ],
    '/unified-voice': [
      'unified voice', 'unified', 'all in one', 'unified interface',
      'voice hub', 'unified voice interface',
    ],
    '/game': [
      'game', 'games', 'game screen', 'game hub',
      'play games', 'games hub', 'game center',
    ],
    '/game-play': [
      'game play', 'gameplay', 'play game', 'game play screen',
      'playing game', 'active game', 'current game',
    ],
    '/voice-assistant-game': [
      'voice assistant game', 'voice game', 'game with voice',
      'voice controlled game', 'assistant game',
    ],
    '/voice-studio': [
      'voice studio', 'studio', 'voice studio screen',
      'record voice', 'voice recording', 'voice models',
      'voice lab',
    ],
    '/alarm': [
      'alarm', 'alarms', 'alarm screen', 'alarm list',
      'my alarms', 'set alarm', 'alarm clock',
    ],
    '/alarm-edit': [
      'alarm edit', 'edit alarm', 'create alarm', 'new alarm',
      'alarm editor', 'add alarm', 'alarm settings',
    ],
    '/alarm-ringing': [
      'alarm ringing', 'ringing alarm', 'alarm ringing screen',
      'stop alarm', 'alarm going off', 'snooze',
    ],
    '/naam-jaap': [
      'naam jaap', 'jaap', 'naam jaap screen', 'naam jaap meditation',
      'chanting', 'spiritual', 'mantra', 'japa', 'naam simran',
    ],
    '/history': [
      'history', 'chat history', 'history screen',
      'past conversations', 'conversation history', 'my history',
      'activity', 'recent chats',
    ],
    '/about': [
      'about', 'about screen', 'app information', 'about app',
      'about this app', 'app details', 'developer',
    ],
    '/settings': [
      'settings', 'setting', 'settings screen', 'preferences',
      'configure', 'app settings', 'options', 'configuration',
    ],
    '/profile': [
      'profile', 'my profile', 'profile screen', 'user profile',
      'my account', 'account', 'personal info',
    ],
    '/splash': [
      'splash', 'splash screen', 'start screen', 'loading screen',
    ],
    '/welcome': [
      'welcome', 'welcome screen', 'onboarding', 'intro',
      'introduction', 'getting started',
    ],
    '/authentication': [
      'authentication', 'login', 'sign in', 'sign in screen',
      'login screen', 'sign up',
    ],
    '/wallpaper': [
      'wallpaper', 'wallpapers', 'wallpaper screen',
      'live wallpaper', 'background', 'set wallpaper',
      'wallpaper gallery', 'themes',
    ],
    '/wallpaper-set': [
      'wallpaper set', 'set wallpaper', 'wallpaper setter',
      'apply wallpaper', 'choose wallpaper', 'wallpaper preview',
    ],
    '/wallpaper-trim': [
      'wallpaper trim', 'trim wallpaper', 'crop wallpaper',
      'wallpaper edit', 'wallpaper crop',
    ],
    '/reminder': [
      'reminder', 'reminders', 'reminder screen', 'reminder list',
      'my reminders', 'set reminder', 'task list',
    ],
    '/reminder-edit': [
      'reminder edit', 'edit reminder', 'create reminder',
      'new reminder', 'add reminder', 'reminder editor',
    ],
    '/language-coach': [
      'language coach', 'language coaching', 'learn language',
      'language learning', 'pronunciation coach', 'speak practice',
      'language lessons',
    ],
    '/pdf-viewer': [
      'pdf viewer', 'pdf reader', 'document viewer',
      'view pdf', 'read document',
    ],
    '/privacy': [
      'privacy', 'privacy settings', 'privacy screen',
      'data privacy', 'privacy controls',
    ],
    '/privacy-policy': [
      'privacy policy', 'policy', 'privacy policy screen',
      'legal', 'terms',
    ],
  };

  static final List<String> navigationTriggers = [
    'go to', 'take me to', 'navigate to', 'switch to',
    'jump to', 'open', 'move to', 'redirect to',
    'redirect me to', 'put me', 'put me in', 'send me to',
    'go', 'let\'s go', 'let\'s go to',
    'can you take me to', 'can you go to', 'can you redirect me to',
    'can you switch to', 'can you move me to', 'i want to go to',
    'i want to', 'take me', 'bring me to', 'show me',
    'show me the', 'launch', 'navigate', 'head to',
    'get me to', 'take me to the', 'bring me', 'lead me to',
    'direct me to', 'point me to',
  ];

  static final Map<String, List<String>> navigationTriggersByLanguage = {
    'hi': [
      'जाओ', 'ले जाओ', 'नेविगेट करो', 'स्विच करो',
      'स्विच करें', 'जंप करो', 'खोलो', 'पर जाओ',
      'मुझे ले जाओ', 'मुझे भेजो', 'मुझे रिडायरेक्ट करो',
      'मुझे रिडायरेक्ट करें', 'चलो', 'चलिए', 'दिखाओ',
      'मुझे दिखाओ', 'पर ले चलो', 'खोल दो',
    ],
    'hi-en': [
      'go to', 'jao', 'le jao', 'lejao', 'redirect', 'switch',
      'kholo', 'dikhao', 'mujhe', 'le chal', 'le chalo',
      'dikhaye', 'khol do',
    ],
  };

  /// Core detection method with multilingual support
  NavigationIntent detectNavigationIntent(
    String userInput, {
    String? currentRoute,
    String? preferredLanguage = 'en',
  }) {
    final input = userInput.trim();
    if (input.isEmpty) {
      return NavigationIntent(
        isNavigationIntent: false,
        reason: 'Empty input',
      );
    }

    // STEP 1: Try direct keyword matching
    var result = _tryKeywordMatch(input, currentRoute, preferredLanguage);
    if (result.isNavigationIntent) return result;

    // STEP 2: Direct screen name check (user might just say a screen name)
    result = _tryDirectScreenMatch(input, currentRoute);
    if (result.isNavigationIntent) return result;

    return NavigationIntent(
      isNavigationIntent: false,
      reason: 'No navigation intent detected',
    );
  }

  NavigationIntent _tryKeywordMatch(
    String input,
    String? currentRoute,
    String? preferredLanguage,
  ) {
    final lower = input.toLowerCase().trim();

    // Check navigation triggers
    bool hasTrigger = navigationTriggers.any((t) => lower.contains(t));

    if (!hasTrigger && preferredLanguage != null) {
      for (final entry in navigationTriggersByLanguage.entries) {
        if (preferredLanguage.startsWith(entry.key) ||
            entry.key.startsWith(preferredLanguage)) {
          if (entry.value.any((t) => lower.contains(t))) {
            hasTrigger = true;
            break;
          }
        }
      }
    }

    if (!hasTrigger) {
      return NavigationIntent(
        isNavigationIntent: false,
        reason: 'No navigation keywords detected',
      );
    }

    final screenMatch = _extractScreenName(lower);
    if (screenMatch == null) {
      return NavigationIntent(
        isNavigationIntent: true,
        confidence: 0.3,
        reason: 'Navigation intent detected but could not identify target screen',
      );
    }

    final route = _findClosestRoute(screenMatch.screenName);
    if (route == null) {
      return NavigationIntent(
        isNavigationIntent: true,
        confidence: 0.5,
        reason: 'Could not find matching screen for "${screenMatch.screenName}"',
      );
    }

    return NavigationIntent(
      isNavigationIntent: true,
      targetRoute: route,
      targetScreenName: _getPrimaryName(route),
      confidence: screenMatch.confidence,
      reason: 'Keyword match succeeded',
    );
  }

  NavigationIntent _tryDirectScreenMatch(
    String input,
    String? currentRoute,
  ) {
    final lower = input.toLowerCase().trim();

    // Check if input directly matches a screen name
    for (final entry in screenAliases.entries) {
      for (final alias in entry.value) {
        if (lower == alias || lower.contains(alias)) {
          final similarity = _calculateSimilarity(lower, alias);
          if (similarity > 0.8) {
            return NavigationIntent(
              isNavigationIntent: true,
              targetRoute: entry.key,
              targetScreenName: _getPrimaryName(entry.key),
              confidence: similarity,
              reason: 'Direct screen name match',
            );
          }
        }
      }
    }

    return NavigationIntent(
      isNavigationIntent: false,
      reason: 'No direct screen match',
    );
  }

  bool _isNonEnglish(String input, String? preferredLanguage) {
    if (preferredLanguage != null && preferredLanguage != 'en') return true;
    return input.codeUnits.any((c) => c > 127);
  }

  ScreenMatch? _extractScreenName(String input) {
    String remaining = input;
    for (final trigger in navigationTriggers) {
      remaining = remaining.replaceAll(trigger.toLowerCase(), '').trim();
    }

    for (final entry in navigationTriggersByLanguage.entries) {
      for (final trigger in entry.value) {
        remaining = remaining.replaceAll(trigger.toLowerCase(), '').trim();
      }
    }

    final fillers = [
      'the', 'a', 'an', 'to', 'me', 'please', 'screen', 'app',
      'interface', 'window', 'can you', 'could you', 'would you',
      'i want', 'i would like', 'my', 'the screen', 'page',
    ];
    for (final filler in fillers) {
      remaining = remaining.replaceAll(filler, '').trim();
    }

    if (remaining.isEmpty) return null;
    return ScreenMatch(remaining, 0.7);
  }

  String? _findClosestRoute(String screenName) {
    const double confidenceThreshold = 0.6;
    const double highConfidenceThreshold = 0.85;

    double bestScore = 0.0;
    String? bestRoute;

    final lowerName = screenName.toLowerCase().trim();

    for (final entry in screenAliases.entries) {
      final route = entry.key;
      final aliases = entry.value;

      for (final alias in aliases) {
        final similarity = _calculateSimilarity(lowerName, alias);
        if (similarity > bestScore) {
          bestScore = similarity;
          bestRoute = route;
        }
        if (similarity >= highConfidenceThreshold) break;
      }
      if (bestScore >= highConfidenceThreshold) break;
    }

    if (bestScore >= confidenceThreshold) {
      debugPrint('✅ [VoiceNav] Matched "$screenName" → $bestRoute (${bestScore.toStringAsFixed(2)})');
      return bestRoute;
    }

    debugPrint('❌ [VoiceNav] No match for "$screenName" (best: ${bestScore.toStringAsFixed(2)})');
    return null;
  }

  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    if (s1.contains(s2) || s2.contains(s1)) return 0.95;

    if (_isSubsequence(s1, s2) || _isSubsequence(s2, s1)) return 0.85;

    final distance = _levenshteinDistance(s1, s2);
    final maxLength = (s1.length + s2.length) / 2.0;
    return 1.0 - (distance / maxLength).clamp(0.0, 1.0);
  }

  bool _isSubsequence(String shorter, String longer) {
    if (shorter.length > longer.length) return false;
    int sIdx = 0;
    for (int lIdx = 0; lIdx < longer.length && sIdx < shorter.length; lIdx++) {
      if (shorter[sIdx] == longer[lIdx]) sIdx++;
    }
    return sIdx == shorter.length;
  }

  int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;
    final d = List<List<int>>.generate(
      len1 + 1,
      (i) => List<int>.filled(len2 + 1, 0),
    );
    for (int i = 0; i <= len1; i++) { d[i][0] = i; }
    for (int j = 0; j <= len2; j++) { d[0][j] = j; }
    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1,
          d[i][j - 1] + 1,
          d[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    return d[len1][len2];
  }

  List<String> getAllScreenNames() {
    final names = <String>[];
    screenAliases.forEach((_, aliases) {
      if (aliases.isNotEmpty) names.add(aliases.first);
    });
    return names;
  }

  List<String> getAllRoutes() {
    return screenAliases.keys.toList();
  }

  String? getDisplayName(String route) {
    return screenAliases.containsKey(route)
        ? screenAliases[route]!.first
        : null;
  }

  String _getPrimaryName(String route) {
    return screenAliases[route]?.first ?? route;
  }

  Future<NavigationIntent> detectNavigationIntentMultilingual(
    String userInput, {
    String? currentRoute,
    String? preferredLanguage = 'en',
  }) async {
    // STEP 1: Try direct keyword match
    var result = detectNavigationIntent(
      userInput,
      currentRoute: currentRoute,
      preferredLanguage: preferredLanguage,
    );
    if (result.isNavigationIntent && result.confidence >= 0.6) return result;

    // STEP 2: If input appears non-English, translate and retry
    if (_isNonEnglish(userInput, preferredLanguage)) {
      try {
        final translationResult = await TranslationService.translate(
          text: userInput,
          targetLanguage: 'en',
        );
        final translated = translationResult.translatedText;
        if (translated.isNotEmpty && translated != userInput) {
          debugPrint('🌐 [VoiceNav] Async translated: "$userInput" → "$translated"');
          result = detectNavigationIntent(
            translated,
            currentRoute: currentRoute,
            preferredLanguage: 'en',
          );
          if (result.isNavigationIntent && result.confidence >= 0.5) return result;
        }
      } catch (e) {
        debugPrint('❌ [VoiceNav] Async translation error: $e');
      }
    }

    return result;
  }
}
