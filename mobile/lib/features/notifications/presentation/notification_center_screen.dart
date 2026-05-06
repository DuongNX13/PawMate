import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_bottom_nav.dart';
import '../application/notification_providers.dart';
import '../data/notification_api.dart';
import '../domain/pawmate_notification.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsState = ref.watch(notificationListProvider);

    return Scaffold(
      bottomNavigationBar: const PawMateBottomNav(currentRoute: '/health'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 132),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/health'),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
                Expanded(
                  child: Text(
                    'Thong bao',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                TextButton(
                  onPressed: notificationsState.maybeWhen(
                    data: (result) => result.unreadCount == 0
                        ? null
                        : () => _markAllRead(ref),
                    orElse: () => null,
                  ),
                  child: const Text('Doc het'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Cap nhat lich nhac, suc khoe va he thong.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            ...notificationsState.when(
              loading: () => const [
                _NotificationStatusCard(
                  title: 'Dang tai thong bao',
                  message: 'PawMate dang dong bo trung tam thong bao.',
                  showProgress: true,
                ),
              ],
              error: (error, _) => [
                _NotificationStatusCard(
                  title: 'Chua tai duoc thong bao',
                  message: _notificationErrorMessage(error),
                  actionLabel: 'Thu lai',
                  onAction: () => ref.invalidate(notificationListProvider),
                ),
              ],
              data: (result) {
                if (result.items.isEmpty) {
                  return const [
                    _NotificationStatusCard(
                      title: 'Khong co thong bao',
                      message:
                          'Khi co lich nhac den han, PawMate se hien tai day.',
                    ),
                  ];
                }

                return [
                  _UnreadBanner(unreadCount: result.unreadCount),
                  const SizedBox(height: 12),
                  ...result.items.map(
                    (notification) => _NotificationCard(
                      notification: notification,
                      onMarkRead: () => _markRead(ref, notification.id),
                      onDismiss: () => _dismiss(ref, notification.id),
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markRead(WidgetRef ref, String notificationId) async {
    final accessToken = await ref.read(notificationAccessTokenProvider.future);
    if (accessToken == null) {
      return;
    }
    await ref
        .read(notificationApiProvider)
        .markRead(notificationId, accessToken: accessToken);
    ref.invalidate(notificationListProvider);
  }

  Future<void> _markAllRead(WidgetRef ref) async {
    final accessToken = await ref.read(notificationAccessTokenProvider.future);
    if (accessToken == null) {
      return;
    }
    await ref
        .read(notificationApiProvider)
        .markAllRead(accessToken: accessToken);
    ref.invalidate(notificationListProvider);
  }

  Future<void> _dismiss(WidgetRef ref, String notificationId) async {
    final accessToken = await ref.read(notificationAccessTokenProvider.future);
    if (accessToken == null) {
      return;
    }
    await ref
        .read(notificationApiProvider)
        .dismiss(notificationId, accessToken: accessToken);
    ref.invalidate(notificationListProvider);
  }
}

class _UnreadBanner extends StatelessWidget {
  const _UnreadBanner({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: unreadCount > 0
            ? AppColors.primarySoft
            : AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        unreadCount > 0 ? '$unreadCount thong bao chua doc' : 'Tat ca da doc',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: unreadCount > 0
              ? AppColors.primary700
              : AppColors.secondary500,
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onMarkRead,
    required this.onDismiss,
  });

  final PawMateNotification notification;
  final VoidCallback onMarkRead;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: notification.isUnread
            ? AppColors.primarySoft.withAlpha(120)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: notification.isUnread
              ? AppColors.primary500.withAlpha(110)
              : AppColors.border,
        ),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: notification.isUnread
                ? AppColors.primarySoft
                : AppColors.secondarySoft,
            child: Icon(
              Icons.notifications_active_outlined,
              color: notification.isUnread
                  ? AppColors.primary700
                  : AppColors.secondary500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: notification.isUnread ? onMarkRead : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatRelativeDate(notification.createdAt),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'read') {
                onMarkRead();
              }
              if (value == 'dismiss') {
                onDismiss();
              }
            },
            itemBuilder: (context) => [
              if (notification.isUnread)
                const PopupMenuItem(value: 'read', child: Text('Danh dau doc')),
              const PopupMenuItem(
                value: 'dismiss',
                child: Text('An thong bao'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationStatusCard extends StatelessWidget {
  const _NotificationStatusCard({
    required this.title,
    required this.message,
    this.showProgress = false,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final bool showProgress;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showProgress) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

String _formatRelativeDate(DateTime value) {
  final now = DateTime.now();
  if (value.year == now.year &&
      value.month == now.month &&
      value.day == now.day) {
    return 'Hom nay';
  }
  final yesterday = now.subtract(const Duration(days: 1));
  if (value.year == yesterday.year &&
      value.month == yesterday.month &&
      value.day == yesterday.day) {
    return 'Hom qua';
  }
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

String _notificationErrorMessage(Object error) {
  if (error is NotificationApiException) {
    return error.message;
  }
  return 'Khong the dong bo thong bao. Vui long thu lai.';
}
