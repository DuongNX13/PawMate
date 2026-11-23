import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';

/// Canonical rounded media surface for pet, clinic and rescue imagery.
class PawMateMedia extends StatelessWidget {
  const PawMateMedia({
    super.key,
    required this.semanticLabel,
    this.image,
    this.aspectRatio = AppControlSize.mediaAspectRatio,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius = AppRadius.card,
    this.placeholder,
    this.placeholderIcon = Icons.pets_outlined,
    this.onTap,
  });

  final String semanticLabel;
  final ImageProvider<Object>? image;
  final double aspectRatio;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final double borderRadius;
  final Widget? placeholder;
  final IconData placeholderIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = image == null
        ? _placeholder()
        : Image(
            image: image!,
            fit: fit,
            alignment: alignment,
            width: double.infinity,
            height: double.infinity,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => _placeholder(),
          );
    final radius = BorderRadius.circular(borderRadius);
    final visual = AspectRatio(
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          border: Border.all(
            color: AppColors.border,
            width: AppBorderWidth.hairline,
          ),
          borderRadius: radius,
        ),
        child: ClipRRect(borderRadius: radius, child: content),
      ),
    );
    final interactive = onTap != null;

    return Semantics(
      container: true,
      image: !interactive,
      button: interactive,
      enabled: interactive ? true : null,
      label: semanticLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: interactive
            ? Material(
                color: Colors.transparent,
                borderRadius: radius,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: radius,
                  child: visual,
                ),
              )
            : visual,
      ),
    );
  }

  Widget _placeholder() =>
      placeholder ??
      Center(
        child: Icon(
          placeholderIcon,
          size: AppControlSize.mediaPlaceholderIcon,
          color: AppColors.primary700,
        ),
      );
}
