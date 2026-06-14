/// ═══════════════════════════════════════════════════════════════
/// Game Screen — Voice-Controlled Games Hub
/// ═══════════════════════════════════════════════════════════════
/// Displays 4 voice-controlled games organized by category:
///   🎮 Strategy: Tic-Tac-Toe 3D
///   🧠 Brain: Voice Assistant
///   �️ Discovery: Global Radio, World TV Window
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
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/responsive.dart';
import '../../shared/theme/responsive_widgets.dart';
import 'games/widgets/ttt_loading_screen.dart';
import 'games/widgets/ball_sort_loading_screen.dart';
import 'widgets/garden_portal_screen.dart';
import '../../services/stt_service.dart';
import '../../services/voice_session_restoration_manager.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late final AnimationController _staggerController;
  final List<AnimationController> _cardControllers = [];
  final List<Animation<double>> _cardScales = [];
  final List<Animation<double>> _cardFades = [];

  @override
  void initState() {
    super.initState();

    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Create stagger animations for each game card
    for (int i = 0; i < GameRegistry.allGames.length; i++) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      _cardControllers.add(controller);
      _cardScales.add(Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
      ));
      _cardFades.add(Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOut),
      ));
    }

    // Stagger the card animations
    _startStaggeredAnimation();
  }

  void _startStaggeredAnimation() async {
    for (int i = 0; i < _cardControllers.length; i++) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (mounted) {
        _cardControllers[i].forward();
      }
    }
  }

  @override
  void dispose() {
    _staggerController.dispose();
    for (final c in _cardControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      currentRoute: AppRoutes.game,
      content: TabletConstrained(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFFFFB2EE),
                          Color(0xFFFF69B4),
                          Color(0xFF8B5CF6)
                        ],
                      ).createShader(bounds),
                      child: Text(
                        'Voice Games',
                        style: TextStyle(
                          fontSize: context.r.sp(28),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '3 games • Speak to play • AI-powered',
                      style: TextStyle(
                        fontSize: context.r.sp(13),
                        color: Colors.grey[500],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Category sections
            ..._buildCategorySections(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCategorySections() {
    final categories = [
      GameCategory.strategy,
      GameCategory.discovery,
      GameCategory.mystical,
      GameCategory.learning,
      GameCategory.brain,
    ];

    final widgets = <Widget>[];

    for (final category in categories) {
      final games =
          GameRegistry.allGames.where((g) => g.category == category).toList();
      if (games.isEmpty) continue;

      // Category header
      widgets.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(left: 4, top: 8, bottom: 12),
            child: Row(
              children: [
                Icon(
                  _categoryIcon(category),
                  size: context.r.scale(20),
                  color: AppColors.textPrimary(context).withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  games.first.categoryLabel,
                  style: TextStyle(
                    fontSize: context.r.sp(16),
                    fontWeight: FontWeight.w700,
                    color:
                        AppColors.textPrimary(context).withValues(alpha: 0.8),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Game cards - horizontally scrollable
      widgets.add(
        SliverToBoxAdapter(
          child: SizedBox(
            height: context.r.scale(120),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: games.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final game = games[index];
                final globalIndex = GameRegistry.allGames.indexOf(game);

                return AnimatedBuilder(
                  animation: _cardControllers[globalIndex],
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _cardScales[globalIndex].value,
                      child: Opacity(
                        opacity: _cardFades[globalIndex].value,
                        child: child,
                      ),
                    );
                  },
                  child: SizedBox(
                    width: 300,
                    child: _buildGameCard(game),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildGameCard(GameInfo game) {
    return Semantics(
      label: 'Play ${game.name}',
      button: true,
      child: GestureDetector(
        onTap: () => _launchGame(game),
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      game.gradientColors[0].withValues(alpha: 0.2),
                      game.gradientColors[1].withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: game.gradientColors[0].withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Game icon
                    Container(
                      width: context.r.scale(56),
                      height: context.r.scale(56),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: game.gradientColors,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color:
                                game.gradientColors[0].withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        game.icon,
                        color: Colors.white,
                        size: context.r.scale(28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Name and description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            game.name,
                            style: TextStyle(
                              fontSize: context.r.sp(16),
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            game.description,
                            style: TextStyle(
                              fontSize: context.r.sp(12),
                              color: AppColors.textSecondary(context),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Play button
                    Container(
                      width: context.r.scale(44),
                      height: context.r.scale(44),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            game.gradientColors[0].withValues(alpha: 0.5),
                            game.gradientColors[1].withValues(alpha: 0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: game.gradientColors[0].withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: context.r.scale(26),
                      ),
                    ),
                    // Timer badge
                    if (game.hasTTimer) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer,
                                color: Color(0xFFEF4444), size: 12),
                            SizedBox(width: 2),
                            Text(
                              '60s',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _launchGame(GameInfo game) async {
    await SoundService.to.playClick();

    final gameController = Get.find<GameController>();
    gameController.startGame(game.type);

    if (game.type == GameType.ticTacToe) {
      await Get.to(
        () => TttLoadingScreen(
          onLoadingComplete: () {
            gameController.tttLoading.value = false;
            gameController.activeGameInstance?.onStart();
            Get.offNamed(AppRoutes.gamePlay);
          },
        ),
      );
    } else if (game.type == GameType.ballSortPuzzle) {
      await Get.to(
        () => BallSortLoadingScreen(
          onLoadingComplete: () {
            // startGame() already created the BallSortPuzzleGame instance.
            // Just call onStart() on the existing one — do NOT create a second.
            gameController.activeGameInstance?.onStart();
            Get.offNamed(AppRoutes.gamePlay);
          },
        ),
      );
    } else if (game.type == GameType.voiceAssistant) {
      await Get.toNamed(AppRoutes.voiceAssistantGame);
    } else if (game.type == GameType.globalRadio) {
      await Get.to(() => const GardenPortalScreen(
            url: 'https://radio.garden',
            title: 'Global Radio Explorer',
          ));

      // ── Clean standalone Independent Lifecycle execution ────────────────
      _restoreAfterPortal();
    } else if (game.type == GameType.globalTV) {
      await Get.to(() => const GardenPortalScreen(
            url: 'https://tvgarden.world',
            title: 'World TV Window',
          ));

      // ── Clean standalone Independent Lifecycle execution ────────────────
      _restoreAfterPortal();
    } else {
      Get.toNamed(AppRoutes.gamePlay);
    }
  }

  /// Called immediately after Get.to(GardenPortalScreen) returns.
  /// Delegates directly to the new VoiceSessionRestorationManager architecture.
  void _restoreAfterPortal() {
    Future.microtask(() async {
      try {
        await VoiceSessionRestorationManager.to.restore();
      } catch (e) {
        debugPrint(
            '⚠️ [GameScreen] Independent Restore Architecture failed: $e');
      }
    });
  }

  IconData _categoryIcon(GameCategory category) {
    switch (category) {
      case GameCategory.strategy:
        return Icons.emoji_events_outlined;
      case GameCategory.brain:
        return Icons.psychology_outlined;
      case GameCategory.discovery:
        return Icons.explore_outlined;
      case GameCategory.mystical:
        return Icons.auto_awesome_outlined;
      case GameCategory.learning:
        return Icons.school_outlined;
    }
  }
}
