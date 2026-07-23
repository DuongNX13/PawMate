import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';

enum PawMateToastType { info, success, warning, error }

class PawMateToast {
  const PawMateToast._();

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    PawMateToastType type = PawMateToastType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final presentation = _ToastPresentation.resolve(
      type,
      PawMateStatusColors.of(context),
    );
    return messenger.showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: presentation.background,
        content: Semantics(
          liveRegion: true,
          label: message,
          child: Row(
            children: [
              Icon(presentation.icon, color: presentation.foreground),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.bodyCompact(
                    color: presentation.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: presentation.foreground,
                onPressed: onAction,
              ),
      ),
    );
  }
}

class _ToastPresentation {
  const _ToastPresentation({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  static _ToastPresentation resolve(
    PawMateToastType type,
    PawMateStatusColors colors,
  ) => switch (type) {
    PawMateToastType.info => _ToastPresentation(
      icon: Icons.info_outline,
      background: colors.info,
      foreground: AppColors.white,
    ),
    PawMateToastType.success => _ToastPresentation(
      icon: Icons.check_circle_outline,
      background: colors.success,
      foreground: AppColors.white,
    ),
    PawMateToastType.warning => _ToastPresentation(
      icon: Icons.warning_amber_rounded,
      background: colors.warningContainer,
      foreground: colors.warning,
    ),
    PawMateToastType.error => _ToastPresentation(
      icon: Icons.error_outline,
      background: colors.error,
      foreground: AppColors.white,
    ),
  };
}
