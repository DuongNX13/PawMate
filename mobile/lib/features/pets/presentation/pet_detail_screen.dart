import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_badge.dart';
import '../../../core/widgets/pawmate_button.dart';
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

    void openEdit() => context.push(
      Uri(
        path: '/pets/$petId/edit',
        queryParameters: {'returnTo': '/pets/$petId'},
      ).toString(),
    );
    final microchip = pet.microchip?.trim();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.creamTile,
        title: Semantics(
          header: true,
          label: 'Hồ sơ thú cưng của ${pet.name}',
          child: ExcludeSemantics(
            child: Text(
              'Hồ sơ của ${pet.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.appBarTitle(color: AppColors.deepTeal),
            ),
          ),
        ),
        actions: [
          IconButton(
            key: const Key('pet-detail-edit-button'),
            tooltip: 'Chỉnh sửa hồ sơ',
            color: AppColors.deepTeal,
            onPressed: openEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      backgroundColor: AppColors.creamTile,
      body: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: EdgeInsets.fromLTRB(
            constraints.maxWidth < 360 ? AppSpacing.s16 : 22,
            AppSpacing.s12,
            constraints.maxWidth < 360 ? AppSpacing.s16 : 22,
            AppSpacing.s32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            _PetIdentityHeader(
              pet: pet,
              subtitle: _subtitle(pet),
              healthStatus: _toDisplayHealthStatus(pet.healthStatus),
            ),
            const SizedBox(height: AppSpacing.s24),
            Text(
              'Thông tin sức khỏe',
              style: AppTextStyles.bodyStrong(color: AppColors.deepTeal),
            ),
            const SizedBox(height: AppSpacing.s8),
            _HealthFactsCard(
              items: [
                _PetInfo(
                  icon: Icons.calendar_today_outlined,
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
                _PetInfo(
                  icon: Icons.favorite_border_rounded,
                  label: 'Tình trạng',
                  value: _toDisplayHealthStatus(pet.healthStatus),
                ),
                _PetInfo(
                  icon: Icons.health_and_safety_outlined,
                  label: 'Triệt sản',
                  value: pet.isNeutered ? 'Đã triệt sản' : 'Chưa triệt sản',
                ),
                if (pet.color != null)
                  _PetInfo(
                    icon: Icons.palette_outlined,
                    label: 'Màu lông',
                    value: pet.color!,
                  ),
              ],
            ),
            if (microchip != null && microchip.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s24),
              _MicrochipCard(code: microchip),
            ],
            const SizedBox(height: AppSpacing.s24),
            PawMateButton(
              label: 'Chỉnh sửa hồ sơ',
              onPressed: openEdit,
              leadingIcon: Icons.edit_outlined,
            ),
            const SizedBox(height: AppSpacing.s8),
            Center(
              child: TextButton(
                onPressed: () => context.go('/pets/list'),
                child: const Text('Quay lại danh sách thú cưng'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(PetProfile pet) {
    final breed = pet.breed.trim();
    final parts = [
      breed.isEmpty ? _toDisplaySpecies(pet.species) : breed,
      _toDisplayGender(pet.gender),
      if (pet.dateOfBirth != null) _age(pet.dateOfBirth!),
    ];
    return parts.join(' · ');
  }

  String _age(DateTime dob) {
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    if (years >= 1) return '$years tuổi';
    final months = (now.year - dob.year) * 12 + now.month - dob.month;
    return '${months < 1 ? 1 : months} tháng';
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

class _PetIdentityHeader extends StatelessWidget {
  const _PetIdentityHeader({
    required this.pet,
    required this.subtitle,
    required this.healthStatus,
  });

  final PetProfile pet;
  final String subtitle;
  final String healthStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('pet-detail-identity-card'),
      children: [
        Container(
          width: 152,
          height: 152,
          padding: const EdgeInsets.all(7),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(color: AppColors.healthHeroSoft, blurRadius: 40),
            ],
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
                      size: 52,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        PawMateBadge(
          label: healthStatus,
          variant: PawMateBadgeVariant.success,
          icon: Icons.verified_rounded,
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          pet.name,
          textAlign: TextAlign.center,
          style: AppTextStyles.h2(color: AppColors.deepTeal),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption(),
        ),
      ],
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

class _HealthFactsCard extends StatelessWidget {
  const _HealthFactsCard({required this.items});

  final List<_PetInfo> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pet-detail-health-facts'),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns =
              constraints.maxWidth >= 300 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.3;
          final width = twoColumns
              ? (constraints.maxWidth - AppSpacing.s16) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: AppSpacing.s16,
            runSpacing: AppSpacing.s16,
            children: [
              for (final item in items)
                SizedBox(
                  width: width,
                  child: _FactTile(item: item),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.item});

  final _PetInfo item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconSquare(icon: item.icon, size: 40),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label, style: AppTextStyles.caption()),
              const SizedBox(height: AppSpacing.s4),
              Text(item.value, style: AppTextStyles.bodyStrong()),
            ],
          ),
        ),
      ],
    );
  }
}

class _IconSquare extends StatelessWidget {
  const _IconSquare({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.healthHeroSoft,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Icon(icon, size: size * 0.55, color: AppColors.deepTeal),
  );
}

class _MicrochipCard extends StatelessWidget {
  const _MicrochipCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pet-detail-microchip-card'),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          const _IconSquare(icon: Icons.qr_code_2_rounded, size: 56),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mã Microchip', style: AppTextStyles.caption()),
                const SizedBox(height: AppSpacing.s4),
                Text(code, style: AppTextStyles.bodyStrong()),
              ],
            ),
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
