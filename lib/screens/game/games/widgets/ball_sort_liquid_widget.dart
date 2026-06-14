import 'dart:math';
import 'package:flutter/material.dart';

/// A single liquid segment filling one slot of a glass tube.
///
/// Visual stack (bottom → top):
///   1. A rounded gradient body that reads as fluid under glass.
///   2. A subtle inner shadow on the bottom edge to suggest weight.
///   3. A shimmering wave surface at the top of the segment that
///      animates gently while the level is on screen.
///   4. A glossy highlight stripe that drifts across the surface.
class LiquidSegment extends StatefulWidget {
  final Color color;
  final double width;
  final double height;
  final bool isTopmost;
  final double phase;

  const LiquidSegment({
    super.key,
    required this.color,
    required this.width,
    required this.height,
    this.isTopmost = false,
    this.phase = 0,
  });

  @override
  State<LiquidSegment> createState() => _LiquidSegmentState();
}

class _LiquidSegmentState extends State<LiquidSegment>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          // Base fluid body with vertical gradient.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _mixWithWhite(widget.color, 0.35),
                    widget.color,
                    _mixWithBlack(widget.color, 0.18),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          // Inner highlight band on the left side (light through glass).
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.18,
                  heightFactor: 0.85,
                  child: Container(
                    margin: const EdgeInsets.only(left: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.width),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.28),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Wave surface on the topmost segment only.
          if (widget.isTopmost)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: widget.height * 0.55,
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) => CustomPaint(
                  painter: _WavePainter(
                    color: widget.color,
                    highlight: _mixWithWhite(widget.color, 0.55),
                    progress: _ctrl.value,
                    phase: widget.phase,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _mixWithWhite(Color c, double t) {
    return Color.lerp(c, Colors.white, t) ?? c;
  }

  Color _mixWithBlack(Color c, double t) {
    return Color.lerp(c, Colors.black, t) ?? c;
  }
}

class _WavePainter extends CustomPainter {
  final Color color;
  final Color highlight;
  final double progress;
  final double phase;

  _WavePainter({
    required this.color,
    required this.highlight,
    required this.progress,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Build the wave path so the fluid surface sways in/out.
    final w = size.width;
    final h = size.height;
    final midY = h * 0.55;
    final amp = h * 0.12;
    final path = Path()..moveTo(0, midY);
    const segments = 24;
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final x = t * w;
      final theta = (t * 2 * pi * 1.4) + (progress * 2 * pi) + phase;
      final y = midY + sin(theta) * amp;
      path.lineTo(x, y);
    }
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    // Underlay gradient (slightly lighter at the top of the wave).
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          highlight,
          color,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, fill);

    // Glossy highlight stripe along the wave crest.
    final crest = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final crestPath = Path()..moveTo(0, midY);
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final x = t * w;
      final theta = (t * 2 * pi * 1.4) + (progress * 2 * pi) + phase;
      final y = midY + sin(theta) * amp - 1.5;
      crestPath.lineTo(x, y);
    }
    canvas.drawPath(crestPath, crest);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.progress != progress || old.phase != phase;
}
