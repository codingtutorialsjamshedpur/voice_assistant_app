import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/haptic/haptic_feedback.dart';

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key});

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _glowController;
  late AnimationController _blinkController;
  late AnimationController _talkController;
  late AnimationController _particleController;
  bool _isSigningIn = false;
  bool _showSigningInText = false;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

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

    _particleController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _startBlinking();
    _setupAuthStateListener();
  }

  void _setupAuthStateListener() {
    SupabaseService().client.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        setState(() => _isSigningIn = false);
        await StorageService.to.setLoggedIn(true);
        final user = session.user;

        // Extract metadata from Google Sign-In
        final String? fullName = user.userMetadata?['full_name'];
        final String? avatarUrl = user.userMetadata?['avatar_url'];

        if (user.email != null) {
          await StorageService.to.setUserProfile({
            'email': user.email,
            'id': user.id,
            'name': fullName ?? '',
            'profileImage': avatarUrl ?? '',
            'isOnline': true,
          });
        }
        if (mounted) {
          Get.offAllNamed(AppRoutes.profile);
        }
      }
    });
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

  void _signInWithGoogle() async {
    AppHaptic.medium();
    setState(() {
      _isSigningIn = true;
      _showSigningInText = false;
    });

    // Show "Signing in..." text after 1.5 seconds if still loading
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _isSigningIn) {
        setState(() => _showSigningInText = true);
      }
    });

    try {
      await SupabaseService().signInWithGoogle();
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      setState(() => _isSigningIn = false);
      Get.snackbar(
        'Authentication Error',
        'Failed to sign in with Google. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withAlpha(204),
        colorText: Colors.white,
      );
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _glowController.dispose();
    _blinkController.dispose();
    _talkController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Face Sprite with Vertical Movement
              _buildAnimatedFace(),
              const SizedBox(height: 24),
              // Title
              const Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF230F1F),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to continue your spiritual journey',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF5A3E54).withAlpha(204),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Glass Form Panel
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(38),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withAlpha(102),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D1F2687),
                      blurRadius: 32,
                      spreadRadius: 0,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Google Sign In Button - Primary Authentication
                          Semantics(
                            label: 'Sign in with Google',
                            button: true,
                            enabled: !_isSigningIn,
                            child: GestureDetector(
                              onTap: _isSigningIn ? null : _signInWithGoogle,
                              child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                color: _isSigningIn
                                    ? Colors.white.withAlpha(100)
                                    : Colors.white.withAlpha(153),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withAlpha(153),
                                ),
                                boxShadow: _isSigningIn
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(26),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isSigningIn)
                                    const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF69B4)),
                                      ),
                                    )
                                  else
                                    Image.asset(
                                      'assets/images/google.png',
                                      width: 24,
                                      height: 24,
                                      fit: BoxFit.contain,
                                    ),
                                  const SizedBox(width: 16),
                                  Text(
                                    _isSigningIn ? 'Signing In' : 'Sign In',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: _isSigningIn
                                          ? const Color(0xFF5A3E54)
                                          : const Color(0xFF230F1F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Signing in indicator
              AnimatedOpacity(
                opacity: _showSigningInText ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: const Text(
                  'Signing in…',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF5A3E54),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              // Floating spiritual particles
              SizedBox(
                height: 60,
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _particleController,
                      builder: (context, child) {
                        final progress = _particleController.value;
                        return CustomPaint(
                          size: const Size(double.infinity, 60),
                          painter: _SpiritualParticlePainter(progress),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Home Indicator
              Container(
                width: 128,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937).withAlpha(102),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
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
}

class _SpiritualParticlePainter extends CustomPainter {
  final double progress;

  _SpiritualParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFB39DDB).withAlpha(40);

    // Draw floating lotus-petal-like shapes
    for (int i = 0; i < 5; i++) {
      final offset = (i / 5) * size.width;
      final phase = (progress + i * 0.2) % 1.0;
      final x = offset + (phase * size.width * 0.3) % size.width;
      final y = size.height * (1 - phase);

      // Petal shape
      final path = Path();
      path.moveTo(x, y);
      path.cubicTo(
        x - 6, y - 8,
        x - 3, y - 14,
        x, y - 16,
      );
      path.cubicTo(
        x + 3, y - 14,
        x + 6, y - 8,
        x, y,
      );

      canvas.drawPath(path, paint);
    }

    // Draw Om-like circles
    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFFFB2EE).withAlpha(30);

    for (int i = 0; i < 3; i++) {
      final phase = (progress + i * 0.3) % 1.0;
      final cx = size.width * (0.2 + i * 0.3);
      final cy = size.height * (1 - phase);
      final r = 4 + phase * 4;
      canvas.drawCircle(Offset(cx, cy), r, circlePaint);
    }
  }

  @override
  bool shouldRepaint(_SpiritualParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
