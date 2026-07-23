import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';
import 'pawmate_adaptive.dart';

class PawMateTopBar extends StatelessWidget implements PreferredSizeWidget {
  const PawMateTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = false,
    this.onBack,
    this.leading,
    this.actions = const [],
    this.brandTitle = false,
    this.centerTitle = false,
  });

  final String title;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Widget? leading;
  final List<Widget> actions;
  final bool brandTitle;
  final bool centerTitle;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 64 : 76);

  @override
  Widget build(BuildContext context) {
    const foreground = AppColors.textPrimary;
    final titleWidget = subtitle == null
        ? Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: brandTitle
                ? AppTextStyles.h3(color: AppColors.primary700)
                : AppTextStyles.h4(color: foreground),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: centerTitle
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: brandTitle
                    ? AppTextStyles.h3(color: AppColors.primary700)
                    : AppTextStyles.h4(color: foreground),
              ),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption(),
              ),
            ],
          );

    return AppBar(
      toolbarHeight: preferredSize.height,
      automaticallyImplyLeading: false,
      centerTitle: centerTitle,
      titleSpacing: leading != null || showBackButton ? 0 : AppSpacing.s16,
      leadingWidth: leading != null || showBackButton ? 64 : 0,
      leading:
          leading ??
          (showBackButton
              ? Center(child: PawMateAdaptiveBackButton(onPressed: onBack))
              : null),
      title: Semantics(header: true, child: titleWidget),
      actions: actions,
    );
  }
}
