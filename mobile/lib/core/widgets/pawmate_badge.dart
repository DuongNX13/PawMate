import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';

enum PawMateBadgeVariant { neutral, info, success, warning, error }

/// Non-interactive semantic label for statuses and compact metadata.
class PawMateBadge extends StatelessWidget {
  const PawMateBadge({
    super.key,
    required this.label,
    this.variant = PawMateBadgeVariant.neutral,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final PawMateBadgeVariant variant;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = _BadgeColors.resolve(
      variant,
      status: PawMateStatusColors.of(context),
    );
    return Semantics(
      container: true,
      label: semanticLabel ?? label,
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppControlSize.chipHeight,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s4,
          ),
          decoration: BoxDecoration(
            color: colors.background,
            border: Border.all(
              color: colors.border,
              width: AppBorderWidth.hairline,
            ),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: AppControlSize.iconSmall,
                  color: colors.foreground,
                ),
                const SizedBox(width: AppSpacing.s4),
              ],
              Flexible(
                child: Text(
                  label,
                  softWrap: true,
                  style: AppTextStyles.captionStrong(color: colors.foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeColors {
  const _BadgeColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;

  static _BadgeColors resolve(
    PawMateBadgeVariant variant, {
    required PawMateStatusColors status,
  }) => switch (variant) {
    PawMateBadgeVariant.neutral => const _BadgeColors(
      background: AppColors.surfaceVariant,
      foreground: AppColors.textSecondary,
      border: AppColors.border,
    ),
    PawMateBadgeVariant.info => _BadgeColors(
      background: status.infoContainer,
      foreground: status.info,
      border: status.info,
    ),
    PawMateBadgeVariant.success => _BadgeColors(
      background: status.successContainer,
      foreground: status.success,
      border: status.success,
    ),
    PawMateBadgeVariant.warning => _BadgeColors(
      background: status.warningContainer,
      foreground: status.warning,
      border: status.warning,
    ),
    PawMateBadgeVariant.error => _BadgeColors(
      background: status.errorContainer,
      foreground: status.error,
      border: status.error,
    ),
  };
}
