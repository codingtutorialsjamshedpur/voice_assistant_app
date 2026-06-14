/// ═══════════════════════════════════════════════════════════════
/// Game Controller — Central state management for voice-controlled games
/// ═══════════════════════════════════════════════════════════════
/// Manages:
///   - Active game selection & phase tracking
///   - Score / timer / conversation context
///   - AI prompt construction per game type
///   - Sound effect triggers
///   - Tic-Tac-Toe board logic with minimax AI
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/game_models.dart';
import '../controllers/language_controller.dart';
import '../services/sound_service.dart';
import '../services/tts_service.dart';
import '../services/tts_engine_switcher.dart';
import '../services/history_logger_service.dart';
import '../screens/game/games/tic_tac_toe_game.dart';
import '../screens/game/games/ball_sort_puzzle_game.dart';
import '../screens/game/games/voice_game.dart';
import '../controllers/interstitial_ad_controller.dart';

class GameController extends GetxController {
  // ── Observable State ──────────────────────────────────────────
  final activeGame = Rxn<GameType>();
  final gamePhase = GamePhase.menu.obs;
  final gameScore = 0.obs;
  final totalQuestions = 0.obs;
  final correctAnswers = 0.obs;

  // Timer
  final timerSeconds = 60.obs;
  final isTimerRunning = false.obs;
  Timer? _countdownTimer;

  // Conversation
  final conversationHistory = <GameChatMessage>[].obs;
  final isProcessing = false.obs;

  // Tic-Tac-Toe specific
  final tttLoading = false.obs;
  VoiceGame? activeGameInstance;

  // Game start time for results
  DateTime? _gameStartTime;

  // ── Lifecycle ─────────────────────────────────────────────────

  @override
  void onClose() {
    _countdownTimer?.cancel();
    super.onClose();
  }

  // ── TTS Helper ────────────────────────────────────────────────

  /// Speak an AI response aloud via TTS using the user's **selected language**.
  /// Routes through TtsEngineSwitcher when available (same logic as VoiceAssistantGameController)
  /// so the correct avatar/voice model is used — not the default Hindi/Hinglish.
  void _speakResponse(String text) {
    try {
      final clean = text
          .replaceAll('[CORRECT]', 'Correct!')
          .replaceAll('[WRONG]', 'Wrong.');

      // Resolve BCP-47 locale from LanguageController
      String locale = 'hi-IN'; // safe fallback
      try {
        locale =
            Get.find<LanguageController>().selectedLanguage.value.sttLocale;
      } catch (_) {}

      // Prefer TtsEngineSwitcher — handles Sherpa, Google TTS and flutter_tts
      try {
        Get.find<TtsEngineSwitcher>().speakInLanguage(clean, locale);
        return;
      } catch (_) {}

      // Fallback: direct TTSService call with explicit locale
      Get.find<TTSService>().speak(clean, languageCode: locale);
    } catch (_) {
      debugPrint('⚠️ TTSService not available for game speech');
    }
  }

  // ── Start Game ────────────────────────────────────────────────

  /// Start a game — Ready for new game implementations
  Future<void> startGame(GameType type, {int difficulty = 1}) async {
    activeGame.value = type;
    gamePhase.value = GamePhase.playing;
    gameScore.value = 0;
    totalQuestions.value = 0;
    correctAnswers.value = 0;
    conversationHistory.clear();
    _gameStartTime = DateTime.now();

    if (type == GameType.ticTacToe) {
      activeGameInstance = TicTacToeGame(this);
      tttLoading.value = true;
      activeGameInstance!.onStart().then((_) {
        tttLoading.value = false;
      });
      return;
    }

    if (type == GameType.ballSortPuzzle) {
      activeGameInstance = BallSortPuzzleGame(this);
      activeGameInstance!.onStart();
      return;
    }

    // Play start sounds
    await SoundService.to.playGetReady();
    await Future.delayed(const Duration(milliseconds: 800));
    await SoundService.to.playGo();
  }

  // ── End Game ──────────────────────────────────────────────────

  Future<void> endGame() async {
    _countdownTimer?.cancel();
    isTimerRunning.value = false;
    gamePhase.value = GamePhase.results;

    final duration = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!).inSeconds
        : null;

    await HistoryLoggerService().logGameActivity(
      gameName: activeGame.value?.name ?? 'Unknown Game',
      score: gameScore.value,
      durationSeconds: duration,
    );

    await SoundService.to.playGameOver();

    // Show interstitial ad when game ends
    try {
      final interstitialCtrl = Get.find<InterstitialAdController>();
      interstitialCtrl.showAd();
    } catch (_) {}

    // Check for perfect score
    if (correctAnswers.value == totalQuestions.value &&
        totalQuestions.value > 0) {
      await Future.delayed(const Duration(milliseconds: 500));
      await SoundService.to.playCheer();
    }
  }

  GameResult getResult() {
    final elapsed = _gameStartTime != null
        ? DateTime.now().difference(_gameStartTime!)
        : Duration.zero;
    return GameResult(
      score: correctAnswers.value,
      total: totalQuestions.value,
      timeTaken: elapsed,
      feedbackText: _generateFeedback(),
      gameType: null, // TODO: Update when new games are added
    );
  }

  void resetToHub() {
    _countdownTimer?.cancel();
    activeGameInstance?.onDispose();
    activeGameInstance = null;
    activeGame.value = null;
    gamePhase.value = GamePhase.menu;
    conversationHistory.clear();
    isTimerRunning.value = false;
    tttLoading.value = false;
  }

  // ── Exposed Helpers for Games ─────────────────────────────────

  void addUserMessage(String text) {
    conversationHistory.add(GameChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      isUser: true,
    ));
  }

  void addAssistantMessage(String text) {
    conversationHistory.add(GameChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      isUser: false,
    ));
    // Try to score if markers are present
    _parseScoreFromResponse(text);
    // Speak aloud
    _speakResponse(text);
  }

  void endGameWithResults(String message) {
    addAssistantMessage(message);
    endGame();
  }

  // ── Process User Input ────────────────────────────────────────

  /// Process game input from voice or text
  Future<void> processGameInput(String voiceText) async {
    if (activeGame.value == null) return;
    if (isProcessing.value) return;

    if (activeGameInstance != null) {
      isProcessing.value = true;
      addUserMessage(voiceText);
      try {
        await activeGameInstance!.onInput(voiceText);
      } finally {
        isProcessing.value = false;
      }
    }
  }

  // ── Timer ─────────────────────────────────────────────────────

  // ── Game UI Methods ───────────────────────────────────────────

  /// Placeholder for Tic-Tac-Toe restart — ready for new implementation
  void restartTicTacToe() {
    // TODO: Implement when tic-tac-toe game is added
  }

  /// Placeholder for making moves — ready for new implementation
  void makeTicTacToeMove(int cellIndex) {
    // TODO: Implement when tic-tac-toe game is added
  }

  // ── Score Parsing ─────────────────────────────────────────────

  void _parseScoreFromResponse(String response) {
    if (response.contains('[CORRECT]')) {
      correctAnswers.value++;
      totalQuestions.value++;
      gameScore.value += 10;
      SoundService.to.playCorrect();
    } else if (response.contains('[WRONG]')) {
      totalQuestions.value++;
      SoundService.to.playWrong();
    }
  }

  String _generateFeedback() {
    final pct = totalQuestions.value > 0
        ? (correctAnswers.value / totalQuestions.value * 100).round()
        : 0;
    if (pct >= 90) return 'Outstanding! You\'re a genius! 🏆';
    if (pct >= 70) return 'Great job! Well played! 🌟';
    if (pct >= 50) return 'Good effort! Keep practising! 💪';
    if (pct >= 30) return 'Nice try! You\'ll do better next time! 🎯';
    return 'Keep learning — practice makes perfect! 📚';
  }
}
