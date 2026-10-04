import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_accents.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  /// Status-bar icon style for a theme brightness: dark icons on light
  /// backgrounds, light icons on dark backgrounds. Colors are left null
  /// so the existing status-bar background is untouched.
  static SystemUiOverlayStyle overlayStyle(Brightness brightness) =>
      brightness == Brightness.dark
          ? const SystemUiOverlayStyle(
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            )
          : const SystemUiOverlayStyle(
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            );
  // google_fonts 9.x targets the standalone material_ui package, whose
  // TextTheme is a different class from Flutter material's — so we apply
  // the font family onto the material TextTheme instead of using the
  // *TextTheme() helpers (GoogleFonts.inter() itself returns the shared
  // TextStyle class and is safe to use).
  static String get _interFamily => GoogleFonts.inter().fontFamily ?? 'Inter';

  /// Tabular numerals across the whole text theme so amounts never jitter
  /// when digits change (e.g. during count-up animations). Only digit
  /// glyphs are affected; prose renders exactly as before.
  static TextTheme _tabular(TextTheme t) {
    TextStyle? f(TextStyle? s) => s?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    return TextTheme(
      displayLarge: f(t.displayLarge),
      displayMedium: f(t.displayMedium),
      displaySmall: f(t.displaySmall),
      headlineLarge: f(t.headlineLarge),
      headlineMedium: f(t.headlineMedium),
      headlineSmall: f(t.headlineSmall),
      titleLarge: f(t.titleLarge),
      titleMedium: f(t.titleMedium),
      titleSmall: f(t.titleSmall),
      bodyLarge: f(t.bodyLarge),
      bodyMedium: f(t.bodyMedium),
      bodySmall: f(t.bodySmall),
      labelLarge: f(t.labelLarge),
      labelMedium: f(t.labelMedium),
      labelSmall: f(t.labelSmall),
    );
  }

  static ThemeData dark(Color accent) {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgBase,
      colorScheme: ColorScheme.dark(
        primary: accent,
        onPrimary: onAccent(accent),
        secondary: AppColors.violet,
        surface: AppColors.bgSurface,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textMuted,
        surfaceContainerHighest: AppColors.bgRaised,
        outline: AppColors.hairline,
        error: AppColors.expense,
      ),
      textTheme: _tabular(base.textTheme.apply(fontFamily: _interFamily)),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        systemOverlayStyle: overlayStyle(Brightness.dark),
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
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent(accent),
        shape: const CircleBorder(),
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

  static ThemeData light(Color accent) {
    final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: ColorScheme.light(
        primary: accent,
        onPrimary: onAccent(accent),
        secondary: AppColors.violet,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightInk,
        onSurfaceVariant: AppColors.lightMuted,
        surfaceContainerHighest: AppColors.lightRaised,
        outline: AppColors.lightHairline,
        error: AppColors.expense,
      ),
      textTheme: _tabular(base.textTheme.apply(fontFamily: _interFamily)),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        systemOverlayStyle: overlayStyle(Brightness.light),
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
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent(accent),
        shape: const CircleBorder(),
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
