import 'package:flutter/material.dart';

/// ════════════════════════════════════════════════════════════════════════════════
/// BLINKING BADGE WIDGET
/// Shows unread message count with blinking animation
/// Tapping triggers the message queue reveal callback
/// ════════════════════════════════════════════════════════════════════════════════
class BlinkingBadge extends StatefulWidget {
  final int count;
  final VoidCallback onTap;
  final Color? blinkColor;
  final Color? backgroundColor;

  const BlinkingBadge({
    super.key,
    required this.count,
    required this.onTap,
    this.blinkColor,
    this.backgroundColor,
  });

  @override
  State<BlinkingBadge> createState() => _BlinkingBadgeState();
}

class _BlinkingBadgeState extends State<BlinkingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // Create blinking animation - alternates between opaque and transparent
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: -8,
      top: -8,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _opacityAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (widget.backgroundColor ?? Colors.red)
                          .withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                child: Center(
                  child: Text(
                    '${widget.count}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// ════════════════════════════════════════════════════════════════════════════════
/// WELCOME MESSAGE WITH BADGE
/// Wraps the first welcome message with a tappable badge
/// ════════════════════════════════════════════════════════════════════════════════
class WelcomeMessageWithBadge extends StatelessWidget {
  final String messageContent;
  final int badgeCount;
  final VoidCallback onBadgeTap;
  final bool showBadge;

  const WelcomeMessageWithBadge({
    super.key,
    required this.messageContent,
    required this.badgeCount,
    required this.onBadgeTap,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Welcome message bubble
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2D3748),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.blueAccent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            messageContent,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
        // Blinking badge
        if (showBadge && badgeCount > 0)
          BlinkingBadge(
            count: badgeCount,
            onTap: onBadgeTap,
            backgroundColor: Colors.amber.shade600,
            blinkColor: Colors.amber.shade400,
          ),
      ],
    );
  }
}
