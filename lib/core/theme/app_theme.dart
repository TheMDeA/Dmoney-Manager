import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  // google_fonts 9.x targets the standalone material_ui package, whose
  // TextTheme is a different class from Flutter material's — so we apply
  // the font family onto the material TextTheme instead of using the
  // *TextTheme() helpers (GoogleFonts.inter() itself returns the shared
  // TextStyle class and is safe to use).
  static String get _interFamily => GoogleFonts.inter().fontFamily ?? 'Inter';

  static ThemeData dark() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgBase,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.lime,
        onPrimary: Colors.black,
        secondary: AppColors.violet,
        surface: AppColors.bgSurface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.bgRaised,
        outline: AppColors.hairline,
        error: AppColors.expense,
      ),
      textTheme: base.textTheme.apply(fontFamily: _interFamily),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.lime,
        foregroundColor: Colors.black,
        shape: CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dividerTheme: const DividerThemeData(color: AppColors.hairline, thickness: 1),
    );
  }

  static ThemeData light() {
    final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brandBlue,
        onPrimary: Colors.white,
        secondary: AppColors.violet,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightInk,
        surfaceContainerHighest: AppColors.lightRaised,
        outline: AppColors.lightHairline,
        error: AppColors.expense,
      ),
      textTheme: base.textTheme.apply(fontFamily: _interFamily),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.brandBlue,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      dividerTheme: const DividerThemeData(color: AppColors.lightHairline, thickness: 1),
    );
  }
}
