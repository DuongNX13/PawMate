import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_bottom_nav.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../application/vet_finder_session_provider.dart';
import '../application/vet_map_provider.dart';
import '../domain/vet_map_models.dart';
import '../domain/vet_models.dart';
import 'vet_actions.dart';
import 'vet_map_canvas.dart';
import 'vet_preview_sheet.dart';

class VetMapScreen extends ConsumerStatefulWidget {
  const VetMapScreen({super.key});

  @override
  ConsumerState<VetMapScreen> createState() => _VetMapScreenState();
}

class _VetMapScreenState extends ConsumerState<VetMapScreen> {
  VetMapStyle _mapStyle = VetMapStyle.standard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vetMapProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vetMapProvider);
    final finder = ref.watch(vetFinderSessionProvider);
    final builder = ref.watch(vetMapCanvasBuilderProvider);
    final notifier = ref.read(vetMapProvider.notifier);
    final compactAccessibility =
        MediaQuery.sizeOf(context).height < 700 &&
        MediaQuery.textScalerOf(context).scale(1) > 1.3;

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const PawMateBottomNav(currentRoute: '/vets/map'),
      body: SafeArea(
        // With expanded text, pinned overlays can obscure each other's touch
        // targets. Keep the normal map composition, but put compact
        // accessibility controls in a single scroll flow above the fixed nav.
        child: compactAccessibility
            ? ListView(
                key: const Key('vet-map-accessible-flow'),
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _VetMapHeader(
                      onNotificationsTap: () =>
                          context.go('/notifications?returnTo=%2Fvets%2Fmap'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _VetSearchBar(
                          onSearchTap: () => context.push('/vets/list'),
                          onFilterTap: () => context.push('/vets/list'),
                        ),
                        const SizedBox(height: 12),
                        _LocationPermissionStrip(
                          onEnableTap: () =>
                              notifier.refresh(forceLocationRefresh: true),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 160,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _VetMapSurface(
                            state: state,
                            builder: builder,
                            mapStyle: _mapStyle,
                            onMarkerTap: (vetId) {
                              ref
                                  .read(vetFinderSessionProvider.notifier)
                                  .selectVet(vetId);
                              _openPreviewSheet(vetId, state.items);
                            },
                            onMapUnavailable: notifier.markMapUnavailable,
                          ),
                        ),
                        Positioned(
                          right: 16,
                          top: 8,
                          child: Column(
                            children: [
                              _MapToolButton(
                                key: const Key(
                                  'vet-map-current-location-button',
                                ),
                                icon: Icons.my_location_rounded,
                                semanticLabel: 'Lấy lại vị trí hiện tại',
                                onTap: () => notifier.refresh(
                                  forceLocationRefresh: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _MapToolButton(
                                key: const Key('vet-map-style-toggle-button'),
                                icon: Icons.layers_outlined,
                                semanticLabel: 'Đổi kiểu bản đồ',
                                onTap: () => setState(
                                  () => _mapStyle =
                                      _mapStyle == VetMapStyle.standard
                                      ? VetMapStyle.night
                                      : VetMapStyle.standard,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _VetMapBottomPanel(
                    state: state,
                    selectedVetId: finder.selectedVetId,
                    onViewAll: () => context.push('/vets/list'),
                    onViewDetail: (vet) => context.push(
                      Uri(
                        path: '/vets/${vet.vetId}',
                        queryParameters: const {'returnTo': '/vets/map'},
                      ).toString(),
                    ),
                    onGetDirections: (vet) => launchVetDirections(context, vet),
                    onCallNow: (vet) => launchVetCall(context, vet.phone),
                    onRetry: () => notifier.refresh(forceLocationRefresh: true),
                    onRetryMap: notifier.retryMap,
                    onClearFilters: () {
                      ref
                          .read(vetFinderSessionProvider.notifier)
                          .resetFilters();
                      notifier.refresh();
                    },
                  ),
                ],
              )
            : Stack(
                children: [
                  Positioned.fill(
                    child: _VetMapSurface(
                      state: state,
                      builder: builder,
                      mapStyle: _mapStyle,
                      onMarkerTap: (vetId) {
                        ref
                            .read(vetFinderSessionProvider.notifier)
                            .selectVet(vetId);
                        _openPreviewSheet(vetId, state.items);
                      },
                      onMapUnavailable: notifier.markMapUnavailable,
                    ),
                  ),
                  Positioned(
                    right: 16,
                    top: 220,
                    child: Column(
                      children: [
                        _MapToolButton(
                          key: const Key('vet-map-current-location-button'),
                          icon: Icons.my_location_rounded,
                          semanticLabel: 'Lấy lại vị trí hiện tại',
                          onTap: () =>
                              notifier.refresh(forceLocationRefresh: true),
                        ),
                        const SizedBox(height: 12),
                        _MapToolButton(
                          key: const Key('vet-map-style-toggle-button'),
                          icon: Icons.layers_outlined,
                          semanticLabel: 'Đổi kiểu bản đồ',
                          onTap: () {
                            setState(() {
                              _mapStyle = _mapStyle == VetMapStyle.standard
                                  ? VetMapStyle.night
                                  : VetMapStyle.standard;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _VetMapBottomPanel(
                      state: state,
                      selectedVetId: finder.selectedVetId,
                      onViewAll: () => context.push('/vets/list'),
                      onViewDetail: (vet) => context.push(
                        Uri(
                          path: '/vets/${vet.vetId}',
                          queryParameters: const {'returnTo': '/vets/map'},
                        ).toString(),
                      ),
                      onGetDirections: (vet) =>
                          launchVetDirections(context, vet),
                      onCallNow: (vet) => launchVetCall(context, vet.phone),
                      onRetry: () =>
                          notifier.refresh(forceLocationRefresh: true),
                      onRetryMap: notifier.retryMap,
                      onClearFilters: () {
                        ref
                            .read(vetFinderSessionProvider.notifier)
                            .resetFilters();
                        notifier.refresh();
                      },
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    top: 10,
                    child: _VetMapHeader(
                      onNotificationsTap: () =>
                          context.go('/notifications?returnTo=%2Fvets%2Fmap'),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _VetSearchBar(
                          onSearchTap: () => context.push('/vets/list'),
                          onFilterTap: () => context.push('/vets/list'),
                        ),
                        const SizedBox(height: 12),
                        _LocationPermissionStrip(
                          onEnableTap: () =>
                              notifier.refresh(forceLocationRefresh: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _openPreviewSheet(String vetId, List<VetSummary> items) {
    final target = items.cast<VetSummary?>().firstWhere(
      (item) => item?.id == vetId,
      orElse: () => null,
    );
    if (target == null) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: AppColors.surface,
      builder: (context) => VetPreviewSheet(
        vet: target,
        onViewDetail: () {
          Navigator.of(context).pop();
          this.context.push(
            Uri(
              path: '/vets/${target.vetId}',
              queryParameters: const {'returnTo': '/vets/map'},
            ).toString(),
          );
        },
        onGetDirections: () => launchVetDirections(context, target),
        onCallNow: () => launchVetCall(context, target.phone),
      ),
    );
  }
}

class _VetMapHeader extends StatelessWidget {
  const _VetMapHeader({required this.onNotificationsTap});

  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactBrand =
        textScale > 1.3 ||
        (MediaQuery.sizeOf(context).width < 360 && textScale >= 1.3);

    return Row(
      children: [
        if (compactBrand)
          Semantics(
            label: 'PawMate',
            image: true,
            child: ExcludeSemantics(
              child: Icon(
                Icons.pets_rounded,
                color: AppColors.primary500,
                size: 24,
              ),
            ),
          )
        else ...[
          const Icon(Icons.pets_rounded, color: AppColors.primary500, size: 24),
          const SizedBox(width: AppSpacing.s8),
          Text('PawMate', style: AppTextStyles.h2(color: AppColors.primary700)),
        ],
        const Spacer(),
        IconButton(
          tooltip: 'Thông báo',
          onPressed: onNotificationsTap,
          icon: const Icon(Icons.notifications_none_rounded),
          color: AppColors.textPrimary,
        ),
        const SizedBox(width: AppSpacing.s8),
        Semantics(
          image: true,
          label: 'Ảnh đại diện thú cưng Kem',
          child: SizedBox.square(
            dimension: AppControlSize.minTouchTarget,
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.careGreenSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: Image.asset(
                  'assets/images/pets/p1_05_kem.png',
                  fit: BoxFit.cover,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) {
                          return child;
                        }
                        return const Icon(
                          Icons.pets_rounded,
                          color: AppColors.deepGreen,
                          size: 20,
                        );
                      },
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.pets_rounded,
                    color: AppColors.deepGreen,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VetSearchBar extends StatelessWidget {
  const _VetSearchBar({required this.onSearchTap, required this.onFilterTap});

  final VoidCallback onSearchTap;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('vet-map-search-shell'),
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      elevation: 3,
      shadowColor: AppColors.shadow,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: onSearchTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppControlSize.minTouchTarget,
          ),
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: AppColors.label,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  'Tìm phòng khám, bác sĩ...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.field(color: AppColors.textMuted),
                ),
              ),
              IconButton(
                tooltip: 'Bộ lọc phòng khám',
                onPressed: onFilterTap,
                icon: const Icon(Icons.tune_rounded),
                color: AppColors.primary700,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationPermissionStrip extends StatelessWidget {
  const _LocationPermissionStrip({required this.onEnableTap});

  final VoidCallback onEnableTap;

  @override
  Widget build(BuildContext context) {
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;
    final guidance = Text(
      'Bật định vị để tìm phòng khám gần nhất',
      maxLines: usesExpandedTextLayout ? null : 2,
      overflow: usesExpandedTextLayout ? null : TextOverflow.ellipsis,
      style: AppTextStyles.captionStrong(color: AppColors.deepGreen),
    );
    final enableButton = TextButton(
      onPressed: onEnableTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.deepGreen,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
        minimumSize: const Size(72, AppControlSize.minTouchTarget),
        textStyle: AppTextStyles.captionStrong(),
      ),
      child: const Text('Bật ngay'),
    );

    return Container(
      key: const Key('vet-map-location-banner'),
      constraints: const BoxConstraints(
        minHeight: AppControlSize.minTouchTarget,
      ),
      padding: usesExpandedTextLayout
          ? const EdgeInsets.fromLTRB(12, 8, 4, 4)
          : const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: AppColors.careGreenSoft.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: const [
          BoxShadow(
            color: AppColors.scrimSoft,
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: usesExpandedTextLayout
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.deepGreen,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(child: guidance),
                  ],
                ),
                Align(alignment: Alignment.centerRight, child: enableButton),
              ],
            )
          : Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.deepGreen,
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(child: guidance),
                enableButton,
              ],
            ),
    );
  }
}

class _VetMapSurface extends StatelessWidget {
  const _VetMapSurface({
    required this.state,
    required this.builder,
    required this.mapStyle,
    required this.onMarkerTap,
    required this.onMapUnavailable,
  });

  final VetMapState state;
  final VetMapCanvasBuilder builder;
  final VetMapStyle mapStyle;
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
            child: builder(
              center,
              state.items,
              mapStyle,
              onMarkerTap,
              onMapUnavailable,
            ),
          )
        else
          const _MapPlaceholder(),
        if (state.status == VetMapStatus.loading)
          Container(
            color: AppColors.surface.withValues(alpha: 0.16),
            alignment: const Alignment(0, -0.04),
            child: const CircularProgressIndicator(),
          ),
      ],
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.lightBeige, AppColors.surfaceContainer],
        ),
      ),
      child: CustomPaint(painter: _MapGridPainter()),
    );
  }
}

class _MapUnavailableSurface extends StatelessWidget {
  const _MapUnavailableSurface();

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactAccessibilitySurface =
        MediaQuery.sizeOf(context).height < 700 && textScale > 1.3;

    return ColoredBox(
      color: AppColors.lightBeige,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          // The recovery panel has the complete title, description and both
          // actions. At large text on a compact viewport, rendering that same
          // copy again in the map canvas leaves no usable surface and overflows
          // behind the panel. Keep this layer decorative; the panel remains
          // the semantic recovery surface.
          child: ExcludeSemantics(
            child: compactAccessibilitySurface
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: AppShadows.soft,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.map_outlined,
                        color: AppColors.primary500,
                        size: 28,
                      ),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: AppShadows.soft,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(18),
                          child: Icon(
                            Icons.map_outlined,
                            color: AppColors.primary500,
                            size: 34,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Bản đồ đang tạm gián đoạn',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bạn vẫn có thể xem đầy đủ phòng khám ở dạng danh sách.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.76)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final thinRoadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.58)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final parkPaint = Paint()..color = AppColors.mint;

    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.52,
        size.height * 0.35,
        size.width * 0.34,
        150,
      ),
      parkPaint,
    );

    for (var x = -40.0; x < size.width + 80; x += 78) {
      canvas.drawLine(Offset(x, 0), Offset(x + 90, size.height), thinRoadPaint);
    }
    for (var y = 132.0; y < size.height; y += 72) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 18), roadPaint);
    }
    canvas.drawLine(
      Offset(size.width * 0.42, 0),
      Offset(size.width * 0.52, size.height),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        elevation: 8,
        shadowColor: AppColors.shadow,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: AppColors.primary700),
          ),
        ),
      ),
    );
  }
}

class _VetMapBottomPanel extends StatelessWidget {
  const _VetMapBottomPanel({
    required this.state,
    required this.selectedVetId,
    required this.onViewAll,
    required this.onViewDetail,
    required this.onGetDirections,
    required this.onCallNow,
    required this.onRetry,
    required this.onRetryMap,
    required this.onClearFilters,
  });

  final VetMapState state;
  final String? selectedVetId;
  final VoidCallback onViewAll;
  final ValueChanged<VetSummary> onViewDetail;
  final ValueChanged<VetSummary> onGetDirections;
  final ValueChanged<VetSummary> onCallNow;
  final VoidCallback onRetry;
  final VoidCallback onRetryMap;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final compactHeight = MediaQuery.sizeOf(context).height < 700;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final visibleVet = state.items.cast<VetSummary?>().firstWhere(
      (item) => item?.vetId == selectedVetId,
      orElse: () => state.items.isNotEmpty ? state.items.first : null,
    );
    final Widget panel;
    if (state.mapUnavailable) {
      panel = _MapPanelState(
        key: const ValueKey('map-unavailable'),
        title: 'Không hiển thị được bản đồ',
        description:
            'Dịch vụ bản đồ đang tạm gián đoạn. Chuyển sang danh sách để tiếp tục tìm phòng khám.',
        actionLabel: 'Tải lại bản đồ',
        onAction: onRetryMap,
        secondaryActionLabel: 'Xem dạng danh sách',
        onSecondaryAction: onViewAll,
      );
    } else {
      panel = switch (state.status) {
        VetMapStatus.loading => const _MapPanelLoading(),
        VetMapStatus.permissionDenied => _MapPanelState(
          key: const ValueKey('permission-denied'),
          title: 'Chưa có quyền vị trí',
          description:
              state.message ??
              'Bật quyền vị trí để PawMate tìm phòng khám quanh bạn.',
          actionLabel: 'Bật ngay',
          onAction: onRetry,
          secondaryActionLabel: 'Xem dạng danh sách',
          onSecondaryAction: onViewAll,
        ),
        VetMapStatus.locationServicesDisabled => _MapPanelState(
          key: const ValueKey('location-disabled'),
          title: 'Thiết bị đang tắt định vị',
          description:
              state.message ??
              'Hãy bật dịch vụ vị trí rồi tải lại danh sách gần bạn.',
          actionLabel: 'Tải lại',
          onAction: onRetry,
          secondaryActionLabel: 'Xem dạng danh sách',
          onSecondaryAction: onViewAll,
        ),
        VetMapStatus.error => _MapPanelState(
          key: const ValueKey('map-error'),
          title: 'Không tải được dữ liệu gần bạn',
          description:
              state.message ?? 'Có lỗi khi tải dữ liệu phòng khám gần bạn.',
          actionLabel: 'Thử lại',
          onAction: onRetry,
          secondaryActionLabel: 'Xem dạng danh sách',
          onSecondaryAction: onViewAll,
        ),
        VetMapStatus.empty => _MapPanelState(
          key: const ValueKey('map-empty'),
          title: 'Trống',
          description:
              'Chưa có phòng khám trong bán kính hiện tại. Hãy đổi bộ lọc hoặc xem danh sách.',
          actionLabel: 'Xem dạng danh sách',
          onAction: onViewAll,
          secondaryActionLabel: 'Xóa bộ lọc',
          onSecondaryAction: onClearFilters,
        ),
        _ when visibleVet != null => _VetPreviewCard(
          key: ValueKey(visibleVet.vetId),
          vet: visibleVet,
          onViewDetail: () => onViewDetail(visibleVet),
          onGetDirections: () => onGetDirections(visibleVet),
          onCallNow: () => onCallNow(visibleVet),
        ),
        _ => _MapPanelState(
          key: const ValueKey('map-idle'),
          title: 'Đang chuẩn bị bản đồ',
          description: 'PawMate sẽ tải vị trí và phòng khám gần bạn.',
          actionLabel: 'Tải lại',
          onAction: onRetry,
        ),
      };
    }

    return Container(
      key: const Key('vet-map-bottom-panel'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      constraints: BoxConstraints(
        maxHeight: textScale > 1.3 ? 390 : (compactHeight ? 224 : 260),
      ),
      padding: EdgeInsets.fromLTRB(
        compactHeight ? 12 : 16,
        compactHeight ? 10 : 14,
        compactHeight ? 12 : 16,
        compactHeight ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: SingleChildScrollView(
        primary: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: panel,
        ),
      ),
    );
  }
}

class _MapPanelLoading extends StatelessWidget {
  const _MapPanelLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      key: ValueKey('map-loading'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _PanelHandle(),
        SizedBox(height: 34),
        Center(child: CircularProgressIndicator()),
        SizedBox(height: 34),
      ],
    );
  }
}

class _MapPanelState extends StatelessWidget {
  const _MapPanelState({
    super.key,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final expandedText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PanelHandle(),
        const SizedBox(height: 18),
        Text(
          title,
          maxLines: expandedText ? null : 2,
          overflow: expandedText ? TextOverflow.visible : TextOverflow.ellipsis,
          style: AppTextStyles.h4(),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          maxLines: expandedText ? null : 3,
          overflow: expandedText ? TextOverflow.visible : TextOverflow.ellipsis,
          style: AppTextStyles.bodyCompact(),
        ),
        const SizedBox(height: 16),
        PawMateButton(label: actionLabel, onPressed: onAction),
        if (secondaryActionLabel != null && onSecondaryAction != null) ...[
          const SizedBox(height: 8),
          PawMateButton(
            label: secondaryActionLabel!,
            onPressed: onSecondaryAction,
            variant: PawMateButtonVariant.secondary,
          ),
        ],
      ],
    );
  }
}

class _VetPreviewCard extends StatelessWidget {
  const _VetPreviewCard({
    super.key,
    required this.vet,
    required this.onViewDetail,
    required this.onGetDirections,
    required this.onCallNow,
  });

  final VetSummary vet;
  final VoidCallback onViewDetail;
  final VoidCallback onGetDirections;
  final VoidCallback onCallNow;

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final compactHeight = mediaSize.height < 700;
    final accessibilityText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ClinicThumb(compact: compactHeight),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          vet.name,
                          maxLines: accessibilityText ? null : 2,
                          overflow: accessibilityText
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          style: AppTextStyles.h4(),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Xem chi tiết ${vet.name}',
                        child: IconButton(
                          key: const Key('vet-map-info-button'),
                          tooltip: 'Xem chi tiết phòng khám',
                          onPressed: onViewDetail,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: AppControlSize.minTouchTarget,
                            minHeight: AppControlSize.minTouchTarget,
                          ),
                          icon: const Icon(Icons.info_outline_rounded),
                          color: AppColors.primary700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Text('Google', style: AppTextStyles.bodyCompact()),
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.warningAccent,
                        size: 18,
                      ),
                      Text(
                        vet.averageRating?.toStringAsFixed(1) ?? '—',
                        style: AppTextStyles.bodyCompact(
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: AppColors.primary700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _openingCopy(vet),
                          maxLines: accessibilityText ? null : 1,
                          overflow: accessibilityText
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          style: AppTextStyles.captionStrong(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 18,
                        color: AppColors.primary700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          vet.address,
                          maxLines: accessibilityText ? null : 2,
                          overflow: accessibilityText
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          style: AppTextStyles.captionStrong(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: compactHeight ? 8 : 12),
        Row(
          children: [
            Expanded(
              child: PawMateButton(
                label: 'Gọi ngay',
                compact: true,
                leadingIcon: Icons.call_rounded,
                onPressed: onCallNow,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PawMateButton(
                label: 'Chỉ đường',
                compact: true,
                leadingIcon: Icons.assistant_direction_outlined,
                onPressed: onGetDirections,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _openingCopy(VetSummary vet) {
    if (vet.is24h == true) {
      return '00:00–24:00';
    }
    return vet.isOpen == null ? 'Đang cập nhật giờ' : '08:00–21:00';
  }
}

class _PanelHandle extends StatelessWidget {
  const _PanelHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 48,
        height: 6,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}

class _ClinicThumb extends StatelessWidget {
  const _ClinicThumb({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Hình minh họa phòng khám thú y',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Image.asset(
          'assets/images/brand/pawmate_vet_clinic_reception.png',
          width: compact ? 96 : 116,
          height: compact ? 96 : 116,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: compact ? 96 : 116,
            height: compact ? 96 : 116,
            color: AppColors.surfaceContainer,
            alignment: Alignment.center,
            child: const Icon(
              Icons.local_hospital_outlined,
              color: AppColors.primary700,
            ),
          ),
        ),
      ),
    );
  }
}
