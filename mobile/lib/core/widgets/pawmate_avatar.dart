import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';

/// Circular, center-cropped avatar with a deterministic text fallback.
class PawMateAvatar extends StatelessWidget {
  const PawMateAvatar({
    super.key,
    required this.semanticLabel,
    required this.fallbackText,
    this.image,
    this.size = AppControlSize.avatar,
    this.onTap,
    this.showBorder = true,
  });

  final String semanticLabel;
  final String fallbackText;
  final ImageProvider<Object>? image;
  final double size;
  final VoidCallback? onTap;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final visual = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: AppColors.borderStrong,
                width: AppBorderWidth.hairline,
              )
            : null,
      ),
      child: image == null
          ? _AvatarFallback(text: fallbackText)
          : Image(
              image: image!,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => _AvatarFallback(text: fallbackText),
            ),
    );
    final interactive = onTap != null;
    final surface = ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: AppControlSize.minTouchTarget,
        minHeight: AppControlSize.minTouchTarget,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return AppColors.focusOverlay;
            }
            if (states.contains(WidgetState.pressed)) {
              return AppColors.pressedOverlay;
            }
            return Colors.transparent;
          }),
          child: Center(child: visual),
        ),
      ),
    );

    return Semantics(
      container: true,
      image: !interactive,
      button: interactive,
      enabled: interactive ? true : null,
      label: semanticLabel,
      onTap: onTap,
      child: ExcludeSemantics(child: surface),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text.trim().isEmpty ? '?' : text.trim().characters.first.toUpperCase(),
      style: AppTextStyles.bodyStrong(color: AppColors.primary700),
    ),
  );
}
