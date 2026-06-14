import 'package:flutter/material.dart';

/// Premium glassmorphism ball used in Ball-Sort levels 1–20.
///
/// Layers (back to front):
///   * Outer colored glow (boxShadow).
///   * Glass body with a radial gradient (white highlight → color → darker edge).
///   * Inner colored core that suggests depth under the glass.
///   * Glossy crescent highlight at the top-left.
///   * Small specular highlight for the "wet glass" look.
///   * (Top balls only) a brighter pulse + larger outer glow that animates
///     to draw the player's eye to the moveable ball.
class BallSortBallWidget extends StatefulWidget {
  final Color ballColor;
  final double ballDiameter;
  final bool isTopBall;

  const BallSortBallWidget({
    super.key,
    required this.ballColor,
    required this.ballDiameter,
    this.isTopBall = false,
  });

  @override
  State<BallSortBallWidget> createState() => _BallSortBallWidgetState();
}

class _BallSortBallWidgetState extends State<BallSortBallWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.isTopBall) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant BallSortBallWidget old) {
    super.didUpdateWidget(old);
    if (widget.isTopBall && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isTopBall && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.ballDiameter;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        // Pulse adds a gentle "breathing" glow to the top ball.
        final pulse = widget.isTopBall ? _pulse.value : 0.0;
        final outerGlow = 10.0 + 10.0 * pulse;
        final innerGlow = 6.0 + 8.0 * pulse;
        final highlightBoost = 0.06 * pulse;

        return SizedBox(
          width: d,
          height: d,
          child: Stack(
            children: [
              // Glass body with radial gradient.
              Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.32, -0.32),
                    radius: 0.95,
                    colors: [
                      Color.lerp(
                          Colors.white, widget.ballColor, 0.05 + highlightBoost) ??
                          widget.ballColor,
                      widget.ballColor,
                      _darken(widget.ballColor, 0.35),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 0.8,
                  ),
                  boxShadow: [
                    // Outer colored glow.
                    BoxShadow(
                      color: widget.ballColor.withValues(
                          alpha: widget.isTopBall ? 0.55 : 0.40),
                      blurRadius: outerGlow,
                      spreadRadius: widget.isTopBall ? 0.5 + pulse * 0.6 : 0.3,
                      offset: const Offset(0, 3),
                    ),
                    // Tight inner highlight to give the glass body depth.
                    BoxShadow(
                      color: widget.ballColor.withValues(alpha: 0.6),
                      blurRadius: innerGlow,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
              // Inner colored core (sits below the surface for depth).
              Positioned(
                left: d * 0.22,
                top: d * 0.30,
                child: Container(
                  width: d * 0.55,
                  height: d * 0.55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _lighten(widget.ballColor, 0.35),
                        _lighten(widget.ballColor, 0.10),
                        widget.ballColor.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
              // Top-left glossy crescent.
              Positioned(
                left: d * 0.14,
                top: d * 0.10,
                child: Container(
                  width: d * 0.42,
                  height: d * 0.26,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(d),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white
                            .withValues(alpha: 0.85 + highlightBoost * 0.5),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Tiny specular highlight (the "wet" dot).
              Positioned(
                left: d * 0.30,
                top: d * 0.22,
                child: Container(
                  width: d * 0.10,
                  height: d * 0.10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.95),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.7),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _lighten(Color c, double t) =>
      Color.lerp(c, Colors.white, t) ?? c;

  Color _darken(Color c, double t) =>
      Color.lerp(c, Colors.black, t) ?? c;
}
