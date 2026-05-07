import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            vet.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            vet.address,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: vet.displayServices
                .take(3)
                .map((service) => _MetaPill(label: service, soft: true))
                .toList(),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onViewDetail,
              child: const Text('Xem chi tiết'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGetDirections,
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Chỉ đường'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCallNow,
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Gọi ngay'),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: soft ? AppColors.secondarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: soft ? Colors.transparent : AppColors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: soft ? AppColors.secondary500 : AppColors.textSecondary,
        ),
      ),
    );
  }
}
