import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

enum PawMateCardVariant { object, task, raised }

class PawMateCard extends StatelessWidget {
  const PawMateCard({
    super.key,
    required this.child,
    this.variant = PawMateCardVariant.object,
    this.onTap,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(AppSpacing.s16),
    this.margin = EdgeInsets.zero,
    this.backgroundColor,
  });

  final Widget child;
  final PawMateCardVariant variant;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final fill =
        backgroundColor ??
        switch (variant) {
          PawMateCardVariant.object => AppColors.surface,
          PawMateCardVariant.task => AppColors.surfaceMuted,
          PawMateCardVariant.raised => AppColors.surface,
        };
    final decoration = BoxDecoration(
      color: fill,
      border: Border.all(
        color: AppColors.border,
        width: AppBorderWidth.hairline,
      ),
      borderRadius: BorderRadius.circular(AppRadius.md),
      boxShadow: variant == PawMateCardVariant.raised
          ? AppShadows.raised
          : null,
    );

    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: content,
        ),
      );
    }

    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      child: Container(
        margin: margin,
        clipBehavior: Clip.antiAlias,
        decoration: decoration,
        child: content,
      ),
    );
  }
}
