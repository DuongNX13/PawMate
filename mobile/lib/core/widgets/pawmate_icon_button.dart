import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

enum PawMateIconButtonVariant { standard, tonal, filled, danger }

/// Canonical icon-only action for PawMate surfaces.
///
/// [tooltip] is required because an icon cannot own its accessible name. The
/// visual icon stays 24dp while the interactive surface is always at least
/// 48dp, including disabled and focusable desktop/platform variants.
class PawMateIconButton extends StatelessWidget {
  const PawMateIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.variant = PawMateIconButtonVariant.standard,
    this.focusNode,
    this.autofocus = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final PawMateIconButtonVariant variant;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final colors = _IconButtonColors.resolve(
      context,
      variant,
      enabled: enabled,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
      side: BorderSide(color: colors.border, width: AppBorderWidth.hairline),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      onTap: enabled ? onPressed : null,
      child: ExcludeSemantics(
        child: Tooltip(
          message: tooltip,
          excludeFromSemantics: true,
          child: SizedBox.square(
            dimension: AppControlSize.minTouchTarget,
            child: Material(
              color: colors.background,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? onPressed : null,
                focusNode: focusNode,
                autofocus: autofocus,
                canRequestFocus: enabled,
                customBorder: shape,
                overlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.focused)) {
                    return AppColors.focusOverlay;
                  }
                  if (states.contains(WidgetState.pressed)) {
                    return AppColors.pressedOverlay;
                  }
                  return Colors.transparent;
                }),
                child: Icon(
                  icon,
                  size: AppControlSize.icon,
                  color: colors.foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconButtonColors {
  const _IconButtonColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;

  static _IconButtonColors resolve(
    BuildContext context,
    PawMateIconButtonVariant variant, {
    required bool enabled,
  }) {
    final status = PawMateStatusColors.of(context);
    if (!enabled) {
      return _IconButtonColors(
        background: status.disabledContainer,
        foreground: status.disabledContent,
        border: AppColors.border,
      );
    }
    return switch (variant) {
      PawMateIconButtonVariant.standard => const _IconButtonColors(
        background: Colors.transparent,
        foreground: AppColors.icon,
        border: Colors.transparent,
      ),
      PawMateIconButtonVariant.tonal => const _IconButtonColors(
        background: AppColors.surfaceContainer,
        foreground: AppColors.primary700,
        border: AppColors.border,
      ),
      PawMateIconButtonVariant.filled => const _IconButtonColors(
        background: AppColors.primary500,
        foreground: AppColors.white,
        border: AppColors.primary500,
      ),
      PawMateIconButtonVariant.danger => _IconButtonColors(
        background: status.errorContainer,
        foreground: status.error,
        border: status.error,
      ),
    };
  }
}
