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
    this.mapPreviewAsset,
    this.now,
  });

  final bool browseEnabled;
  final bool createEnabled;
  final String? mapPreviewAsset;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    if (!browseEnabled) {
      return _RescueStagedHomeScreen(
        browseEnabled: browseEnabled,
        createEnabled: createEnabled,
      );
    }
    return _RescueLiveHomeScreen(
      createEnabled: createEnabled,
      mapPreviewAsset: mapPreviewAsset,
      now: now,
    );
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
      layoutMode: PawMatePageLayoutMode.fullResponsive,
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
  const _RescueLiveHomeScreen({
    required this.createEnabled,
    required this.mapPreviewAsset,
    required this.now,
  });

  final bool createEnabled;
  final String? mapPreviewAsset;
  final DateTime Function()? now;

  @override
  ConsumerState<_RescueLiveHomeScreen> createState() =>
      _RescueLiveHomeScreenState();
}

class _RescueLiveHomeScreenState extends ConsumerState<_RescueLiveHomeScreen>
    with RestorationMixin {
  late final RescueHomeNotifier _notifier;
  final RestorableStringN _selectedCaseId = RestorableStringN(null);

  @override
  String get restorationId => 'rescue-home-selection';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_selectedCaseId, 'selected-case-id');
  }

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
    _selectedCaseId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rescueHomeProvider);
    final now = widget.now?.call() ?? ref.watch(rescueClockProvider)();
    final notifier = _notifier;
    RescueCaseSummary? selectedCase;
    for (final item in state.items) {
      if (item.caseId == _selectedCaseId.value) selectedCase = item;
    }
    final selectedCard = _selectedCaseId.value == null
        ? null
        : _RescueSelectedCaseCard(
            item: selectedCase,
            onClose: () => setState(() => _selectedCaseId.value = null),
            onOpenDetails: selectedCase == null
                ? null
                : () => context.push(
                    '/rescue/${Uri.encodeComponent(selectedCase!.caseId)}',
                  ),
          );

    return PawMatePageScaffold(
      layoutMode: PawMatePageLayoutMode.fullResponsive,
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
            AppSpacing.s24,
            AppSpacing.s16,
            AppSpacing.s32,
          ),
          children: [
            Text('Cứu hộ', style: AppTextStyles.pageTitle()),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Danh sách chó mèo đi lạc quanh bạn',
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s16),
            _RescueCreateCard(
              enabled: widget.createEnabled,
              onPressed: () => context.go('/rescue/create'),
            ),
            const SizedBox(height: AppSpacing.s12),
            if (selectedCard != null &&
                (state.status == RescueHomeLoadStatus.empty ||
                    state.status == RescueHomeLoadStatus.error))
              selectedCard,
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
                now: now,
                mapPreviewAsset: widget.mapPreviewAsset,
                onOpenMap: () => context.go('/rescue/map'),
                onOpenCase: (item) =>
                    context.push('/rescue/${Uri.encodeComponent(item.caseId)}'),
                selectedCaseId: _selectedCaseId.value,
                onSelectCase: (item) =>
                    setState(() => _selectedCaseId.value = item.caseId),
                selectedCard: selectedCard,
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s8,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.pets_rounded,
                  size: 24,
                  color: AppColors.deepGreen,
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Báo mất', style: AppTextStyles.h4()),
                    Text(
                      enabled
                          ? 'Gửi thông tin tìm kiếm thú cưng ngay'
                          : 'Gửi thông tin tìm kiếm thú cưng',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.brown),
            ],
          ),
        ),
      ),
    );
  }
}

class _RescueReadyContent extends StatelessWidget {
  const _RescueReadyContent({
    required this.state,
    required this.now,
    required this.mapPreviewAsset,
    required this.onOpenMap,
    required this.onOpenCase,
    required this.selectedCaseId,
    required this.onSelectCase,
    required this.selectedCard,
  });

  final RescueHomeState state;
  final DateTime now;
  final String? mapPreviewAsset;
  final VoidCallback onOpenMap;
  final ValueChanged<RescueCaseSummary> onOpenCase;
  final String? selectedCaseId;
  final ValueChanged<RescueCaseSummary> onSelectCase;
  final Widget? selectedCard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RescueMapPreview(
          items: state.items,
          onOpenMap: onOpenMap,
          backgroundAsset: mapPreviewAsset,
          selectedCaseId: selectedCaseId,
          onSelectCase: onSelectCase,
        ),
        const SizedBox(height: AppSpacing.s12),
        if (selectedCard != null) ...[
          selectedCard!,
          const SizedBox(height: AppSpacing.s12),
        ],
        if (state.isStale && state.message != null)
          _StaleBanner(message: state.message!),
        _RescueListCard(state: state, now: now, onOpenCase: onOpenCase),
      ],
    );
  }
}

class _RescueSelectedCaseCard extends StatelessWidget {
  const _RescueSelectedCaseCard({
    required this.item,
    required this.onClose,
    required this.onOpenDetails,
  });

  final RescueCaseSummary? item;
  final VoidCallback onClose;
  final VoidCallback? onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final value = item;
    return PawMateCard(
      key: Key(
        value == null
            ? 'rescue-selected-unavailable'
            : 'rescue-selected-case-card',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  value?.petName ?? 'Ca đã chọn không còn trong danh sách',
                  style: AppTextStyles.h3(),
                ),
              ),
              IconButton(
                key: const Key('rescue-selected-close'),
                tooltip: 'Đóng thông tin ca đã chọn',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          if (value == null)
            Text(
              'Tin báo có thể đã bị xóa hoặc không còn phù hợp bộ lọc. Hãy chọn một ca khác.',
              style: AppTextStyles.body(),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RescueThumbnail(item: value, image: value.primaryImage),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          value.breedOrColor ?? value.species.label,
                          if (value.ageLabel != null) value.ageLabel!,
                        ].join(' · '),
                        style: AppTextStyles.body(),
                      ),
                      Text(
                        'Khu vực ước tính: ${value.publicLocation.areaLabel}',
                        style: AppTextStyles.bodyCompact(),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      _StatusChip(status: value.status),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            FilledButton(
              key: const Key('rescue-selected-details'),
              onPressed: onOpenDetails,
              child: const Text('Xem chi tiết'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RescueListCard extends StatefulWidget {
  const _RescueListCard({
    required this.state,
    required this.now,
    required this.onOpenCase,
  });

  final RescueHomeState state;
  final DateTime now;
  final ValueChanged<RescueCaseSummary> onOpenCase;

  @override
  State<_RescueListCard> createState() => _RescueListCardState();
}

class _RescueListCardState extends State<_RescueListCard>
    with RestorationMixin {
  final RestorableBool _isExpanded = RestorableBool(false);

  void _toggleExpanded() =>
      setState(() => _isExpanded.value = !_isExpanded.value);

  @override
  String? get restorationId => 'rescue-nearby-list';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_isExpanded, 'expanded');
  }

  @override
  void dispose() {
    _isExpanded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;
    final mediaQuery = MediaQuery.of(context);
    final reduceMotion =
        mediaQuery.disableAnimations || mediaQuery.accessibleNavigation;
    final state = widget.state;
    final now = widget.now;
    final nearbyItems = state.items.take(5).toList(growable: false);
    final visibleItems = _isExpanded.value
        ? nearbyItems
        : nearbyItems.take(2).toList(growable: false);
    final canToggle = nearbyItems.length > 2;
    final caseRows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in visibleItems)
          _RescueCaseRow(
            item: item,
            now: now,
            onTap: () => widget.onOpenCase(item),
          ),
      ],
    );
    final updatedLabel = state.lastUpdatedAt == null
        ? 'ĐANG CẬP NHẬT'
        : 'CẬP NHẬT ${_relativeTime(state.lastUpdatedAt!, now)}';
    final header = usesExpandedTextLayout
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('5 ca gần nhất', style: AppTextStyles.h3()),
              const SizedBox(height: AppSpacing.s4),
              Text(updatedLabel, style: AppTextStyles.captionStrong()),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text('5 ca gần nhất', style: AppTextStyles.h3())),
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
          );
    return PawMateCard(
      key: const Key('rescue-nearby-list'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s12,
              AppSpacing.s16,
              AppSpacing.s8,
            ),
            child: header,
          ),
          if (reduceMotion)
            KeyedSubtree(
              key: const Key('rescue-nearby-animated-size'),
              child: caseRows,
            )
          else
            AnimatedSize(
              key: const Key('rescue-nearby-animated-size'),
              duration: AppMotion.standard,
              curve: AppMotion.standardCurve,
              alignment: Alignment.topCenter,
              child: caseRows,
            ),
          if (canToggle)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s12,
                AppSpacing.s4,
                AppSpacing.s12,
                AppSpacing.s8,
              ),
              child: Semantics(
                key: const Key('rescue-nearby-toggle'),
                button: true,
                toggled: _isExpanded.value,
                onTap: _toggleExpanded,
                label: _isExpanded.value
                    ? 'Thu gọn danh sách ca gần nhất'
                    : 'Mở rộng 5 ca gần nhất',
                child: ExcludeSemantics(
                  child: OutlinedButton(
                    key: const Key('rescue-load-more'),
                    onPressed: _toggleExpanded,
                    child: Text(_isExpanded.value ? 'Thu gọn' : 'Xem thêm'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RescueCaseRow extends StatelessWidget {
  const _RescueCaseRow({
    required this.item,
    required this.now,
    required this.onTap,
  });

  final RescueCaseSummary item;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = item.primaryImage;
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.petName,
          maxLines: usesExpandedTextLayout ? null : 1,
          overflow: usesExpandedTextLayout ? null : TextOverflow.ellipsis,
          style: AppTextStyles.bodyStrong(),
        ),
        const SizedBox(height: 2),
        Text(
          item.breedOrColor ?? item.species.label,
          maxLines: usesExpandedTextLayout ? null : 1,
          overflow: usesExpandedTextLayout ? null : TextOverflow.ellipsis,
          style: AppTextStyles.bodyCompact(),
        ),
        const SizedBox(height: 2),
        Text(
          '${item.publicLocation.areaLabel} · ${_caseTime(item.lostAt, now)}',
          maxLines: usesExpandedTextLayout ? null : 2,
          overflow: usesExpandedTextLayout ? null : TextOverflow.ellipsis,
          style: AppTextStyles.caption(),
        ),
      ],
    );
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
            vertical: AppSpacing.s4,
          ),
          child: usesExpandedTextLayout
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RescueThumbnail(item: item, image: image),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(child: details),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _StatusChip(status: item.status),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _RescueThumbnail(item: item, image: image),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(child: details),
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
      return SizedBox(width: 52, height: 52, child: placeholder);
    }
    if (image!.publicUrl.scheme == 'asset') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Image.asset(
          image!.publicUrl.path,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          semanticLabel: 'Ảnh minh họa ${item.petName}',
          errorBuilder: (_, _, _) =>
              SizedBox(width: 52, height: 52, child: placeholder),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Image.network(
        image!.publicUrl.toString(),
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        semanticLabel: 'Ảnh minh họa ${item.petName}',
        errorBuilder: (_, _, _) =>
            SizedBox(width: 52, height: 52, child: placeholder),
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
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;
    return Container(
      constraints: BoxConstraints(
        minHeight: usesExpandedTextLayout ? AppControlSize.minTouchTarget : 32,
        maxWidth: usesExpandedTextLayout ? double.infinity : 88,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: usesExpandedTextLayout ? AppSpacing.s4 : 0,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: found ? AppColors.surfaceContainer : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        status.label,
        maxLines: usesExpandedTextLayout ? null : 1,
        overflow: usesExpandedTextLayout ? null : TextOverflow.ellipsis,
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
        PawMateSkeleton(width: double.infinity, height: 193, borderRadius: 32),
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

String _relativeTime(DateTime value, DateTime now) {
  final delta = now.toUtc().difference(value.toUtc());
  if (delta.isNegative) return 'VỪA XONG';
  if (delta.inSeconds < 60) return 'VỪA XONG';
  if (delta.inMinutes < 60) return '${delta.inMinutes} PHÚT TRƯỚC';
  if (delta.inHours < 24) return '${delta.inHours} GIỜ TRƯỚC';
  return '${delta.inDays} NGÀY TRƯỚC';
}

String _caseTime(DateTime value, DateTime now) {
  final delta = now.toUtc().difference(value.toUtc());
  if (delta.isNegative || delta.inMinutes < 1) return 'vừa xong';
  if (delta.inHours < 1) return '${delta.inMinutes} phút trước';
  if (delta.inHours < 24) return '${delta.inHours} giờ trước';
  return '${delta.inDays} ngày trước';
}
