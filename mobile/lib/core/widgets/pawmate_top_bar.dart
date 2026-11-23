import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';
import 'pawmate_adaptive.dart';

class PawMateTopBar extends StatelessWidget implements PreferredSizeWidget {
  const PawMateTopBar({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.showBackButton = false,
    this.onBack,
    this.leading,
    this.leadingWidth,
    this.titleSpacing,
    this.actions = const [],
    this.brandTitle = false,
    this.titleColor,
    this.titleStyle,
    this.semanticTitle,
    this.centerTitle = false,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Widget? leading;
  final double? leadingWidth;
  final double? titleSpacing;
  final List<Widget> actions;
  final bool brandTitle;
  final Color? titleColor;
  final TextStyle? titleStyle;
  final String? semanticTitle;
  final bool centerTitle;

  @override
  Size get preferredSize {
    final supportingLines =
        (eyebrow == null ? 0 : 1) + (subtitle == null ? 0 : 1);
    return Size.fromHeight(
      supportingLines == 0
          ? 64
          : supportingLines == 1
          ? 76
          : 92,
    );
  }

  @override
  Widget build(BuildContext context) {
    const foreground = AppColors.textPrimary;
    final titleWidget = eyebrow == null && subtitle == null
        ? Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                titleStyle ??
                (brandTitle
                    ? AppTextStyles.h3(color: AppColors.primary700)
                    : AppTextStyles.h4(color: titleColor ?? foreground)),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: centerTitle
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              if (eyebrow != null)
                Text(
                  eyebrow!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label(color: AppColors.primary700),
                ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    titleStyle ??
                    (brandTitle
                        ? AppTextStyles.h3(color: AppColors.primary700)
                        : AppTextStyles.h4(color: titleColor ?? foreground)),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(),
                ),
            ],
          );

    final stackedOffset = eyebrow == null ? Offset.zero : const Offset(0, -10);
    return AppBar(
      toolbarHeight: preferredSize.height,
      automaticallyImplyLeading: false,
      centerTitle: centerTitle,
      titleSpacing:
          titleSpacing ??
          (leading != null || showBackButton ? 0 : AppSpacing.s16),
      leadingWidth: leading != null || showBackButton
          ? (leadingWidth ?? 64)
          : 0,
      leading:
          leading ??
          (showBackButton
              ? Transform.translate(
                  offset: stackedOffset,
                  child: Center(
                    child: PawMateAdaptiveBackButton(onPressed: onBack),
                  ),
                )
              : null),
      title: Transform.translate(
        offset: stackedOffset,
        child: semanticTitle == null
            ? Semantics(header: true, child: titleWidget)
            : Semantics(
                header: true,
                label: semanticTitle,
                child: ExcludeSemantics(child: titleWidget),
              ),
      ),
      actions: actions,
    );
  }
}
