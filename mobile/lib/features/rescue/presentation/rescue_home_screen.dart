import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_adaptive.dart';
import '../../../core/widgets/pawmate_card.dart';
import '../../../core/widgets/pawmate_page_scaffold.dart';
import '../../../core/widgets/pawmate_skeleton.dart';
import '../../../core/widgets/pawmate_state_view.dart';
import '../../../core/widgets/pawmate_top_bar.dart';
import '../application/rescue_home_provider.dart';
import '../domain/rescue_case_models.dart';
import 'rescue_map_preview.dart';

/// Rescue root surface.
///
/// The staged branch intentionally does not depend on Riverpod. That keeps the
/// flag-off route cheap and guarantees zero Rescue API/provider work.
class RescueHomeScreen extends StatelessWidget {
  const RescueHomeScreen({
    super.key,
    this.browseEnabled = false,
    this.createEnabled = false,
  });

  final bool browseEnabled;
  final bool createEnabled;

  @override
  Widget build(BuildContext context) {
    if (!browseEnabled) {
      return _RescueStagedHomeScreen(
        browseEnabled: browseEnabled,
        createEnabled: createEnabled,
      );
    }
    return _RescueLiveHomeScreen(createEnabled: createEnabled);
  }
}

class _RescueStagedHomeScreen extends StatelessWidget {
  const _RescueStagedHomeScreen({
    required this.browseEnabled,
    required this.createEnabled,
  });

  final bool browseEnabled;
  final bool createEnabled;

  @override
  Widget build(BuildContext context) {
    return PawMatePageScaffold(
      topBar: PawMateTopBar(
        title: 'Cứu hộ thú cưng',
        subtitle: 'Triển khai theo từng giai đoạn',
        actions: [
          IconButton(
            key: const ValueKey('rescue-notifications-button'),
            tooltip: 'Thông báo',
            onPressed: () => context.go('/notifications?returnTo=%2Frescue'),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      bottomNavCurrentRoute: '/rescue',
      body: ListView(
        key: const Key('rescue-staged-state'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s8,
          AppSpacing.s16,
          AppSpacing.s24,
        ),
        children: [
          PawMateStateView(
            type: PawMateStateType.empty,
            icon: Icons.health_and_safety_outlined,
            title: 'Rescue chưa mở dữ liệu thật',
            message: _statusMessage,
            primaryActionLabel: 'Về Trang chủ',
            onPrimaryAction: () => context.go('/pets'),
          ),
          const SizedBox(height: AppSpacing.s8),
          const _RescueSafetyCard(),
        ],
      ),
    );
  }

  String get _statusMessage {
    if (createEnabled) {
      return 'Cờ xem và tạo tin đã bật, nhưng giao diện Day 39 cùng API cứu hộ chưa được nối trong lane hiện tại. PawMate không hiển thị ca mẫu hoặc gửi dữ liệu giả.';
    }
    if (browseEnabled) {
      return 'Cờ xem tin đã bật, nhưng giao diện Day 39 cùng API cứu hộ chưa được nối trong lane hiện tại. PawMate không hiển thị ca mẫu hoặc vị trí giả.';
    }
    return 'Tính năng đang được chuẩn bị. Khi cờ Rescue tắt, PawMate không tải ca cứu hộ, bản đồ hoặc vị trí thật.';
  }
}

class _RescueLiveHomeScreen extends ConsumerStatefulWidget {
  const _RescueLiveHomeScreen({required this.createEnabled});

  final bool createEnabled;

  @override
  ConsumerState<_RescueLiveHomeScreen> createState() =>
      _RescueLiveHomeScreenState();
}

class _RescueLiveHomeScreenState extends ConsumerState<_RescueLiveHomeScreen> {
  late final RescueHomeNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(rescueHomeProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifier.initialize();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rescueHomeProvider);
    final notifier = _notifier;

    return PawMatePageScaffold(
      backgroundColor: AppColors.background,
      topBar: PawMateTopBar(
        title: 'PawMate',
        brandTitle: true,
        actions: [
          IconButton(
            key: const ValueKey('rescue-filter-button'),
            tooltip: 'Lọc ca cứu hộ',
            onPressed: () => _showFilterSheet(context, state.filter),
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            key: const ValueKey('rescue-notifications-button'),
            tooltip: 'Thông báo',
            onPressed: () => context.go('/notifications?returnTo=%2Frescue'),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            key: const ValueKey('rescue-settings-button'),
            tooltip: 'Cài đặt',
            onPressed: () => context.go('/profile/controls'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      bottomNavCurrentRoute: '/rescue',
      body: RefreshIndicator(
        key: const Key('rescue-refresh'),
        color: AppColors.deepGreen,
        onRefresh: notifier.refresh,
        child: ListView(
          key: const Key('rescue-live-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s16,
            AppSpacing.s16,
            AppSpacing.s16,
            AppSpacing.s32,
          ),
          children: [
            Text('Cứu hộ', style: AppTextStyles.pageTitle()),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Danh sách chó mèo đi lạc gần đây',
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s24),
            _RescueCreateCard(
              enabled: widget.createEnabled,
              onPressed: () => context.go('/rescue/create'),
            ),
            const SizedBox(height: AppSpacing.s24),
            if (state.status == RescueHomeLoadStatus.loading &&
                state.items.isEmpty)
              const _RescueLoadingContent()
            else if (state.status == RescueHomeLoadStatus.error)
              _RescueErrorContent(
                message: state.message ?? 'Không tải được các ca cứu hộ.',
                onRetry: notifier.refresh,
              )
            else if (state.status == RescueHomeLoadStatus.empty)
              _RescueEmptyContent(
                filter: state.filter,
                onClearFilter: state.filter == RescueHomeFilter.all
                    ? null
                    : () => notifier.applyFilter(RescueHomeFilter.all),
              )
            else
              _RescueReadyContent(
                state: state,
                onOpenMap: () => context.go('/rescue/map'),
                onOpenCase: (item) =>
                    context.go('/rescue/${Uri.encodeComponent(item.caseId)}'),
                onLoadMore: notifier.loadMore,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilterSheet(
    BuildContext context,
    RescueHomeFilter selected,
  ) async {
    final next = await showPawMateAdaptiveActionSheet<RescueHomeFilter>(
      context: context,
      title: 'Lọc ca cứu hộ',
      message: 'Chỉ dùng dữ liệu công khai và khu vực ước tính.',
      actions: [
        for (final filter in RescueHomeFilter.values)
          PawMateAdaptiveAction<RescueHomeFilter>(
            key: ValueKey('rescue-filter-${filter.name}'),
            label: filter == selected ? '✓ ${filter.label}' : filter.label,
            value: filter,
            icon: filter == selected ? Icons.check : Icons.filter_alt_outlined,
            isDefaultAction: filter == selected,
          ),
      ],
    );
    if (!mounted || next == null) return;
    await ref.read(rescueHomeProvider.notifier).applyFilter(next);
  }
}

class _RescueCreateCard extends StatelessWidget {
  const _RescueCreateCard({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: true,
      label: enabled
          ? 'Báo mất. Gửi thông tin tìm kiếm thú cưng.'
          : 'Báo mất. Mở luồng này khi tính năng tạo tin được bật.',
      child: PawMateCard(
        key: const Key('rescue-create-entry'),
        onTap: onPressed,
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.pets_rounded,
                size: 30,
                color: AppColors.deepGreen,
              ),
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Báo mất', style: AppTextStyles.h4()),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    enabled
                        ? 'Gửi thông tin tìm kiếm thú cưng ngay'
                        : 'Gửi thông tin tìm kiếm thú cưng',
                    style: AppTextStyles.bodyCompact(),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.brown),
          ],
        ),
      ),
    );
  }
}

class _RescueReadyContent extends StatelessWidget {
  const _RescueReadyContent({
    required this.state,
    required this.onOpenMap,
    required this.onOpenCase,
    required this.onLoadMore,
  });

  final RescueHomeState state;
  final VoidCallback onOpenMap;
  final ValueChanged<RescueCaseSummary> onOpenCase;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RescueMapPreview(items: state.items, onOpenMap: onOpenMap),
        const SizedBox(height: AppSpacing.s24),
        if (state.isStale && state.message != null)
          _StaleBanner(message: state.message!),
        _RescueListCard(
          state: state,
          onOpenCase: onOpenCase,
          onLoadMore: onLoadMore,
        ),
      ],
    );
  }
}

class _RescueListCard extends StatelessWidget {
  const _RescueListCard({
    required this.state,
    required this.onOpenCase,
    required this.onLoadMore,
  });

  final RescueHomeState state;
  final ValueChanged<RescueCaseSummary> onOpenCase;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final updatedLabel = state.lastUpdatedAt == null
        ? 'ĐANG CẬP NHẬT'
        : 'CẬP NHẬT ${_relativeTime(state.lastUpdatedAt!)}';
    return PawMateCard(
      key: const Key('rescue-nearby-list'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s16,
              AppSpacing.s16,
              AppSpacing.s8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text('5 ca gần nhất', style: AppTextStyles.h3()),
                ),
                const SizedBox(width: AppSpacing.s8),
                Flexible(
                  child: Text(
                    updatedLabel,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.captionStrong(),
                  ),
                ),
              ],
            ),
          ),
          for (final item in state.items)
            _RescueCaseRow(item: item, onTap: () => onOpenCase(item)),
          if (state.hasMore)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: OutlinedButton(
                key: const Key('rescue-load-more'),
                onPressed: state.isLoadingMore ? null : onLoadMore,
                child: state.isLoadingMore
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Xem thêm'),
              ),
            ),
        ],
      ),
    );
  }
}

class _RescueCaseRow extends StatelessWidget {
  const _RescueCaseRow({required this.item, required this.onTap});

  final RescueCaseSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = item.primaryImage;
    return Semantics(
      button: true,
      label:
          'Mở ${item.petName}, ${item.species.label}, ${item.status.label}, khu vực ước tính ${item.publicLocation.areaLabel}',
      child: InkWell(
        key: Key('rescue-case-${item.caseId}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _RescueThumbnail(item: item, image: image),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.petName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong(),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.breedOrColor ?? item.species.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyCompact(),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.publicLocation.areaLabel} · ${_caseTime(item.lostAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              _StatusChip(status: item.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _RescueThumbnail extends StatelessWidget {
  const _RescueThumbnail({required this.item, required this.image});

  final RescueCaseSummary item;
  final RescuePublicMedia? image;

  @override
  Widget build(BuildContext context) {
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(
        item.species == RescueSpecies.cat ? Icons.pets : Icons.pets_rounded,
        color: AppColors.deepGreen,
        size: 28,
      ),
    );
    if (image == null) {
      return SizedBox(width: 56, height: 56, child: placeholder);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Image.network(
        image!.publicUrl.toString(),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        semanticLabel: 'Ảnh minh họa ${item.petName}',
        errorBuilder: (_, _, _) =>
            SizedBox(width: 56, height: 56, child: placeholder),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final RescueCaseStatus status;

  @override
  Widget build(BuildContext context) {
    final found = status == RescueCaseStatus.found;
    return Container(
      constraints: const BoxConstraints(minHeight: 32, maxWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: found ? AppColors.surfaceContainer : const Color(0xFFDCE9E2),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        status.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.captionStrong(
          color: found ? AppColors.deepGreen : AppColors.deepGreen,
        ),
      ),
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('rescue-stale-banner'),
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: PawMateStatusColors.of(context).warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: PawMateStatusColors.of(context).warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 20,
            color: PawMateStatusColors.of(context).warning,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              'Dữ liệu hiển thị có thể đã cũ. $message',
              style: AppTextStyles.caption(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RescueLoadingContent extends StatelessWidget {
  const _RescueLoadingContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PawMateSkeleton(width: double.infinity, height: 178, borderRadius: 32),
        SizedBox(height: AppSpacing.s24),
        PawMateCard(
          padding: EdgeInsets.all(AppSpacing.s16),
          child: Column(
            children: [
              PawMateSkeleton(width: double.infinity, height: 30),
              SizedBox(height: AppSpacing.s16),
              PawMateSkeleton(width: double.infinity, height: 72),
              SizedBox(height: AppSpacing.s8),
              PawMateSkeleton(width: double.infinity, height: 72),
              SizedBox(height: AppSpacing.s8),
              PawMateSkeleton(width: double.infinity, height: 72),
            ],
          ),
        ),
      ],
    );
  }
}

class _RescueErrorContent extends StatelessWidget {
  const _RescueErrorContent({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PawMateStateView(
      type: PawMateStateType.error,
      icon: Icons.cloud_off_outlined,
      title: 'Chưa tải được ca cứu hộ',
      message: message,
      primaryActionLabel: 'Thử lại',
      onPrimaryAction: onRetry,
    );
  }
}

class _RescueEmptyContent extends StatelessWidget {
  const _RescueEmptyContent({
    required this.filter,
    required this.onClearFilter,
  });

  final RescueHomeFilter filter;
  final VoidCallback? onClearFilter;

  @override
  Widget build(BuildContext context) {
    return PawMateStateView(
      key: const Key('rescue-empty-state'),
      type: PawMateStateType.empty,
      icon: Icons.pets_outlined,
      title: 'Chưa có ca nào gần bạn',
      message: filter == RescueHomeFilter.all
          ? 'Hãy thử kiểm tra lại sau. PawMate chỉ hiển thị khu vực ước tính.'
          : 'Không có ca phù hợp với bộ lọc này.',
      primaryActionLabel: onClearFilter == null ? null : 'Xóa bộ lọc',
      onPrimaryAction: onClearFilter,
    );
  }
}

class _RescueSafetyCard extends StatelessWidget {
  const _RescueSafetyCard();

  @override
  Widget build(BuildContext context) {
    final status = PawMateStatusColors.of(context);
    return Semantics(
      container: true,
      label:
          'Cam kết an toàn. Chỉ dùng dữ liệu thử nghiệm. Không công khai vị trí chính xác hoặc thông tin liên hệ cá nhân.',
      child: Container(
        key: const Key('rescue-safety-note'),
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: status.infoContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: status.info.withValues(alpha: 0.35),
            width: AppBorderWidth.hairline,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.privacy_tip_outlined, color: status.info),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cam kết an toàn', style: AppTextStyles.bodyStrong()),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'Chỉ dùng tài khoản và dữ liệu thử nghiệm. Không công khai vị trí chính xác, số điện thoại hay địa chỉ cá nhân.',
                    style: AppTextStyles.bodyCompact(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _relativeTime(DateTime value) {
  final delta = DateTime.now().toUtc().difference(value.toUtc());
  if (delta.inSeconds < 60) return 'VỪA XONG';
  if (delta.inMinutes < 60) return '${delta.inMinutes} PHÚT TRƯỚC';
  if (delta.inHours < 24) return '${delta.inHours} GIỜ TRƯỚC';
  return '${delta.inDays} NGÀY TRƯỚC';
}

String _caseTime(DateTime value) {
  final delta = DateTime.now().toUtc().difference(value.toUtc());
  if (delta.isNegative || delta.inMinutes < 1) return 'vừa xong';
  if (delta.inHours < 1) return '${delta.inMinutes} phút trước';
  if (delta.inHours < 24) return '${delta.inHours} giờ trước';
  return '${delta.inDays} ngày trước';
}
