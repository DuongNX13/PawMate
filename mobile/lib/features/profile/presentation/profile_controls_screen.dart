import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_navigation.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_ui.dart';
import '../../auth/application/auth_session_coordinator.dart';
import '../../auth/data/auth_api.dart';
import '../../preferences/application/preference_providers.dart';
import '../../preferences/data/preference_api.dart';
import '../../preferences/domain/preference_models.dart';

class ProfileControlsScreen extends ConsumerWidget {
  const ProfileControlsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(authSessionSnapshotProvider);
    final notificationState = ref.watch(notificationPreferencesProvider);
    final privacyState = ref.watch(privacyDefaultsProvider);
    final notifications =
        notificationState.value ??
        ref.read(notificationPreferencesProvider.notifier).lastSuccessful;
    final privacy =
        privacyState.value ??
        ref.read(privacyDefaultsProvider.notifier).lastSuccessful;
    final isEmailVerified =
        sessionState.asData?.value?.user.emailVerified ?? false;

    return PawMatePageScaffold(
      key: const Key('profile-controls-screen'),
      backgroundColor: AppColors.background,
      bottomNavCurrentRoute: '/profile',
      topBar: PawMateTopBar(
        title: 'Tài khoản',
        titleColor: AppColors.deepGreen,
        titleSpacing: AppSpacing.s8,
        showBackButton: true,
        onBack: () => PawMateNavigation.backOrGo(context, '/profile'),
        actions: [if (isEmailVerified) const _SecurityStatusPill()],
      ),
      body: ListView(
        key: const Key('profile-controls-scroll'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s24,
          AppSpacing.s16,
          AppSpacing.s32,
        ),
        children: [
          sessionState.when(
            loading: () => const _AccountCard(
              displayName: 'Đang tải tài khoản',
              email: 'PawMate',
              verified: false,
            ),
            error: (_, _) => const _AccountCard(
              displayName: 'Người dùng PawMate',
              email: 'Chưa tải được tài khoản',
              verified: false,
            ),
            data: (session) => _AccountCard.fromSession(session),
          ),
          if (notificationState.isLoading || privacyState.isLoading) ...[
            const SizedBox(height: AppSpacing.s12),
            const LinearProgressIndicator(
              semanticsLabel: 'Đang đồng bộ cài đặt tài khoản',
            ),
          ],
          const SizedBox(height: AppSpacing.s24),
          const _GroupTitle('THÔNG BÁO & QUYỀN RIÊNG TƯ'),
          const SizedBox(height: AppSpacing.s16),
          _ControlsGroup(
            children: [
              _GlobalNotificationTile(
                preferences: notifications,
                busy: notificationState.isLoading,
                onChanged: notifications == null
                    ? null
                    : (enabled) => _saveNotifications(
                        context,
                        ref,
                        notifications.copyWith(
                          nearbyLostCases: enabled,
                          chatMessages: enabled,
                          adoptionUpdates: enabled,
                        ),
                      ),
                onOpen: () => context.push('/profile/notifications'),
                onRetry: () => ref.invalidate(notificationPreferencesProvider),
              ),
              _ControlTile(
                key: const Key('profile-controls-privacy'),
                icon: Icons.shield_outlined,
                title: 'Cài đặt quyền riêng tư',
                minTileHeight: 70,
                subtitle: privacy == null
                    ? 'Chưa tải được cài đặt · chạm để thử lại'
                    : null,
                onTap: () {
                  if (privacy == null) {
                    ref.invalidate(privacyDefaultsProvider);
                  }
                  context.push('/profile/privacy');
                },
              ),
              _QuietHoursTile(
                preferences: notifications,
                busy: notificationState.isLoading,
                onChanged: notifications == null
                    ? null
                    : (enabled) {
                        final updated = enabled
                            ? notifications.copyWith(
                                quietHoursEnabled: true,
                                quietHoursStart:
                                    notifications.quietHoursStart ?? '22:00',
                                quietHoursEnd:
                                    notifications.quietHoursEnd ?? '07:00',
                              )
                            : notifications.copyWith(
                                quietHoursEnabled: false,
                                clearQuietHours: true,
                              );
                        return _saveNotifications(context, ref, updated);
                      },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s24),
          const _GroupTitle('TÀI KHOẢN & BẢO MẬT'),
          const SizedBox(height: AppSpacing.s16),
          _ControlsGroup(
            children: [
              _ControlTile(
                key: const Key('profile-controls-two-factor'),
                icon: Icons.lock_outline,
                title: 'Xác thực 2 lớp (OTP)',
                subtitle: 'Chưa hỗ trợ trong PawMate v1',
                trailingLabel: 'Sắp có',
                onTap: () => _showUnavailable(context, 'Xác thực hai bước'),
              ),
              _ControlTile(
                key: const Key('profile-controls-rescue-account'),
                icon: Icons.volunteer_activism_outlined,
                title: 'Tài khoản trạm cứu hộ',
                subtitle: 'Xác minh vai trò nằm ngoài phạm vi v1',
                trailingLabel: 'Sắp có',
                onTap: () => _showUnavailable(context, 'Tài khoản trạm cứu hộ'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s24),
          const _GroupTitle('QUẢN LÝ TÀI KHOẢN'),
          const SizedBox(height: AppSpacing.s16),
          _ControlsGroup(
            children: [
              _ControlTile(
                key: const Key('profile-controls-delete-account'),
                icon: Icons.delete_outline,
                title: 'Xóa tài khoản',
                subtitle:
                    'Thao tác phá hủy luôn yêu cầu xác nhận và hiện chưa mở trong v1',
                danger: true,
                onTap: () => _confirmDeleteUnavailable(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveNotifications(
    BuildContext context,
    WidgetRef ref,
    NotificationPreferences updated,
  ) async {
    final saved = await ref
        .read(notificationPreferencesProvider.notifier)
        .save(updated);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Đã cập nhật cài đặt thông báo.'
              : _preferenceError(
                  ref.read(notificationPreferencesProvider).error,
                ),
        ),
      ),
    );
  }

  void _showUnavailable(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature chưa hỗ trợ trong PawMate v1. Không có thay đổi nào được lưu.',
        ),
      ),
    );
  }

  Future<void> _confirmDeleteUnavailable(BuildContext context) async {
    final confirmed = await showPawMateAdaptiveDialog<bool>(
      context: context,
      dialogKey: const Key('profile-controls-delete-confirmation'),
      title: 'Xóa tài khoản?',
      message:
          'Đây là thao tác không thể hoàn tác. PawMate v1 chưa mở API xóa tài khoản, nên xác nhận này sẽ không xóa dữ liệu.',
      actions: const [
        PawMateAdaptiveAction<bool>(label: 'Hủy'),
        PawMateAdaptiveAction<bool>(
          key: Key('profile-controls-delete-confirm'),
          label: 'Tôi đã hiểu',
          value: true,
          isDefaultAction: true,
        ),
      ],
    );
    if (confirmed == true && context.mounted) {
      _showUnavailable(context, 'Xóa tài khoản');
    }
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.displayName,
    required this.email,
    required this.verified,
  });

  factory _AccountCard.fromSession(AuthSession? session) {
    final rawName = session?.user.displayName?.trim();
    return _AccountCard(
      displayName: rawName?.isNotEmpty == true
          ? rawName!
          : 'Người dùng PawMate',
      email: session?.user.email.trim().isNotEmpty == true
          ? session!.user.email
          : 'Chưa đăng nhập',
      verified: session?.user.emailVerified ?? false,
    );
  }

  final String displayName;
  final String email;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.trim().isEmpty
        ? 'P'
        : displayName.trim().characters.first.toUpperCase();
    return Container(
      constraints: const BoxConstraints(minHeight: 98),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceContainer),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.mint,
            foregroundColor: AppColors.deepGreen,
            child: Text(initial, style: AppTextStyles.h3()),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h4(),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  email,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption(),
                ),
              ],
            ),
          ),
          if (verified)
            const Tooltip(
              message: 'Email đã xác minh',
              child: Icon(Icons.verified, color: AppColors.deepGreen),
            ),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: AppTextStyles.overline(color: AppColors.textMuted));
}

class _ControlsGroup extends StatelessWidget {
  const _ControlsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadius.lg),
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceContainer),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              const Divider(
                height: 1,
                indent: 64,
                endIndent: AppSpacing.s16,
                color: AppColors.surfaceContainer,
              ),
          ],
        ],
      ),
    ),
  );
}

class _GlobalNotificationTile extends StatelessWidget {
  const _GlobalNotificationTile({
    required this.preferences,
    required this.busy,
    required this.onChanged,
    required this.onOpen,
    required this.onRetry,
  });

  final NotificationPreferences? preferences;
  final bool busy;
  final ValueChanged<bool>? onChanged;
  final VoidCallback onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final value =
        preferences != null &&
        preferences!.nearbyLostCases &&
        preferences!.chatMessages &&
        preferences!.adoptionUpdates;
    final enabledCount = preferences == null
        ? 0
        : [
            preferences!.nearbyLostCases,
            preferences!.chatMessages,
            preferences!.adoptionUpdates,
          ].where((enabled) => enabled).length;
    return Semantics(
      toggled: value,
      label: 'Thông báo ứng dụng. $enabledCount trên 3 nhóm đang bật.',
      child: ListTile(
        key: const Key('profile-controls-global-notifications'),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
        minVerticalPadding: AppSpacing.s12,
        minLeadingWidth: 40,
        horizontalTitleGap: AppSpacing.s12,
        leading: const _ControlIconBadge(
          icon: Icons.notifications,
          iconColor: AppColors.brown,
        ),
        title: Text('Thông báo ứng dụng', style: AppTextStyles.label()),
        subtitle: Text(
          preferences == null
              ? 'Chưa tải được · chạm để thử lại'
              : '$enabledCount/3 nhóm đang bật · chạm tiêu đề để tùy chỉnh',
          style: AppTextStyles.caption(),
        ),
        onTap: preferences == null ? onRetry : onOpen,
        trailing: Switch.adaptive(
          value: value,
          onChanged: busy || preferences == null ? null : onChanged,
        ),
      ),
    );
  }
}

class _QuietHoursTile extends StatelessWidget {
  const _QuietHoursTile({
    required this.preferences,
    required this.busy,
    required this.onChanged,
  });

  final NotificationPreferences? preferences;
  final bool busy;
  final Future<void> Function(bool)? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = preferences?.quietHoursEnabled ?? false;
    final start = preferences?.quietHoursStart ?? '22:00';
    final end = preferences?.quietHoursEnd ?? '07:00';
    final schedule = '$start - $end';
    return Semantics(
      toggled: enabled,
      label: 'Giờ yên tĩnh. ${enabled ? 'Đang bật $schedule' : 'Đang tắt'}',
      child: Container(
        key: const Key('profile-controls-quiet-hours'),
        constraints: const BoxConstraints(minHeight: 132),
        padding: const EdgeInsets.all(AppSpacing.s16),
        color: AppColors.surfaceMuted,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _ControlIconBadge(
                  icon: Icons.dark_mode_outlined,
                  size: AppControlSize.minTouchTarget,
                  backgroundColor: AppColors.deepGreen,
                  iconColor: AppColors.white,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    'Giờ yên tĩnh',
                    style: AppTextStyles.label(color: AppColors.deepGreen),
                  ),
                ),
                Switch.adaptive(
                  value: enabled,
                  onChanged: busy || preferences == null ? null : onChanged,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              enabled ? 'TỰ ĐỘNG BẬT: $schedule' : 'MẶC ĐỊNH: 22:00 - 07:00',
              style: AppTextStyles.overline(color: AppColors.deepGreen),
            ),
            Text(
              enabled
                  ? 'Các nhóm thông báo bạn chọn sẽ tạm dừng trong khung giờ này. Quyền thông báo của điện thoại vẫn được quản lý riêng.'
                  : 'Bật để tạm dừng thông báo trong khung giờ bạn chọn.',
              style: AppTextStyles.caption(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlTile extends StatelessWidget {
  const _ControlTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingLabel,
    this.danger = false,
    this.minTileHeight = 88,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final String? trailingLabel;
  final bool danger;
  final double minTileHeight;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
    minTileHeight: minTileHeight,
    minVerticalPadding: AppSpacing.s12,
    minLeadingWidth: 40,
    horizontalTitleGap: AppSpacing.s12,
    leading: _ControlIconBadge(
      icon: icon,
      backgroundColor: danger
          ? AppColors.errorSoft
          : AppColors.surfaceContainer,
      iconColor: danger ? AppColors.error : AppColors.deepGreen,
    ),
    title: Text(
      title,
      style: AppTextStyles.label(
        color: danger ? AppColors.error : AppColors.textPrimary,
      ),
    ),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption(),
          ),
    trailing: trailingLabel == null
        ? const Icon(Icons.chevron_right)
        : Text(
            trailingLabel!,
            style: AppTextStyles.captionStrong(color: AppColors.textMuted),
          ),
    onTap: onTap,
  );
}

class _ControlIconBadge extends StatelessWidget {
  const _ControlIconBadge({
    required this.icon,
    this.size = 40,
    this.backgroundColor = AppColors.surfaceContainer,
    this.iconColor = AppColors.deepGreen,
  });

  final IconData icon;
  final double size;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
    child: Icon(icon, size: size == 40 ? 20 : 24, color: iconColor),
  );
}

class _SecurityStatusPill extends StatelessWidget {
  const _SecurityStatusPill();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.s16),
      child: Semantics(
        label: 'Email đã xác minh',
        child: Container(
          key: const Key('profile-controls-security-status'),
          height: 28,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.s8 : AppSpacing.s12,
          ),
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: AppColors.deepGreen,
              ),
              if (!compact) ...[
                const SizedBox(width: AppSpacing.s4),
                Text(
                  'EMAIL ĐÃ XÁC MINH',
                  style: AppTextStyles.overline(color: AppColors.deepGreen),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _preferenceError(Object? error) {
  if (error is PreferenceApiException) {
    if (error.statusCode == 401 || error.code == 'AUTH_REQUIRED') {
      return 'Phiên đăng nhập đã hết hạn.';
    }
    if (error.isVersionConflict) {
      return 'Cài đặt đã đổi ở thiết bị khác. Mức trước đó vẫn được giữ.';
    }
    if (error.code == 'NETWORK_OFFLINE') {
      return 'Không thể kết nối. Mức trước đó vẫn được giữ.';
    }
    return error.message;
  }
  return 'Chưa thể cập nhật. Mức trước đó vẫn được giữ.';
}
