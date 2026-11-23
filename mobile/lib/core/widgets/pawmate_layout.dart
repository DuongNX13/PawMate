import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

enum PawMateResponsiveTier { small, standard, large, wide }

@immutable
class PawMateLayoutMetrics {
  const PawMateLayoutMetrics({
    required this.tier,
    required this.gutter,
    required this.sectionGap,
    required this.maxContentWidth,
    required this.scale,
  });

  final PawMateResponsiveTier tier;
  final double gutter;
  final double sectionGap;
  final double maxContentWidth;
  final double scale;

  static PawMateLayoutMetrics of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 375) {
      return const PawMateLayoutMetrics(
        tier: PawMateResponsiveTier.small,
        gutter: AppSpacing.s16,
        sectionGap: AppSpacing.s16,
        maxContentWidth: 520,
        scale: 0.94,
      );
    }
    if (width < 420) {
      return const PawMateLayoutMetrics(
        tier: PawMateResponsiveTier.standard,
        gutter: 20,
        sectionGap: 20,
        maxContentWidth: 560,
        scale: 1,
      );
    }
    if (width < 720) {
      return const PawMateLayoutMetrics(
        tier: PawMateResponsiveTier.large,
        gutter: AppSpacing.s24,
        sectionGap: AppSpacing.s24,
        maxContentWidth: 620,
        scale: 1.06,
      );
    }
    return const PawMateLayoutMetrics(
      tier: PawMateResponsiveTier.wide,
      gutter: AppSpacing.s32,
      sectionGap: AppSpacing.s24,
      maxContentWidth: 840,
      scale: 1.08,
    );
  }
}

/// Group A wrapper for dynamic main and important-detail screens.
class PawMateResponsiveFrame extends StatelessWidget {
  const PawMateResponsiveFrame({
    super.key,
    required this.builder,
    this.padding,
    this.alignTop = true,
  });

  final Widget Function(BuildContext context, PawMateLayoutMetrics metrics)
  builder;
  final EdgeInsetsGeometry? padding;
  final bool alignTop;

  @override
  Widget build(BuildContext context) {
    final metrics = PawMateLayoutMetrics.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = math.max(
          metrics.gutter,
          constraints.maxWidth > metrics.maxContentWidth
              ? (constraints.maxWidth - metrics.maxContentWidth) / 2
              : metrics.gutter,
        );
        return Align(
          alignment: alignTop ? Alignment.topCenter : Alignment.center,
          child: Padding(
            padding:
                padding ??
                EdgeInsets.fromLTRB(
                  horizontal,
                  0,
                  horizontal,
                  metrics.sectionGap,
                ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: metrics.maxContentWidth),
              child: builder(context, metrics),
            ),
          ),
        );
      },
    );
  }
}

/// Group B wrapper: preserve composition, scale spacing/media conservatively,
/// and always keep a scroll escape hatch for short or IME-heavy flows.
class PawMateScaledFrame extends StatelessWidget {
  const PawMateScaledFrame({
    super.key,
    required this.child,
    this.designWidth = 390,
    this.maxContentWidth = 560,
    this.padding,
    this.scrollable = true,
  });

  final Widget child;
  final double designWidth;
  final double maxContentWidth;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final mediaWidth = MediaQuery.sizeOf(context).width;
    final visualScale = (mediaWidth / designWidth).clamp(0.9, 1.1);
    final horizontal = mediaWidth < 375 ? AppSpacing.s16 : 20.0;
    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: Padding(
          padding:
              padding ??
              EdgeInsets.fromLTRB(
                horizontal,
                AppSpacing.s16 * visualScale,
                horizontal,
                AppSpacing.s24 * visualScale,
              ),
          child: child,
        ),
      ),
    );
    if (!scrollable) return content;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Reusable non-semantic brand canvas. The texture is deliberately subtle and
/// must never replace map, media or semantic state imagery.
class PawMateBrandCanvas extends StatelessWidget {
  const PawMateBrandCanvas({
    super.key,
    required this.child,
    this.showTexture = true,
    this.textureOpacity = 0.26,
  });

  static const textureAsset =
      'assets/images/brand/calm_cartographic_texture.png';

  final Widget child;
  final bool showTexture;
  final double textureOpacity;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showTexture)
            ExcludeSemantics(
              child: IgnorePointer(
                child: Opacity(
                  opacity: textureOpacity,
                  child: Image.asset(
                    textureAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
