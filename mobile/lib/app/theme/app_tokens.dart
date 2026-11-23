import 'package:flutter/material.dart';

/// Canonical PawMate Calm Cartographic light design tokens.
///
/// The semantic names below are the implementation contract for the compact
/// Figma baseline. Legacy names are intentionally kept as aliases while the
/// feature screens migrate, so a palette change cannot silently split the UI
/// into two themes.
class AppColors {
  // Approved five-anchor palette (2026-08-12).
  static const mint = Color(0xFF95D5B2);
  // Mint at 30% opacity over Light Beige. P1-01 and other approved soft input
  // surfaces use this token while keeping the full Mint value for outlines.
  static const mintField = Color(0x4D95D5B2);
  static const brown = Color(0xFF5C3C25);
  static const warmIvory = Color(0xFFF8F3EA);
  static const deepTeal = Color(0xFF155E63);
  static const deepTealPressed = Color(0xFF0F4B4F);
  static const white = Color(0xFFFFFFFF);

  // Source-compatible aliases retained while feature files migrate.
  static const lightBeige = warmIvory;
  static const deepGreen = deepTeal;

  // Semantic action/surface mapping.
  static const primary500 = deepGreen;
  static const primary700 = deepGreen;
  static const primaryAccent = mint;
  static const primarySoft = lightBeige;

  static const background = warmIvory;
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFFBF8F2);
  static const surfaceContainer = Color(0xFFE5F2EC);
  static const surfaceVariant = Color(0xFFF1EEE8);
  static const border = Color(0x29155E63);
  static const divider = Color(0x1F155E63);
  static const borderStrong = deepTeal;

  static const textPrimary = Color(0xFF153D3D);
  static const textSecondary = Color(0xFF5C6662);
  static const textMuted = Color(0xFF6F7975);
  static const label = textPrimary;
  static const icon = deepTeal;

  static const navActive = deepGreen;
  static const navInactiveIcon = cocoa;
  static const navInactiveLabel = textSecondary;

  static const cocoa = brown;

  static const careGreen = deepGreen;
  static const careGreenStrong = deepGreen;
  static const careGreenSoft = mint;

  // Compatibility aliases. Feature code migrates to careGreen* during its
  // scheduled feature day; new code must use the semantic names above.
  @Deprecated('Use AppColors.careGreen.')
  static const secondary500 = careGreen;

  @Deprecated('Use AppColors.careGreenSoft.')
  static const secondarySoft = careGreenSoft;

  static const success = Color(0xFF2D7A55);
  static const successSoft = Color(0xFFF0F8F3);
  // Dark semantic foregrounds are used on their pale containers; the brighter
  // anchor orange/red remain available for non-text accents only.
  static const warning = Color(0xFF8A5A16);
  static const warningAccent = Color(0xFFD88A1D);
  static const warningSoft = Color(0xFFFFF1D6);

  @Deprecated('Use AppColors.warningSoft.')
  static const tertiarySoft = warningSoft;

  // Error remains a semantic signal with sufficient contrast; the supporting
  // surface stays inside the Chocomint family.
  static const dangerAccent = Color(0xFFB34A42);
  static const error = Color(0xFF8A3D36);
  static const errorSoft = Color(0xFFFCEDEA);
  static const info = deepTeal;
  static const infoSoft = Color(0xFFE0F0F1);
  static const mapLand = Color(0xFFF2EDE3);
  static const mapGrid = Color(0xFFC7D9D1);
  static const mapWater = Color(0xFFDDEEEF);
  static const mapRoute = Color(0xFF9C765C);
  static const offline = textSecondary;
  static const disabledContent = textSecondary;
  static const disabledContainer = Color(0xFFEEECE7);

  static const shadow = Color(0x1A153D3D);
  static const pressedOverlay = Color(0x1A155E63);
  static const focusOverlay = Color(0x24155E63);
  static const scrim = Color(0x52000000);
  static const scrimSoft = Color(0x14000000);
  static const scrimMedia = Color(0x66000000);
  static const cocoaOverlay = Color(0xAA5C3C25);
}

/// Semantic state palette used by status, feedback and accessibility surfaces.
///
/// Components consume this extension instead of inventing one-off colors. The
/// app is intentionally light-only, so there is a single canonical instance.
@immutable
class PawMateStatusColors extends ThemeExtension<PawMateStatusColors> {
  const PawMateStatusColors({
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.error,
    required this.errorContainer,
    required this.info,
    required this.infoContainer,
    required this.offline,
    required this.disabledContent,
    required this.disabledContainer,
    required this.focusRing,
    required this.scrim,
    required this.divider,
    required this.outline,
  });

  static const light = PawMateStatusColors(
    success: AppColors.success,
    successContainer: AppColors.successSoft,
    warning: AppColors.warning,
    warningContainer: AppColors.warningSoft,
    error: AppColors.error,
    errorContainer: AppColors.errorSoft,
    info: AppColors.info,
    infoContainer: AppColors.infoSoft,
    offline: AppColors.offline,
    disabledContent: AppColors.disabledContent,
    disabledContainer: AppColors.disabledContainer,
    focusRing: AppColors.deepTeal,
    scrim: AppColors.scrim,
    divider: AppColors.divider,
    outline: AppColors.deepTeal,
  );

  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color error;
  final Color errorContainer;
  final Color info;
  final Color infoContainer;
  final Color offline;
  final Color disabledContent;
  final Color disabledContainer;
  final Color focusRing;
  final Color scrim;
  final Color divider;
  final Color outline;

  static PawMateStatusColors of(BuildContext context) =>
      Theme.of(context).extension<PawMateStatusColors>() ?? light;

  @override
  PawMateStatusColors copyWith({
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? error,
    Color? errorContainer,
    Color? info,
    Color? infoContainer,
    Color? offline,
    Color? disabledContent,
    Color? disabledContainer,
    Color? focusRing,
    Color? scrim,
    Color? divider,
    Color? outline,
  }) => PawMateStatusColors(
    success: success ?? this.success,
    successContainer: successContainer ?? this.successContainer,
    warning: warning ?? this.warning,
    warningContainer: warningContainer ?? this.warningContainer,
    error: error ?? this.error,
    errorContainer: errorContainer ?? this.errorContainer,
    info: info ?? this.info,
    infoContainer: infoContainer ?? this.infoContainer,
    offline: offline ?? this.offline,
    disabledContent: disabledContent ?? this.disabledContent,
    disabledContainer: disabledContainer ?? this.disabledContainer,
    focusRing: focusRing ?? this.focusRing,
    scrim: scrim ?? this.scrim,
    divider: divider ?? this.divider,
    outline: outline ?? this.outline,
  );

  @override
  PawMateStatusColors lerp(covariant PawMateStatusColors? other, double t) {
    if (other == null) return this;
    return PawMateStatusColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      error: Color.lerp(error, other.error, t)!,
      errorContainer: Color.lerp(errorContainer, other.errorContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      offline: Color.lerp(offline, other.offline, t)!,
      disabledContent: Color.lerp(disabledContent, other.disabledContent, t)!,
      disabledContainer: Color.lerp(
        disabledContainer,
        other.disabledContainer,
        t,
      )!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
    );
  }
}

class AppSpacing {
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s48 = 48.0;
  static const s64 = 64.0;
}

class AppRadius {
  static const checkbox = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const control = 18.0;
  static const lg = 18.0;
  static const card = 22.0;
  static const navActive = 24.0;
  static const xl = 24.0;
  static const navShell = 28.0;
  static const mapPreview = 32.0;
  static const pill = 999.0;

  // Kept only so the existing Vet map compiles before its scheduled migration.
  @Deprecated('Use AppRadius.mapPreview.')
  static const xxl = mapPreview;
}

class AppControlSize {
  static const minTouchTarget = 48.0;
  static const buttonHeight = 52.0;
  static const compactButtonVisualHeight = 36.0;
  static const compactButtonMaxTextScale = 1.3;
  static const inputHeight = 52.0;
  static const chipHeight = 32.0;
  static const iconSmall = 16.0;
  static const progressIndicator = 18.0;
  static const iconCompact = 20.0;
  static const icon = 24.0;
  static const avatar = 48.0;
  static const mediaPlaceholderIcon = 40.0;
  static const mediaAspectRatio = 4 / 3;
  static const stateIllustration = 112.0;
  static const stateIcon = 48.0;

  /// Compact shell and icon metrics from the v0.29/v0.30 handoff.
  static const bottomNavHeight = 70.0;
  static const bottomNavActiveHeight = 68.0;
  static const bottomNavIcon = 28.0;
  static const fixedCtaBarMinHeight = 72.0;
}

class AppBorderWidth {
  static const hairline = 1.0;
  static const emphasized = 1.5;
  static const focus = 2.0;
}

class AppElevation {
  static const none = 0.0;
  static const floating = 8.0;
}

class AppMotion {
  static const fast = Duration(milliseconds: 140);
  static const standard = Duration(milliseconds: 180);
  static const deliberate = Duration(milliseconds: 240);
  static const skeletonPulse = Duration(milliseconds: 900);
  static const standardCurve = Curves.easeOutCubic;
}

class AppShadows {
  static const soft = [
    BoxShadow(color: AppColors.shadow, blurRadius: 14, offset: Offset(0, 6)),
  ];

  static const raised = [
    BoxShadow(color: AppColors.shadow, blurRadius: 24, offset: Offset(0, 8)),
  ];
}

/// Transitional gradients retained for legacy screens only.
///
/// New primary actions use a solid [AppColors.primary500] fill.
class AppGradients {
  static const primary = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.primary500, AppColors.primary500],
  );

  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.surfaceMuted, AppColors.warmIvory],
  );

  static const adoption = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.careGreenSoft, AppColors.surface],
  );
}
