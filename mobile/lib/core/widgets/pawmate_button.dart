import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';

enum PawMateButtonVariant { primary, secondary, ghost, danger }

class PawMateButton extends StatelessWidget {
  const PawMateButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PawMateButtonVariant.primary,
    this.isLoading = false,
    this.leadingIcon,
    this.trailingIcon,
    this.fullWidth = true,
    this.compact = false,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final PawMateButtonVariant variant;
  final bool isLoading;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool fullWidth;

  /// Requests the 36dp visual treatment.
  ///
  /// The visible control is compact only when the label fits one line and the
  /// text scale is at most 1.3. Its semantic/tap target always remains at least
  /// 48dp. Larger text automatically gets an unconstrained-height button.
  final bool compact;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final colors = _ButtonColors.resolve(context, variant, enabled: enabled);
    final textScaler = MediaQuery.textScalerOf(context);
    final textScale = textScaler.scale(1);

    Widget buildButton(BoxConstraints constraints) {
      final labelStyle = compact
          ? AppTextStyles.buttonCompact(color: colors.foreground)
          : AppTextStyles.button(color: colors.foreground);
      final compactVisual =
          compact &&
          textScale <= AppControlSize.compactButtonMaxTextScale &&
          _fitsOneLine(
            label,
            style: labelStyle,
            textScaler: textScaler,
            maxWidth: _labelWidth(constraints),
            textDirection: Directionality.of(context),
          );
      final labelText = Text(
        label,
        maxLines: compactVisual ? 1 : null,
        softWrap: !compactVisual,
        textAlign: TextAlign.center,
        style: labelStyle,
      );
      final content = Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: AppBorderWidth.focus,
                color: colors.foreground,
              ),
            )
          else if (leadingIcon != null)
            Icon(leadingIcon, size: 20, color: colors.foreground),
          if (isLoading || leadingIcon != null)
            const SizedBox(width: AppSpacing.s8),
          Flexible(fit: FlexFit.loose, child: labelText),
          if (!isLoading && trailingIcon != null) ...[
            const SizedBox(width: AppSpacing.s8),
            Icon(trailingIcon, size: 20, color: colors.foreground),
          ],
        ],
      );
      final visual = AnimatedContainer(
        duration: AppMotion.standard,
        curve: AppMotion.standardCurve,
        width: fullWidth ? double.infinity : null,
        constraints: BoxConstraints(
          minWidth: AppControlSize.minTouchTarget,
          minHeight: compactVisual
              ? AppControlSize.compactButtonVisualHeight
              : AppControlSize.buttonHeight,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.s12 : AppSpacing.s16,
          vertical: compactVisual ? 0 : AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(
            color: colors.border,
            width: AppBorderWidth.hairline,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: enabled && variant == PawMateButtonVariant.primary
              ? AppShadows.soft
              : null,
        ),
        alignment: Alignment.center,
        child: content,
      );
      final tapSurface = ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: AppControlSize.minTouchTarget,
          minHeight: AppControlSize.minTouchTarget,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            focusNode: focusNode,
            autofocus: autofocus,
            canRequestFocus: enabled,
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.focused)) {
                return AppColors.focusOverlay;
              }
              if (states.contains(WidgetState.pressed)) {
                return AppColors.pressedOverlay;
              }
              return Colors.transparent;
            }),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Center(child: visual),
          ),
        ),
      );

      return fullWidth
          ? SizedBox(width: double.infinity, child: tapSurface)
          : IntrinsicWidth(child: tapSurface);
    }

    final button = fullWidth
        ? LayoutBuilder(
            builder: (context, constraints) => buildButton(constraints),
          )
        : buildButton(const BoxConstraints());
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      value: isLoading ? 'Đang xử lý' : null,
      liveRegion: isLoading,
      onTap: enabled ? onPressed : null,
      child: ExcludeSemantics(child: button),
    );
  }

  double _labelWidth(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth) return double.infinity;
    final iconCount = <IconData?>[
      if (isLoading) Icons.hourglass_empty else leadingIcon,
      if (!isLoading) trailingIcon,
    ].whereType<IconData>().length;
    final iconWidth = iconCount * 20.0;
    final gaps = iconCount * AppSpacing.s8;
    final horizontalPadding = (compact ? AppSpacing.s12 : AppSpacing.s16) * 2;
    return math
        .max(0.0, constraints.maxWidth - iconWidth - gaps - horizontalPadding)
        .toDouble();
  }
}

bool _fitsOneLine(
  String text, {
  required TextStyle style,
  required TextScaler textScaler,
  required double maxWidth,
  required TextDirection textDirection,
}) {
  if (!maxWidth.isFinite) return true;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textScaler: textScaler,
    textDirection: textDirection,
  )..layout(maxWidth: maxWidth);
  return !painter.didExceedMaxLines;
}

class _ButtonColors {
  const _ButtonColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;

  static _ButtonColors resolve(
    BuildContext context,
    PawMateButtonVariant variant, {
    required bool enabled,
  }) {
    final status = PawMateStatusColors.of(context);
    if (!enabled) {
      return _ButtonColors(
        background: status.disabledContainer,
        foreground: status.disabledContent,
        border: AppColors.border,
      );
    }

    return switch (variant) {
      PawMateButtonVariant.primary => const _ButtonColors(
        background: AppColors.primary500,
        foreground: AppColors.white,
        border: AppColors.primary500,
      ),
      PawMateButtonVariant.secondary => const _ButtonColors(
        background: AppColors.surface,
        foreground: AppColors.primary700,
        border: AppColors.borderStrong,
      ),
      PawMateButtonVariant.ghost => const _ButtonColors(
        background: Colors.transparent,
        foreground: AppColors.primary700,
        border: Colors.transparent,
      ),
      PawMateButtonVariant.danger => _ButtonColors(
        background: status.error,
        foreground: AppColors.white,
        border: status.error,
      ),
    };
  }
}
