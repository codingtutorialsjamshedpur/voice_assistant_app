import 'package:flutter/material.dart';

/// Cloud Painter
/// Creates a soft cloud shape for the thought bubble background
class CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Glassmorphic background color - subtle white with low alpha
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    // Glowing border/shadow paint
    final shadowPaint = Paint()
      ..color = const Color(0xFFFFB2EE).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final path = buildCloudPath(size);

    // Draw soft glow behind cloud
    canvas.drawPath(path, shadowPaint);
    // Draw semi-transparent cloud body
    canvas.drawPath(path, paint);

    // Optional: Add a subtle highlight border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  static Path buildCloudPath(Size s) {
    final path = Path();
    final w = s.width;
    final h = s.height;

    // Main central body to fill gaps
    path.addOval(Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.45),
      width: w * 0.7,
      height: h * 0.7,
    ));

    // Top left bubble
    path.addOval(Rect.fromCenter(
      center: Offset(w * 0.28, h * 0.3),
      width: w * 0.45,
      height: h * 0.45,
    ));

    // Top right bubble
    path.addOval(Rect.fromCenter(
      center: Offset(w * 0.72, h * 0.3),
      width: w * 0.45,
      height: h * 0.45,
    ));

    // Left bubble
    path.addOval(Rect.fromCenter(
      center: Offset(w * 0.18, h * 0.55),
      width: w * 0.35,
      height: h * 0.35,
    ));

    // Right bubble
    path.addOval(Rect.fromCenter(
      center: Offset(w * 0.82, h * 0.55),
      width: w * 0.35,
      height: h * 0.35,
    ));

    // Bottom center bubble
    path.addOval(Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.75),
      width: w * 0.5,
      height: h * 0.35,
    ));

    // Bottom left bubble
    path.addOval(Rect.fromCenter(
      center: Offset(w * 0.32, h * 0.70),
      width: w * 0.35,
      height: h * 0.35,
    ));

    // Bottom right bubble
    path.addOval(Rect.fromCenter(
      center: Offset(w * 0.68, h * 0.70),
      width: w * 0.35,
      height: h * 0.35,
    ));

    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cloud Clipper for glassmorphism
/// Used with BackdropFilter to apply blur only within the cloud shape
class CloudClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return CloudPainter.buildCloudPath(size);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
