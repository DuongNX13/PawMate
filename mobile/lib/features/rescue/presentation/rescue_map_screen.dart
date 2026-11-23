import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_adaptive.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_chip.dart';
import '../application/rescue_map_provider.dart';
import '../domain/rescue_case_models.dart';
import '../domain/rescue_map_models.dart';
import 'rescue_map_canvas.dart';

class RescueMapScreen extends ConsumerStatefulWidget {
  const RescueMapScreen({super.key});

  @override
  ConsumerState<RescueMapScreen> createState() => _RescueMapScreenState();
}

class _RescueMapScreenState extends ConsumerState<RescueMapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(rescueMapProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rescueMapProvider);
    final notifier = ref.read(rescueMapProvider.notifier);
    final canvasBuilder = ref.watch(rescueMapCanvasBuilderProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _RescueMapSurface(
                state: state,
                builder: canvasBuilder,
                onMarkerTap: notifier.selectCase,
                onMapUnavailable: notifier.markMapUnavailable,
              ),
            ),
            Positioned(
              left: AppSpacing.s12,
              right: AppSpacing.s12,
              top: AppSpacing.s8,
              child: _RescueMapHeader(
                onBack: () => context.pop(),
                itemCount: state.items.length,
              ),
            ),
            Positioned(
              left: AppSpacing.s12,
              right: AppSpacing.s12,
              top: 88,
              child: _RescueFilterStrip(
                filters: state.filters,
                onClear: () => notifier.applyFilters(const RescueMapFilters()),
                onStatus: notifier.selectStatus,
                onSpecies: notifier.selectSpecies,
                onTime: notifier.selectTime,
              ),
            ),
            if (_needsLocationMessage(state.locationStatus))
              Positioned(
                left: AppSpacing.s12,
                // Reserve the floating-tools column so the banner's Retry
                // target stays reachable as its text wraps at larger scales.
                right:
                    AppSpacing.s16 +
                    AppControlSize.minTouchTarget +
                    AppSpacing.s12,
                top: 136,
                child: _LocationFallbackBanner(
                  status: state.locationStatus,
                  onRetry: notifier.retryLocation,
                ),
              ),
            if (!_needsLocationMessage(state.locationStatus))
              Positioned(
                right: AppSpacing.s16,
                top: 150,
                child: _MapToolButton(
                  key: const Key('rescue-map-current-location-button'),
                  icon: Icons.my_location_rounded,
                  semanticLabel: 'Dùng vị trí hiện tại',
                  onTap: notifier.retryLocation,
                ),
              ),
            Positioned(
              right: AppSpacing.s16,
              top: 210,
              child: _MapToolButton(
                key: const Key('rescue-map-layers-button'),
                icon: Icons.layers_rounded,
                semanticLabel: 'Xem lớp bản đồ',
                onTap: () => _showMapLayers(context),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _RescueMapBottomSheet(
                state: state,
                onRetry: () => notifier.refresh(),
                onRetryMap: notifier.retryMap,
                onReportLost: () => context.go('/rescue/create'),
                onClearFilters: () =>
                    notifier.applyFilters(const RescueMapFilters()),
                onViewAll: () =>
                    notifier.applyFilters(const RescueMapFilters()),
                onOpenCase: (item) =>
                    context.go('/rescue/${Uri.encodeComponent(item.caseId)}'),
                onClearSelection: notifier.clearSelection,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _needsLocationMessage(RescueLocationStatus status) =>
      status == RescueLocationStatus.permissionDenied ||
      status == RescueLocationStatus.serviceDisabled ||
      status == RescueLocationStatus.timeout ||
      status == RescueLocationStatus.error;

  Future<void> _showMapLayers(BuildContext context) async {
    await showPawMateAdaptiveDialog<void>(
      context: context,
      title: 'Lớp bản đồ',
      message:
          'Đang dùng bản đồ tiêu chuẩn. Vị trí ca cứu hộ được làm mờ theo bán kính riêng tư.',
      actions: const [
        PawMateAdaptiveAction<void>(label: 'Đã hiểu', isDefaultAction: true),
      ],
    );
  }
}

class _RescueMapHeader extends StatelessWidget {
  const _RescueMapHeader({required this.onBack, required this.itemCount});

  final VoidCallback onBack;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          key: const Key('rescue-map-back-button'),
          tooltip: 'Quay lại',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.brown,
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Semantics(
            header: true,
            label: 'PawMate, Bản đồ cứu hộ, $itemCount khu vực ước tính',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PawMate',
                  maxLines: 1,
                  style: AppTextStyles.h4(color: AppColors.deepGreen),
                ),
                Text(
                  'Bản đồ cứu hộ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h4(color: AppColors.brown),
                ),
              ],
            ),
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.mint,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.pets_rounded, color: AppColors.deepGreen),
        ),
      ],
    );
  }
}

class _RescueFilterStrip extends StatelessWidget {
  const _RescueFilterStrip({
    required this.filters,
    required this.onClear,
    required this.onStatus,
    required this.onSpecies,
    required this.onTime,
  });

  final RescueMapFilters filters;
  final VoidCallback onClear;
  final ValueChanged<RescueCaseStatus?> onStatus;
  final ValueChanged<RescueSpecies?> onSpecies;
  final ValueChanged<RescueTimeFilter> onTime;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      PawMateChip(
        key: const Key('rescue-map-filter-all'),
        label: 'Tất cả',
        selected:
            filters.status == null &&
            filters.species == null &&
            filters.time == RescueTimeFilter.all,
        onPressed: onClear,
        semanticLabel: 'Xóa bộ lọc',
      ),
      PawMateChip(
        key: const Key('rescue-map-filter-missing'),
        label: 'Chưa thấy',
        selected: filters.status == RescueCaseStatus.missing,
        onPressed: () => onStatus(
          filters.status == RescueCaseStatus.missing
              ? null
              : RescueCaseStatus.missing,
        ),
      ),
      PawMateChip(
        key: const Key('rescue-map-filter-found'),
        label: 'Đã thấy',
        selected: filters.status == RescueCaseStatus.found,
        onPressed: () => onStatus(
          filters.status == RescueCaseStatus.found
              ? null
              : RescueCaseStatus.found,
        ),
      ),
      PawMateChip(
        key: const Key('rescue-map-filter-dogs'),
        label: 'Chó',
        selected: filters.species == RescueSpecies.dog,
        onPressed: () => onSpecies(
          filters.species == RescueSpecies.dog ? null : RescueSpecies.dog,
        ),
      ),
      PawMateChip(
        key: const Key('rescue-map-filter-cats'),
        label: 'Mèo',
        selected: filters.species == RescueSpecies.cat,
        onPressed: () => onSpecies(
          filters.species == RescueSpecies.cat ? null : RescueSpecies.cat,
        ),
      ),
      PawMateChip(
        key: const Key('rescue-map-filter-24h'),
        label: '24 giờ',
        selected: filters.time == RescueTimeFilter.last24Hours,
        onPressed: () => onTime(
          filters.time == RescueTimeFilter.last24Hours
              ? RescueTimeFilter.all
              : RescueTimeFilter.last24Hours,
        ),
      ),
      PawMateChip(
        key: const Key('rescue-map-filter-7d'),
        label: '7 ngày',
        selected: filters.time == RescueTimeFilter.last7Days,
        onPressed: () => onTime(
          filters.time == RescueTimeFilter.last7Days
              ? RescueTimeFilter.all
              : RescueTimeFilter.last7Days,
        ),
      ),
    ];

    return Semantics(
      container: true,
      label: 'Bộ lọc bản đồ: ${filters.semanticsLabel}',
      child: SizedBox(
        height: AppControlSize.minTouchTarget,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < chips.length; index++) ...[
                if (index > 0) const SizedBox(width: AppSpacing.s8),
                chips[index],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationFallbackBanner extends StatelessWidget {
  const _LocationFallbackBanner({required this.status, required this.onRetry});

  final RescueLocationStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final copy = switch (status) {
      RescueLocationStatus.permissionDenied => (
        'Chưa có quyền vị trí',
        'Danh sách công khai vẫn dùng được theo thời gian.',
      ),
      RescueLocationStatus.serviceDisabled => (
        'Thiết bị đang tắt định vị',
        'Bật định vị để sắp xếp khu vực gần bạn.',
      ),
      RescueLocationStatus.timeout => (
        'Vị trí phản hồi chậm',
        'Đang dùng danh sách công khai gần đây.',
      ),
      _ => (
        'Không xác định được vị trí',
        'Bạn vẫn có thể xem danh sách và mở bài đăng.',
      ),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      label: '${copy.$1}. ${copy.$2}',
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s12,
            AppSpacing.s8,
            AppSpacing.s8,
            AppSpacing.s8,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_disabled_outlined,
                color: AppColors.brown,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(copy.$1, style: AppTextStyles.captionStrong()),
                    Text(
                      copy.$2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('rescue-map-location-retry'),
                tooltip: 'Thử lại vị trí',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                color: AppColors.deepGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapToolButton extends StatelessWidget {
  const _MapToolButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onTap,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        elevation: AppElevation.floating,
        child: IconButton(
          tooltip: semanticLabel,
          onPressed: onTap,
          icon: Icon(icon, color: AppColors.deepGreen),
        ),
      ),
    );
  }
}

class _RescueMapSurface extends StatelessWidget {
  const _RescueMapSurface({
    required this.state,
    required this.builder,
    required this.onMarkerTap,
    required this.onMapUnavailable,
  });

  final RescueMapState state;
  final RescueMapCanvasBuilder builder;
  final ValueChanged<String> onMarkerTap;
  final ValueChanged<Object> onMapUnavailable;

  @override
  Widget build(BuildContext context) {
    final center = state.center;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (state.mapUnavailable)
          const _MapUnavailableSurface()
        else if (center != null)
          KeyedSubtree(
            key: ValueKey(state.mapReloadToken),
            child: builder(center, state.items, onMarkerTap, onMapUnavailable),
          )
        else
          const _MapLoadingSurface(),
        if (state.status == RescueMapLoadStatus.loading)
          ColoredBox(
            color: AppColors.surface.withValues(alpha: 0.18),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _MapLoadingSurface extends StatelessWidget {
  const _MapLoadingSurface();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.lightBeige, AppColors.surfaceContainer],
        ),
      ),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _MapUnavailableSurface extends StatelessWidget {
  const _MapUnavailableSurface();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.lightBeige, AppColors.surfaceContainer],
        ),
      ),
      child: Center(
        child: Icon(Icons.map_outlined, size: 48, color: AppColors.deepGreen),
      ),
    );
  }
}

class _RescueMapBottomSheet extends StatelessWidget {
  const _RescueMapBottomSheet({
    required this.state,
    required this.onRetry,
    required this.onRetryMap,
    required this.onReportLost,
    required this.onClearFilters,
    required this.onViewAll,
    required this.onOpenCase,
    required this.onClearSelection,
  });

  final RescueMapState state;
  final VoidCallback onRetry;
  final VoidCallback onRetryMap;
  final VoidCallback onReportLost;
  final VoidCallback onClearFilters;
  final VoidCallback onViewAll;
  final ValueChanged<RescueCaseSummary> onOpenCase;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final sheetHeight = viewportHeight * (viewportHeight < 700 ? 0.48 : 0.415);
    final selected = state.selectedCase;
    final displayItems = selected == null
        ? state.items
        : [
            selected,
            ...state.items.where((item) => item.caseId != selected.caseId),
          ];

    return SizedBox(
      height: sheetHeight,
      child: Material(
        color: AppColors.background,
        elevation: AppElevation.none,
        child: SingleChildScrollView(
          key: const Key('rescue-map-sheet-scroll'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s24,
            AppSpacing.s8,
            AppSpacing.s24,
            AppSpacing.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.mapUnavailable) ...[
                _MapSheetState(
                  key: const ValueKey('rescue-map-unavailable'),
                  title: 'Bản đồ đang tạm gián đoạn',
                  message:
                      'Bạn vẫn có thể xem các ca cứu hộ ở dạng danh sách công khai.',
                  actionLabel: 'Tải lại bản đồ',
                  onAction: onRetryMap,
                ),
                const SizedBox(height: AppSpacing.s12),
              ],
              if (state.status == RescueMapLoadStatus.error &&
                  state.items.isEmpty)
                _MapSheetState(
                  key: const ValueKey('rescue-map-error'),
                  title: 'Chưa tải được ca cứu hộ',
                  message: state.message ?? 'Vui lòng thử lại sau.',
                  actionLabel: 'Thử lại',
                  onAction: onRetry,
                )
              else if (state.status == RescueMapLoadStatus.empty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MapSheetState(
                      key: const ValueKey('rescue-map-empty'),
                      title: 'Chưa có ca phù hợp',
                      message:
                          'Bạn có thể báo mất thú cưng để mọi người cùng tìm kiếm.',
                      actionLabel: 'Báo mất',
                      onAction: onReportLost,
                    ),
                    if (state.filters != const RescueMapFilters()) ...[
                      const SizedBox(height: AppSpacing.s8),
                      PawMateButton(
                        label: 'Xóa bộ lọc',
                        variant: PawMateButtonVariant.secondary,
                        compact: true,
                        onPressed: onClearFilters,
                      ),
                    ],
                  ],
                )
              else ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stackAction =
                        MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
                        constraints.maxWidth < 320;
                    final title = Text(
                      selected == null
                          ? state.usesNearbyQuery
                                ? 'Gần bạn nhất (${state.items.length})'
                                : 'Mới cập nhật (${state.items.length})'
                          : 'Đang chọn ${selected.petName}',
                      style: AppTextStyles.h4(),
                    );
                    final action = TextButton(
                      key: Key(
                        selected == null
                            ? 'rescue-map-view-all'
                            : 'rescue-map-clear-selection',
                      ),
                      onPressed: selected == null
                          ? onViewAll
                          : onClearSelection,
                      child: const Text('Xem tất cả'),
                    );

                    return stackAction
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              title,
                              Align(
                                alignment: Alignment.centerRight,
                                child: action,
                              ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: title),
                              action,
                            ],
                          );
                  },
                ),
                const SizedBox(height: AppSpacing.s12),
                if (state.isStale && state.message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                    child: Text(
                      'Đang hiển thị bản cập nhật trước: ${state.message}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(color: AppColors.textMuted),
                    ),
                  ),
                for (final item in displayItems.take(5)) ...[
                  _RescueMarkerCard(
                    key: ValueKey('rescue-marker-card-${item.caseId}'),
                    item: item,
                    selected: item.caseId == state.selectedCaseId,
                    onOpen: () => onOpenCase(item),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MapSheetState extends StatelessWidget {
  const _MapSheetState({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppTextStyles.h4()),
        const SizedBox(height: AppSpacing.s4),
        Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body(color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.s12),
        PawMateButton(label: actionLabel, compact: true, onPressed: onAction),
      ],
    );
  }
}

class _RescueMarkerCard extends StatelessWidget {
  const _RescueMarkerCard({
    super.key,
    required this.item,
    required this.selected,
    required this.onOpen,
  });

  final RescueCaseSummary item;
  final bool selected;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final distance = item.distanceMeters == null
        ? 'Khu vực ước tính'
        : '${(item.distanceMeters! / 1000).toStringAsFixed(1)} km';
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = MediaQuery.textScalerOf(context).scale(1) > 1.2;
        final statusChip = Container(
          constraints: const BoxConstraints(minHeight: 28),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            item.status.label,
            style: AppTextStyles.micro(color: AppColors.deepGreen),
          ),
        );
        final thumbnailSize = compact ? 64.0 : 80.0;
        final infoRow = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _MarkerThumbnail(item: item, size: thumbnailSize),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (compact) ...[
                    Text(
                      item.petName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardTitle(),
                    ),
                    const SizedBox(height: 2),
                    statusChip,
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.petName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.cardTitle(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        statusChip,
                      ],
                    ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.species.label} • $distance',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption(),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.publicLocation.areaLabel} • khu vực ước tính',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        );
        return Semantics(
          container: true,
          button: true,
          selected: selected,
          label:
              '${item.petName}, ${item.species.label}, ${item.status.label}, ${item.publicLocation.areaLabel}, khu vực ước tính',
          child: Material(
            color: selected ? AppColors.surfaceContainer : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InkWell(
              key: ValueKey('rescue-marker-select-${item.caseId}'),
              onTap: onOpen,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: 13,
                ),
                child: infoRow,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MarkerThumbnail extends StatelessWidget {
  const _MarkerThumbnail({required this.item, required this.size});

  final RescueCaseSummary item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.pets_rounded, color: AppColors.deepGreen),
    );
    final image = item.primaryImage;
    if (image == null) return placeholder;
    if (image.publicUrl.scheme == 'asset') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Image.asset(
          image.publicUrl.toString().substring('asset:'.length),
          width: size,
          height: size,
          fit: BoxFit.cover,
          semanticLabel: 'Ảnh minh họa ${item.petName}',
          errorBuilder: (_, _, _) => placeholder,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Image.network(
        image.publicUrl.toString(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: 'Ảnh minh họa ${item.petName}',
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}
