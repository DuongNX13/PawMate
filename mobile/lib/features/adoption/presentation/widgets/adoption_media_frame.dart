import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../domain/adoption_models.dart';

/// Displays Adoption media without allowing a missing or failed remote image
/// to collapse the layout.
class AdoptionMediaFrame extends StatelessWidget {
  const AdoptionMediaFrame({
    super.key,
    required this.media,
    required this.petName,
    required this.species,
    this.borderRadius = BorderRadius.zero,
    this.imageProvider,
  });

  final AdoptionMedia media;
  final String petName;
  final AdoptionSpecies species;
  final BorderRadius borderRadius;
  final ImageProvider<Object>? imageProvider;

  @override
  Widget build(BuildContext context) {
    final fallback = _MissingMediaPlaceholder(
      petName: petName,
      species: species,
    );
    final url = media.publicUrl;

    return ClipRRect(
      borderRadius: borderRadius,
      child: ColoredBox(
        color: AppColors.surfaceContainer,
        child: imageProvider != null
            ? Image(
                image: imageProvider!,
                fit: BoxFit.cover,
                semanticLabel: 'Ảnh đại diện của $petName',
              )
            : url == null
            ? fallback
            : Image.network(
                url.toString(),
                fit: BoxFit.cover,
                semanticLabel: 'Ảnh đại diện của $petName',
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    return child;
                  }
                  return _LoadingMediaPlaceholder(petName: petName);
                },
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class _LoadingMediaPlaceholder extends StatelessWidget {
  const _LoadingMediaPlaceholder({required this.petName});

  final String petName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Đang tải ảnh của $petName',
      child: const ExcludeSemantics(
        child: Center(
          child: SizedBox.square(
            dimension: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      ),
    );
  }
}

class _MissingMediaPlaceholder extends StatelessWidget {
  const _MissingMediaPlaceholder({
    required this.petName,
    required this.species,
  });

  final String petName;
  final AdoptionSpecies species;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Chưa có ảnh của $petName',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 120 || constraints.maxHeight < 120;
            if (compact) {
              return Center(
                child: Icon(
                  species == AdoptionSpecies.cat
                      ? Icons.cruelty_free_outlined
                      : Icons.pets_outlined,
                  size: 28,
                  color: AppColors.primary700,
                ),
              );
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      species == AdoptionSpecies.cat
                          ? Icons.cruelty_free_outlined
                          : Icons.pets_outlined,
                      size: 48,
                      color: AppColors.primary700,
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      'Chưa có ảnh của $petName',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.brown,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
