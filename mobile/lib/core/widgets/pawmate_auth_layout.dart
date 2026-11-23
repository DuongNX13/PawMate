import 'package:flutter/material.dart';

/// Responsive geometry shared by the Day 90 onboarding/auth surfaces.
///
/// The visual composition stays stable across phones, while tall imagery and
/// decorative gaps yield space first on compact screens or when the IME opens.
abstract final class PawMateAuthLayout {
  static bool isCompact(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width <= 340 || size.height <= 700;
  }

  static bool hasKeyboard(BuildContext context) {
    return MediaQuery.viewInsetsOf(context).bottom > 0;
  }

  static double heroHeight(
    BuildContext context, {
    required double widthFactor,
    required double min,
    required double max,
    double keyboard = 128,
  }) {
    if (hasKeyboard(context)) {
      return keyboard;
    }
    final width = MediaQuery.sizeOf(context).width;
    return (width * widthFactor).clamp(min, max).toDouble();
  }

  static double illustrationSize(BuildContext context) {
    if (hasKeyboard(context)) {
      return 96;
    }
    return (MediaQuery.sizeOf(context).width * 0.42).clamp(120, 168).toDouble();
  }

  static double sectionGap(
    BuildContext context, {
    required double regular,
    required double compact,
  }) {
    return isCompact(context) || hasKeyboard(context) ? compact : regular;
  }
}
