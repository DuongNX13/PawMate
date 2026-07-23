import 'package:flutter/material.dart';

/// Canonical PawMate v0.31 light-only Chocomint visual tokens.
///
/// The semantic names below are the implementation contract for the compact
/// Figma baseline. Legacy names are intentionally kept as aliases while the
/// feature screens migrate, so a palette change cannot silently split the UI
/// into two themes.
class AppColors {
  // Chocomint source colours (Figma v0.29/v0.30).
  static const mint = Color(0xFF95D5B2);
  static const brown = Color(0xFF5C3C25);
  static const lightBeige = Color(0xFFE9F5DB);
  static const deepGreen = Color(0xFF2D6A4F);
  static const white = Color(0xFFFFFFFF);

  // Semantic action/surface mapping.
  static const primary500 = deepGreen;
  static const primary700 = deepGreen;
  static const primaryAccent = mint;
  static const primarySoft = lightBeige;

  static const background = lightBeige;
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF4FAEF);
  static const surfaceContainer = Color(0xFFDFF0D5);
  static const surfaceVariant = lightBeige;
  static const border = mint;
  static const borderStrong = deepGreen;

  static const textPrimary = brown;
  static const textSecondary = brown;
  // Derived accessible muted brown for small copy on Light Beige/White.
  static const textMuted = Color(0xFF80654F);
  static const label = brown;
  static const icon = brown;

  static const navActive = deepGreen;
  static const navInactiveIcon = brown;
  static const navInactiveLabel = textSecondary;

  static const careGreen = deepGreen;
  static const careGreenStrong = deepGreen;
  static const careGreenSoft = mint;

  // Compatibility aliases. Feature code migrates to careGreen* during its
  // scheduled feature day; new code must use the semantic names above.
  @Deprecated('Use AppColors.careGreen.')
  static const secondary500 = careGreen;

  @Deprecated('Use AppColors.careGreenSoft.')
  static const secondarySoft = careGreenSoft;

  static const success = deepGreen;
  // Deep green on mint does not reach 4.5:1 for small status copy. Keep mint
  // as an accent and use the lighter container for semantic success surfaces.
  static const successSoft = surfaceContainer;
  static const warning = brown;
  static const warningSoft = lightBeige;

  @Deprecated('Use AppColors.warningSoft.')
  static const tertiarySoft = warningSoft;

  // Error remains a semantic signal with sufficient contrast; the supporting
  // surface stays inside the Chocomint family.
  static const error = Color(0xFF8A3D2F);
  static const errorSoft = Color(0xFFF4D8CF);

  static const shadow = Color(0x140F172A);
  static const pressedOverlay = Color(0x145C3C25);
  static const focusOverlay = Color(0x1F2D6A4F);
  static const scrim = Color(0x52000000);
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
    success: AppColors.deepGreen,
    successContainer: AppColors.surfaceContainer,
    warning: AppColors.brown,
    warningContainer: AppColors.lightBeige,
    error: AppColors.error,
    errorContainer: AppColors.errorSoft,
    info: AppColors.deepGreen,
    infoContainer: AppColors.surfaceContainer,
    offline: AppColors.brown,
    disabledContent: AppColors.textMuted,
    disabledContainer: AppColors.surfaceVariant,
    focusRing: AppColors.deepGreen,
    scrim: AppColors.scrim,
    divider: AppColors.mint,
    outline: AppColors.deepGreen,
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
  static const lg = 16.0;
  static const navActive = 22.0;
  static const xl = 24.0;
  static const mapPreview = 32.0;
  static const pill = 999.0;

  // Kept only so the existing Vet map compiles before its scheduled migration.
  @Deprecated('Use AppRadius.mapPreview.')
  static const xxl = mapPreview;
}

class AppControlSize {
  static const minTouchTarget = 48.0;
  static const buttonHeight = 48.0;
  static const compactButtonVisualHeight = 36.0;
  static const compactButtonMaxTextScale = 1.3;
  static const inputHeight = 48.0;
  static const chipHeight = 32.0;
  static const icon = 24.0;

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
    BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
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
    colors: [AppColors.primary500, AppColors.primaryAccent],
  );

  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.surfaceMuted, AppColors.primarySoft],
  );

  static const adoption = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.careGreenSoft, AppColors.surface],
  );
}
