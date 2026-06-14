import 'dart:math' as math;
import 'package:flutter/material.dart';

class ContrastChecker {
  static double relativeLuminance(Color c) {
    final r = _linearize(c.r);
    final g = _linearize(c.g);
    final b = _linearize(c.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static double _linearize(double channel) {
    if (channel <= 0.03928) return channel / 12.92;
    return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  static double contrastRatio(Color fg, Color bg) {
    final l1 = relativeLuminance(fg);
    final l2 = relativeLuminance(bg);
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static bool passesAA(Color fg, Color bg, {bool largeText = false}) {
    return contrastRatio(fg, bg) >= (largeText ? 3.0 : 4.5);
  }

  static String report(Color fg, Color bg, {bool largeText = false}) {
    final ratio = contrastRatio(fg, bg);
    final pass = passesAA(fg, bg, largeText: largeText);
    return '${ratio.toStringAsFixed(2)}:1 — ${pass ? "PASS" : "FAIL"}';
  }
}
