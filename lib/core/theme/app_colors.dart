import 'package:flutter/material.dart';

/// UbuntuID brand palette.
///
/// Inspired by South African public-sector visual conventions (green, white,
/// black/charcoal, gold) but original to UbuntuID: this is not a
/// reproduction of any government department's branding or the National
/// Coat of Arms.
class AppColors {
  AppColors._();

  // Brand
  static const Color green = Color(0xFF00723F);
  static const Color greenDark = Color(0xFF00512C);
  static const Color greenLight = Color(0xFFE3F3E9);
  static const Color gold = Color(0xFFC9962C);
  static const Color goldLight = Color(0xFFF7ECD6);

  // Neutrals (light)
  static const Color charcoal = Color(0xFF1B1F1D);
  static const Color charcoalMuted = Color(0xFF54615B);
  static const Color background = Color(0xFFFAFAF8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F3F1);
  static const Color border = Color(0xFFDCE1DD);

  // Neutrals (dark)
  static const Color backgroundDark = Color(0xFF10130F);
  static const Color surfaceDark = Color(0xFF191D19);
  static const Color surfaceMutedDark = Color(0xFF222722);
  static const Color borderDark = Color(0xFF323831);

  // Status
  static const Color success = Color(0xFF1E7B45);
  static const Color successBg = Color(0xFFE4F3E9);
  static const Color warning = Color(0xFFA8720E);
  static const Color warningBg = Color(0xFFFBF0DA);
  static const Color error = Color(0xFFB3261E);
  static const Color errorBg = Color(0xFFFBE9E8);
  static const Color info = Color(0xFF1E5FA8);
  static const Color infoBg = Color(0xFFE7F0FA);
  static const Color neutral = Color(0xFF54615B);
  static const Color neutralBg = Color(0xFFEEF0EE);
}
