import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../features/orb_thinking/orb_thinking_controller.dart';
import '../theme/responsive.dart';

enum OrbState { idle, listening, thinking, speaking }

class AnimatedOrb extends StatefulWidget {
  final double size;

  final bool? isTalking;

  final bool showTalkingAnimation;

  final bool autoBlink;

  final bool showShadow;

  final OrbState? orbState;

  const AnimatedOrb({
    super.key,
    this.size = 140,
    this.isTalking,
    this.showTalkingAnimation = true,
    this.autoBlink = true,
    this.showShadow = true,
    this.orbState,
  });

  @override
  State<AnimatedOrb> createState() => _AnimatedOrbState();
}

class _AnimatedOrbState extends State<AnimatedOrb>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _floatController;
  late AnimationController _blinkController;

  late AnimationController _mouthController;

  late final ValueNotifier<OrbState> _stateNotifier;

  bool _blinkLoopRunning = false;

  OrbState get _currentState {
    if (widget.orbState != null) return widget.orbState!;
    if (widget.isTalking == true) return OrbState.speaking;
    return OrbState.idle;
  }

  @override
  void initState() {
    super.initState();
    _stateNotifier = ValueNotifier<OrbState>(_currentState);

    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );

    _mouthController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    if (widget.autoBlink) {
      _startBlinking(_currentState == OrbState.speaking);
    }

    if (_currentState == OrbState.speaking) {
      _mouthController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedOrb oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldTalking = oldWidget.orbState == OrbState.speaking ||
        (oldWidget.orbState == null && oldWidget.isTalking == true);
    final newTalking = _currentState == OrbState.speaking;

    _stateNotifier.value = _currentState;

    if (oldTalking != newTalking) {
      _blinkLoopRunning = false;
      if (widget.autoBlink) {
        _startBlinking(newTalking);
      }

      if (newTalking) {
        _mouthController.repeat(reverse: true);
      } else {
        _mouthController.stop();
        _mouthController.animateTo(0.0,
            duration: const Duration(milliseconds: 150));
      }
    }
  }

  void _startBlinking(bool isTalkingNow) {
    if (_blinkLoopRunning) return;
    _blinkLoopRunning = true;
    _blinkLoop(isTalkingNow);
  }

  Future<void> _blinkLoop(bool startedAsTalking) async {
    final interval = startedAsTalking
        ? const Duration(milliseconds: 600)
        : const Duration(seconds: 3);

    await Future.delayed(interval);
    if (!mounted || !_blinkLoopRunning) return;

    if ((_currentState == OrbState.speaking) != startedAsTalking) {
      _blinkLoopRunning = false;
      return;
    }

    try {
      final orbController = Get.find<OrbThinkingController>();
      if (orbController.isBlinking || startedAsTalking) {
        await _blinkController.forward();
        await Future.delayed(const Duration(milliseconds: 80));
        await _blinkController.reverse();
        await Future.delayed(const Duration(milliseconds: 120));
        await _blinkController.forward();
        await _blinkController.reverse();
      } else {
        await _blinkController.forward();
        await _blinkController.reverse();
      }
    } catch (_) {
      await _blinkController.forward();
      await _blinkController.reverse();
    }

    _blinkLoop(startedAsTalking);
  }

  @override
  void dispose() {
    _stateNotifier.dispose();
    _glowController.dispose();
    _floatController.dispose();
    _blinkController.dispose();
    _mouthController.dispose();
    super.dispose();
  }

  Widget _stateToAnimatedBuilder(
      Widget Function(BuildContext, OrbState) builder) {
    return AnimatedBuilder(
      animation: _stateNotifier,
      builder: (context, _) => builder(context, _stateNotifier.value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'AI Companion Orb',
      image: true,
      child: RepaintBoundary(
        child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: _stateToAnimatedBuilder((context, state) {
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

                    final isTalkingNow = widget.isTalking ?? false;

                    double glowMultiplier;
                    switch (state) {
                      case OrbState.listening:
                        glowMultiplier = 1.3;
                        break;
                      case OrbState.thinking:
                        glowMultiplier = 0.7;
                        break;
                      case OrbState.speaking:
                        glowMultiplier = 1.5;
                        break;
                      case OrbState.idle:
                        glowMultiplier = 1.0;
                    }

                    if (isTalkingNow && widget.orbState == null) {
                      glowMultiplier = 1.5;
                    }

                    final enhancedGlow = glowIntensity * glowMultiplier;

                    double bodyScale;
                    switch (state) {
                      case OrbState.listening:
                        bodyScale = 1.15;
                        break;
                      case OrbState.speaking:
                        bodyScale =
                            1.0 + (_mouthController.value > 0.5 ? 0.03 : 0.0);
                        break;
                      case OrbState.thinking:
                      case OrbState.idle:
                        bodyScale = 1.0;
                    }

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        if (state == OrbState.listening)
                          AnimatedBuilder(
                            animation: _glowController,
                            builder: (context, _) {
                              final pulse =
                                  0.5 + (_glowController.value * 0.5);
                              return Container(
                                width: widget.size * 1.3,
                                height: widget.size * 1.3,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFFFB1EE).withAlpha(
                                        (255 * 0.3 * pulse).toInt()),
                                    width: context.r.scale(2),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFB1EE).withAlpha(
                                          (255 * 0.15 * pulse).toInt()),
                                      blurRadius: 15 + 10 * pulse,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        Transform.scale(
                          scale: bodyScale,
                          child: Container(
                            width: widget.size,
                            height: widget.size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                center: const Alignment(-0.3, -0.3),
                                radius: 0.8,
                                colors: [
                                  const Color(0xFFFFFFFF)
                                      .withAlpha((255 * 0.9).toInt()),
                                  const Color(0xFFFFE4F5)
                                      .withAlpha((255 * 0.7).toInt()),
                                  const Color(0xFFFFB1EE)
                                      .withAlpha((255 * enhancedGlow).toInt()),
                                  const Color(0xFFFF69B4)
                                      .withAlpha((255 * 0.3).toInt()),
                                ],
                                stops: const [0.0, 0.4, 0.7, 1.0],
                              ),
                              boxShadow: widget.showShadow
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFFFB1EE)
                                            .withAlpha((255 *
                                                    (0.3 + enhancedGlow * 0.3))
                                                .toInt()),
                                        blurRadius:
                                            30 + (enhancedGlow * 15),
                                        spreadRadius:
                                            5 + (enhancedGlow * 10),
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFFFFFFFF)
                                            .withAlpha((255 * 0.3).toInt()),
                                        blurRadius: 50,
                                        spreadRadius: -5,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: ClipOval(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                    sigmaX: 2, sigmaY: 2),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      center: const Alignment(-0.2, -0.2),
                                      radius: 0.6,
                                      colors: [
                                        Colors.transparent,
                                        Colors.white
                                            .withAlpha((255 * 0.1).toInt()),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.white
                                          .withAlpha((255 * 0.5).toInt()),
                                      width: context.r.scale(2),
                                    ),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Positioned(
                                        top: widget.size * 0.18,
                                        left: widget.size * 0.21,
                                        child: Container(
                                          width: widget.size * 0.14,
                                          height: widget.size * 0.086,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    widget.size * 0.043),
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.white.withAlpha(
                                                    (255 * 0.8).toInt()),
                                                Colors.white.withAlpha(0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: widget.size * 0.25,
                                        left: widget.size * 0.18,
                                        child: Container(
                                          width: widget.size * 0.057,
                                          height: widget.size * 0.057,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white.withAlpha(
                                                (255 * 0.6).toInt()),
                                          ),
                                        ),
                                      ),
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              AnimatedBuilder(
                                                animation: _blinkController,
                                                builder:
                                                    (context, child) {
                                                  double scaleY;
                                                  if (state ==
                                                      OrbState.thinking) {
                                                    scaleY = 0.5;
                                                  } else {
                                                    scaleY = 1.0 -
                                                        (_blinkController
                                                                .value *
                                                            0.9);
                                                  }
                                                  return Transform.scale(
                                                    scaleY: scaleY,
                                                    child: Container(
                                                      width:
                                                          widget.size * 0.1,
                                                      height:
                                                          widget.size * 0.1,
                                                      decoration:
                                                          BoxDecoration(
                                                        shape:
                                                            BoxShape.circle,
                                                        color: const Color(
                                                                0xFF2D1B2E)
                                                            .withAlpha((255 *
                                                                    0.7)
                                                                .toInt()),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors
                                                                .white
                                                                .withAlpha(
                                                                    (255 *
                                                                            0.5)
                                                                        .toInt()),
                                                            blurRadius: 4,
                                                            spreadRadius: 1,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                              SizedBox(
                                                  width:
                                                      widget.size * 0.14),
                                              AnimatedBuilder(
                                                animation: _blinkController,
                                                builder:
                                                    (context, child) {
                                                  double scaleY;
                                                  if (state ==
                                                      OrbState.thinking) {
                                                    scaleY = 0.5;
                                                  } else {
                                                    scaleY = 1.0 -
                                                        (_blinkController
                                                                .value *
                                                            0.9);
                                                  }
                                                  return Transform.scale(
                                                    scaleY: scaleY,
                                                    child: Container(
                                                      width:
                                                          widget.size * 0.1,
                                                      height:
                                                          widget.size * 0.1,
                                                      decoration:
                                                          BoxDecoration(
                                                        shape:
                                                            BoxShape.circle,
                                                        color: const Color(
                                                                0xFF2D1B2E)
                                                            .withAlpha((255 *
                                                                    0.7)
                                                                .toInt()),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors
                                                                .white
                                                                .withAlpha(
                                                                    (255 *
                                                                            0.5)
                                                                        .toInt()),
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
                                          SizedBox(
                                              height:
                                                  widget.size * 0.11),
                                          if (state == OrbState.thinking)
                                            CustomPaint(
                                              size: Size(
                                                  widget.size * 0.12,
                                                  widget.size * 0.04),
                                              painter: _WavePainter(
                                                color: const Color(
                                                        0xFF2D1B2E)
                                                    .withAlpha(
                                                        (255 * 0.6)
                                                            .toInt()),
                                              ),
                                            )
                                          else if (widget
                                                      .showTalkingAnimation ||
                                                  widget.isTalking ==
                                                      true)
                                            AnimatedBuilder(
                                              animation:
                                                  _mouthController,
                                              builder:
                                                  (context, child) {
                                                final openAmount =
                                                    _mouthController
                                                        .value;

                                                final mouthHeight =
                                                    widget.size *
                                                        (0.029 +
                                                            openAmount *
                                                                0.043);
                                                final mouthWidth =
                                                    widget.size *
                                                        (0.157 -
                                                            openAmount *
                                                                0.029);
                                                const mouthOpacity =
                                                    0.6;
                                                final topRadius = 4.0 +
                                                    openAmount * 4.0;

                                                return Container(
                                                  width: mouthWidth,
                                                  height: mouthHeight,
                                                  decoration:
                                                      BoxDecoration(
                                                    color: const Color(
                                                            0xFF2D1B2E)
                                                        .withAlpha(
                                                            (255 *
                                                                    mouthOpacity)
                                                                .toInt()),
                                                    borderRadius:
                                                        BorderRadius
                                                            .only(
                                                      bottomLeft:
                                                          const Radius
                                                              .circular(
                                                              12),
                                                      bottomRight:
                                                          const Radius
                                                              .circular(
                                                              12),
                                                      topLeft: Radius
                                                          .circular(
                                                              topRadius),
                                                      topRight:
                                                          Radius.circular(
                                                              topRadius),
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                          else
                                            Container(
                                              width:
                                                  widget.size * 0.157,
                                              height:
                                                  widget.size * 0.029,
                                              decoration:
                                                  BoxDecoration(
                                                color: const Color(
                                                        0xFF2D1B2E)
                                                    .withAlpha(
                                                        (255 * 0.6)
                                                            .toInt()),
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(12),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          );
        }),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final Color color;

  _WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final h = size.height / 2;
    final amp = size.height * 0.35;

    for (double x = 0; x <= size.width; x++) {
      final y = h + amp * math.sin((x / size.width) * 2 * math.pi);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => oldDelegate.color != color;
}
