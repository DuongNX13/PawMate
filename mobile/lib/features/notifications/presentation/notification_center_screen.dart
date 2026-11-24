import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_route_registry.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_bottom_nav.dart';
import '../../../core/widgets/pawmate_fit_title.dart';
import '../application/notification_providers.dart';
import '../data/notification_api.dart';
import '../domain/pawmate_notification.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({
    super.key,
    this.returnPath = '/profile',
    this.now,
  });

  final String returnPath;
  final DateTime Function()? now;

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  String _selectedFilter = _NotificationFilter.all.id;
  final Set<String> _busyNotificationIds = <String>{};
  bool _markingAllRead = false;

  @override
  Widget build(BuildContext context) {
    final notificationsState = ref.watch(notificationListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const PawMateBottomNav(currentRoute: '/profile'),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary500,
          onRefresh: () async {
            ref.invalidate(notificationListProvider);
            try {
              await ref.read(notificationListProvider.future);
            } on Object {
              // RefreshIndicator should close even when the retry state is shown.
            }
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
            children: [
              _NotificationHeader(
                onBack: _goBack,
                onSettings: () => context.push('/profile/notifications'),
              ),
              const SizedBox(height: 12),
              _NotificationFilterRow(
                selectedFilter: _selectedFilter,
                onChanged: (filter) {
                  setState(() => _selectedFilter = filter.id);
                },
              ),
              const SizedBox(height: 14),
              const _QuietHoursCard(),
              const SizedBox(height: 14),
              ...notificationsState.when(
                loading: () => const [
                  _NotificationStatusCard(
                    title: 'Đang tải thông báo',
                    message: 'PawMate đang đồng bộ trung tâm thông báo.',
                    icon: Icons.notifications_none_rounded,
                    showProgress: true,
                  ),
                ],
                error: (error, _) => [
                  _NotificationStatusCard(
                    title: 'Chưa tải được thông báo',
                    message: _notificationErrorMessage(error),
                    icon: Icons.wifi_off_rounded,
                    actionLabel: 'Thử lại',
                    onAction: () => ref.invalidate(notificationListProvider),
                  ),
                ],
                data: _buildNotificationContent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNotificationContent(NotificationListResult result) {
    if (result.items.isEmpty) {
      return [
        _EmptyNotificationState(
          onManage: () => context.go('/profile'),
          onProfile: () => context.go('/profile'),
        ),
      ];
    }

    final filteredItems = result.items.where(_matchesCurrentFilter).toList();
    if (filteredItems.isEmpty) {
      return [
        _NotificationStatusCard(
          title: 'Không có thông báo trong bộ lọc này',
          message: 'Đổi sang bộ lọc khác để xem các cập nhật còn lại.',
          icon: Icons.filter_alt_off_rounded,
          actionLabel: 'Xem tất cả',
          onAction: () {
            setState(() => _selectedFilter = _NotificationFilter.all.id);
          },
        ),
      ];
    }

    final todayItems = filteredItems.where(_isToday).toList();
    final previousItems = filteredItems
        .where((item) => !_isToday(item))
        .toList();
    final widgets = <Widget>[];

    if (todayItems.isNotEmpty) {
      widgets.add(
        _NotificationSectionHeader(
          title: 'HÔM NAY',
          unreadCount: result.unreadCount,
          isBusy: _markingAllRead,
          onMarkAllRead: _markAllRead,
        ),
      );
      widgets.add(const SizedBox(height: 12));
      widgets.addAll(todayItems.map(_buildNotificationCard));
    }

    if (previousItems.isNotEmpty) {
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 11));
      }
      widgets.add(
        _NotificationSectionHeader(
          title: 'TRƯỚC ĐÓ',
          unreadCount: todayItems.isEmpty ? result.unreadCount : 0,
          isBusy: _markingAllRead,
          onMarkAllRead: _markAllRead,
        ),
      );
      widgets.add(const SizedBox(height: 12));
      widgets.addAll(previousItems.map(_buildNotificationCard));
    }

    widgets.add(const SizedBox(height: 12));
    return widgets;
  }

  Widget _buildNotificationCard(PawMateNotification notification) {
    return _NotificationCard(
      key: ValueKey('notification-card-${notification.id}'),
      notification: notification,
      isBusy: _busyNotificationIds.contains(notification.id),
      onTap: () => _openNotification(notification),
      onDismiss: () => _dismiss(notification.id),
    );
  }

  bool _matchesCurrentFilter(PawMateNotification notification) {
    final filter = _NotificationFilter.byId(_selectedFilter);
    if (filter == _NotificationFilter.all) {
      return true;
    }
    return _notificationCategory(notification) == filter.id;
  }

  bool _isToday(PawMateNotification notification) {
    final now = widget.now?.call() ?? DateTime.now();
    final value = notification.createdAt;
    return value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
  }

  Future<void> _openNotification(PawMateNotification notification) async {
    final route = _targetRouteFor(notification);
    if (notification.isUnread) {
      await _markRead(notification.id, showSuccess: false);
    }

    if (!mounted) {
      return;
    }
    context.go(route);
  }

  Future<bool> _markRead(
    String notificationId, {
    bool showSuccess = true,
  }) async {
    setState(() => _busyNotificationIds.add(notificationId));
    try {
      final accessToken = await ref.read(
        notificationAccessTokenProvider.future,
      );
      if (accessToken == null) {
        throw const NotificationApiException(
          'Bạn cần đăng nhập để cập nhật thông báo.',
        );
      }
      await ref
          .read(notificationApiProvider)
          .markRead(notificationId, accessToken: accessToken);
      ref.invalidate(notificationListProvider);
      if (showSuccess && mounted) {
        _showSnack('Đã đánh dấu thông báo là đã đọc.');
      }
      return true;
    } on Object catch (error) {
      if (mounted) {
        _showSnack(_notificationErrorMessage(error));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _busyNotificationIds.remove(notificationId));
      }
    }
  }

  Future<void> _markAllRead() async {
    setState(() => _markingAllRead = true);
    try {
      final accessToken = await ref.read(
        notificationAccessTokenProvider.future,
      );
      if (accessToken == null) {
        throw const NotificationApiException(
          'Bạn cần đăng nhập để cập nhật thông báo.',
        );
      }
      await ref
          .read(notificationApiProvider)
          .markAllRead(accessToken: accessToken);
      ref.invalidate(notificationListProvider);
      if (mounted) {
        _showSnack('Đã đọc tất cả thông báo.');
      }
    } on Object catch (error) {
      if (mounted) {
        _showSnack(_notificationErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _markingAllRead = false);
      }
    }
  }

  Future<void> _dismiss(String notificationId) async {
    setState(() => _busyNotificationIds.add(notificationId));
    try {
      final accessToken = await ref.read(
        notificationAccessTokenProvider.future,
      );
      if (accessToken == null) {
        throw const NotificationApiException(
          'Bạn cần đăng nhập để cập nhật thông báo.',
        );
      }
      await ref
          .read(notificationApiProvider)
          .dismiss(notificationId, accessToken: accessToken);
      ref.invalidate(notificationListProvider);
      if (mounted) {
        _showSnack('Đã ẩn thông báo.');
      }
    } on Object catch (error) {
      if (mounted) {
        _showSnack(_notificationErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busyNotificationIds.remove(notificationId));
      }
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(_safeReturnPath(widget.returnPath));
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NotificationHeader extends StatelessWidget {
  const _NotificationHeader({required this.onBack, required this.onSettings});

  final VoidCallback onBack;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppControlSize.minTouchTarget,
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('notification-back-button'),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.primary700,
            iconSize: 26,
            tooltip: 'Quay lại',
          ),
          const SizedBox(width: 2),
          Expanded(
            child: PawMateFitTitle(
              'Thông báo',
              style: AppTextStyles.appBarTitle(color: AppColors.primary700),
            ),
          ),
          IconButton(
            key: const ValueKey('notification-settings-button'),
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined),
            color: AppColors.textSecondary,
            iconSize: 28,
            tooltip: 'Quản lý thông báo',
          ),
        ],
      ),
    );
  }
}

class _NotificationFilterRow extends StatelessWidget {
  const _NotificationFilterRow({
    required this.selectedFilter,
    required this.onChanged,
  });

  final String selectedFilter;
  final ValueChanged<_NotificationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _NotificationFilter.values) ...[
            _NotificationFilterChip(
              filter: filter,
              isSelected: selectedFilter == filter.id,
              onTap: () => onChanged(filter),
            ),
            const SizedBox(width: 16),
          ],
        ],
      ),
    );
  }
}

class _NotificationFilterChip extends StatelessWidget {
  const _NotificationFilterChip({
    required this.filter,
    required this.isSelected,
    required this.onTap,
  });

  final _NotificationFilter filter;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? AppColors.white : AppColors.textPrimary;
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${filter.label}, ${isSelected ? 'đã chọn' : 'chưa chọn'}',
      child: ExcludeSemantics(
        child: SizedBox(
          key: Key('notification-filter-${filter.id}'),
          height: AppControlSize.minTouchTarget,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Center(
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: AppMotion.standardCurve,
                  height: 40,
                  constraints: BoxConstraints(minWidth: isSelected ? 94 : 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary500
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    filter.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label(color: foreground),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuietHoursCard extends StatelessWidget {
  const _QuietHoursCard();

  @override
  Widget build(BuildContext context) {
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >= 1.3;

    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.lightBeige,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.notifications_paused_outlined,
              color: AppColors.brown,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đang trong giờ nghỉ (22:00 - 07:00)',
                  style: AppTextStyles.body().copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Thông báo sẽ được chuyển đến im lặng để tránh làm phiền bạn.',
                  maxLines: usesExpandedTextLayout ? null : 2,
                  overflow: usesExpandedTextLayout
                      ? null
                      : TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    color: AppColors.textSecondary,
                  ).copyWith(height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSectionHeader extends StatelessWidget {
  const _NotificationSectionHeader({
    required this.title,
    this.unreadCount = 0,
    this.isBusy = false,
    this.onMarkAllRead,
  });

  final String title;
  final int unreadCount;
  final bool isBusy;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppControlSize.minTouchTarget,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.overline(color: AppColors.textSecondary),
            ),
          ),
          if (unreadCount > 0 && onMarkAllRead != null) ...[
            Semantics(
              label: '$unreadCount thông báo chưa đọc',
              child: Container(
                key: const ValueKey('notification-unread-count'),
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary500,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                // Size to content: an aligned Container would stretch to the
                // 48pt header row height.
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: AppTextStyles.micro(color: AppColors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            TextButton(
              key: const ValueKey('notification-mark-all-read-button'),
              onPressed: isBusy ? null : onMarkAllRead,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Đọc hết',
                      style: AppTextStyles.label(color: AppColors.primary700),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    super.key,
    required this.notification,
    required this.isBusy,
    required this.onTap,
    required this.onDismiss,
  });

  final PawMateNotification notification;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final category = _notificationCategory(notification);
    final categoryLabel = _NotificationFilter.byId(category).label;
    final isUnread = notification.isUnread;
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) > 1.3;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isUnread ? AppColors.border : AppColors.border.withAlpha(80),
        ),
      ),
      constraints: const BoxConstraints(minHeight: 170),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: isBusy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: SizedBox(
              height: usesExpandedTextLayout ? null : 144,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NotificationIconTile(category: category),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: usesExpandedTextLayout
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.cardTitle().copyWith(
                                  height: 1.2,
                                ),
                              ),
                            ),
                            if (isUnread)
                              Container(
                                key: ValueKey(
                                  'notification-unread-${notification.id}',
                                ),
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 8, top: 4),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary500,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(
                            color: AppColors.textSecondary,
                          ).copyWith(height: 1.15),
                        ),
                        if (usesExpandedTextLayout)
                          const SizedBox(height: AppSpacing.s8)
                        else
                          const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_formatNotificationTime(notification.createdAt)} • $categoryLabel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.meta(
                                  color: AppColors.primary700,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              key: ValueKey(
                                'notification-dismiss-${notification.id}',
                              ),
                              tooltip: 'Ẩn thông báo',
                              onPressed: isBusy ? null : onDismiss,
                              icon: isBusy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.close_rounded, size: 18),
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationIconTile extends StatelessWidget {
  const _NotificationIconTile({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final icon = switch (category) {
      'health' => Icons.favorite_rounded,
      'vet' => Icons.medical_services_rounded,
      'rescue' => Icons.pets_rounded,
      _ => Icons.notifications_rounded,
    };

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.soft,
      ),
      child: Icon(icon, color: AppColors.primary500, size: 24),
    );
  }
}

class _NotificationStatusCard extends StatelessWidget {
  const _NotificationStatusCard({
    required this.title,
    required this.message,
    required this.icon,
    this.showProgress = false,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final bool showProgress;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: showProgress
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(icon, color: AppColors.primary500),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(title, style: AppTextStyles.cardTitle())),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _EmptyNotificationState extends StatelessWidget {
  const _EmptyNotificationState({
    required this.onManage,
    required this.onProfile,
  });

  final VoidCallback onManage;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 220,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft.withAlpha(120),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Container(
                  width: 132,
                  height: 132,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.primary500,
                    size: 72,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Chưa có thông báo mới',
          style: AppTextStyles.sectionTitle(color: AppColors.primary500),
        ),
        const SizedBox(height: 14),
        Text(
          'Chúng tôi sẽ gửi cho bạn các cập nhật về cứu hộ, nhắc nhở từ bác sĩ thú y và tin nhắn nhận nuôi tại đây.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 30),
        FilledButton(
          key: const ValueKey('notification-empty-manage-button'),
          onPressed: onManage,
          child: const Text('Quản lý thông báo'),
        ),
        const SizedBox(height: 14),
        TextButton(
          key: const ValueKey('notification-empty-profile-button'),
          onPressed: onProfile,
          child: const Text('Về trang cá nhân'),
        ),
      ],
    );
  }
}

class _NotificationFilter {
  const _NotificationFilter(this.id, this.label);

  final String id;
  final String label;

  static const all = _NotificationFilter('all', 'Tất cả');
  static const health = _NotificationFilter('health', 'Sức khỏe');
  static const vet = _NotificationFilter('vet', 'Thú y');
  static const rescue = _NotificationFilter('rescue', 'Cứu hộ');

  static const values = [all, health, vet, rescue];

  static _NotificationFilter byId(String id) {
    return values.firstWhere((filter) => filter.id == id, orElse: () => all);
  }
}

String _notificationCategory(PawMateNotification notification) {
  final type = notification.type.toLowerCase();
  if (type.contains('reminder') ||
      type.contains('health') ||
      type.contains('vaccine') ||
      type.contains('vaccination') ||
      type.contains('medication') ||
      type.contains('deworm')) {
    return _NotificationFilter.health.id;
  }
  if (type.contains('vet') ||
      type.contains('clinic') ||
      type.contains('appointment') ||
      type.contains('review')) {
    return _NotificationFilter.vet.id;
  }
  if (type.contains('rescue') ||
      type.contains('lost') ||
      type.contains('adoption') ||
      type.contains('adopt')) {
    return _NotificationFilter.rescue.id;
  }
  return _NotificationFilter.all.id;
}

String _targetRouteFor(PawMateNotification notification) {
  final type = notification.type.toLowerCase();
  if (type.contains('reminder') || type.contains('health')) {
    return notification.reminderId == null ? '/health' : '/health/reminders';
  }
  if (type.contains('vet') || type.contains('clinic')) {
    return '/vets/list';
  }
  if (type.contains('rescue') || type.contains('lost')) {
    return '/rescue';
  }
  if (notification.petId != null && notification.petId!.trim().isNotEmpty) {
    return '/pets/${Uri.encodeComponent(notification.petId!.trim())}';
  }
  return '/profile';
}

String _safeReturnPath(String value) {
  final route = value.trim();
  if (!AppRouteRegistry.isSupportedAuthenticatedLocation(route)) {
    return '/profile';
  }
  return route;
}

String _formatNotificationTime(DateTime value) {
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String _notificationErrorMessage(Object error) {
  if (error is NotificationApiException) {
    return error.message;
  }
  return 'Không thể đồng bộ thông báo. Vui lòng thử lại.';
}
