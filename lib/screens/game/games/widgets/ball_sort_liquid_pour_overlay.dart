import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../controllers/ball_sort_controller.dart';
import 'ball_sort_liquid_widget.dart';

/// Realistic liquid-pour transfer animation used in Liquid Sort levels.
///
/// 8-stage sequence over `duration` (default 1.8 s):
///
///   0.00 – 0.11  Lift
///   0.11 – 0.22  Move toward destination
///   0.22 – 0.36  Tilt (0° → 55°)
///   0.36 – 0.58  Pour (stream visible, destination fill grows,
///                 source top segment drains)
///   0.58 – 0.69  Untilt (55° → 0°)
///   0.69 – 0.81  Move back
///   0.81 – 1.00  Descend to rest
///
/// The destination tube is not transformed; the source tube is rendered
/// as a transformed copy that lifts, slides, tilts, and returns. While
/// the source tube is in motion, the [BallSortBoardWidget] hides the
/// in-place source tube via `Opacity(0)` so there is no double-render.

double _easeInOut(double t) {
  return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3).toDouble() / 2;
}

double _phase(double t, double start, double end) {
  if (t <= start) return 0;
  if (t >= end) return 1;
  return _easeInOut((t - start) / (end - start));
}

/// Paints the visible liquid stream between source rim and destination
/// top during the Pour phase.
class _PourPainter extends CustomPainter {
  final double progress;
  final Rect sourceRect;
  final Rect destRect;
  final Color liquidColor;

  _PourPainter({
    required this.progress,
    required this.sourceRect,
    required this.destRect,
    required this.liquidColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.36 || progress > 0.58) return;

    final srcCenterX = sourceRect.center.dx;
    final srcTopY = sourceRect.top;
    final dstCenterX = destRect.center.dx;
    final dstTopY = destRect.top;

    final tiltRight = dstCenterX >= srcCenterX;
    final lipOffset = sourceRect.width * 0.32;
    final lipX = tiltRight ? srcCenterX + lipOffset : srcCenterX - lipOffset;
    final lipY = srcTopY + sourceRect.height * 0.05;

    final controlX = (lipX + dstCenterX) / 2;
    final controlY = math.max(lipY, dstTopY) + 60;

    final streamPath = Path()
      ..moveTo(lipX - 3, lipY)
      ..quadraticBezierTo(controlX, controlY, dstCenterX, dstTopY)
      ..lineTo(dstCenterX + 3, dstTopY)
      ..quadraticBezierTo(controlX, controlY, lipX + 3, lipY)
      ..close();

    final streamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          liquidColor.withValues(alpha: 0.55),
          liquidColor.withValues(alpha: 0.85),
        ],
      ).createShader(streamPath.getBounds());

    canvas.drawPath(streamPath, streamPaint);

    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawPath(streamPath, highlight);
  }

  @override
  bool shouldRepaint(covariant _PourPainter old) =>
      old.progress != progress ||
      old.sourceRect != sourceRect ||
      old.destRect != destRect ||
      old.liquidColor != liquidColor;
}

/// Source-tube body used inside the pour overlay. Renders the tube
/// (with the top N segments hidden so the destination fill can take
/// over) and is then transformed (lift / move / tilt / return) by
/// the parent [BallSortLiquidPour].
class _PouringSourceTube extends StatelessWidget {
  final List<String> sourceBalls;
  final int sourceCapacity;
  final double ballDiameter;
  final int hideTopBalls;

  const _PouringSourceTube({
    required this.sourceBalls,
    required this.sourceCapacity,
    required this.ballDiameter,
    required this.hideTopBalls,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.04),
            Colors.white.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(ballDiameter * 0.4),
          bottomRight: Radius.circular(ballDiameter * 0.4),
          topLeft: Radius.circular(ballDiameter * 0.15),
          topRight: Radius.circular(ballDiameter * 0.15),
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ballDiameter * 0.05,
              vertical: ballDiameter * 0.05,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: List<Widget>.generate(sourceCapacity, (i) {
                final ballIdx = sourceCapacity - 1 - i;
                final hidden =
                    ballIdx >= (sourceBalls.length - hideTopBalls);
                final hasBall = ballIdx < sourceBalls.length && !hidden;
                if (!hasBall) {
                  return SizedBox(
                    width: ballDiameter,
                    height: ballDiameter,
                  );
                }
                final color = BallColor.palette[sourceBalls[ballIdx]] ??
                    Colors.transparent;
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: ballDiameter * 0.025),
                  child: LiquidSegment(
                    color: color,
                    width: ballDiameter * 0.95,
                    height: ballDiameter * 0.95,
                    isTopmost: false,
                    phase: 0,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rising liquid column that animates 0 → N segments as the source pours.
class _DestinationFill extends StatelessWidget {
  final String colorKey;
  final double ballDiameter;
  final int segments;
  const _DestinationFill({
    required this.colorKey,
    required this.ballDiameter,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    final color = BallColor.palette[colorKey] ?? Colors.cyan;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: List<Widget>.generate(segments, (_) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: ballDiameter * 0.025),
          child: LiquidSegment(
            color: color,
            width: ballDiameter * 0.95,
            height: ballDiameter * 0.95,
            isTopmost: true,
            phase: 0,
          ),
        );
      }),
    );
  }
}

/// Full overlay widget used by the board during a liquid pour.
class BallSortLiquidPour extends StatefulWidget {
  final Rect sourceRect;
  final Rect destRect;
  final List<String> sourceBalls;
  final int sourceCapacity;
  final List<String> destBalls;
  final int destCapacity;
  final int segmentsToPour;
  final String liquidColorKey;
  final double ballDiameter;
  final Duration duration;
  final VoidCallback onComplete;

  const BallSortLiquidPour({
    super.key,
    required this.sourceRect,
    required this.destRect,
    required this.sourceBalls,
    required this.sourceCapacity,
    required this.destBalls,
    required this.destCapacity,
    required this.segmentsToPour,
    required this.liquidColorKey,
    required this.ballDiameter,
    this.duration = const Duration(milliseconds: 1800),
    required this.onComplete,
  });

  @override
  State<BallSortLiquidPour> createState() => _BallSortLiquidPourState();
}

class _BallSortLiquidPourState extends State<BallSortLiquidPour>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete();
        }
      })
      ..forward();
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.linear);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final t = _progress.value;

        final lift = _phase(t, 0.0, 0.11);
        final move = _phase(t, 0.11, 0.22);
        final tilt = _phase(t, 0.22, 0.36);
        final pourFrac = _phase(t, 0.36, 0.58);
        final untilt = _phase(t, 0.58, 0.69);
        final moveBack = _phase(t, 0.69, 0.81);
        final descend = _phase(t, 0.81, 1.0);

        final liftDy = -widget.ballDiameter * 0.6 * lift;
        final dx = (widget.destRect.center.dx - widget.sourceRect.center.dx) * move;
        final tiltRight =
            widget.destRect.center.dx >= widget.sourceRect.center.dx;
        final tiltDeg = 55.0 * tilt;
        final untiltDeg = 55.0 * untilt;
        final liveDeg = tiltDeg - untiltDeg;
        final angleRad = (tiltRight ? liveDeg : -liveDeg) * math.pi / 180;

        final backDx =
            (widget.destRect.center.dx - widget.sourceRect.center.dx) *
                moveBack;
        final descendDy = -widget.ballDiameter * 0.6 * (1 - descend);

        final tubeTranslationX = dx - backDx;
        final tubeTranslationY = liftDy + descendDy;

        // Source tube top-segment count to hide.
        final inTiltOrPour = t >= 0.22;
        final pastPour = t >= 0.58;
        int hideTopBalls;
        if (!inTiltOrPour) {
          hideTopBalls = widget.segmentsToPour;
        } else if (pastPour) {
          hideTopBalls = 0;
        } else {
          hideTopBalls =
              (widget.segmentsToPour - (widget.segmentsToPour * pourFrac).round())
                  .clamp(0, widget.segmentsToPour);
        }

        // Destination fill height factor.
        double fillFactor;
        if (t < 0.36) {
          fillFactor = 0;
        } else if (t < 0.58) {
          fillFactor = widget.segmentsToPour == 0
              ? 0
              : (widget.segmentsToPour * pourFrac) / widget.segmentsToPour;
        } else {
          fillFactor = 1.0;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Destination-fill column (clipped to dest rect).
            Positioned(
              left: widget.destRect.left,
              top: widget.destRect.top,
              width: widget.destRect.width,
              height: widget.destRect.height,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: fillFactor,
                  child: _DestinationFill(
                    colorKey: widget.liquidColorKey,
                    ballDiameter: widget.ballDiameter,
                    segments: widget.segmentsToPour,
                  ),
                ),
              ),
            ),
            // Stream painter.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PourPainter(
                    progress: t,
                    sourceRect: widget.sourceRect
                        .shift(Offset(tubeTranslationX, tubeTranslationY)),
                    destRect: widget.destRect,
                    liquidColor:
                        BallColor.palette[widget.liquidColorKey] ?? Colors.cyan,
                  ),
                ),
              ),
            ),
            // Transformed source tube.
            Positioned(
              left: widget.sourceRect.left,
              top: widget.sourceRect.top,
              width: widget.sourceRect.width,
              height: widget.sourceRect.height,
              child: Transform.translate(
                offset: Offset(tubeTranslationX, tubeTranslationY),
                child: Transform.rotate(
                  angle: angleRad,
                  alignment: Alignment.bottomCenter,
                  child: _PouringSourceTube(
                    sourceBalls: widget.sourceBalls,
                    sourceCapacity: widget.sourceCapacity,
                    ballDiameter: widget.ballDiameter,
                    hideTopBalls: hideTopBalls,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
