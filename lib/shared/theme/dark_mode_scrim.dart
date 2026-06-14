import 'package:flutter/material.dart';

class DarkModeScrim extends StatelessWidget {
  final Widget child;
  final double opacity;

  const DarkModeScrim({
    super.key,
    required this.child,
    this.opacity = 0.2,
  });

  static const defaultScrim = Color(0x33000000);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return child;

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Container(
            color: Colors.black.withAlpha((opacity * 255).round()),
          ),
        ),
      ],
    );
  }
}

class TextWithScrim extends StatelessWidget {
  final Widget child;
  final double scrimOpacity;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;

  const TextWithScrim({
    super.key,
    required this.child,
    this.scrimOpacity = 0.2,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return child;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      child: Container(
        padding: padding ?? const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha((scrimOpacity * 255).round()),
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
  }
}
