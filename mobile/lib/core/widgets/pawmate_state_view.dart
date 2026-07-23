import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';
import 'pawmate_button.dart';

enum PawMateStateType { empty, error, offline, success }

class PawMateStateView extends StatelessWidget {
  const PawMateStateView({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    this.illustration,
    this.icon,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final PawMateStateType type;
  final String title;
  final String message;
  final Widget? illustration;
  final IconData? icon;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final presentation = _StatePresentation.resolve(
      type,
      colors: PawMateStatusColors.of(context),
      overrideIcon: icon,
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      liveRegion: type != PawMateStateType.empty,
      label: '$title. $message',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child:
                      illustration ??
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          color: presentation.background,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          presentation.icon,
                          size: 48,
                          color: presentation.foreground,
                        ),
                      ),
                ),
                const SizedBox(height: AppSpacing.s24),
                ExcludeSemantics(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h3(),
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                ExcludeSemantics(
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyCompact(),
                  ),
                ),
                if (primaryActionLabel != null) ...[
                  const SizedBox(height: AppSpacing.s24),
                  PawMateButton(
                    label: primaryActionLabel!,
                    onPressed: onPrimaryAction,
                    leadingIcon:
                        type == PawMateStateType.error ||
                            type == PawMateStateType.offline
                        ? Icons.refresh
                        : null,
                  ),
                ],
                if (secondaryActionLabel != null) ...[
                  const SizedBox(height: AppSpacing.s8),
                  PawMateButton(
                    label: secondaryActionLabel!,
                    onPressed: onSecondaryAction,
                    variant: PawMateButtonVariant.ghost,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatePresentation {
  const _StatePresentation({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  static _StatePresentation resolve(
    PawMateStateType type, {
    required PawMateStatusColors colors,
    IconData? overrideIcon,
  }) => switch (type) {
    PawMateStateType.empty => _StatePresentation(
      icon: overrideIcon ?? Icons.pets_outlined,
      background: colors.infoContainer,
      foreground: colors.info,
    ),
    PawMateStateType.error => _StatePresentation(
      icon: overrideIcon ?? Icons.error_outline,
      background: colors.errorContainer,
      foreground: colors.error,
    ),
    PawMateStateType.offline => _StatePresentation(
      icon: overrideIcon ?? Icons.cloud_off_outlined,
      background: colors.warningContainer,
      foreground: colors.offline,
    ),
    PawMateStateType.success => _StatePresentation(
      icon: overrideIcon ?? Icons.check_circle_outline,
      background: colors.successContainer,
      foreground: colors.success,
    ),
  };
}
