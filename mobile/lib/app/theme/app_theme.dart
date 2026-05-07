import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

class AppTheme {
  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary500,
      onPrimary: Colors.white,
      secondary: AppColors.secondary500,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    final textTheme = _textTheme(base.textTheme, Brightness.light);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkRipple.splashFactory,
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s20,
          vertical: 18,
        ),
        labelStyle: textTheme.labelLarge?.copyWith(color: AppColors.label),
        hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.label),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.primary500, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: Colors.white,
          backgroundColor: AppColors.primary500,
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: AppColors.secondary500,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.secondary500,
          textStyle: textTheme.labelLarge,
        ),
      ),
      dividerColor: AppColors.border,
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary500;
          }
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary500,
      onPrimary: Colors.white,
      secondary: AppColors.secondary500,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.darkSurface,
      onSurface: Colors.white,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    final textTheme = _textTheme(base.textTheme, Brightness.dark);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.primary500, width: 1.5),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, Brightness brightness) {
    final bodyColor = brightness == Brightness.light
        ? AppColors.textPrimary
        : Colors.white;
    final secondaryColor = brightness == Brightness.light
        ? AppColors.textSecondary
        : AppColors.darkTextSecondary;

    return GoogleFonts.beVietnamProTextTheme(base).copyWith(
      headlineLarge: GoogleFonts.beVietnamPro(
        fontSize: 32,
        height: 1.18,
        fontWeight: FontWeight.w700,
        color: bodyColor,
      ),
      headlineMedium: GoogleFonts.beVietnamPro(
        fontSize: 28,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: bodyColor,
      ),
      headlineSmall: GoogleFonts.beVietnamPro(
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: bodyColor,
      ),
      titleLarge: GoogleFonts.beVietnamPro(
        fontSize: 20,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: bodyColor,
      ),
      titleMedium: GoogleFonts.beVietnamPro(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: bodyColor,
      ),
      bodyLarge: GoogleFonts.beVietnamPro(
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: bodyColor,
      ),
      bodyMedium: GoogleFonts.beVietnamPro(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
      ),
      bodySmall: GoogleFonts.beVietnamPro(
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: secondaryColor,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: brightness == Brightness.light
            ? AppColors.label
            : AppColors.darkTextSecondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: secondaryColor,
      ),
    );
  }
}
