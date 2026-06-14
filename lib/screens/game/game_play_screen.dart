/// ═══════════════════════════════════════════════════════════════
/// Game Play Screen — Unified screen for all 4 voice-controlled games
/// ═══════════════════════════════════════════════════════════════
/// Features:
///   - Game title header with themed gradient
///   - Conversation area (AI chat bubbles)
///   - Score & timer display
///   - Tic-Tac-Toe board (when applicable)
///   - Results screen at game end
///   - Voice input via DualModeInputPanel (from DefaultLayout)
/// ═══════════════════════════════════════════════════════════════
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/game_controller.dart';
import '../../models/game_models.dart';
import '../../routes/app_routes.dart';
import '../../services/sound_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/theme/responsive.dart';
import 'games/tic_tac_toe_game.dart';
import 'games/ball_sort_puzzle_game.dart';
import 'games/widgets/ttt_board_widget.dart';
import 'games/widgets/ball_sort_board_widget.dart';
import 'games/widgets/ball_sort_level_complete.dart';

class GamePlayScreen extends StatefulWidget {
  const GamePlayScreen({super.key});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen>
    with TickerProviderStateMixin {
  final GameController _gameController = Get.find<GameController>();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _headerAnimController;
  late Animation<double> _headerSlide;
  late Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerSlide = Tween<double>(begin: -30, end: 0).animate(
      CurvedAnimation(
          parent: _headerAnimController, curve: Curves.easeOutCubic),
    );
    _headerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _headerAnimController, curve: Curves.easeOut),
    );
    _headerAnimController.forward();

    // Auto-scroll when new messages arrive
    ever(_gameController.conversationHistory, (_) {
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      currentRoute: AppRoutes.gamePlay,
      customTopPanel: _buildGameHeader(),
      content: Obx(() {
        final phase = _gameController.gamePhase.value;
        if (phase == GamePhase.results) {
          return _buildResultsView();
        }
        return _buildGameplayView();
      }),
    );
  }

  // ── Game Header ─────────────────────────────────────────────

  Widget _buildGameHeader() {
    return Obx(() {
      final gameType = _gameController.activeGame.value;
      if (gameType == null) return const SizedBox.shrink();

      final info = GameRegistry.getInfo(gameType);
      if (info == null) return const SizedBox.shrink();

      return AnimatedBuilder(
        animation: _headerAnimController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _headerSlide.value),
            child: Opacity(
              opacity: _headerFade.value,
              child: child,
            ),
          );
        },
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        info.gradientColors[0].withValues(alpha: 0.3),
                        info.gradientColors[1].withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: info.gradientColors[0].withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () {
                          SoundService.to.playClick();
                          _gameController.resetToHub();
                          Get.offNamed(AppRoutes.game); // Always go to Game Hub
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Game icon
                      Container(
                        width: context.r.scale(40),
                        height: context.r.scale(40),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: info.gradientColors,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  info.gradientColors[0].withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(info.icon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              info.name,
                              style: TextStyle(
                                fontSize: context.r.sp(16),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              info.categoryLabel,
                              style: TextStyle(
                                fontSize: context.r.sp(11),
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Score
                      if (_gameController.totalQuestions.value > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_gameController.correctAnswers.value}/${_gameController.totalQuestions.value}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: context.r.sp(14),
                            ),
                          ),
                        ),
                      // Timer
                      if (info.hasTTimer) ...[
                        const SizedBox(width: 8),
                        _buildTimerBadge(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildTimerBadge() {
    return Obx(() {
      final seconds = _gameController.timerSeconds.value;
      final isLow = seconds <= 10;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLow
                ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                : [
                    Colors.white.withValues(alpha: 0.2),
                    Colors.white.withValues(alpha: 0.1)
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer,
              color: isLow ? Colors.white : Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '${seconds}s',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isLow ? 16 : 14,
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── Gameplay View ─────────────────────────────────────────────

  Widget _buildGameplayView() {
    return Obx(() {
      final gameType = _gameController.activeGame.value;
      if (gameType == null) return const SizedBox.shrink();

      return Column(
        children: [
          if (gameType == GameType.ticTacToe) _buildTicTacToeBoard(),
          if (gameType == GameType.ballSortPuzzle) _buildBallSortBoard(),
          Expanded(
            child: _buildConversationArea(),
          ),
        ],
      );
    });
  }

  Widget _buildTicTacToeBoard() {
    return Obx(() {
      final game = _gameController.activeGameInstance as TicTacToeGame?;
      if (game == null) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TttBoardWidget(
          board: game.board.toList(),
          roundNumber: game.roundNumber.value,
          statusLine: game.statusLine.value,
          winningLine: game.winningLine.toList(),
          onTap: (index) {
            if (!game.isPlayerTurn.value || game.isGameOver) return;
            _gameController.processGameInput((index + 1).toString());
          },
        ),
      );
    });
  }

  Widget _buildBallSortBoard() {
    final game = _gameController.activeGameInstance as BallSortPuzzleGame?;
    if (game == null) return const SizedBox.shrink();

    // Give the board a bounded height so LayoutBuilder works correctly.
    // 42% of screen height leaves more room for the conversation area
    // below so the messages are clearly visible to the user.
    final boardHeight = MediaQuery.of(context).size.height * 0.42;
    return SizedBox(
      height: boardHeight,
      width: double.infinity,
      child: Stack(
        children: [
          const Positioned.fill(child: BallSortBoardWidget()),
          const Positioned.fill(child: BallSortLevelComplete()),
        ],
      ),
    );
  }

  Widget _buildConversationArea() {
    return Obx(() {
      final messages = _gameController.conversationHistory;

      if (messages.isEmpty && _gameController.isProcessing.value) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: context.r.scale(48),
                height: context.r.scale(48),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Setting up the game...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: context.r.sp(14),
                ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount:
            messages.length + (_gameController.isProcessing.value ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == messages.length) {
            // Processing indicator
            return _buildTypingIndicator();
          }
          return _buildChatBubble(messages[index]);
        },
      );
    });
  }

  Widget _buildChatBubble(GameChatMessage message) {
    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 60 : 8,
        right: isUser ? 8 : 60,
        bottom: 10,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isUser
                      ? [
                          const Color(0xFF6366F1).withValues(alpha: 0.6),
                          const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.15),
                          Colors.white.withValues(alpha: 0.08),
                        ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: Border.all(
                  color: isUser
                      ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Text(
                // Clean up score markers before display
                message.content
                    .replaceAll('[CORRECT]', '✅')
                    .replaceAll('[WRONG]', '❌'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: context.r.sp(15),
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 60, bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 600 + (i * 200)),
                    builder: (context, value, child) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white
                              .withValues(alpha: 0.3 + (0.5 * (1 - value))),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Results View ──────────────────────────────────────────────

  Widget _buildResultsView() {
    final result = _gameController.getResult();
    final info =
        result.gameType != null ? GameRegistry.getInfo(result.gameType!) : null;

    // Fallback colors if no game info
    final gradientColors = info?.gradientColors ??
        [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)];

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Trophy/Result icon
            Container(
              width: context.r.scale(100),
              height: context.r.scale(100),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: gradientColors[0].withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                result.percentage >= 70
                    ? Icons.emoji_events
                    : Icons.sports_score,
                color: Colors.white,
                size: context.r.scale(48),
              ),
            ),
            const SizedBox(height: 24),

            // Game Over text
            Text(
              'Game Over!',
              style: TextStyle(
                fontSize: context.r.sp(28),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            // Score
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${result.score}/${result.total}',
                        style: TextStyle(
                          fontSize: context.r.sp(48),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${result.percentage.round()}% correct',
                        style: TextStyle(
                          fontSize: context.r.sp(16),
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Time: ${result.timeTaken.inMinutes}m ${result.timeTaken.inSeconds % 60}s',
                        style: TextStyle(
                          fontSize: context.r.sp(14),
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Feedback
            Text(
              result.feedbackText,
              style: TextStyle(
                fontSize: context.r.sp(18),
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildResultButton(
                  label: 'Play Again',
                  icon: Icons.replay,
                  gradient: gradientColors,
                  onTap: () {
                    SoundService.to.playClick();
                    if (result.gameType != null) {
                      _gameController.startGame(result.gameType!);
                    }
                  },
                ),
                const SizedBox(width: 16),
                _buildResultButton(
                  label: 'Back to Hub',
                  icon: Icons.home,
                  gradient: [
                    Colors.white.withValues(alpha: 0.2),
                    Colors.white.withValues(alpha: 0.1)
                  ],
                  onTap: () {
                    SoundService.to.playClick();
                    _gameController.resetToHub();
                    Get.offNamed(AppRoutes.game); // Always go to Game Hub
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultButton({
    required String label,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: context.r.sp(14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
