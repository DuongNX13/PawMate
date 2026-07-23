import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_bottom_nav.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../auth/application/auth_session_coordinator.dart';
import '../../auth/data/auth_api.dart';
import '../../pets/application/pet_list_provider.dart';
import '../../pets/domain/pet_profile.dart';
import '../../pets/presentation/widgets/pet_avatar_media.dart';

final profileSessionProvider = authSessionSnapshotProvider;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(profileSessionProvider);
    final petsState = ref.watch(petBackendListProvider);
    final cachedPets = ref.watch(petListProvider);
    final pets = petsState.maybeWhen(
      data: (items) => items,
      orElse: () => cachedPets,
    );
    final selectedPetId = ref.watch(selectedPetIdProvider);

    return Scaffold(
      bottomNavigationBar: const PawMateBottomNav(currentRoute: '/profile'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 112),
          children: [
            _ProfileTopBar(
              onSettings: () => context.push('/profile/controls'),
              onNotifications: () =>
                  context.go('/notifications?returnTo=%2Fprofile'),
            ),
            const SizedBox(height: 24),
            sessionState.when(
              loading: () => const _ProfileHeroCard(
                email: 'Đang tải tài khoản',
                displayName: 'PawMate',
                verified: false,
                onEdit: null,
              ),
              error: (_, _) => _ProfileHeroCard(
                email: 'Chưa xác định',
                displayName: 'Người dùng PawMate',
                verified: false,
                onEdit: () => context.push('/profile/controls'),
              ),
              data: (session) => _ProfileHeroCard(
                email: session?.user.email ?? 'Chưa đăng nhập',
                displayName:
                    session?.user.displayName?.trim().isNotEmpty == true
                    ? session!.user.displayName!
                    : 'Người dùng PawMate',
                verified: session?.user.emailVerified ?? false,
                onEdit: () => context.push('/profile/controls'),
              ),
            ),
            const SizedBox(height: 28),
            Text('Thú cưng của tôi', style: AppTextStyles.h4()),
            const SizedBox(height: 18),
            if (pets.isEmpty && petsState.isLoading)
              const _PetPreviewStatus(
                key: Key('profile-pets-loading-state'),
                title: 'Đang tải thú cưng',
                message: 'PawMate đang đồng bộ danh sách thú cưng của bạn.',
                icon: Icons.sync_rounded,
              )
            else if (pets.isEmpty && petsState.hasError)
              _PetPreviewStatus(
                key: const Key('profile-pets-error-state'),
                title: 'Chưa tải được thú cưng',
                message: 'Kiểm tra mạng rồi thử lại sau.',
                icon: Icons.cloud_off_outlined,
                onRetry: () => ref.invalidate(petBackendListProvider),
              )
            else
              _PetPreviewGrid(
                pets: pets,
                selectedPetId: selectedPetId,
                onPetTap: (pet) {
                  ref.read(selectedPetIdProvider.notifier).select(pet.id);
                  context.push('/pets/${pet.id}');
                },
              ),
            const SizedBox(height: 32),
            Text(
              'CÀI ĐẶT HỆ THỐNG',
              style: AppTextStyles.label(color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            _SettingsGroup(
              children: [
                _ProfileActionTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Thông báo',
                  subtitle: 'Quản lý các tin nhắn và cập nhật',
                  showAlertDot: true,
                  onTap: () => context.go('/notifications?returnTo=%2Fprofile'),
                ),
                _ProfileActionTile(
                  key: const Key('profile-privacy-action'),
                  icon: Icons.shield_outlined,
                  title: 'Quyền riêng tư & Bảo mật',
                  subtitle: 'Mật khẩu, quyền truy cập dữ liệu',
                  onTap: () => context.push('/profile/privacy'),
                ),
                _ProfileActionTile(
                  icon: Icons.calendar_month_outlined,
                  title: 'Lịch nhắc',
                  subtitle: 'Tiêm phòng, tẩy giun và tái khám',
                  onTap: () => context.go('/health/reminders'),
                ),
                _ProfileActionTile(
                  icon: Icons.local_hospital_outlined,
                  title: 'Phòng khám gần bạn',
                  subtitle: 'Tìm nhanh cơ sở thú y phù hợp',
                  onTap: () => context.go('/vets/list'),
                ),
                _ProfileActionTile(
                  icon: Icons.logout_rounded,
                  title: 'Đăng xuất tài khoản',
                  subtitle: 'Kết thúc phiên trên tất cả thiết bị',
                  danger: true,
                  onTap: () => _logout(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authSessionCoordinatorProvider).logout();
      ref.invalidate(authSessionSnapshotProvider);
      ref.invalidate(petBackendListProvider);
      if (context.mounted) {
        context.go('/auth/login');
      }
    } on AuthApiException catch (error) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Chưa thể đăng xuất an toàn. ${error.message}'),
          ),
        );
      }
    } on Object {
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Chưa thể đăng xuất an toàn. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }
}

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar({
    required this.onSettings,
    required this.onNotifications,
  });

  final VoidCallback onSettings;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.pets_rounded, color: AppColors.primary500, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'PawMate',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.h3(color: AppColors.primary700),
          ),
        ),
        IconButton(
          tooltip: 'Cài đặt',
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined, size: 24),
          color: AppColors.primary700,
        ),
        IconButton(
          tooltip: 'Thông báo',
          onPressed: onNotifications,
          icon: const Icon(Icons.notifications_none_rounded, size: 24),
          color: AppColors.primary700,
        ),
      ],
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.email,
    required this.displayName,
    required this.verified,
    required this.onEdit,
  });

  final String email;
  final String displayName;
  final bool verified;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 254),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.45)),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  _profileInitials(displayName),
                  style: AppTextStyles.h2(color: AppColors.primary700),
                ),
              ),
              if (onEdit != null)
                Positioned(
                  right: -8,
                  bottom: -8,
                  child: Material(
                    color: AppColors.primary500,
                    shape: const CircleBorder(),
                    child: IconButton(
                      key: const Key('profile-edit-action'),
                      tooltip: 'Chỉnh sửa hồ sơ',
                      onPressed: onEdit,
                      constraints: const BoxConstraints.tightFor(
                        width: AppControlSize.minTouchTarget,
                        height: AppControlSize.minTouchTarget,
                      ),
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: AppColors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.h2(),
          ),
          const SizedBox(height: 2),
          Text(
            email,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyCompact(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.careGreenSoft,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  verified ? Icons.verified_rounded : Icons.schedule_rounded,
                  size: 14,
                  color: AppColors.careGreen,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    verified ? 'Verified Owner' : 'Chờ xác minh',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.captionStrong(
                      color: AppColors.careGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PetPreviewStatus extends StatelessWidget {
  const _PetPreviewStatus({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.pets_outlined,
    this.onRetry,
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppControlSize.minTouchTarget,
            height: AppControlSize.minTouchTarget,
            decoration: const BoxDecoration(
              color: AppColors.careGreenSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.careGreen, size: 24),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.cardTitle()),
                const SizedBox(height: AppSpacing.s4),
                Text(message, style: AppTextStyles.caption()),
                if (onRetry != null) ...[
                  const SizedBox(height: AppSpacing.s12),
                  PawMateButton(
                    key: const Key('profile-pets-retry-action'),
                    label: 'Thử lại',
                    onPressed: onRetry,
                    fullWidth: false,
                    variant: PawMateButtonVariant.secondary,
                    leadingIcon: Icons.refresh_rounded,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PetPreviewGrid extends StatelessWidget {
  const _PetPreviewGrid({
    required this.pets,
    required this.selectedPetId,
    required this.onPetTap,
  });

  final List<PetProfile> pets;
  final String? selectedPetId;
  final ValueChanged<PetProfile> onPetTap;

  @override
  Widget build(BuildContext context) {
    if (pets.isEmpty) {
      return const _PetPreviewStatus(
        key: Key('profile-pets-empty-state'),
        title: 'Chưa có thú cưng',
        message: 'Thêm hồ sơ đầu tiên từ màn Home để quản lý tại đây.',
      );
    }

    final visiblePets = pets.take(2).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = visiblePets.length == 1
            ? constraints.maxWidth.clamp(120.0, 160.0).toDouble()
            : ((constraints.maxWidth - AppSpacing.s16) / 2)
                  .clamp(120.0, 160.0)
                  .toDouble();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < visiblePets.length; index++) ...[
              SizedBox(
                width: cardWidth,
                child: _PetPreviewCard(
                  pet: visiblePets[index],
                  selected: visiblePets[index].id == selectedPetId,
                  onTap: () => onPetTap(visiblePets[index]),
                ),
              ),
              if (index != visiblePets.length - 1)
                const SizedBox(width: AppSpacing.s16),
            ],
          ],
        );
      },
    );
  }
}

class _PetPreviewCard extends StatelessWidget {
  const _PetPreviewCard({
    required this.pet,
    required this.selected,
    required this.onTap,
  });

  final PetProfile pet;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        key: Key('profile-pet-${pet.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          height: 145,
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? AppColors.deepGreen : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.careGreenSoft,
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: PetAvatarMedia(
                      source: pet.avatarPath,
                      semanticLabel: 'Ảnh ${pet.name}',
                      fallback: Center(
                        child: Text(
                          _petInitial(pet.name),
                          style: AppTextStyles.h3(color: AppColors.careGreen),
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Icon(
                        Icons.check_circle_rounded,
                        key: Key('profile-pet-selected-${pet.id}'),
                        color: AppColors.deepGreen,
                        size: 20,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                pet.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.label(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.careGreenSoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  _petHealthLabel(pet),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.micro(color: AppColors.careGreen),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.45)),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(
                height: 1,
                indent: 18,
                endIndent: 18,
                color: AppColors.border.withValues(alpha: 0.4),
              ),
          ],
        ],
      ),
    );
  }
}

String _petHealthLabel(PetProfile pet) {
  final status = pet.healthStatus.trim().toLowerCase();
  switch (status) {
    case 'healthy':
    case 'good':
      return 'Khỏe mạnh';
    case 'needs_vaccine':
      return 'Cần tiêm';
    default:
      return 'Theo dõi';
  }
}

String _profileInitials(String displayName) {
  final parts = displayName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'PM';
  }
  if (parts.length == 1) {
    return parts.first.characters.first.toUpperCase();
  }
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}

String _petInitial(String name) {
  final normalized = name.trim();
  return normalized.isEmpty ? 'P' : normalized.characters.first.toUpperCase();
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showAlertDot = false,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showAlertDot;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? AppColors.error : AppColors.primary700;
    final background = danger ? AppColors.errorSoft : AppColors.primarySoft;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label(
                        color: danger ? AppColors.error : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(),
                    ),
                  ],
                ),
              ),
              if (showAlertDot) ...[
                const SizedBox(width: 12),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: danger ? AppColors.error : AppColors.primary500,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
