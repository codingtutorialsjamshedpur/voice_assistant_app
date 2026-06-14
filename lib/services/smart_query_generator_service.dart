// Smart Query Generator Service
// Analyzes user queries to understand interests and generates intelligent follow-up questions
// Creates unpredictable, contextual engagement that feels organic

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/voice_controller.dart';

class SmartQueryGeneratorService extends GetxService {
  static SmartQueryGeneratorService get to => Get.find();

  final RxBool isAnalyzingQueries = false.obs;
  final RxList<String> detectedInterests = <String>[].obs;
  final RxString lastGeneratedQuery = ''.obs;

  bool _hasGeneratedSmartQuery = false;

  VoiceController? _voiceController;
  Timer? _queryAnalysisTimer;
  int _previousMessageCount = 0;
  List<String> _recentUserQueries = [];

  @override
  void onInit() {
    super.onInit();
    // Auto-initialize when service is created
    Future.delayed(const Duration(milliseconds: 800), () {
      _initializeService();
    });
  }

  @override
  void onClose() {
    _queryAnalysisTimer?.cancel();
    super.onClose();
  }

  /// Initialize service - setup message listener
  void _initializeService() {
    try {
      _voiceController = Get.find<VoiceController>();
      debugPrint('✅ [SmartQueryGenerator] Service initialized');

      // Listen to messages observable for changes
      ever(_voiceController!.messages, (messages) {
        _onMessagesChanged(messages);
      });

      debugPrint('🎯 [SmartQueryGenerator] Message listener setup complete');
    } catch (e) {
      debugPrint('❌ [SmartQueryGenerator] Initialization error: $e');
    }
  }

  /// Called whenever messages list changes
  void _onMessagesChanged(List<dynamic> messages) {
    try {
      if (_hasGeneratedSmartQuery) return;

      // Check if we have new messages since last check
      if (messages.length > _previousMessageCount) {
        _previousMessageCount = messages.length;

        if (messages.isEmpty) return;
        final lastMessage = messages.last;
        if (lastMessage.role != 'user') return;

        // Get all user messages
        final userMessages = messages.where((m) => m.role == 'user').toList();

        // When we detect 2 or more user queries
        if (userMessages.length >= 2) {
          debugPrint(
              '📊 [SmartQueryGenerator] Detected ${userMessages.length} user queries');

          // Extract recent user queries
          _extractRecentQueries(userMessages);

          // Analyze interests from queries
          _analyzeUserInterests();

          // Disabled to prevent unwanted spontaneous chat injections.
          // _scheduleSmartQueryGeneration();
        }
      }
    } catch (e) {
      debugPrint('❌ [SmartQueryGenerator] Message change handler error: $e');
    }
  }

  /// Extract text from recent user messages
  void _extractRecentQueries(List<dynamic> userMessages) {
    try {
      _recentUserQueries = userMessages
          .take(3) // Last 3 queries
          .map((m) => m.content.toString().toLowerCase())
          .toList();

      debugPrint(
          '📝 [SmartQueryGenerator] Extracted queries: $_recentUserQueries');
    } catch (e) {
      debugPrint('❌ [SmartQueryGenerator] Query extraction error: $e');
    }
  }

  /// Analyze user interests from queries
  void _analyzeUserInterests() {
    try {
      isAnalyzingQueries.value = true;
      final interests = <String>[].obs;

      // Interest keyword mapping
      const interestKeywords = {
        'coding|programming|python|javascript|react|flutter|dev|code|bug':
            'Programming',
        'fitness|exercise|gym|workout|yoga|health|body|diet|calories':
            'Fitness',
        'music|song|play|listen|audio|instrument|guitar|piano': 'Music',
        'travel|trip|visit|vacation|explore|destination|place': 'Travel',
        'book|read|novel|story|reading|author|write|writing': 'Reading',
        'game|gaming|play|level|win|score|strategy|esports': 'Gaming',
        'learn|study|course|education|skill|training|tutorial': 'Learning',
        'business|startup|invest|finance|money|entrepreneur|market': 'Business',
        'cooking|recipe|food|cook|eat|cuisine|kitchen|chef': 'Cooking',
        'art|draw|design|creative|paint|color|visual|photo': 'Art',
        'science|research|physics|chemistry|biology|experiment|discover':
            'Science',
        'meditation|mindfulness|peace|calm|stress|relax|breathing':
            'Meditation',
        'sports|football|cricket|tennis|soccer|basketball|athlete': 'Sports',
      };

      // Scan queries for keywords
      for (var query in _recentUserQueries) {
        interestKeywords.forEach((keywords, interest) {
          final pattern = RegExp(keywords);
          if (pattern.hasMatch(query) && !interests.contains(interest)) {
            interests.add(interest);
          }
        });
      }

      detectedInterests.value = interests;
      debugPrint(
          '🎯 [SmartQueryGenerator] Detected interests: ${interests.join(", ")}');
      isAnalyzingQueries.value = false;
    } catch (e) {
      debugPrint('❌ [SmartQueryGenerator] Interest analysis error: $e');
      isAnalyzingQueries.value = false;
    }
  }

  /// Schedule smart query generation after idle period
  void _scheduleSmartQueryGeneration() {
    // Cancel previous timer
    _queryAnalysisTimer?.cancel();

    // Wait 5 seconds of idle, then generate smart query
    _queryAnalysisTimer = Timer(const Duration(seconds: 5), () async {
      await _generateAndInjectSmartQuery();
    });
  }

  /// Generate a smart, contextual query based on detected interests
  Future<void> _generateAndInjectSmartQuery() async {
    try {
      if (detectedInterests.isEmpty) {
        debugPrint('⚠️ [SmartQueryGenerator] No interests detected');
        return;
      }

      // Pick a random detected interest
      final selectedInterest = detectedInterests[
          DateTime.now().millisecond % detectedInterests.length];

      // Generate smart query for this interest
      final smartQuery = _generateSmartQueryForInterest(selectedInterest);

      if (smartQuery.isEmpty) return;

      lastGeneratedQuery.value = smartQuery;
      _hasGeneratedSmartQuery = true;

      // Inject as AI message (proactive engagement)
      await _injectSmartQueryAsMessage(smartQuery);

      debugPrint('✨ [SmartQueryGenerator] Smart query injected: $smartQuery');
    } catch (e) {
      debugPrint('❌ [SmartQueryGenerator] Query generation error: $e');
    }
  }

  /// Generate contextual smart question based on interest
  String _generateSmartQueryForInterest(String interest) {
    const smartQueries = {
      'Programming': [
        'I noticed you\'re interested in programming! What\'s your current project or the language you\'re most excited about right now? 💻',
        'You seem to be exploring coding! Are you building something specific or learning for general knowledge? 🚀',
        'Coding enthusiast! What\'s the most challenging part you\'re facing right now? Let\'s solve it together! 🔧',
        'I see you\'re diving into programming. What\'s your biggest goal with it? 🎯',
      ],
      'Fitness': [
        'You\'re focused on fitness! What\'s your main goal - building strength, improving endurance, or general wellness? 💪',
        'Fitness matters to you! What\'s your current routine and what are you trying to achieve? 🏋️',
        'I can see you\'re into fitness! Any specific workout style that excites you? 🏃',
        'Your fitness journey is interesting! What\'s motivating you the most? 🎯',
      ],
      'Music': [
        'Music seems to be your passion! What genres or artists inspire you the most? 🎵',
        'I see you love music! Are you learning an instrument or just exploring different styles? 🎸',
        'Music enthusiast! What\'s your favorite way to experience music - listening, playing, or creating? 🎼',
        'You mentioned music! What role does it play in your daily life? 🎧',
      ],
      'Travel': [
        'Travel excites you! Where\'s on your dream destination list? ✈️',
        'Adventure calls! Do you prefer planned trips or spontaneous exploration? 🗺️',
        'I see wanderlust in your questions! What\'s been your most memorable trip? 🌍',
        'Travel enthusiast! What\'s the one place you absolutely must visit? 🏖️',
      ],
      'Reading': [
        'You\'re a reader! What genre captures your heart the most? 📚',
        'Reading is your thing! Are you currently into any series or author? 📖',
        'Book lover detected! What\'s the last book that really moved you? ✨',
        'I sense you love reading! Do you prefer fiction or non-fiction? 📕',
      ],
      'Gaming': [
        'Gamer alert! What\'s your go-to game right now? 🎮',
        'You love gaming! Are you more into competitive or casual games? 🕹️',
        'Gaming enthusiast! What\'s the most addictive game you\'ve played? 🎯',
        'I see gaming in your questions! What platform do you prefer? 🎮',
      ],
      'Learning': [
        'Lifelong learner! What skill are you most eager to master? 🧠',
        'Growth mindset detected! What\'s your next learning goal? 📚',
        'You love to learn! What subject area excites you the most? 🎓',
        'Education enthusiast! What\'s driving your desire to learn? 🚀',
      ],
      'Business': [
        'Entrepreneur spirit! What business idea are you thinking about? 💼',
        'Business interests you! Are you looking to start something or grow existing? 📈',
        'Business-minded! What\'s your biggest business challenge right now? 🎯',
        'I sense entrepreneurial energy! What\'s your vision? 🚀',
      ],
      'Cooking': [
        'Foodie alert! What\'s your favorite cuisine to cook? 👨‍🍳',
        'You love cooking! Are you into experimental cooking or traditional recipes? 🍳',
        'Chef in the making! What\'s your signature dish? 🍽️',
        'Cooking enthusiast! What ingredient can\'t you live without? 🧂',
      ],
      'Art': [
        'Creative soul! What art form do you practice or admire? 🎨',
        'Artist energy! What\'s your current creative project? ✨',
        'Art inspires you! Do you create or collect? 🖼️',
        'Creative mind! What\'s your artistic style or influence? 🎭',
      ],
      'Science': [
        'Science lover! What field fascinates you the most? 🔬',
        'Scientific mind! Are you interested in practical applications or theory? 🧪',
        'I see curiosity in your questions! What scientific breakthrough excites you? 🚀',
        'Knowledge seeker! What aspect of science intrigues you? 🌌',
      ],
      'Meditation': [
        'Mindfulness matters to you! How does meditation fit into your daily life? 🧘',
        'Seeker of peace! What\'s your favorite meditation practice? 🕉️',
        'I sense inner growth! What meditation goal are you working towards? ☮️',
        'Calm spirit! How has meditation changed your perspective? 🧘‍♀️',
      ],
      'Sports': [
        'Sports enthusiast! What\'s your favorite sport to play or watch? ⚽',
        'Athlete energy! Are you competitive or playing for fun? 🏆',
        'Sports passion! Who\'s your inspiration in the sports world? 🌟',
        'Game on! What\'s your sports dream? 🎯',
      ],
    };

    final queries = smartQueries[interest];
    if (queries == null || queries.isEmpty) return '';

    return queries[DateTime.now().millisecond % queries.length];
  }

  /// Inject smart query as AI message to engage user
  Future<void> _injectSmartQueryAsMessage(String query) async {
    try {
      if (_voiceController == null) return;

      // Create ChatMessage object
      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'assistant',
        content: query,
        timestamp: DateTime.now(),
        modelName: 'CTJ Voice - Smart Query',
      );

      // Add to messages
      _voiceController!.messages.add(message);

      // Speak the message
      _voiceController!.speakMessage(message);

      debugPrint('✅ [SmartQueryGenerator] Smart query added and spoken');
    } catch (e) {
      debugPrint('❌ [SmartQueryGenerator] Message injection error: $e');
    }
  }

  /// Get summary of detected interests
  String getInterestsSummary() {
    if (detectedInterests.isEmpty) return 'Analyzing your interests...';
    return 'Detected interests: ${detectedInterests.join(", ")}';
  }

  /// Reset for new conversation
  void reset() {
    _previousMessageCount = 0;
    _recentUserQueries.clear();
    detectedInterests.clear();
    lastGeneratedQuery.value = '';
    _hasGeneratedSmartQuery = false;
    _queryAnalysisTimer?.cancel();
    debugPrint('🔄 [SmartQueryGenerator] Service reset');
  }
}
