import 'dart:math' as math;
import 'package:flutter/material.dart';

class RecordingIndicatorAnimation extends StatefulWidget {
  final Color color;
  final Duration cycleDuration;
  final int dotCount;

  const RecordingIndicatorAnimation({
    super.key,
    required this.color,
    this.cycleDuration = const Duration(milliseconds: 600),
    this.dotCount = 6,
  });

  @override
  State<RecordingIndicatorAnimation> createState() =>
      _RecordingIndicatorAnimationState();
}

class _RecordingIndicatorAnimationState
    extends State<RecordingIndicatorAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.cycleDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi * 0.5,
          child: SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: List.generate(widget.dotCount, (index) {
                final phase = (index / widget.dotCount) * 2 * math.pi;
                final scale = 0.6 +
                    0.4 * math.sin(_controller.value * 2 * math.pi + phase);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withValues(alpha: 0.4 + scale * 0.4),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.3),
                          blurRadius: 4 * scale,
                          spreadRadius: 1 * scale,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
