import 'package:flutter/material.dart';
import 'responsive.dart';

class AppTextStyles {
  static TextStyle displayLarge(BuildContext context) =>
      TextStyle(fontSize: context.r.sp(32), fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static TextStyle displayMedium(BuildContext context) =>
      TextStyle(fontSize: context.r.sp(28), fontWeight: FontWeight.w700, letterSpacing: -0.3);
  static TextStyle headlineLarge(BuildContext context) =>
      TextStyle(fontSize: context.r.sp(24), fontWeight: FontWeight.w700);
  static TextStyle headlineMedium(BuildContext context) =>
      TextStyle(fontSize: context.r.sp(20), fontWeight: FontWeight.w600);
  static TextStyle titleLarge(BuildContext context) =>
      TextStyle(fontSize: context.r.sp(18), fontWeight: FontWeight.w600);
  static TextStyle titleMedium(BuildContext context) =>
      TextStyle(fontSize: context.r.sp(16), fontWeight: FontWeight.w600);
  static TextStyle bodyLarge(BuildContext context) =>
      TextStyle(fontSize: context.r.sp(16), fontWeight: FontWeight.w400, height: 1.5);
  static TextStyle bodyMedium(BuildContext context) =>
      TextStyle(fontSize: context.r.sp(14), fontWeight: FontWeight.w400, height: 1.5);
  static TextStyle bodySmall(BuildContext context) =>
      TextStyle(fontSize: context.r.sp(12), fontWeight: FontWeight.w400, height: 1.4);
  static TextStyle labelLarge(BuildContext context) =>
      TextStyle(fontSize: context.r.sp(14), fontWeight: FontWeight.w600, letterSpacing: 0.1);
  static TextStyle labelMedium(BuildContext context) =>
      TextStyle(fontSize: context.r.sp(12), fontWeight: FontWeight.w500, letterSpacing: 0.5);
  static TextStyle labelSmall(BuildContext context) =>
      TextStyle(fontSize: context.r.sp(10), fontWeight: FontWeight.w500, letterSpacing: 0.5);
  static TextStyle caption(BuildContext context) =>
      TextStyle(fontSize: context.r.sp(11), fontWeight: FontWeight.w400, letterSpacing: 0.4);
  static TextStyle sectionHeader(BuildContext context) =>
      TextStyle(fontSize: context.r.sp(11), fontWeight: FontWeight.w700, letterSpacing: 1.2, color: const Color(0xFF9E9E9E));
}
