import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';

enum PawMateStatusValue {
  neutral,
  attention,
  success,
  error,
  unresolved,
  resolved,
}

class PawMateStatus extends StatelessWidget {
  const PawMateStatus({
    super.key,
    required this.label,
    required this.value,
    this.text,
  });

  final String label;
  final PawMateStatusValue value;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final presentation = _StatusPresentation.resolve(
      value,
      colors: PawMateStatusColors.of(context),
      text: text,
    );
    return Semantics(
      container: true,
      label: '$label: ${presentation.text}',
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
            color: presentation.background,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(presentation.icon, size: 16, color: presentation.foreground),
              const SizedBox(width: AppSpacing.s4),
              Flexible(
                child: Text(
                  presentation.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.captionStrong(
                    color: presentation.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPresentation {
  const _StatusPresentation({
    required this.text,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String text;
  final IconData icon;
  final Color background;
  final Color foreground;

  static _StatusPresentation resolve(
    PawMateStatusValue value, {
    required PawMateStatusColors colors,
    String? text,
  }) => switch (value) {
    PawMateStatusValue.neutral => _StatusPresentation(
      text: text ?? 'Thông tin',
      icon: Icons.info_outline,
      background: colors.infoContainer,
      foreground: colors.info,
    ),
    PawMateStatusValue.attention => _StatusPresentation(
      text: text ?? 'Cần chú ý',
      icon: Icons.error_outline,
      background: colors.warningContainer,
      foreground: colors.warning,
    ),
    PawMateStatusValue.success => _StatusPresentation(
      text: text ?? 'Thành công',
      icon: Icons.check_circle_outline,
      background: colors.successContainer,
      foreground: colors.success,
    ),
    PawMateStatusValue.error => _StatusPresentation(
      text: text ?? 'Có lỗi',
      icon: Icons.error_outline,
      background: colors.errorContainer,
      foreground: colors.error,
    ),
    PawMateStatusValue.unresolved => _StatusPresentation(
      text: text ?? 'Chưa thấy',
      icon: Icons.search,
      background: colors.warningContainer,
      foreground: colors.warning,
    ),
    PawMateStatusValue.resolved => _StatusPresentation(
      text: text ?? 'Đã thấy',
      icon: Icons.check_circle,
      background: colors.successContainer,
      foreground: colors.success,
    ),
  };
}
