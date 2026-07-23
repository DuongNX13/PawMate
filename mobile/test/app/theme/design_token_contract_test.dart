import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_text_styles.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PawMate Day 9 Chocomint color contract', () {
    test('locks v0.29/v0.30 source colours and semantic mapping', () {
      expect(AppColors.mint, const Color(0xFF95D5B2));
      expect(AppColors.brown, const Color(0xFF5C3C25));
      expect(AppColors.lightBeige, const Color(0xFFE9F5DB));
      expect(AppColors.deepGreen, const Color(0xFF2D6A4F));
      expect(AppColors.white, const Color(0xFFFFFFFF));
      expect(AppColors.primary500, AppColors.deepGreen);
      expect(AppColors.primaryAccent, AppColors.mint);
      expect(AppColors.primarySoft, AppColors.lightBeige);
      expect(AppColors.background, AppColors.lightBeige);
      expect(AppColors.textPrimary, AppColors.brown);
      expect(AppColors.navInactiveIcon, AppColors.brown);
      expect(AppColors.careGreen, AppColors.deepGreen);
      expect(AppColors.border, AppColors.mint);
    });

    test('keeps action and small-label contrast accessible', () {
      expect(
        _contrastRatio(Colors.white, AppColors.primary500),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(Colors.white, AppColors.primary700),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(AppColors.label, AppColors.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(AppColors.careGreen, AppColors.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(AppColors.brown, AppColors.mint),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(AppColors.deepGreen, AppColors.lightBeige),
        greaterThanOrEqualTo(4.5),
      );

      const status = PawMateStatusColors.light;
      for (final pair in <(Color, Color)>[
        (status.success, status.successContainer),
        (status.warning, status.warningContainer),
        (status.error, status.errorContainer),
        (status.info, status.infoContainer),
        (status.disabledContent, status.disabledContainer),
      ]) {
        expect(_contrastRatio(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
    });

    test('registers the complete light-only semantic status palette', () {
      final theme = AppTheme.light();
      final status = theme.extension<PawMateStatusColors>();

      expect(theme.brightness, Brightness.light);
      expect(status, isNotNull);
      expect(status!.success, AppColors.deepGreen);
      expect(status.successContainer, AppColors.surfaceContainer);
      expect(status.warning, AppColors.brown);
      expect(status.warningContainer, AppColors.lightBeige);
      expect(status.error, AppColors.error);
      expect(status.errorContainer, AppColors.errorSoft);
      expect(status.info, AppColors.deepGreen);
      expect(status.infoContainer, AppColors.surfaceContainer);
      expect(status.offline, AppColors.brown);
      expect(status.disabledContent, AppColors.textMuted);
      expect(status.disabledContainer, AppColors.surfaceVariant);
      expect(status.focusRing, AppColors.deepGreen);
      expect(status.scrim, AppColors.scrim);
      expect(status.divider, AppColors.mint);
      expect(status.outline, AppColors.deepGreen);
      expect(theme.colorScheme.scrim, status.scrim);
      expect(theme.colorScheme.outline, status.outline);
    });

    test('copyWith can override every semantic status token', () {
      const replacement = Color(0xFF123456);
      final unchanged = PawMateStatusColors.light.copyWith();
      expect(unchanged.success, PawMateStatusColors.light.success);
      expect(
        unchanged.successContainer,
        PawMateStatusColors.light.successContainer,
      );
      expect(unchanged.warning, PawMateStatusColors.light.warning);
      expect(
        unchanged.warningContainer,
        PawMateStatusColors.light.warningContainer,
      );
      expect(unchanged.error, PawMateStatusColors.light.error);
      expect(
        unchanged.errorContainer,
        PawMateStatusColors.light.errorContainer,
      );
      expect(unchanged.info, PawMateStatusColors.light.info);
      expect(unchanged.infoContainer, PawMateStatusColors.light.infoContainer);
      expect(unchanged.offline, PawMateStatusColors.light.offline);
      expect(
        unchanged.disabledContent,
        PawMateStatusColors.light.disabledContent,
      );
      expect(
        unchanged.disabledContainer,
        PawMateStatusColors.light.disabledContainer,
      );
      expect(unchanged.focusRing, PawMateStatusColors.light.focusRing);
      expect(unchanged.scrim, PawMateStatusColors.light.scrim);
      expect(unchanged.divider, PawMateStatusColors.light.divider);
      expect(unchanged.outline, PawMateStatusColors.light.outline);

      final status = PawMateStatusColors.light.copyWith(
        success: replacement,
        successContainer: replacement,
        warning: replacement,
        warningContainer: replacement,
        error: replacement,
        errorContainer: replacement,
        info: replacement,
        infoContainer: replacement,
        offline: replacement,
        disabledContent: replacement,
        disabledContainer: replacement,
        focusRing: replacement,
        scrim: replacement,
        divider: replacement,
        outline: replacement,
      );

      expect(<Color>[
        status.success,
        status.successContainer,
        status.warning,
        status.warningContainer,
        status.error,
        status.errorContainer,
        status.info,
        status.infoContainer,
        status.offline,
        status.disabledContent,
        status.disabledContainer,
        status.focusRing,
        status.scrim,
        status.divider,
        status.outline,
      ], everyElement(replacement));
    });
  });

  group('PawMate Day 9 scale contract', () {
    test('spacing scale is canonical and unique', () {
      const spacing = <double>[
        AppSpacing.s4,
        AppSpacing.s8,
        AppSpacing.s12,
        AppSpacing.s16,
        AppSpacing.s24,
        AppSpacing.s32,
        AppSpacing.s48,
        AppSpacing.s64,
      ];
      expect(spacing, <double>[4, 8, 12, 16, 24, 32, 48, 64]);
      expect(spacing.toSet().length, spacing.length);
    });

    test('radii use canonical scale plus named exceptions', () {
      expect(AppRadius.checkbox, 4);
      expect(AppRadius.sm, 8);
      expect(AppRadius.md, 12);
      expect(AppRadius.lg, 16);
      expect(AppRadius.navActive, 22);
      expect(AppRadius.xl, 24);
      expect(AppRadius.mapPreview, 32);
      expect(AppRadius.pill, 999);
    });

    test('compact nav metrics keep full control touch targets', () {
      expect(AppControlSize.bottomNavHeight, 70);
      expect(AppControlSize.bottomNavActiveHeight, 68);
      expect(AppControlSize.bottomNavIcon, 28);
      expect(AppControlSize.minTouchTarget, greaterThanOrEqualTo(48));
      expect(AppControlSize.buttonHeight, greaterThanOrEqualTo(48));
      expect(AppControlSize.compactButtonVisualHeight, 36);
      expect(AppControlSize.compactButtonMaxTextScale, 1.3);
      expect(
        AppControlSize.minTouchTarget,
        greaterThan(AppControlSize.compactButtonVisualHeight),
      );
      expect(AppControlSize.inputHeight, greaterThanOrEqualTo(48));
    });

    test('locks border, elevation and motion behavior', () {
      expect(AppBorderWidth.hairline, 1);
      expect(AppBorderWidth.emphasized, 1.5);
      expect(AppBorderWidth.focus, 2);
      expect(AppElevation.none, 0);
      expect(AppElevation.floating, 8);
      expect(AppMotion.fast, const Duration(milliseconds: 140));
      expect(AppMotion.standard, const Duration(milliseconds: 180));
      expect(AppMotion.deliberate, const Duration(milliseconds: 240));
      expect(AppMotion.skeletonPulse, const Duration(milliseconds: 900));
    });

    test('shadows match native Figma effect styles', () {
      final soft = AppShadows.soft.single;
      final raised = AppShadows.raised.single;

      expect(soft.color, const Color(0x140F172A));
      expect(soft.blurRadius, 10);
      expect(soft.offset, const Offset(0, 4));
      expect(raised.color, const Color(0x140F172A));
      expect(raised.blurRadius, 24);
      expect(raised.offset, const Offset(0, 8));
    });
  });

  group('PawMate Day 9 typography contract', () {
    test('locks the complete Be Vietnam Pro type scale', () {
      _expectStyle(AppTextStyles.display(), 32, 40, FontWeight.w700);
      _expectStyle(AppTextStyles.h1(), 28, 36, FontWeight.w700);
      _expectStyle(AppTextStyles.h2(), 24, 32, FontWeight.w700);
      _expectStyle(AppTextStyles.h3(), 20, 28, FontWeight.w700);
      _expectStyle(AppTextStyles.h4(), 18, 24, FontWeight.w600);
      _expectStyle(AppTextStyles.body(), 14, 20, FontWeight.w400);
      _expectStyle(AppTextStyles.bodyStrong(), 16, 24, FontWeight.w600);
      _expectStyle(AppTextStyles.label(), 14, 20, FontWeight.w600);
      _expectStyle(AppTextStyles.button(), 16, 24, FontWeight.w600);
      _expectStyle(AppTextStyles.buttonCompact(), 14, 20, FontWeight.w600);
      _expectStyle(AppTextStyles.caption(), 12, 16, FontWeight.w400);
      _expectStyle(AppTextStyles.overline(), 11, 16, FontWeight.w700);
      _expectStyle(AppTextStyles.micro(), 10, 15, FontWeight.w700);
      _expectStyle(AppTextStyles.nav(), 13, 18, FontWeight.w500);
      _expectStyle(AppTextStyles.navActive(), 13, 18, FontWeight.w600);
      _expectStyle(AppTextStyles.field(), 16, 24, FontWeight.w400);
    });

    test('Material theme maps to the canonical scale without Inter', () {
      final theme = AppTheme.light();
      final styles = <TextStyle?>[
        theme.textTheme.displaySmall,
        theme.textTheme.headlineLarge,
        theme.textTheme.headlineMedium,
        theme.textTheme.headlineSmall,
        theme.textTheme.titleLarge,
        theme.textTheme.titleMedium,
        theme.textTheme.bodyLarge,
        theme.textTheme.bodyMedium,
        theme.textTheme.bodySmall,
        theme.textTheme.labelLarge,
        theme.textTheme.labelMedium,
        theme.textTheme.labelSmall,
      ];

      expect(styles, everyElement(isNotNull));
      for (final style in styles.whereType<TextStyle>()) {
        expect(style.fontFamily?.toLowerCase(), isNot(contains('inter')));
        expect(style.letterSpacing, anyOf(isNull, 0));
      }
      expect(theme.textTheme.headlineLarge?.fontSize, 28);
      expect(theme.textTheme.headlineMedium?.fontSize, 24);
      expect(theme.textTheme.headlineSmall?.fontSize, 20);
      expect(theme.textTheme.titleLarge?.fontSize, 18);
      expect(theme.textTheme.bodyLarge?.fontSize, 14);
      expect(theme.textTheme.bodyMedium?.fontSize, 14);
      expect(theme.textTheme.bodySmall?.fontSize, 12);
      expect(theme.textTheme.bodyLarge?.fontFamily, 'BeVietnamPro');
      expect(
        theme.cupertinoOverrideTheme?.textTheme?.textStyle.fontFamily,
        'BeVietnamPro',
      );
    });
  });

  test('Material control defaults honor the primitive contract', () {
    final theme = AppTheme.light();
    final states = <WidgetState>{};
    final filledStyle = theme.filledButtonTheme.style!;
    final outlinedStyle = theme.outlinedButtonTheme.style!;

    expect(
      filledStyle.minimumSize?.resolve(states),
      const Size(AppControlSize.minTouchTarget, AppControlSize.buttonHeight),
    );
    expect(
      outlinedStyle.minimumSize?.resolve(states),
      const Size(AppControlSize.minTouchTarget, AppControlSize.buttonHeight),
    );
    expect(_radiusOf(filledStyle.shape?.resolve(states)), AppRadius.md);
    expect(_radiusOf(theme.inputDecorationTheme.enabledBorder), AppRadius.md);
    expect(_radiusOf(theme.cardTheme.shape), AppRadius.md);
  });
}

void _expectStyle(
  TextStyle style,
  double fontSize,
  double lineHeight,
  FontWeight weight,
) {
  expect(style.fontFamily?.toLowerCase(), isNot(contains('inter')));
  expect(style.fontSize, fontSize);
  expect(style.height, closeTo(lineHeight / fontSize, 0.0001));
  expect(style.fontWeight, weight);
  expect(style.letterSpacing, 0);
}

double? _radiusOf(ShapeBorder? shape) {
  if (shape is RoundedRectangleBorder) {
    return shape.borderRadius.resolve(TextDirection.ltr).topLeft.x;
  }
  if (shape is OutlineInputBorder) {
    return shape.borderRadius.topLeft.x;
  }
  return null;
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLum = foreground.computeLuminance();
  final backgroundLum = background.computeLuminance();
  final lighter = foregroundLum > backgroundLum ? foregroundLum : backgroundLum;
  final darker = foregroundLum > backgroundLum ? backgroundLum : foregroundLum;
  return (lighter + 0.05) / (darker + 0.05);
}
