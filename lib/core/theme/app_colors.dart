import 'package:flutter/material.dart';

/// Design tokens taken from the 2026 dark-first mockup.
abstract final class AppColors {
  // ---- Dark theme surfaces ----
  static const bgBase = Color(0xFF0C0C0C);
  static const bgSurface = Color(0xFF141414);
  static const bgRaised = Color(0xFF1F1F23);
  static const hairline = Color(0xFF2A2A2E);
  static const textPrimary = Color(0xFFF5F5F4);
  static const textMuted = Color(0xFFA1A1AA);

  // ---- Light theme surfaces ----
  static const lightBg = Color(0xFFFAFAF8);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightRaised = Color(0xFFF1EFEA);
  static const lightInk = Color(0xFF101828);
  static const lightMuted = Color(0xFF667085);
  static const lightHairline = Color(0xFFE7E5E0);
  static const brandBlue = Color(0xFF2563EB);

  // ---- Brand accents ----
  static const lime = Color(0xFFC6FF4A);
  static const violet = Color(0xFFA78BFA);

  // ---- Semantics: always paired with a +/- sign or arrow glyph,
  // never conveyed by color alone (colorblind-safe) ----
  static const income = Color(0xFF22C55E);
  static const expense = Color(0xFFF04444);
  static const warning = Color(0xFFF5C518);
}
