import 'package:flutter/material.dart';
import 'package:pawmate_mobile/app/theme/app_text_styles.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_ui.dart';

/// Executable catalog for the Day 82 PawMate shared-primitives contract.
///
/// This is test support, not a production route. It keeps every primitive in
/// one deterministic composition so focused tests can catch token, semantics
/// and large-text regressions without changing the application shell.
class Day82ComponentCatalog extends StatelessWidget {
  const Day82ComponentCatalog({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        Text('PawMate primitives', style: AppTextStyles.h2()),
        const SizedBox(height: AppSpacing.s16),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            PawMateIconButton(
              icon: Icons.notifications_outlined,
              tooltip: 'Thông báo',
              onPressed: _noOp,
            ),
            PawMateIconButton(
              icon: Icons.favorite_outline,
              tooltip: 'Yêu thích',
              variant: PawMateIconButtonVariant.tonal,
              onPressed: _noOp,
            ),
            const PawMateIconButton(
              icon: Icons.delete_outline,
              tooltip: 'Xóa',
              variant: PawMateIconButtonVariant.danger,
              onPressed: null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        PawMateButton(label: 'Lưu hồ sơ', onPressed: _noOp),
        const SizedBox(height: AppSpacing.s8),
        PawMateButton(
          label: 'Xem thông tin chi tiết',
          onPressed: _noOp,
          variant: PawMateButtonVariant.secondary,
        ),
        const SizedBox(height: AppSpacing.s16),
        const PawMateTextField(
          label: 'Tên thú cưng',
          hintText: 'Ví dụ: Mochi',
          isRequired: true,
        ),
        const SizedBox(height: AppSpacing.s16),
        PawMateCard(
          semanticLabel: 'Hồ sơ Mochi',
          onTap: _noOp,
          child: const Row(
            children: [
              PawMateAvatar(
                semanticLabel: 'Ảnh đại diện của Mochi',
                fallbackText: 'M',
              ),
              SizedBox(width: AppSpacing.s12),
              Expanded(child: Text('Mochi — khỏe mạnh và vui vẻ')),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        const PawMateMedia(
          semanticLabel: 'Ảnh minh họa thú cưng',
          placeholderIcon: Icons.pets_outlined,
        ),
        const SizedBox(height: AppSpacing.s16),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            PawMateChip(label: 'Tất cả', selected: true, onPressed: _noOp),
            PawMateChip(label: 'Vaccine', onPressed: _noOp),
            const PawMateBadge(
              label: 'Đã xác minh',
              variant: PawMateBadgeVariant.success,
              icon: Icons.verified_outlined,
            ),
            const PawMateBadge(
              label: 'Cần chú ý',
              variant: PawMateBadgeVariant.warning,
              icon: Icons.error_outline,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        const PawMateStatus(
          label: 'Trạng thái hồ sơ',
          value: PawMateStatusValue.success,
        ),
        const SizedBox(height: AppSpacing.s16),
        const Row(
          children: [
            PawMateSkeleton(
              width: 48,
              height: 48,
              circular: true,
              animate: false,
            ),
            SizedBox(width: AppSpacing.s12),
            Expanded(
              child: PawMateSkeleton(
                width: double.infinity,
                height: 48,
                animate: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        PawMateStateView(
          type: PawMateStateType.empty,
          title: 'Chưa có dữ liệu',
          message: 'Thêm hồ sơ đầu tiên để bắt đầu chăm sóc bé.',
          primaryActionLabel: 'Thêm hồ sơ',
          onPrimaryAction: _noOp,
        ),
      ],
    );
  }
}

void _noOp() {}
