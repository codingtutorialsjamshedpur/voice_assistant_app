import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../controllers/ball_sort_controller.dart';
import '../../../../shared/theme/responsive.dart';
import 'ball_sort_ball_widget.dart';
import 'ball_sort_liquid_widget.dart';

/// One glass tube that holds either colored balls (Ball mode) or
/// liquid segments (Liquid mode).
///
/// Responsibilities:
///   * Renders the glass body with a soft inner highlight.
///   * Lays out balls/liquids from the bottom up.
///   * Flags the top-most ball/liquid as "isTop" so the ball widget
///     can apply the pulsing move-cue glow.
///   * Drives the **idle anticipation** animation: when the player
///     hasn't interacted for a few seconds, every ball gently lifts
///     ~2 px and settles back, with a per-tube phase offset so the
///     tubes feel alive but uncoordinated.
class BallSortTubeWidget extends StatefulWidget {
  final int tubeIndex;
  final Tube tube;
  final double ballDiameter;
  final bool isSelected;
  final bool isHintSource;
  final bool isHintDest;
  final bool isCompleted;
  final int hideTopBalls;
  final VoidCallback onTap;

  const BallSortTubeWidget({
    super.key,
    required this.tubeIndex,
    required this.tube,
    required this.ballDiameter,
    required this.isSelected,
    required this.isHintSource,
    required this.isHintDest,
    required this.isCompleted,
    this.hideTopBalls = 0,
    required this.onTap,
  });

  @override
  State<BallSortTubeWidget> createState() => _BallSortTubeWidgetState();
}

class _BallSortTubeWidgetState extends State<BallSortTubeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anticipation;
  Worker? _interactionWorker;
  bool _userIdle = false;

  @override
  void initState() {
    super.initState();
    _anticipation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _anticipation.addListener(_onTick);

    // Watch the controller for interaction signals so we can fade the
    // anticipation in only after the player has been idle a moment.
    if (Get.isRegistered<BallSortController>()) {
      final c = Get.find<BallSortController>();
      _interactionWorker = ever<int>(c.lastInteractionMs, (_) {
        _userIdle = false;
        _anticipation.value = 0;
      });
    }
  }

  void _onTick() {
    if (!mounted) return;
    // Pull the latest "last interaction" timestamp every frame; once
    // we cross the idle threshold, allow the anticipation to play.
    if (Get.isRegistered<BallSortController>()) {
      final last = Get.find<BallSortController>().lastInteractionMs.value;
      final now = DateTime.now().millisecondsSinceEpoch;
      _userIdle = (now - last) > 3500;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _anticipation.removeListener(_onTick);
    _anticipation.dispose();
    _interactionWorker?.dispose();
    super.dispose();
  }

  double _anticipationOffset() {
    if (!_userIdle) return 0;
    // Per-tube phase offset so tubes don't all move in lock-step.
    final phase = (widget.tubeIndex * 0.45) % (2 * pi);
    final v = sin((_anticipation.value * 2 * pi) + phase);
    // Amplitude is intentionally tiny (≤ 2 px) — adds life, not noise.
    return v * widget.ballDiameter * 0.08;
  }

  @override
  Widget build(BuildContext context) {
    final tubeHeight = widget.ballDiameter * 4.8;
    final tubeWidth = widget.ballDiameter * 1.6;
    final isLiquidMode = Get.find<BallSortController>().isLiquidMode;

    final tubeColor = _resolveTubeColor();
    final glowColor = _resolveGlowColor();

    return GestureDetector(
      onTap: widget.onTap,
      child: RepaintBoundary(
        child: Container(
          width: tubeWidth,
          height: tubeHeight,
          decoration: BoxDecoration(
            // Glass tube body: subtle inner gradient + soft edge.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.04),
                Colors.white.withValues(alpha: 0.10),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(
                  isLiquidMode ? widget.ballDiameter * 0.4 : widget.ballDiameter * 0.8),
              bottomRight: Radius.circular(
                  isLiquidMode ? widget.ballDiameter * 0.4 : widget.ballDiameter * 0.8),
              topLeft: Radius.circular(widget.ballDiameter * 0.15),
              topRight: Radius.circular(widget.ballDiameter * 0.15),
            ),
            border: Border.all(
              color: glowColor ??
                  (widget.isSelected
                      ? const Color(0xFF6C63FF)
                      : Colors.white.withValues(alpha: 0.3)),
              width: widget.isSelected || widget.isHintSource || widget.isHintDest
                  ? context.r.scale(2.0)
                  : context.r.scale(1.2),
            ),
            boxShadow: glowColor != null
                ? [
                    BoxShadow(
                      color: glowColor,
                      blurRadius: 22,
                      spreadRadius: 3,
                    ),
                  ]
                : (widget.isSelected
                    ? [
                        const BoxShadow(
                          color: Color(0x666C63FF),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ]
                    : null),
          ),
          child: Stack(
            children: [
              // Inner glass highlight (left vertical stripe).
              Positioned(
                top: tubeHeight * 0.05,
                bottom: tubeHeight * 0.05,
                left: widget.ballDiameter * 0.18,
                child: Container(
                  width: context.r.scale(2.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(context.r.scale(2)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.35),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // The actual contents: balls or liquid.
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.ballDiameter *
                      (isLiquidMode ? 0.05 : 0.15),
                  vertical:
                      widget.ballDiameter * (isLiquidMode ? 0.05 : 0.3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: _buildContents(isLiquidMode, tubeColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color? _resolveGlowColor() {
    if (widget.isCompleted) {
      final ballColor = widget.tube.balls.isNotEmpty
          ? BallColor.palette[widget.tube.balls.first] ?? Colors.white
          : Colors.white;
      return ballColor.withValues(alpha: 0.45);
    }
    return null;
  }

  Color _resolveTubeColor() {
    if (widget.tube.balls.isEmpty) return Colors.white;
    final key = widget.tube.balls.last;
    return BallColor.palette[key] ?? Colors.white;
  }

  List<Widget> _buildContents(bool isLiquidMode, Color tubeColor) {
    final offset = _anticipationOffset();
    final topIndex = widget.tube.balls.length - 1;
    final hiddenCount = widget.hideTopBalls.clamp(0, widget.tube.balls.length);
    return List<Widget>.generate(widget.tube.capacity, (i) {
      final ballIdx = widget.tube.capacity - 1 - i;
      final isHiddenTop = ballIdx >= (widget.tube.balls.length - hiddenCount);
      final hasBall = ballIdx < widget.tube.balls.length && !isHiddenTop;
      final colorKey = hasBall ? widget.tube.balls[ballIdx] : null;
      final color = colorKey != null
          ? (BallColor.palette[colorKey] ?? Colors.transparent)
          : Colors.transparent;
      final isTop = hasBall && ballIdx == topIndex && hiddenCount == 0;

      if (!hasBall) {
        // Reserve the slot so balls always sit at the bottom of the tube.
        return SizedBox(
          width: widget.ballDiameter,
          height: widget.ballDiameter,
        );
      }

      Widget child = isLiquidMode
          ? _buildLiquidSegment(color, isTop)
          : _buildBall(color, isTop);

      if (offset != 0) {
        child = Transform.translate(
          offset: Offset(0, -offset),
          child: child,
        );
      }
      return child;
    });
  }

  Widget _buildBall(Color color, bool isTop) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.ballDiameter * 0.04),
      child: BallSortBallWidget(
        ballColor: color,
        ballDiameter: widget.ballDiameter,
        isTopBall: isTop,
      ),
    );
  }

  Widget _buildLiquidSegment(Color color, bool isTop) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.ballDiameter * 0.025),
      child: LiquidSegment(
        color: color,
        width: widget.ballDiameter * 0.95,
        height: widget.ballDiameter * 0.95,
        isTopmost: isTop,
        phase: (widget.tubeIndex * 0.7) % (2 * pi),
      ),
    );
  }
}
