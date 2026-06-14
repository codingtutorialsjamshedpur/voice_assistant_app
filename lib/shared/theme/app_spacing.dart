import 'package:flutter/material.dart';
import 'responsive.dart';

class AppSpacing {
  static double xs(BuildContext ctx) => ctx.r.scale(4);
  static double sm(BuildContext ctx) => ctx.r.scale(8);
  static double md(BuildContext ctx) => ctx.r.scale(16);
  static double lg(BuildContext ctx) => ctx.r.scale(24);
  static double xl(BuildContext ctx) => ctx.r.scale(32);
  static double xxl(BuildContext ctx) => ctx.r.scale(48);
  static double xxxl(BuildContext ctx) => ctx.r.scale(64);

  static double cardPadding(BuildContext ctx) => ctx.r.scale(16);
  static double cardRadius(BuildContext ctx) => ctx.r.scale(20);
  static double inputRadius(BuildContext ctx) => ctx.r.scale(14);
  static double buttonRadius(BuildContext ctx) => ctx.r.scale(28);
  static double chipRadius(BuildContext ctx) => ctx.r.scale(20);
  static double screenPadding(BuildContext ctx) => ctx.r.scale(16);
  static double sectionGap(BuildContext ctx) => ctx.r.scale(24);
  static double itemGap(BuildContext ctx) => ctx.r.scale(12);
}
