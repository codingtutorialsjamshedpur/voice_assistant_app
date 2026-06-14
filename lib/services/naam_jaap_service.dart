import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';

/// Naam Jaap Language Support
enum NaamJaapLanguage {
  english,
  hindi,
  hinglish,
}

/// Naam Jaap Mantra Entry
class MantraEntry {
  final String id;
  final String text;
  final String transliteration;
  final String meaning;
  final NaamJaapLanguage language;
  final int targetCount;
  final DateTime createdAt;
  final bool isFavorite;
  final String? audioUrl;

  MantraEntry({
    required this.id,
    required this.text,
    required this.transliteration,
    required this.meaning,
    required this.language,
    this.targetCount = 108,
    required this.createdAt,
    this.isFavorite = false,
    this.audioUrl,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'transliteration': transliteration,
        'meaning': meaning,
        'language': language.index,
        'targetCount': targetCount,
        'createdAt': createdAt.toIso8601String(),
        'isFavorite': isFavorite,
        'audioUrl': audioUrl,
      };

  factory MantraEntry.fromJson(Map<String, dynamic> json) => MantraEntry(
        id: json['id'],
        text: json['text'],
        transliteration: json['transliteration'],
        meaning: json['meaning'],
        language: NaamJaapLanguage.values[json['language'] ?? 0],
        targetCount: json['targetCount'] ?? 108,
        createdAt: DateTime.parse(json['createdAt']),
        isFavorite: json['isFavorite'] ?? false,
        audioUrl: json['audioUrl'],
      );
}

/// Naam Jaap Session State
enum JaapSessionState {
  idle,
  active,
  paused,
  completed,
}

/// Comprehensive Naam Jaap Service
///
/// Features:
/// - Multi-language support (English, Hindi, Hinglish)
/// - Predefined mantras with meanings
/// - Custom mantra creation
/// - Session tracking and statistics
/// - Audio playback integration
/// - TTS/STT integration for guided chanting
class NaamJaapService extends GetxService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Observable states
  final currentState = JaapSessionState.idle.obs;
  final currentCount = 0.obs;
  final targetCount = 108.obs;
  final currentMantra = Rxn<MantraEntry>();
  final mantras = <MantraEntry>[].obs;
  final sessionHistory = <Map<String, dynamic>>[].obs;
  final currentLanguage = NaamJaapLanguage.hinglish.obs;
  final sessionDuration = Duration.zero.obs;
  final isAutoPlayEnabled = true.obs;
  final chantSpeed = 1.0.obs; // Chants per second
  final totalLifetimeChants = 0.obs;
  final currentStreak = 0.obs;
  final longestStreak = 0.obs;
  final lastSessionDate = Rxn<DateTime>();

  // Timer for session duration
  Timer? _sessionTimer;
  Timer? _chantTimer;

  // Predefined mantras database
  late final List<MantraEntry> _predefinedMantras;

  @override
  Future<void> onInit() async {
    super.onInit();
    _initializeMantras();
    await _loadData();
  }

  /// Initialize predefined mantras
  void _initializeMantras() {
    _predefinedMantras = [
      // ENGLISH MANTRAS
      MantraEntry(
        id: 'om_english',
        text: 'Om',
        transliteration: 'Om',
        meaning:
            'The primordial sound of the universe, representing the ultimate reality',
        language: NaamJaapLanguage.english,
        targetCount: 108,
        createdAt: DateTime.now(),
        isFavorite: true,
      ),
      MantraEntry(
        id: 'shanti_english',
        text: 'Om Shanti Shanti Shanti',
        transliteration: 'Om Shanti Shanti Shanti',
        meaning:
            'Peace within, peace in the environment, peace in the universal forces',
        language: NaamJaapLanguage.english,
        targetCount: 108,
        createdAt: DateTime.now(),
      ),
      MantraEntry(
        id: 'namah_shivaya_english',
        text: 'Om Namah Shivaya',
        transliteration: 'Om Namah Shivaya',
        meaning: 'I bow to Lord Shiva, the inner Self',
        language: NaamJaapLanguage.english,
        targetCount: 108,
        createdAt: DateTime.now(),
        isFavorite: true,
      ),
      MantraEntry(
        id: 'gam_ganapati_english',
        text: 'Om Gam Ganapataye Namaha',
        transliteration: 'Om Gam Ganapataye Namaha',
        meaning: 'Salutations to Lord Ganesha, the remover of obstacles',
        language: NaamJaapLanguage.english,
        targetCount: 108,
        createdAt: DateTime.now(),
      ),
      MantraEntry(
        id: 'hanuman_english',
        text: 'Om Hanumate Namaha',
        transliteration: 'Om Hanumate Namaha',
        meaning:
            'Salutations to Lord Hanuman, the symbol of strength and devotion',
        language: NaamJaapLanguage.english,
        targetCount: 108,
        createdAt: DateTime.now(),
      ),

      // HINDI MANTRAS (Devanagari)
      MantraEntry(
        id: 'om_hindi',
        text: 'ॐ',
        transliteration: 'Om',
        meaning: 'ब्रह्मांड की प्रारंभिक ध्वनि, परम सत्य का प्रतीक',
        language: NaamJaapLanguage.hindi,
        targetCount: 108,
        createdAt: DateTime.now(),
        isFavorite: true,
      ),
      MantraEntry(
        id: 'namah_shivaya_hindi',
        text: 'ॐ नमः शिवाय',
        transliteration: 'Om Namah Shivaya',
        meaning: 'मैं भगवान शिव को नमन करता हूँ, जो आंतरिक आत्मा हैं',
        language: NaamJaapLanguage.hindi,
        targetCount: 108,
        createdAt: DateTime.now(),
        isFavorite: true,
      ),
      MantraEntry(
        id: 'gayatri_hindi',
        text:
            'ॐ भूर्भुवः स्वः तत्सवितुर्वरेण्यं भर्गो देवस्य धीमहि धियो यो नः प्रचोदयात्',
        transliteration:
            'Om Bhur Bhuvaḥ Swaḥ Tat-savitur Vareñyaṃ Bhargo Devasya Dhīmahi Dhiyo Yonaḥ Prachodayāt',
        meaning:
            'हम उस दिव्य प्रकाश का ध्यान करते हैं जो सबसे उत्तम है, जो हमारे भीतर ज्ञान और प्रेरणा दे',
        language: NaamJaapLanguage.hindi,
        targetCount: 108,
        createdAt: DateTime.now(),
      ),
      MantraEntry(
        id: 'mahamrityunjaya_hindi',
        text:
            'ॐ त्र्यम्बकं यजामहे सुगन्धिं पुष्टिवर्धनम् उर्वारुकमिव बन्धनान्मृत्योर्मुक्षीय मामृतात्',
        transliteration:
            'Om Tryambakam Yajamahe Sugandhim Pushtivardhanam Urvarukamiva Bandhanan Mrityor Mukshiya Maamritat',
        meaning:
            'हम तीन नेत्रों वाले (शिव) की पूजा करते हैं जो सुगंधित और पोषण करने वाले हैं, जैसे ककड़ी बेल से मुक्त होकर पक जाती है, वैसे ही मृत्यु से मुक्ति दिलाएं',
        language: NaamJaapLanguage.hindi,
        targetCount: 108,
        createdAt: DateTime.now(),
      ),
      MantraEntry(
        id: 'hare_krishna_hindi',
        text:
            'हरे कृष्ण हरे कृष्ण कृष्ण कृष्ण हरे हरे हरे राम हरे राम राम राम हरे हरे',
        transliteration:
            'Hare Krishna Hare Krishna Krishna Krishna Hare Hare Hare Rama Hare Rama Rama Rama Hare Hare',
        meaning:
            'हे कृष्ण, हे कृष्ण, हे कृष्ण, हे कृष्ण, हे हरे, हे हरे। हे राम, हे राम, हे राम, हे राम, हे हरे, हे हरे',
        language: NaamJaapLanguage.hindi,
        targetCount: 108,
        createdAt: DateTime.now(),
      ),
      MantraEntry(
        id: 'ganapati_hindi',
        text: 'ॐ गं गणपतये नमः',
        transliteration: 'Om Gam Ganapataye Namaha',
        meaning: 'बाधाओं के हर्ता गणेश को नमन',
        language: NaamJaapLanguage.hindi,
        targetCount: 108,
        createdAt: DateTime.now(),
      ),

      // HINGLISH MANTRAS (Hindi in English script)
      MantraEntry(
        id: 'om_hinglish',
        text: 'Om',
        transliteration: 'Om',
        meaning: 'Brahmand ki prarambhik dhvani, parm satya ka prateek',
        language: NaamJaapLanguage.hinglish,
        targetCount: 108,
        createdAt: DateTime.now(),
        isFavorite: true,
      ),
      MantraEntry(
        id: 'namah_shivaya_hinglish',
        text: 'Om Namah Shivaya',
        transliteration: 'Om Namah Shivaya',
        meaning:
            'Main Bhagwan Shiv ko naman karta hoon, jo aantarik aatma hain',
        language: NaamJaapLanguage.hinglish,
        targetCount: 108,
        createdAt: DateTime.now(),
        isFavorite: true,
      ),
      MantraEntry(
        id: 'shanti_hinglish',
        text: 'Om Shanti Shanti Shanti',
        transliteration: 'Om Shanti Shanti Shanti',
        meaning:
            'Antarik shanti, aas-paas ki shanti, brahmandiya shakti mein shanti',
        language: NaamJaapLanguage.hinglish,
        targetCount: 108,
        createdAt: DateTime.now(),
      ),
      MantraEntry(
        id: 'gayatri_hinglish',
        text:
            'Om Bhur Bhuvah Swah Tat Savitur Varenyam Bhargo Devasya Dhimahi Dhiyo Yo Nah Prachodayat',
        transliteration:
            'Om Bhur Bhuvah Swah Tat Savitur Varenyam Bhargo Devasya Dhimahi Dhiyo Yo Nah Prachodayat',
        meaning:
            'Hum us divya prakash ka dhyan karte hain jo sabse uttam hai, jo hamare bheetar gyan aur prerna de',
        language: NaamJaapLanguage.hinglish,
        targetCount: 108,
        createdAt: DateTime.now(),
      ),
      MantraEntry(
        id: 'mahamrityunjaya_hinglish',
        text:
            'Om Tryambakam Yajamahe Sugandhim Pushtivardhanam Urvarukamiva Bandhanan Mrityor Mukshiya Maamritat',
        transliteration:
            'Om Tryambakam Yajamahe Sugandhim Pushtivardhanam Urvarukamiva Bandhanan Mrityor Mukshiya Maamritat',
        meaning:
            'Hum teen netron wale (Shiv) ki puja karte hain jo sugandhit aur poshan karne wale hain, jaise kakri bel se mukt hokar pak jaati hai, waise hi mrityu se mukti dilayein',
        language: NaamJaapLanguage.hinglish,
        targetCount: 108,
        createdAt: DateTime.now(),
      ),
      MantraEntry(
        id: 'hare_krishna_hinglish',
        text:
            'Hare Krishna Hare Krishna Krishna Krishna Hare Hare Hare Rama Hare Rama Rama Rama Hare Hare',
        transliteration:
            'Hare Krishna Hare Krishna Krishna Krishna Hare Hare Hare Rama Hare Rama Rama Rama Hare Hare',
        meaning:
            'Hey Krishna, Hey Krishna, Hey Krishna, Hey Krishna, Hey Hare, Hey Hare. Hey Ram, Hey Ram, Hey Ram, Hey Ram, Hey Hare, Hey Hare',
        language: NaamJaapLanguage.hinglish,
        targetCount: 108,
        createdAt: DateTime.now(),
      ),
      MantraEntry(
        id: 'ganapati_hinglish',
        text: 'Om Gam Ganapataye Namaha',
        transliteration: 'Om Gam Ganapataye Namaha',
        meaning: 'Badhaon ke harta Ganesh ko naman',
        language: NaamJaapLanguage.hinglish,
        targetCount: 108,
        createdAt: DateTime.now(),
      ),
      MantraEntry(
        id: 'durga_hinglish',
        text: 'Om Dum Durgayei Namaha',
        transliteration: 'Om Dum Durgayei Namaha',
        meaning: 'Maa Durga ko naman, jo shakti aur raksha ki devi hain',
        language: NaamJaapLanguage.hinglish,
        targetCount: 108,
        createdAt: DateTime.now(),
      ),
      MantraEntry(
        id: 'lakshmi_hinglish',
        text: 'Om Shreem Mahalakshmiyei Namaha',
        transliteration: 'Om Shreem Mahalakshmiyei Namaha',
        meaning: 'Maa Lakshmi ko naman, jo sampanna aur samriddhi ki devi hain',
        language: NaamJaapLanguage.hinglish,
        targetCount: 108,
        createdAt: DateTime.now(),
      ),
      MantraEntry(
        id: 'saraswati_hinglish',
        text: 'Om Aim Saraswatyai Namaha',
        transliteration: 'Om Aim Saraswatyai Namaha',
        meaning: 'Maa Saraswati ko naman, jo gyan aur vidya ki devi hain',
        language: NaamJaapLanguage.hinglish,
        targetCount: 108,
        createdAt: DateTime.now(),
      ),
      MantraEntry(
        id: 'hanuman_hinglish',
        text: 'Om Hanumate Namaha',
        transliteration: 'Om Hanumate Namaha',
        meaning:
            'Bajrangbali Hanuman ko naman, jo shakti aur bhakti ke prateek hain',
        language: NaamJaapLanguage.hinglish,
        targetCount: 108,
        createdAt: DateTime.now(),
      ),
    ];
  }

  /// Load data from storage
  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load custom mantras
      final mantrasJson = prefs.getString('customMantras');
      if (mantrasJson != null) {
        final List<dynamic> decoded = jsonDecode(mantrasJson);
        mantras.value =
            decoded.map((json) => MantraEntry.fromJson(json)).toList();
      }

      // Load session history
      final historyJson = prefs.getString('jaapHistory');
      if (historyJson != null) {
        final List<dynamic> decoded = jsonDecode(historyJson);
        sessionHistory.value = decoded.cast<Map<String, dynamic>>();
      }

      // Load statistics
      totalLifetimeChants.value = prefs.getInt('totalLifetimeChants') ?? 0;
      currentStreak.value = prefs.getInt('currentStreak') ?? 0;
      longestStreak.value = prefs.getInt('longestStreak') ?? 0;
      final lastDateStr = prefs.getString('lastSessionDate');
      if (lastDateStr != null) {
        lastSessionDate.value = DateTime.parse(lastDateStr);
      }

      // Load settings
      currentLanguage.value = NaamJaapLanguage.values[
          prefs.getInt('jaapLanguage') ?? NaamJaapLanguage.hinglish.index];
      targetCount.value = prefs.getInt('jaapTargetCount') ?? 108;
      isAutoPlayEnabled.value = prefs.getBool('jaapAutoPlay') ?? true;
      chantSpeed.value = prefs.getDouble('jaapSpeed') ?? 1.0;

      // Add predefined mantras if none exist
      if (mantras.isEmpty) {
        mantras.addAll(_predefinedMantras);
      }

      debugPrint('✅ Naam Jaap Service Loaded');
    } catch (e) {
      debugPrint('❌ Naam Jaap Load Error: $e');
    }
  }

  /// Save data to storage
  Future<void> saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save custom mantras (only custom ones, not predefined)
      final customMantras = mantras
          .where((m) => !_predefinedMantras.any((p) => p.id == m.id))
          .toList();
      await prefs.setString('customMantras',
          jsonEncode(customMantras.map((m) => m.toJson()).toList()));

      // Save session history
      await prefs.setString('jaapHistory', jsonEncode(sessionHistory));

      // Save statistics
      await prefs.setInt('totalLifetimeChants', totalLifetimeChants.value);
      await prefs.setInt('currentStreak', currentStreak.value);
      await prefs.setInt('longestStreak', longestStreak.value);
      if (lastSessionDate.value != null) {
        await prefs.setString(
            'lastSessionDate', lastSessionDate.value!.toIso8601String());
      }

      // Save settings
      await prefs.setInt('jaapLanguage', currentLanguage.value.index);
      await prefs.setInt('jaapTargetCount', targetCount.value);
      await prefs.setBool('jaapAutoPlay', isAutoPlayEnabled.value);
      await prefs.setDouble('jaapSpeed', chantSpeed.value);
    } catch (e) {
      debugPrint('❌ Naam Jaap Save Error: $e');
    }
  }

  /// Get mantras by language
  List<MantraEntry> getMantrasByLanguage(NaamJaapLanguage lang) {
    return mantras.where((m) => m.language == lang).toList();
  }

  /// Get favorite mantras
  List<MantraEntry> getFavoriteMantras() {
    return mantras.where((m) => m.isFavorite).toList();
  }

  /// Add custom mantra
  Future<void> addCustomMantra({
    required String text,
    required String transliteration,
    required String meaning,
    required NaamJaapLanguage language,
    int targetCount = 108,
  }) async {
    final mantra = MantraEntry(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      transliteration: transliteration,
      meaning: meaning,
      language: language,
      targetCount: targetCount,
      createdAt: DateTime.now(),
    );

    mantras.add(mantra);
    await saveData();
  }

  /// Toggle favorite
  Future<void> toggleFavorite(String mantraId) async {
    final index = mantras.indexWhere((m) => m.id == mantraId);
    if (index != -1) {
      final updated = MantraEntry(
        id: mantras[index].id,
        text: mantras[index].text,
        transliteration: mantras[index].transliteration,
        meaning: mantras[index].meaning,
        language: mantras[index].language,
        targetCount: mantras[index].targetCount,
        createdAt: mantras[index].createdAt,
        isFavorite: !mantras[index].isFavorite,
        audioUrl: mantras[index].audioUrl,
      );
      mantras[index] = updated;
      await saveData();
    }
  }

  /// Delete custom mantra
  Future<void> deleteMantra(String mantraId) async {
    // Don't allow deleting predefined mantras
    if (_predefinedMantras.any((m) => m.id == mantraId)) {
      return;
    }
    mantras.removeWhere((m) => m.id == mantraId);
    await saveData();
  }

  /// Start Jaap session
  void startSession(MantraEntry mantra) {
    if (currentState.value == JaapSessionState.active) {
      stopSession();
    }

    currentMantra.value = mantra;
    targetCount.value = mantra.targetCount;
    currentCount.value = 0;
    sessionDuration.value = Duration.zero;
    currentState.value = JaapSessionState.active;

    // Start session timer
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      sessionDuration.value += const Duration(seconds: 1);
    });

    // Start auto-chant if enabled
    if (isAutoPlayEnabled.value) {
      _startAutoChant();
    }

    debugPrint('🙏 Jaap Session Started: ${mantra.text}');
  }

  /// Pause session
  void pauseSession() {
    if (currentState.value == JaapSessionState.active) {
      currentState.value = JaapSessionState.paused;
      _chantTimer?.cancel();
      debugPrint('⏸️ Jaap Session Paused');
    }
  }

  /// Resume session
  void resumeSession() {
    if (currentState.value == JaapSessionState.paused) {
      currentState.value = JaapSessionState.active;
      if (isAutoPlayEnabled.value) {
        _startAutoChant();
      }
      debugPrint('▶️ Jaap Session Resumed');
    }
  }

  /// Stop session
  Future<void> stopSession() async {
    _sessionTimer?.cancel();
    _chantTimer?.cancel();

    // Save session to history if there was progress
    if (currentCount.value > 0) {
      await _saveSessionToHistory();
      await _updateStreak();
    }

    currentState.value = JaapSessionState.idle;
    debugPrint('⏹️ Jaap Session Stopped');
  }

  /// Increment count manually
  void incrementCount() {
    if (currentState.value == JaapSessionState.active) {
      currentCount.value++;
      totalLifetimeChants.value++;

      // Play sound effect if available
      _playChantSound();

      // Check for completion
      if (currentCount.value >= targetCount.value) {
        _onSessionCompleted();
      }
    }
  }

  /// Start auto-chant timer
  void _startAutoChant() {
    _chantTimer?.cancel();
    final interval = Duration(milliseconds: (1000 / chantSpeed.value).round());

    _chantTimer = Timer.periodic(interval, (_) {
      if (currentState.value == JaapSessionState.active) {
        incrementCount();
      }
    });
  }

  /// Play chant sound
  Future<void> _playChantSound() async {
    // This can be implemented to play a soft bell or chant sound
    // For now, we'll use haptic feedback
    HapticFeedback.lightImpact();
  }

  /// On session completed
  Future<void> _onSessionCompleted() async {
    currentState.value = JaapSessionState.completed;
    _chantTimer?.cancel();

    // Play completion sound
    await _playCompletionSound();

    // Save session
    await _saveSessionToHistory();
    await _updateStreak();

    // Show completion notification
    _showCompletionNotification();
  }

  /// Play completion sound
  Future<void> _playCompletionSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/game_sounds/success.mp3'));
    } catch (e) {
      debugPrint('Sound play error: $e');
    }
  }

  /// Show completion notification
  void _showCompletionNotification() {
    final mantra = currentMantra.value;
    if (mantra != null) {
      final languageName = getLanguageName(mantra.language);
      Get.snackbar(
        '🙏 Jaap Complete!',
        '${mantra.text}\nTarget: $targetCount chants\nLanguage: $languageName',
        backgroundColor: Colors.orange.withValues(alpha: 0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        icon: const Icon(Icons.self_improvement, color: Colors.white),
      );
    }
  }

  /// Save session to history
  Future<void> _saveSessionToHistory() async {
    final session = {
      'mantraId': currentMantra.value?.id,
      'mantraText': currentMantra.value?.text,
      'count': currentCount.value,
      'target': targetCount.value,
      'duration': sessionDuration.value.inSeconds,
      'timestamp': DateTime.now().toIso8601String(),
      'language': currentMantra.value?.language.index,
    };

    sessionHistory.insert(0, session);

    // Keep only last 100 sessions
    if (sessionHistory.length > 100) {
      sessionHistory.removeRange(100, sessionHistory.length);
    }

    await saveData();
  }

  /// Update streak
  Future<void> _updateStreak() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lastSessionDate.value != null) {
      final lastDate = DateTime(
        lastSessionDate.value!.year,
        lastSessionDate.value!.month,
        lastSessionDate.value!.day,
      );

      final difference = today.difference(lastDate).inDays;

      if (difference == 0) {
        // Same day, no change
      } else if (difference == 1) {
        // Consecutive day, increment streak
        currentStreak.value++;
        if (currentStreak.value > longestStreak.value) {
          longestStreak.value = currentStreak.value;
        }
      } else {
        // Streak broken
        currentStreak.value = 1;
      }
    } else {
      // First session
      currentStreak.value = 1;
    }

    lastSessionDate.value = now;
    await saveData();
  }

  /// Set language
  Future<void> setLanguage(NaamJaapLanguage lang) async {
    currentLanguage.value = lang;
    await saveData();
  }

  /// Set target count
  Future<void> setTargetCount(int count) async {
    targetCount.value = count;
    await saveData();
  }

  /// Set auto-play
  Future<void> setAutoPlay(bool enabled) async {
    isAutoPlayEnabled.value = enabled;
    if (currentState.value == JaapSessionState.active) {
      if (enabled) {
        _startAutoChant();
      } else {
        _chantTimer?.cancel();
      }
    }
    await saveData();
  }

  /// Set chant speed
  Future<void> setChantSpeed(double speed) async {
    chantSpeed.value = speed.clamp(0.5, 3.0);
    if (currentState.value == JaapSessionState.active &&
        isAutoPlayEnabled.value) {
      _startAutoChant(); // Restart with new speed
    }
    await saveData();
  }

  /// Get language name
  String getLanguageName(NaamJaapLanguage lang) {
    switch (lang) {
      case NaamJaapLanguage.english:
        return 'English';
      case NaamJaapLanguage.hindi:
        return 'Hindi (Devanagari)';
      case NaamJaapLanguage.hinglish:
        return 'Hinglish';
    }
  }

  /// Get formatted duration
  String getFormattedDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Get daily statistics
  Map<String, dynamic> getDailyStatistics(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final daySessions = sessionHistory.where((s) {
      final sessionDate = DateTime.parse(s['timestamp']);
      return sessionDate.isAfter(dayStart) && sessionDate.isBefore(dayEnd);
    }).toList();

    final totalChants =
        daySessions.fold<int>(0, (sum, s) => sum + (s['count'] as int));
    final totalDuration =
        daySessions.fold<int>(0, (sum, s) => sum + (s['duration'] as int));

    return {
      'totalChants': totalChants,
      'totalSessions': daySessions.length,
      'totalDuration': totalDuration,
      'averageSpeed': totalDuration > 0 ? totalChants / totalDuration : 0,
    };
  }

  /// Get weekly statistics
  Map<String, dynamic> getWeeklyStatistics() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final weekSessions = sessionHistory.where((s) {
      final sessionDate = DateTime.parse(s['timestamp']);
      return sessionDate.isAfter(weekAgo);
    }).toList();

    final totalChants =
        weekSessions.fold<int>(0, (sum, s) => sum + (s['count'] as int));

    return {
      'totalChants': totalChants,
      'totalSessions': weekSessions.length,
      'averagePerDay': totalChants / 7,
    };
  }

  @override
  void onClose() {
    _sessionTimer?.cancel();
    _chantTimer?.cancel();
    _audioPlayer.dispose();
    super.onClose();
  }
}
