import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AnimationManager extends GetxService {
  Path buildArcPath(Offset src, Offset dst) {
    final Path path = Path();
    path.moveTo(src.dx, src.dy);

    final controlPoint = Offset(
      (src.dx + dst.dx) / 2,
      min(src.dy, dst.dy) - 120.0,
    );

    path.quadraticBezierTo(
      controlPoint.dx,
      controlPoint.dy,
      dst.dx,
      dst.dy,
    );
    return path;
  }
}
