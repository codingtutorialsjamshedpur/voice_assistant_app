import 'package:flutter/material.dart';

/// Dotted Connector Painter
/// Draws animated dotted line from orb to thought bubble
class DottedConnectorPainter extends CustomPainter {
  final Offset start; // bottom-left of bubble
  final Offset end; // top-right of orb

  DottedConnectorPainter({required this.start, required this.end});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFB2EE).withValues(alpha: 0.7)
      ..strokeWidth = 2
      ..style = PaintingStyle.fill;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = (end - start).distance;
    const dotSpacing = 10.0;
    final steps = (distance / dotSpacing).floor();

    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = start.dx + dx * t;
      final y = start.dy + dy * t;
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DottedConnectorPainter old) =>
      old.start != start || old.end != end;
}
