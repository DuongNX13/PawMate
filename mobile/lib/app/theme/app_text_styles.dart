import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// PawMate's single user-facing type scale.
///
/// All styles use Be Vietnam Pro. Inter/Plus Jakarta found in old Figma/code
/// nodes is legacy drift and must not be introduced in new user-facing UI.
class AppTextStyles {
  static TextStyle display({Color color = AppColors.textPrimary}) =>
      _style(size: 32, lineHeight: 40, weight: FontWeight.w700, color: color);

  static TextStyle h1({Color color = AppColors.textPrimary}) =>
      _style(size: 28, lineHeight: 36, weight: FontWeight.w700, color: color);

  static TextStyle h2({Color color = AppColors.textPrimary}) =>
      _style(size: 24, lineHeight: 32, weight: FontWeight.w700, color: color);

  static TextStyle h3({Color color = AppColors.textPrimary}) =>
      _style(size: 20, lineHeight: 28, weight: FontWeight.w700, color: color);

  static TextStyle h4({Color color = AppColors.textPrimary}) =>
      _style(size: 18, lineHeight: 24, weight: FontWeight.w600, color: color);

  static TextStyle body({Color color = AppColors.textPrimary}) =>
      _style(size: 14, lineHeight: 20, weight: FontWeight.w400, color: color);

  static TextStyle bodyStrong({Color color = AppColors.textPrimary}) =>
      _style(size: 16, lineHeight: 24, weight: FontWeight.w600, color: color);

  static TextStyle bodyCompact({Color color = AppColors.textSecondary}) =>
      _style(size: 14, lineHeight: 20, weight: FontWeight.w400, color: color);

  static TextStyle label({Color color = AppColors.label}) =>
      _style(size: 14, lineHeight: 20, weight: FontWeight.w600, color: color);

  static TextStyle button({Color color = Colors.white}) =>
      _style(size: 16, lineHeight: 24, weight: FontWeight.w600, color: color);

  static TextStyle buttonCompact({Color color = Colors.white}) =>
      _style(size: 14, lineHeight: 20, weight: FontWeight.w600, color: color);

  static TextStyle caption({Color color = AppColors.textSecondary}) =>
      _style(size: 12, lineHeight: 16, weight: FontWeight.w400, color: color);

  static TextStyle captionStrong({Color color = AppColors.label}) =>
      _style(size: 12, lineHeight: 16, weight: FontWeight.w600, color: color);

  static TextStyle overline({Color color = AppColors.label}) =>
      _style(size: 11, lineHeight: 16, weight: FontWeight.w700, color: color);

  static TextStyle micro({Color color = AppColors.label}) =>
      _style(size: 10, lineHeight: 15, weight: FontWeight.w700, color: color);

  static TextStyle nav({Color color = AppColors.navInactiveLabel}) =>
      _style(size: 13, lineHeight: 18, weight: FontWeight.w500, color: color);

  static TextStyle navActive({Color color = Colors.white}) =>
      _style(size: 13, lineHeight: 18, weight: FontWeight.w600, color: color);

  // Explicit Figma role names keep screen code readable while the legacy
  // aliases above remain source-compatible during the migration waves.
  static TextStyle pageTitle({Color color = AppColors.textPrimary}) =>
      h1(color: color);

  static TextStyle sectionTitle({Color color = AppColors.textPrimary}) =>
      h3(color: color);

  static TextStyle appBarTitle({Color color = AppColors.textPrimary}) =>
      h4(color: color);

  static TextStyle cardTitle({Color color = AppColors.textPrimary}) =>
      bodyStrong(color: color);

  static TextStyle field({Color color = AppColors.textPrimary}) =>
      _style(size: 16, lineHeight: 24, weight: FontWeight.w400, color: color);

  static TextStyle meta({Color color = AppColors.textSecondary}) =>
      caption(color: color);

  static TextStyle _style({
    required double size,
    required double lineHeight,
    required FontWeight weight,
    required Color color,
  }) => TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    letterSpacing: 0,
    color: color,
  );
}
