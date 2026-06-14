import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';
import '../../services/storage_service.dart';
import '../../services/sound_service.dart';
import '../../services/supabase_service.dart';
import '../../services/api_keys_config.dart';
import '../../controllers/wallpaper_controller.dart';
import '../../shared/widgets/shared_widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _bounceController;
  late AnimationController _glowController;
  late AnimationController _blinkController;
  late AnimationController _talkController;
  late AnimationController _floatController;
  late AnimationController _messageController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _messageOpacity;
  late Animation<Offset> _messageSlide;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();

    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _talkController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..repeat(reverse: true);

    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _startBlinking();

    _messageController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _messageOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _messageController,
        curve: Curves.easeOut,
      ),
    );

    _messageSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _messageController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeController.forward();
    _startMessageAnimation();

    // Play splash sound
    try {
      SoundService.to.playSplashSound();
    } catch (_) {}

    _initializeApp();
  }

  void _startBlinking() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        await _blinkController.forward();
        await _blinkController.reverse();
        _startBlinking();
      }
    });
  }

  void _startMessageAnimation() {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _messageController.forward();
      }
    });
  }

  Future<void> _initializeApp() async {
    // 1. Initial wait to show off the beautiful splash
    await Future.delayed(const Duration(seconds: 4));

    final isLoggedIn = StorageService.to.userIsLoggedIn;
    final isFirstTime = StorageService.to.isFirstTimeUser;
    final hasAcceptedPrivacy = StorageService.to.hasAcceptedPrivacy;
    final hasProfile = StorageService.to.hasProfile;

    if (isFirstTime) {
      Get.offAllNamed(AppRoutes.welcome);
      return;
    }

    if (!hasAcceptedPrivacy) {
      Get.offAllNamed(AppRoutes.privacyPolicy);
      return;
    }

    if (!isLoggedIn || !hasProfile) {
      Get.offAllNamed(AppRoutes.authentication);
      return;
    }

    // RETURNING USER FLOW:
    // 2. Ensuring Supabase session is restored BEFORE proceeding
    // This fixes the "guest user" glitch where RLS prevents data loading
    debugPrint(
        '🔄 [SplashScreen] Returning user detected. Restoring session...');
    await SupabaseService().restoreSession();

    // 3. Await critical background services that the Voice Chat depends on
    // such as API Keys and Wallpapers
    debugPrint('🔄 [SplashScreen] Loading critical configurations...');
    try {
      // Ensure we have a fresh sync AFTER session is restored
      if (Get.isRegistered<WallpaperController>()) {
        Get.find<WallpaperController>().refreshWallpapers();
      }

      await Future.wait([
        ApiKeysConfig.init(),
        _waitForWallpaperSync(),
      ]).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint(
          '⚠️ [SplashScreen] Configuration sync took too long, proceeding anyway: $e');
    }

    // 4. Finally navigate to Voice Chat
    Get.offAllNamed(AppRoutes.voiceChat);
  }

  /// Helper to ensure WallpaperController has finished its initial sync
  Future<void> _waitForWallpaperSync() async {
    if (Get.isRegistered<WallpaperController>()) {
      final controller = Get.find<WallpaperController>();
      int attempts = 0;
      while (controller.isLoading.value && attempts < 20) {
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }
    } else {
      // If not even registered yet, wait a bit
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _bounceController.dispose();
    _glowController.dispose();
    _blinkController.dispose();
    _talkController.dispose();
    _floatController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Main Glass Panel
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: MediaQuery.of(context).size.width - 48,
                    height: MediaQuery.of(context).size.width - 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(38),
                      borderRadius: BorderRadius.circular(48),
                      border: Border.all(
                        color: Colors.white.withAlpha(77),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F1F2687),
                          blurRadius: 32,
                          spreadRadius: 0,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(48),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withAlpha(51),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Animated Face Sprite with Vertical Movement
                              _buildAnimatedFace(),
                              const SizedBox(height: 24),
                              // App Name
                              const Text(
                                'CTJ Voice Chat',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w300,
                                  color: Colors.white,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Version
                              Text(
                                'Version 1.0',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withAlpha(204),
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Loading Dots
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildBouncingDot(0),
                                  const SizedBox(width: 12),
                                  _buildBouncingDot(1),
                                  const SizedBox(width: 12),
                                  _buildBouncingDot(2),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                // Welcome Message Container with Glassmorphism
                FadeTransition(
                  opacity: _messageOpacity,
                  child: SlideTransition(
                    position: _messageSlide,
                    child: AnimatedBuilder(
                      animation: _messageController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 0.95 + (0.05 * _messageController.value),
                          child: Container(
                            width: MediaQuery.of(context).size.width - 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(51),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withAlpha(102),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(26),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withAlpha(77),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: RichText(
                                    textAlign: TextAlign.center,
                                    text: const TextSpan(
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFFF2F2F2),
                                        height: 1.6,
                                        letterSpacing: 0.3,
                                      ),
                                      children: [
                                        TextSpan(
                                          text:
                                              'Namaste! I\'m your AI Companion.\n\n',
                                        ),
                                        TextSpan(
                                          text:
                                              'Crafted with care by CTJ Team —\n',
                                        ),
                                        TextSpan(
                                          text: 'Indie Flutter Developer ',
                                        ),
                                        TextSpan(
                                          text: 'Sourav Kumar',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFFFB1EE),
                                            fontSize: 15,
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              '.\n\nHere to help you learn, communicate,\ncreate, and grow.\n\nLet\'s begin your journey!',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 3D GLASS ORB WITH ANIMATED SPRITE FACE - Exact implementation from About Screen
  Widget _buildAnimatedFace() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final floatValue = _floatController.value;
        final offsetY = (floatValue - 0.5) * 8;

        return Transform.translate(
          offset: Offset(0, offsetY),
          child: AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              final glowValue = _glowController.value;
              final glowIntensity = 0.3 + (glowValue * 0.4);

              return Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.3),
                    radius: 0.8,
                    colors: [
                      const Color(0xFFFFFFFF).withValues(alpha: 0.9),
                      const Color(0xFFFFE4F5).withValues(alpha: 0.7),
                      const Color(0xFFFFB1EE).withValues(alpha: glowIntensity),
                      const Color(0xFFFF69B4).withValues(alpha: 0.3),
                    ],
                    stops: const [0.0, 0.4, 0.7, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB1EE)
                          .withValues(alpha: 0.3 + glowValue * 0.3),
                      blurRadius: 30 + (glowValue * 15),
                      spreadRadius: 5 + (glowValue * 10),
                    ),
                    BoxShadow(
                      color: const Color(0xFFFFFFFF).withValues(alpha: 0.3),
                      blurRadius: 50,
                      spreadRadius: -5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.2, -0.2),
                          radius: 0.6,
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.1),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Inner reflections
                          Positioned(
                            top: 25,
                            left: 30,
                            child: Container(
                              width: 20,
                              height: 12,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.8),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 35,
                            left: 25,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          // Animated Face with Blinking Eyes and Talking Mouth
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Blinking Eyes Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Left Blinking Eye
                                  AnimatedBuilder(
                                    animation: _blinkController,
                                    builder: (context, child) {
                                      final scaleY =
                                          1.0 - (_blinkController.value * 0.9);
                                      return Transform.scale(
                                        scaleY: scaleY,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF2D1B2E)
                                                .withValues(alpha: 0.7),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.white
                                                    .withValues(alpha: 0.5),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 20),
                                  // Right Blinking Eye
                                  AnimatedBuilder(
                                    animation: _blinkController,
                                    builder: (context, child) {
                                      final scaleY =
                                          1.0 - (_blinkController.value * 0.9);
                                      return Transform.scale(
                                        scaleY: scaleY,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF2D1B2E)
                                                .withValues(alpha: 0.7),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.white
                                                    .withValues(alpha: 0.5),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Animated Talking Mouth
                              AnimatedBuilder(
                                animation: _talkController,
                                builder: (context, child) {
                                  final talkValue = _talkController.value;
                                  final mouthHeight = 4.0 + (talkValue * 6.0);
                                  final mouthWidth = 22.0 - (talkValue * 4.0);

                                  return Container(
                                    width: mouthWidth,
                                    height: mouthHeight,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2D1B2E)
                                          .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: const Radius.circular(12),
                                        bottomRight: const Radius.circular(12),
                                        topLeft: Radius.circular(
                                            4 + (talkValue * 4)),
                                        topRight: Radius.circular(
                                            4 + (talkValue * 4)),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBouncingDot(int index) {
    final delays = [0.0, -0.32, -0.16];
    final delay = delays[index];

    return AnimatedBuilder(
      animation: _bounceController,
      builder: (context, child) {
        final value = _bounceController.value;
        final adjustedValue = (value + (delay < 0 ? 1 + delay : delay)) % 1.0;
        final yOffset = adjustedValue < 0.5
            ? -10 * (adjustedValue * 2)
            : -10 * ((1 - adjustedValue) * 2);

        return Transform.translate(
          offset: Offset(0, yOffset),
          child: Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFFFFB1EE),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x66FFB1EE),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
