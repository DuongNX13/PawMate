import 'package:flutter/material.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_chip.dart';
import '../domain/vet_models.dart';

class VetPreviewSheet extends StatelessWidget {
  const VetPreviewSheet({
    super.key,
    required this.vet,
    required this.onViewDetail,
    required this.onGetDirections,
    required this.onCallNow,
  });

  final VetSummary vet;
  final VoidCallback onViewDetail;
  final VoidCallback onGetDirections;
  final VoidCallback onCallNow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            vet.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.h3(),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            vet.address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyCompact(),
          ),
          const SizedBox(height: AppSpacing.s12),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              _MetaPill(
                label: vet.averageRating != null
                    ? '★ ${vet.averageRating!.toStringAsFixed(1)}'
                    : 'Top #${vet.seedRank}',
              ),
              _MetaPill(label: vet.distanceLabel ?? vet.statusLabel),
              _MetaPill(label: '${vet.reviewCount} đánh giá'),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: vet.displayServices
                .take(3)
                .map((service) => _MetaPill(label: service, soft: true))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.s16),
          PawMateButton(
            label: 'Xem chi tiết',
            onPressed: onViewDetail,
            leadingIcon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              Expanded(
                child: PawMateButton(
                  label: 'Chỉ đường',
                  onPressed: onGetDirections,
                  leadingIcon: Icons.directions_outlined,
                  variant: PawMateButtonVariant.secondary,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: PawMateButton(
                  label: 'Gọi ngay',
                  onPressed: onCallNow,
                  leadingIcon: Icons.call_outlined,
                  variant: PawMateButtonVariant.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, this.soft = false});

  final String label;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return PawMateChip(
      label: label,
      variant: soft ? PawMateChipVariant.status : PawMateChipVariant.filter,
      enabled: true,
    );
  }
}
