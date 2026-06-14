import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

bool get isLowEndDevice {
  if (kIsWeb) return false;
  return _isLowEnd();
}

bool _isLowEnd() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return true;
  }
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return false;
  }
  return false;
}

class AdaptiveGlass extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final Color? fallbackColor;
  final EdgeInsetsGeometry? padding;
  final Border? border;
  final BorderRadiusGeometry? borderRadius;
  final List<BoxShadow>? boxShadow;

  const AdaptiveGlass({
    super.key,
    required this.child,
    this.blurSigma = 16,
    this.fallbackColor,
    this.padding,
    this.border,
    this.borderRadius,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    if (isLowEndDevice) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: fallbackColor ?? Colors.white.withAlpha(60),
          borderRadius: borderRadius ?? BorderRadius.circular(20),
          border: border ?? Border.all(color: Colors.white.withAlpha(80), width: 1),
          boxShadow: boxShadow,
        ),
        child: child,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          border: border ?? Border.all(color: Colors.white.withAlpha(80), width: 1),
          borderRadius: borderRadius,
          boxShadow: boxShadow,
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: fallbackColor ?? Colors.white.withAlpha(60),
              borderRadius: borderRadius,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
