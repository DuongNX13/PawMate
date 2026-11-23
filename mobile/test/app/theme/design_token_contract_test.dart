import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_text_styles.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PawMate Calm Cartographic anchor color contract', () {
    test('locks the approved five-anchor source colours and mapping', () {
      expect(AppColors.mint, const Color(0xFF95D5B2));
      expect(AppColors.brown, const Color(0xFF5C3C25));
      expect(AppColors.warmIvory, const Color(0xFFF8F3EA));
      expect(AppColors.deepTeal, const Color(0xFF155E63));
      expect(AppColors.lightBeige, AppColors.warmIvory);
      expect(AppColors.deepGreen, AppColors.deepTeal);
      expect(AppColors.white, const Color(0xFFFFFFFF));
      expect(AppColors.primary500, AppColors.deepTeal);
      expect(AppColors.primaryAccent, AppColors.mint);
      expect(AppColors.primarySoft, AppColors.warmIvory);
      expect(AppColors.background, AppColors.warmIvory);
      expect(AppColors.textPrimary, const Color(0xFF153D3D));
      expect(AppColors.navInactiveIcon, AppColors.cocoa);
      expect(AppColors.careGreen, AppColors.deepTeal);
      expect(AppColors.border, const Color(0x29155E63));
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
      expect(status!.success, AppColors.success);
      expect(status.successContainer, AppColors.successSoft);
      expect(status.warning, AppColors.warning);
      expect(status.warningContainer, AppColors.warningSoft);
      expect(status.error, AppColors.error);
      expect(status.errorContainer, AppColors.errorSoft);
      expect(status.info, AppColors.info);
      expect(status.infoContainer, AppColors.infoSoft);
      expect(status.offline, AppColors.offline);
      expect(status.disabledContent, AppColors.disabledContent);
      expect(status.disabledContainer, AppColors.disabledContainer);
      expect(status.focusRing, AppColors.deepTeal);
      expect(status.scrim, AppColors.scrim);
      expect(status.divider, AppColors.divider);
      expect(status.outline, AppColors.deepTeal);
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
      expect(AppRadius.control, 18);
      expect(AppRadius.lg, 18);
      expect(AppRadius.card, 22);
      expect(AppRadius.navActive, 24);
      expect(AppRadius.xl, 24);
      expect(AppRadius.navShell, 28);
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
      expect(AppControlSize.iconSmall, 16);
      expect(AppControlSize.progressIndicator, 18);
      expect(AppControlSize.iconCompact, 20);
      expect(AppControlSize.avatar, 48);
      expect(AppControlSize.mediaPlaceholderIcon, 40);
      expect(AppControlSize.mediaAspectRatio, closeTo(4 / 3, 0.0001));
      expect(AppControlSize.stateIllustration, 112);
      expect(AppControlSize.stateIcon, 48);
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

      expect(soft.color, AppColors.shadow);
      expect(soft.blurRadius, 14);
      expect(soft.offset, const Offset(0, 6));
      expect(raised.color, AppColors.shadow);
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
      _expectStyle(AppTextStyles.h4(), 18, 26, FontWeight.w600);
      _expectStyle(AppTextStyles.body(), 15, 23, FontWeight.w400);
      _expectStyle(AppTextStyles.bodyStrong(), 16, 24, FontWeight.w600);
      _expectStyle(AppTextStyles.label(), 14, 20, FontWeight.w600);
      _expectStyle(AppTextStyles.button(), 16, 22, FontWeight.w700);
      _expectStyle(AppTextStyles.buttonCompact(), 14, 20, FontWeight.w600);
      _expectStyle(AppTextStyles.caption(), 12, 18, FontWeight.w500);
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
      expect(theme.textTheme.bodyLarge?.fontSize, 15);
      expect(theme.textTheme.bodyMedium?.fontSize, 15);
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
    expect(_radiusOf(filledStyle.shape?.resolve(states)), AppRadius.control);
    expect(
      _radiusOf(theme.inputDecorationTheme.enabledBorder),
      AppRadius.control,
    );
    expect(_radiusOf(theme.cardTheme.shape), AppRadius.card);
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
