import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Expressive display type (Space Grotesk) for balances and headers,
/// tabular numerals everywhere money is shown.
abstract final class AppTextStyles {
  static TextStyle get displayBalance => GoogleFonts.spaceGrotesk(
        fontSize: 44,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get displaySection => GoogleFonts.spaceGrotesk(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      );

  static TextStyle amount({double size = 16, FontWeight weight = FontWeight.w600}) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
