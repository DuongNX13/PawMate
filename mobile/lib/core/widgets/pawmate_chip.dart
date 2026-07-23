import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';

enum PawMateChipVariant { filter, choice, status }

class PawMateChip extends StatelessWidget {
  const PawMateChip({
    super.key,
    required this.label,
    this.onPressed,
    this.selected = false,
    this.enabled = true,
    this.variant = PawMateChipVariant.filter,
    this.leadingIcon,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool selected;
  final bool enabled;
  final PawMateChipVariant variant;
  final IconData? leadingIcon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && onPressed != null;
    final colors = _resolveColors(context);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: 16, color: colors.foreground),
          const SizedBox(width: AppSpacing.s4),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.micro(color: colors.foreground),
          ),
        ),
      ],
    );

    return Semantics(
      button: onPressed != null,
      enabled: enabled,
      selected: selected,
      label: semanticLabel ?? label,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppControlSize.minTouchTarget,
            minWidth: AppControlSize.minTouchTarget,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: InkWell(
              onTap: interactive ? onPressed : null,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Center(
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: AppMotion.standardCurve,
                  constraints: const BoxConstraints(
                    minHeight: AppControlSize.chipHeight,
                    minWidth: AppControlSize.chipHeight,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.background,
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  alignment: Alignment.center,
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ChipColors _resolveColors(BuildContext context) {
    final status = PawMateStatusColors.of(context);
    if (!enabled) {
      return _ChipColors(
        background: status.disabledContainer,
        foreground: status.disabledContent,
        border: AppColors.border,
      );
    }
    if (selected) {
      return const _ChipColors(
        background: AppColors.primary500,
        foreground: Colors.white,
        border: AppColors.primary500,
      );
    }
    if (variant == PawMateChipVariant.status) {
      return _ChipColors(
        background: status.successContainer,
        foreground: status.success,
        border: status.success,
      );
    }
    return const _ChipColors(
      background: AppColors.surface,
      foreground: AppColors.textSecondary,
      border: AppColors.borderStrong,
    );
  }
}

class _ChipColors {
  const _ChipColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}
