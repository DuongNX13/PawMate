import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_adaptive.dart';
import '../../../core/widgets/pawmate_bottom_nav.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../auth/application/auth_session_coordinator.dart';
import '../../auth/data/auth_api.dart';
import '../../pets/application/pet_list_provider.dart';
import '../../pets/domain/pet_profile.dart';
import '../../pets/presentation/widgets/pet_avatar_media.dart';

final profileSessionProvider = authSessionSnapshotProvider;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.avatarAsset});

  /// Optional deterministic asset used by the canonical visual harness.
  /// Production sessions continue to use the initials fallback until the
  /// account avatar contract is available from the backend.
  final String? avatarAsset;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _logoutInProgress = false;

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 8),
            sessionState.when(
              loading: () => _ProfileHeroCard(
                email: 'Đang tải tài khoản',
                displayName: 'PawMate',
                verified: false,
                avatarAsset: widget.avatarAsset,
                onEdit: null,
              ),
              error: (_, _) => _ProfileHeroCard(
                email: 'Chưa xác định',
                displayName: 'Người dùng PawMate',
                verified: false,
                avatarAsset: widget.avatarAsset,
                onEdit: () => context.push('/profile/controls'),
              ),
              data: (session) => _ProfileHeroCard(
                email: session?.user.email ?? 'Chưa đăng nhập',
                displayName:
                    session?.user.displayName?.trim().isNotEmpty == true
                    ? session!.user.displayName!
                    : 'Người dùng PawMate',
                verified: session?.user.emailVerified ?? false,
                avatarAsset: widget.avatarAsset,
                onEdit: () => context.push('/profile/controls'),
              ),
            ),
            const SizedBox(height: 12),
            if (MediaQuery.textScalerOf(context).scale(1) > 1.3)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thú cưng của tôi', style: AppTextStyles.h4()),
                  TextButton(
                    key: const Key('profile-view-all-pets'),
                    onPressed: () => context.go('/pets'),
                    child: const Text('Xem tất cả'),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Text('Thú cưng của tôi', style: AppTextStyles.h4()),
                  ),
                  TextButton(
                    key: const Key('profile-view-all-pets'),
                    onPressed: () => context.go('/pets'),
                    child: const Text('Xem tất cả'),
                  ),
                ],
              ),
            const SizedBox(height: 6),
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
            const SizedBox(height: 12),
            Text(
              'CÀI ĐẶT HỆ THỐNG',
              // Figma brown label; also fixes low contrast (D123-IOS-A11Y-001).
              style: AppTextStyles.label(color: AppColors.brown),
            ),
            const SizedBox(height: 8),
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
                  onTap: _confirmLogout,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    if (_logoutInProgress) return;
    _logoutInProgress = true;
    try {
      final confirmed = await showPawMateAdaptiveDialog<bool>(
        context: context,
        dialogKey: const Key('profile-logout-confirmation'),
        title: 'Đăng xuất tài khoản?',
        message: 'Bạn cần đăng nhập lại để tiếp tục sử dụng tài khoản PawMate.',
        actions: const [
          PawMateAdaptiveAction<bool>(
            key: Key('profile-logout-cancel'),
            label: 'Hủy',
            isDefaultAction: true,
          ),
          PawMateAdaptiveAction<bool>(
            key: Key('profile-logout-confirm'),
            label: 'Đăng xuất',
            value: true,
            isDestructiveAction: true,
          ),
        ],
      );
      if (confirmed == true && mounted) {
        await _logout();
      }
    } finally {
      _logoutInProgress = false;
    }
  }

  Future<void> _logout() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authSessionCoordinatorProvider).logout();
      ref.invalidate(authSessionSnapshotProvider);
      ref.invalidate(petBackendListProvider);
      if (mounted) {
        context.go('/auth/login');
      }
    } on AuthApiException catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Chưa thể đăng xuất an toàn. ${error.message}'),
          ),
        );
      }
    } on Object {
      if (mounted) {
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
    this.avatarAsset,
  });

  final String email;
  final String displayName;
  final bool verified;
  final VoidCallback? onEdit;
  final String? avatarAsset;

  @override
  Widget build(BuildContext context) {
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 38,
          backgroundColor: AppColors.primarySoft,
          child: avatarAsset == null
              ? Text(
                  _profileInitials(displayName),
                  style: AppTextStyles.h2(color: AppColors.primary700),
                )
              : ClipOval(
                  child: Image.asset(
                    avatarAsset!,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (context, error, stackTrace) => Text(
                      _profileInitials(displayName),
                      style: AppTextStyles.h2(color: AppColors.primary700),
                    ),
                  ),
                ),
        ),
        if (onEdit != null)
          Positioned(
            right: -10,
            bottom: -10,
            child: Semantics(
              button: true,
              label: 'Chỉnh sửa hồ sơ',
              child: SizedBox(
                width: AppControlSize.minTouchTarget,
                height: AppControlSize.minTouchTarget,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const Key('profile-edit-action'),
                    customBorder: const CircleBorder(),
                    onTap: onEdit,
                    child: Center(
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: AppColors.primary500,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: AppColors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    final details = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: usesExpandedTextLayout
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          displayName,
          maxLines: usesExpandedTextLayout ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          textAlign: usesExpandedTextLayout ? TextAlign.center : TextAlign.left,
          style: AppTextStyles.h3(),
        ),
        const SizedBox(height: 2),
        if (usesExpandedTextLayout)
          Text(
            email,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyCompact(),
          )
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              email,
              maxLines: 1,
              softWrap: false,
              style: AppTextStyles.bodyCompact(),
            ),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              const SizedBox(width: 5),
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
    );

    return Container(
      constraints: BoxConstraints(
        minHeight: usesExpandedTextLayout ? 214 : 124,
      ),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.45)),
        boxShadow: AppShadows.soft,
      ),
      child: usesExpandedTextLayout
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                avatar,
                const SizedBox(height: AppSpacing.s16),
                details,
              ],
            )
          : Row(
              children: [
                avatar,
                const SizedBox(width: 22),
                Expanded(child: details),
                const Icon(Icons.chevron_right_rounded, color: AppColors.brown),
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
        final cardWidth = (constraints.maxWidth - AppSpacing.s16) / 2;
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
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        key: Key('profile-pet-${pet.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          height: usesExpandedTextLayout ? null : 184,
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
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
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: AppColors.careGreenSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
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
              const SizedBox(height: 8),
              Text(
                pet.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyStrong(color: AppColors.deepTeal),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
    // Figma v0.34 P1-16: every setting is its own white card, 2pt apart.
    return Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          Material(
            key: Key('profile-settings-card-$index'),
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            clipBehavior: Clip.antiAlias,
            child: children[index],
          ),
          if (index != children.length - 1) const SizedBox(height: 2),
        ],
      ],
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
    final background = danger ? AppColors.errorSoft : AppColors.healthHeroSoft;
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
          child: Row(
            children: [
              Container(
                key: const Key('profile-settings-icon'),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: usesExpandedTextLayout ? null : 1,
                      overflow: usesExpandedTextLayout
                          ? null
                          : TextOverflow.ellipsis,
                      style: AppTextStyles.label(
                        color: danger ? AppColors.error : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: usesExpandedTextLayout ? null : 2,
                      overflow: usesExpandedTextLayout
                          ? null
                          : TextOverflow.ellipsis,
                      style: AppTextStyles.caption(),
                    ),
                  ],
                ),
              ),
              if (showAlertDot) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              const SizedBox(width: 6),
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
