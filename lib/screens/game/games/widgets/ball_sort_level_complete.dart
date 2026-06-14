import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../controllers/ball_sort_controller.dart';
import '../../../../controllers/game_controller.dart';

class BallSortLevelComplete extends StatefulWidget {
  const BallSortLevelComplete({super.key});

  @override
  State<BallSortLevelComplete> createState() => _BallSortLevelCompleteState();
}

class _BallSortLevelCompleteState extends State<BallSortLevelComplete> {
  // When the user taps "No", we hide the proceed dialog but keep the
  // controller's level-complete state intact so they can still inspect
  // the finished board. Tapping "Yes" advances to the next level.
  bool _proceedDialogDismissed = false;

  @override
  Widget build(BuildContext context) {
    final bsc = Get.isRegistered<BallSortController>()
        ? Get.find<BallSortController>()
        : null;
    if (bsc == null) return const SizedBox.shrink();

    return Obx(() {
      if (!bsc.isLevelComplete.value &&
          !bsc.isGameComplete.value &&
          !bsc.isGameOver.value) {
        // Reset local dismissal flag whenever a fresh level is shown so
        // the Yes/No dialog reappears for the next completed level.
        if (_proceedDialogDismissed) {
          _proceedDialogDismissed = false;
        }
        return const SizedBox.shrink();
      }

      return Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (bsc.isGameComplete.value)
                _buildGameComplete(bsc)
              else if (bsc.isGameOver.value)
                _buildGameOver(bsc)
              else
                _buildLevelComplete(bsc),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildLevelComplete(BallSortController bsc) {
    if (_proceedDialogDismissed) {
      return _buildLevelCompleteSummary(bsc);
    }
    return _buildProceedDialog(bsc);
  }

  /// Renders the 3-star rating. Lit stars are gold; unlit stars are
  /// dimmed with a subtle outline so empty positions are still visible.
  Widget _buildStarRow(int filled) {
    const total = 3;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(total, (i) {
        final isLit = i < filled;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Icon(
            Icons.star_rounded,
            size: 34,
            color: isLit
                ? const Color(0xFFFFD700)
                : Colors.white.withValues(alpha: 0.25),
            shadows: isLit
                ? const [
                    Shadow(
                        color: Color(0xAAFFD700),
                        blurRadius: 12,
                        offset: Offset(0, 0)),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildProceedDialog(BallSortController bsc) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '✅ Level Complete!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _buildStarRow(bsc.starCount.value),
              const SizedBox(height: 14),
              _buildStatLine(
                  'Best Possible', '${bsc.optimalMoves.value} moves'),
              const SizedBox(height: 4),
              _buildStatLine('Your Result',
                  '${bsc.moveCount.value} / ${bsc.maxAllowedMoves.value} moves',
                  highlight: true),
              const SizedBox(height: 12),
              Text(
                bsc.performanceRating.value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFD700), // Gold
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Proceed to next level?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildButton(
                    'Next',
                    Colors.green,
                    () {
                      _proceedDialogDismissed = false;
                      bsc.loadNextLevel();
                    },
                  ),
                  const SizedBox(width: 10),
                  _buildButton(
                    'Retry',
                    Colors.white,
                    () {
                      _proceedDialogDismissed = false;
                      bsc.restartLevel();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelCompleteSummary(BallSortController bsc) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '✅ Level Complete!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildStarRow(bsc.starCount.value),
              const SizedBox(height: 8),
              Text(
                'Best ${bsc.optimalMoves.value} • Yours ${bsc.moveCount.value} / ${bsc.maxAllowedMoves.value}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bsc.performanceRating.value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildButton('Next Level', Colors.green, () {
                    bsc.loadNextLevel();
                  }),
                  const SizedBox(width: 10),
                  _buildButton('Retry', Colors.white, () {
                    bsc.restartLevel();
                  }),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Tap a tube to dismiss',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOver(BallSortController bsc) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '❌ GAME OVER',
                style: TextStyle(
                  color: Color(0xFFFF4C4C),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _buildStarRow(bsc.starCount.value),
              const SizedBox(height: 10),
              Text(
                'You exceeded the\nmaximum limit of ${bsc.maxAllowedMoves.value} moves.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              _buildStatLine(
                  'Best Possible', '${bsc.optimalMoves.value} moves'),
              const SizedBox(height: 4),
              _buildStatLine('Your Result',
                  '${bsc.moveCount.value} / ${bsc.maxAllowedMoves.value} moves',
                  highlight: true),
              const SizedBox(height: 18),
              _buildButton('Retry Level', Colors.white, () {
                bsc.restartLevel();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameComplete(BallSortController bsc) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B9D), Color(0xFF9B5DE5)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B9D).withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🎉 All 40 Levels Complete!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildButton('Play Again from Level 1', Colors.white, () {
            bsc.clearProgress();
          }),
          const SizedBox(height: 8),
          _buildButton('Return to Game Hub', Colors.white, () {
            Get.find<GameController>().resetToHub();
            Get.offNamed('/game');
          }),
        ],
      ),
    );
  }

  Widget _buildStatLine(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: highlight ? 16 : 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlight ? const Color(0xFFFFD700) : Colors.white,
            fontSize: highlight ? 18 : 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildButton(String label, Color accentColor, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.55),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
