import 'package:flutter/material.dart';

class AppColors {
  static Brightness _brightness(BuildContext c) => Theme.of(c).brightness;

  // Brand Core
  static const primaryPink      = Color(0xFFFFB2EE);
  static const darkPink         = Color(0xFFFF69B4);
  static const deepPurple       = Color(0xFF8B5CF6);
  static const lightPurple      = Color(0xFFB39DDB);

  // Semantic States
  static const success          = Color(0xFF4CAF50);
  static const error            = Color(0xFFE53935);
  static const warning          = Color(0xFFFFB300);
  static const info             = Color(0xFF2196F3);

  // Surface & Background
  static const glassLight       = Color(0x40FFFFFF);
  static const glassDark        = Color(0x1AFFFFFF);
  static const overlayDark      = Color(0x33000000);
  static const overlayLight     = Color(0x66FFFFFF);

  // Text (static constants for direct use)
  static const textPrimaryColor = Color(0xFF230F1F);
  static const textSecondaryColor = Color(0xFF5A3E54);
  static const textTertiaryColor = Color(0xFF9E9E9E);
  static const textOnDark       = Color(0xFFF0E6EE);

  // Nav Bar Themes (per section)
  static const navChat          = Color(0xFF26C6DA);
  static const navGame          = Color(0xFF8B5CF6);
  static const navVoice         = Color(0xFF8B5CF6);
  static const navAlarm         = Color(0xFFFF69B4);
  static const navNaamJaap      = Color(0xFFFF69B4);
  static const navHistory       = Color(0xFF4CAF50);
  static const navSettings      = Color(0xFF4CAF50);

  // ── ORIGINAL ADAPTIVE METHODS (preserved for backward compatibility) ──

  static Color textPrimary(BuildContext c) =>
      _brightness(c) == Brightness.dark
          ? const Color(0xFFF0E6EE)
          : const Color(0xFF230F1F);

  static Color textSecondary(BuildContext c) =>
      _brightness(c) == Brightness.dark
          ? const Color(0xFFCBBEC7)
          : const Color(0xFF5A3E54);

  static Color textTertiary(BuildContext c) =>
      _brightness(c) == Brightness.dark
          ? const Color(0xFF998A95)
          : Colors.grey[600]!;

  static Color iconNeutral(BuildContext c) =>
      _brightness(c) == Brightness.dark
          ? const Color(0xFFB0A0AC)
          : Colors.grey[600]!;

  static Color inputSurface(BuildContext c) =>
      _brightness(c) == Brightness.dark
          ? Colors.black.withAlpha(51)
          : Colors.white.withAlpha(128);

  static Color divider(BuildContext c) =>
      _brightness(c) == Brightness.dark
          ? Colors.white.withAlpha(38)
          : Colors.white.withAlpha(102);
}
