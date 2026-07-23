import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_navigation.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
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
          primaryActionLabel: backendPetsState.hasError ? 'Thử lại' : null,
          onPrimaryAction: backendPetsState.hasError
              ? () => ref.invalidate(petBackendListProvider)
              : null,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          pet.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.appBarTitle(),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s24,
          AppSpacing.s16,
          AppSpacing.s24,
          AppSpacing.s32,
        ),
        children: [
          Center(
            child: ClipOval(
              child: SizedBox.square(
                key: const Key('pet-detail-avatar'),
                dimension: 100,
                child: PetAvatarMedia(
                  source: pet.avatarPath,
                  fit: BoxFit.cover,
                  semanticLabel: 'Ảnh của ${pet.name}',
                  fallback: const ColoredBox(
                    color: AppColors.careGreenSoft,
                    child: Center(
                      child: Icon(
                        Icons.pets_rounded,
                        color: AppColors.careGreen,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '${_toDisplaySpecies(pet.species)} • ${pet.breed}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyStrong(),
            ),
          ),
          const SizedBox(height: 24),
          _InfoTile(label: 'Giới tính', value: _toDisplayGender(pet.gender)),
          _InfoTile(
            label: 'Ngày sinh',
            value: pet.dateOfBirth == null
                ? 'Chưa cập nhật'
                : '${pet.dateOfBirth!.day}/${pet.dateOfBirth!.month}/${pet.dateOfBirth!.year}',
          ),
          _InfoTile(
            label: 'Cân nặng',
            value: pet.weightKg == null
                ? 'Chưa cập nhật'
                : '${pet.weightKg!.toStringAsFixed(1)} kg',
          ),
          _InfoTile(
            label: 'Tình trạng sức khỏe',
            value: _toDisplayHealthStatus(pet.healthStatus),
          ),
          if (pet.color != null) _InfoTile(label: 'Màu sắc', value: pet.color!),
          if (pet.microchip != null)
            _InfoTile(label: 'Microchip', value: pet.microchip!),
          _InfoTile(
            label: 'Trạng thái triệt sản',
            value: pet.isNeutered ? 'Đã triệt sản' : 'Chưa triệt sản',
          ),
          const SizedBox(height: 24),
          PawMateButton(
            label: 'Quay lại danh sách',
            onPressed: () => PawMateNavigation.backOrGo(context, '/pets/list'),
            variant: PawMateButtonVariant.secondary,
            leadingIcon: Icons.arrow_back_rounded,
          ),
        ],
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return PawMateCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.captionStrong()),
          const SizedBox(height: AppSpacing.s4),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(),
          ),
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
