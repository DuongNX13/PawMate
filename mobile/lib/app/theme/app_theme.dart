import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_text_styles.dart';
import 'app_tokens.dart';

class AppTheme {
  const AppTheme._();

  static const systemUiOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: AppColors.border,
  );

  /// PawMate v0.31 intentionally ships a single light Chocomint theme.
  static ThemeData light() {
    const status = PawMateStatusColors.light;
    final colorScheme =
        const ColorScheme.light(
          primary: AppColors.primary500,
          onPrimary: AppColors.white,
          secondary: AppColors.careGreen,
          onSecondary: AppColors.white,
          error: AppColors.error,
          onError: AppColors.white,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        ).copyWith(
          primaryContainer: AppColors.primarySoft,
          onPrimaryContainer: AppColors.textPrimary,
          secondaryContainer: AppColors.surfaceContainer,
          onSecondaryContainer: AppColors.textPrimary,
          errorContainer: status.errorContainer,
          onErrorContainer: status.error,
          surfaceContainerLowest: AppColors.surface,
          surfaceContainerLow: AppColors.surfaceMuted,
          surfaceContainer: AppColors.surfaceContainer,
          surfaceContainerHigh: AppColors.primarySoft,
          surfaceContainerHighest: AppColors.surfaceVariant,
          onSurfaceVariant: AppColors.textSecondary,
          outline: status.outline,
          outlineVariant: AppColors.border,
          shadow: AppColors.shadow,
          scrim: status.scrim,
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      fontFamily: 'BeVietnamPro',
    );
    final textTheme = _textTheme(base.textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      fontFamily: 'BeVietnamPro',
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: const <ThemeExtension<dynamic>>[status],
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.primary500,
        scaffoldBackgroundColor: AppColors.background,
        barBackgroundColor: AppColors.surface,
        textTheme: CupertinoTextThemeData(
          primaryColor: AppColors.primary500,
          textStyle: AppTextStyles.body(),
          actionTextStyle: AppTextStyles.bodyStrong(
            color: AppColors.primary500,
          ),
          actionSmallTextStyle: AppTextStyles.label(
            color: AppColors.primary500,
          ),
          tabLabelTextStyle: AppTextStyles.nav(),
          navTitleTextStyle: AppTextStyles.appBarTitle(),
          navLargeTitleTextStyle: AppTextStyles.h1(),
          navActionTextStyle: AppTextStyles.label(color: AppColors.primary500),
          pickerTextStyle: AppTextStyles.bodyStrong(),
          dateTimePickerTextStyle: AppTextStyles.bodyStrong(),
        ),
      ),
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.surface,
      cardColor: AppColors.surface,
      dividerColor: status.divider,
      disabledColor: status.disabledContent,
      focusColor: AppColors.focusOverlay,
      hoverColor: AppColors.focusOverlay,
      highlightColor: AppColors.pressedOverlay,
      splashColor: AppColors.pressedOverlay,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      iconTheme: const IconThemeData(
        color: AppColors.icon,
        size: AppControlSize.icon,
      ),
      cardTheme: CardThemeData(
        elevation: AppElevation.none,
        color: AppColors.surface,
        shadowColor: AppColors.shadow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            color: AppColors.border,
            width: AppBorderWidth.hairline,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary500,
        foregroundColor: AppColors.white,
        elevation: AppElevation.none,
        focusElevation: AppElevation.none,
        hoverElevation: AppElevation.none,
        highlightElevation: AppElevation.none,
        extendedTextStyle: AppTextStyles.buttonCompact(color: AppColors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: AppElevation.none,
        scrolledUnderElevation: AppElevation.none,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: systemUiOverlayStyle,
        titleTextStyle: AppTextStyles.appBarTitle(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        labelStyle: AppTextStyles.label(),
        hintStyle: AppTextStyles.field(color: AppColors.textSecondary),
        helperStyle: AppTextStyles.caption(color: AppColors.textSecondary),
        errorStyle: AppTextStyles.caption(color: status.error),
        border: _inputBorder(status.outline),
        enabledBorder: _inputBorder(AppColors.border),
        focusedBorder: _inputBorder(
          status.focusRing,
          width: AppBorderWidth.emphasized,
        ),
        errorBorder: _inputBorder(status.error),
        focusedErrorBorder: _inputBorder(
          status.error,
          width: AppBorderWidth.emphasized,
        ),
        disabledBorder: _inputBorder(status.disabledContainer),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppTextStyles.bodyCompact(color: AppColors.white),
        actionTextColor: AppColors.mint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.floating,
        shadowColor: AppColors.shadow,
        titleTextStyle: AppTextStyles.h4(),
        contentTextStyle: AppTextStyles.body(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: status.scrim,
        elevation: AppElevation.floating,
        modalElevation: AppElevation.floating,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(
            AppControlSize.minTouchTarget,
            AppControlSize.buttonHeight,
          ),
          foregroundColor: AppColors.white,
          backgroundColor: AppColors.primary500,
          disabledForegroundColor: status.disabledContent,
          disabledBackgroundColor: status.disabledContainer,
          textStyle: AppTextStyles.button(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(
            AppControlSize.minTouchTarget,
            AppControlSize.buttonHeight,
          ),
          foregroundColor: AppColors.primary700,
          disabledForegroundColor: status.disabledContent,
          side: const BorderSide(
            color: AppColors.borderStrong,
            width: AppBorderWidth.hairline,
          ),
          textStyle: AppTextStyles.button(color: AppColors.primary700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size.square(AppControlSize.minTouchTarget),
          foregroundColor: AppColors.primary700,
          textStyle: AppTextStyles.label(color: AppColors.primary700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(AppControlSize.minTouchTarget),
          foregroundColor: AppColors.icon,
          focusColor: AppColors.focusOverlay,
          highlightColor: AppColors.pressedOverlay,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primarySoft,
        disabledColor: status.disabledContainer,
        side: const BorderSide(
          color: AppColors.border,
          width: AppBorderWidth.hairline,
        ),
        shape: const StadiumBorder(),
        labelStyle: AppTextStyles.label(color: AppColors.textSecondary),
        secondaryLabelStyle: AppTextStyles.label(color: AppColors.primary700),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: AppBorderWidth.hairline,
        space: AppSpacing.s16,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary500;
          }
          return Colors.transparent;
        }),
        side: const BorderSide(
          color: AppColors.borderStrong,
          width: AppBorderWidth.hairline,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.checkbox),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.primary500,
        headerForegroundColor: AppColors.white,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.white;
          }
          if (states.contains(WidgetState.disabled)) {
            return status.disabledContent;
          }
          return AppColors.textPrimary;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary500;
          }
          return Colors.transparent;
        }),
        todayForegroundColor: const WidgetStatePropertyAll(
          AppColors.primary700,
        ),
        todayBorder: const BorderSide(
          color: AppColors.primary500,
          width: AppBorderWidth.hairline,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        hourMinuteColor: AppColors.surfaceContainer,
        hourMinuteTextColor: AppColors.textPrimary,
        dialBackgroundColor: AppColors.surfaceMuted,
        dialHandColor: AppColors.primary500,
        dialTextColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.white;
          }
          return AppColors.textPrimary;
        }),
        entryModeIconColor: AppColors.primary500,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(
    Color color, {
    double width = AppBorderWidth.hairline,
  }) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: BorderSide(color: color, width: width),
  );

  static TextTheme _textTheme(TextTheme base) => base.copyWith(
    displayLarge: AppTextStyles.display(),
    displayMedium: AppTextStyles.display(),
    displaySmall: AppTextStyles.display(),
    headlineLarge: AppTextStyles.h1(),
    headlineMedium: AppTextStyles.h2(),
    headlineSmall: AppTextStyles.h3(),
    titleLarge: AppTextStyles.h4(),
    titleMedium: AppTextStyles.bodyStrong(),
    titleSmall: AppTextStyles.label(),
    bodyLarge: AppTextStyles.body(),
    bodyMedium: AppTextStyles.bodyCompact(),
    bodySmall: AppTextStyles.caption(),
    labelLarge: AppTextStyles.label(),
    labelMedium: AppTextStyles.captionStrong(),
    labelSmall: AppTextStyles.overline(),
  );
}
