import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';
import 'pawmate_button.dart';

class PawMateAction {
  const PawMateAction({
    required this.label,
    required this.onPressed,
    this.variant = PawMateButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.trailingIcon,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final PawMateButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final IconData? trailingIcon;
  final String? semanticLabel;
}

/// Responsive action layout shared by fixed and inline CTA groups.
///
/// At normal text scale, short actions may use a horizontal compact visual.
/// Long labels, widths below 320dp, or text scale above 1.3 always switch to a
/// full-width vertical layout with content-driven height.
class PawMateActionCluster extends StatelessWidget {
  const PawMateActionCluster({
    super.key,
    required this.primaryAction,
    this.secondaryAction,
    this.spacing = AppSpacing.s8,
  });

  final PawMateAction primaryAction;
  final PawMateAction? secondaryAction;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final textScaler = MediaQuery.textScalerOf(context);
        final textScale = textScaler.scale(1);
        final hasSecondary = secondaryAction != null;
        final compactCandidate =
            textScale <= AppControlSize.compactButtonMaxTextScale &&
            width < 480;
        final available = math
            .max(0.0, width - (hasSecondary ? spacing : 0))
            .toDouble();
        final primaryWidth = hasSecondary
            ? available * (compactCandidate ? 3 / 5 : 2 / 3)
            : available;
        final secondaryWidth = hasSecondary
            ? available - primaryWidth
            : double.infinity;
        final primaryFits = _actionFitsOneLine(
          context,
          primaryAction,
          maxWidth: primaryWidth,
          compact: compactCandidate,
        );
        final secondaryFits =
            !hasSecondary ||
            _actionFitsOneLine(
              context,
              secondaryAction!,
              maxWidth: secondaryWidth,
              compact: compactCandidate,
            );
        final stack =
            hasSecondary &&
            (width < 320 ||
                textScale > AppControlSize.compactButtonMaxTextScale ||
                !primaryFits ||
                !secondaryFits);
        final useCompactVisual =
            compactCandidate && primaryFits && secondaryFits && !stack;

        if (stack) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAction(primaryAction),
              SizedBox(height: spacing),
              _buildAction(secondaryAction!),
            ],
          );
        }

        if (!hasSecondary) {
          return _buildAction(primaryAction, compact: useCompactVisual);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: compactCandidate ? 2 : 1,
              child: _buildAction(
                secondaryAction!,
                compact: useCompactVisual,
                includeIcon: !useCompactVisual,
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              flex: compactCandidate ? 3 : 2,
              child: _buildAction(
                primaryAction,
                compact: useCompactVisual,
                includeIcon: !useCompactVisual,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAction(
    PawMateAction action, {
    bool compact = false,
    bool includeIcon = true,
  }) {
    return PawMateButton(
      label: action.label,
      onPressed: action.onPressed,
      variant: action.variant,
      isLoading: action.isLoading,
      leadingIcon: includeIcon ? action.icon : null,
      trailingIcon: includeIcon ? action.trailingIcon : null,
      compact: compact,
      semanticLabel: action.semanticLabel,
    );
  }

  bool _actionFitsOneLine(
    BuildContext context,
    PawMateAction action, {
    required double maxWidth,
    required bool compact,
  }) {
    if (!maxWidth.isFinite) return true;
    final horizontalPadding = (compact ? AppSpacing.s12 : AppSpacing.s16) * 2;
    final iconCount = <IconData?>[
      if (action.isLoading) Icons.hourglass_empty else action.icon,
      if (!action.isLoading) action.trailingIcon,
    ].whereType<IconData>().length;
    final labelWidth = math
        .max(
          0.0,
          maxWidth - horizontalPadding - (iconCount * (20 + AppSpacing.s8)),
        )
        .toDouble();
    final style = compact
        ? AppTextStyles.buttonCompact()
        : AppTextStyles.button();
    final painter = TextPainter(
      text: TextSpan(text: action.label, style: style),
      maxLines: 1,
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    )..layout(maxWidth: labelWidth);
    return !painter.didExceedMaxLines;
  }
}

class PawMateFixedCtaBar extends StatelessWidget {
  const PawMateFixedCtaBar({
    super.key,
    required this.primaryAction,
    this.secondaryAction,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.s16,
      AppSpacing.s12,
      AppSpacing.s16,
      AppSpacing.s12,
    ),
  });

  final PawMateAction primaryAction;
  final PawMateAction? secondaryAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final imeBottom = MediaQuery.viewInsetsOf(context).bottom;
    final imeSpacer = math.max(0.0, imeBottom - safeBottom).toDouble();

    return Material(
      color: AppColors.surface,
      elevation: AppElevation.floating,
      shadowColor: AppColors.shadow,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.zero,
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PawMateActionCluster(
                primaryAction: primaryAction,
                secondaryAction: secondaryAction,
                spacing: AppSpacing.s12,
              ),
              if (imeSpacer > 0) SizedBox(height: imeSpacer),
            ],
          ),
        ),
      ),
    );
  }
}
