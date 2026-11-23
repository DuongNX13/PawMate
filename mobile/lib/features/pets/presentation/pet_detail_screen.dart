import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_badge.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_card.dart';
import '../../../core/widgets/pawmate_skeleton.dart';
import '../../../core/widgets/pawmate_state_view.dart';
import '../application/pet_list_provider.dart';
import '../domain/pet_profile.dart';
import 'widgets/pet_avatar_media.dart';

class PetDetailScreen extends ConsumerWidget {
  const PetDetailScreen({required this.petId, super.key});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backendPetsState = ref.watch(petBackendListProvider);
    final cachedPet = ref.watch(petByIdProvider(petId));
    final pet =
        cachedPet ??
        backendPetsState.maybeWhen(
          data: (pets) => _findPetById(pets, petId),
          orElse: () => null,
        );
    if (pet == null) {
      if (backendPetsState.isLoading) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Chi tiết thú cưng',
              style: AppTextStyles.appBarTitle(),
            ),
          ),
          body: const _PetDetailLoadingState(),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: Text('Chi tiết thú cưng', style: AppTextStyles.appBarTitle()),
        ),
        body: PawMateStateView(
          key: Key(
            backendPetsState.hasError
                ? 'pet-detail-error-state'
                : 'pet-detail-empty-state',
          ),
          type: backendPetsState.hasError
              ? PawMateStateType.offline
              : PawMateStateType.empty,
          title: backendPetsState.hasError
              ? 'Chưa đồng bộ được hồ sơ thú cưng'
              : 'Không tìm thấy thú cưng',
          message: backendPetsState.hasError
              ? 'Kiểm tra kết nối rồi thử tải lại hồ sơ.'
              : 'Hồ sơ có thể đã được xóa hoặc không còn khả dụng.',
          primaryActionLabel: backendPetsState.hasError
              ? 'Thử lại'
              : 'Quay lại danh sách',
          onPrimaryAction: backendPetsState.hasError
              ? () => ref.invalidate(petBackendListProvider)
              : () => context.go('/pets/list'),
          secondaryActionLabel: backendPetsState.hasError
              ? 'Quay lại danh sách'
              : null,
          onSecondaryAction: backendPetsState.hasError
              ? () => context.go('/pets/list')
              : null,
        ),
      );
    }

    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          label: 'Hồ sơ thú cưng của ${pet.name}',
          child: ExcludeSemantics(
            child: Text(
              usesExpandedTextLayout ? 'Hồ sơ' : 'Hồ sơ thú cưng',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.appBarTitle(),
            ),
          ),
        ),
        actions: [
          IconButton(
            key: const Key('pet-detail-edit-button'),
            tooltip: 'Chỉnh sửa hồ sơ',
            onPressed: () => context.push(
              Uri(
                path: '/pets/$petId/edit',
                queryParameters: {'returnTo': '/pets/$petId'},
              ).toString(),
            ),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: EdgeInsets.fromLTRB(
            constraints.maxWidth < 360 ? AppSpacing.s16 : AppSpacing.s24,
            AppSpacing.s12,
            constraints.maxWidth < 360 ? AppSpacing.s16 : AppSpacing.s24,
            AppSpacing.s32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            _PetIdentityCard(
              pet: pet,
              species: _toDisplaySpecies(pet.species),
              healthStatus: _toDisplayHealthStatus(pet.healthStatus),
            ),
            const SizedBox(height: AppSpacing.s16),
            Text('Thông tin cơ bản', style: AppTextStyles.h3()),
            const SizedBox(height: AppSpacing.s12),
            _PetInfoGrid(
              items: [
                _PetInfo(
                  icon: Icons.transgender_rounded,
                  label: 'Giới tính',
                  value: _toDisplayGender(pet.gender),
                ),
                _PetInfo(
                  icon: Icons.cake_outlined,
                  label: 'Ngày sinh',
                  value: pet.dateOfBirth == null
                      ? 'Chưa cập nhật'
                      : '${pet.dateOfBirth!.day.toString().padLeft(2, '0')}/${pet.dateOfBirth!.month.toString().padLeft(2, '0')}/${pet.dateOfBirth!.year}',
                ),
                _PetInfo(
                  icon: Icons.monitor_weight_outlined,
                  label: 'Cân nặng',
                  value: pet.weightKg == null
                      ? 'Chưa cập nhật'
                      : '${pet.weightKg!.toStringAsFixed(1)} kg',
                ),
                if (pet.color != null)
                  _PetInfo(
                    icon: Icons.palette_outlined,
                    label: 'Màu lông',
                    value: pet.color!,
                  ),
                if (pet.microchip != null)
                  _PetInfo(
                    icon: Icons.memory_rounded,
                    label: 'Microchip',
                    value: pet.microchip!,
                  ),
                _PetInfo(
                  icon: Icons.health_and_safety_outlined,
                  label: 'Triệt sản',
                  value: pet.isNeutered ? 'Đã triệt sản' : 'Chưa triệt sản',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s24),
            PawMateButton(
              label: 'Quay lại danh sách',
              onPressed: () => context.go('/pets/list'),
              variant: PawMateButtonVariant.secondary,
              leadingIcon: Icons.arrow_back_rounded,
            ),
          ],
        ),
      ),
    );
  }

  String _toDisplaySpecies(String species) {
    switch (species) {
      case 'dog':
        return 'Chó';
      case 'cat':
        return 'Mèo';
      case 'bird':
        return 'Chim';
      case 'rabbit':
        return 'Thỏ';
      default:
        return 'Khác';
    }
  }

  String _toDisplayGender(String gender) {
    switch (gender) {
      case 'male':
        return 'Đực';
      case 'female':
        return 'Cái';
      default:
        return 'Chưa rõ';
    }
  }

  String _toDisplayHealthStatus(String healthStatus) {
    switch (healthStatus) {
      case 'monitoring':
        return 'Cần theo dõi';
      case 'chronic':
        return 'Bệnh mạn tính';
      case 'recovery':
        return 'Đang hồi phục';
      case 'healthy':
        return 'Ổn định';
      default:
        return 'Chưa rõ';
    }
  }
}

PetProfile? _findPetById(List<PetProfile> pets, String petId) {
  for (final pet in pets) {
    if (pet.id == petId) {
      return pet;
    }
  }
  return null;
}

class _PetIdentityCard extends StatelessWidget {
  const _PetIdentityCard({
    required this.pet,
    required this.species,
    required this.healthStatus,
  });

  final PetProfile pet;
  final String species;
  final String healthStatus;

  @override
  Widget build(BuildContext context) {
    return PawMateCard(
      key: const Key('pet-detail-identity-card'),
      variant: PawMateCardVariant.raised,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useRow =
              constraints.maxWidth >= 270 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.3;
          final avatar = Container(
            width: 116,
            height: 116,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.mint, width: 2),
            ),
            child: ClipOval(
              child: SizedBox.expand(
                key: const Key('pet-detail-avatar'),
                child: PetAvatarMedia(
                  source: pet.avatarPath,
                  fit: BoxFit.cover,
                  semanticLabel: 'Ảnh của ${pet.name}',
                  fallback: const ColoredBox(
                    color: AppColors.surfaceContainer,
                    child: Center(
                      child: Icon(
                        Icons.pets_rounded,
                        color: AppColors.primary700,
                        size: 44,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final identity = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: useRow
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Text(
                pet.name,
                textAlign: useRow ? TextAlign.start : TextAlign.center,
                style: AppTextStyles.h2(),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                '$species • ${pet.breed}',
                textAlign: useRow ? TextAlign.start : TextAlign.center,
                style: AppTextStyles.body(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s12),
              PawMateBadge(
                label: healthStatus,
                variant: PawMateBadgeVariant.success,
                icon: Icons.favorite_rounded,
              ),
            ],
          );
          if (!useRow) {
            return Column(
              children: [
                avatar,
                const SizedBox(height: AppSpacing.s16),
                identity,
              ],
            );
          }
          return Row(
            children: [
              avatar,
              const SizedBox(width: AppSpacing.s16),
              Expanded(child: identity),
            ],
          );
        },
      ),
    );
  }
}

class _PetInfo {
  const _PetInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _PetInfoGrid extends StatelessWidget {
  const _PetInfoGrid({required this.items});

  final List<_PetInfo> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns =
            constraints.maxWidth >= 300 &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.3;
        final width = useTwoColumns
            ? (constraints.maxWidth - AppSpacing.s12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: AppSpacing.s12,
          runSpacing: AppSpacing.s12,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _PetInfoTile(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _PetInfoTile extends StatelessWidget {
  const _PetInfoTile({required this.item});

  final _PetInfo item;

  @override
  Widget build(BuildContext context) {
    return PawMateCard(
      variant: PawMateCardVariant.task,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 18, color: AppColors.primary700),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(item.label, style: AppTextStyles.captionStrong()),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(item.value, style: AppTextStyles.body()),
        ],
      ),
    );
  }
}

class _PetDetailLoadingState extends StatelessWidget {
  const _PetDetailLoadingState();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      key: Key('pet-detail-loading-state'),
      padding: EdgeInsets.all(AppSpacing.s24),
      child: Column(
        children: [
          PawMateSkeleton(width: 100, height: 100, circular: true),
          SizedBox(height: AppSpacing.s24),
          PawMateSkeleton(width: 180, height: 24),
          SizedBox(height: AppSpacing.s24),
          PawMateSkeleton(
            width: double.infinity,
            height: 72,
            borderRadius: AppRadius.md,
          ),
          SizedBox(height: AppSpacing.s12),
          PawMateSkeleton(
            width: double.infinity,
            height: 72,
            borderRadius: AppRadius.md,
          ),
        ],
      ),
    );
  }
}
