import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_bottom_nav.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_chip.dart';
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

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const PawMateBottomNav(currentRoute: '/vets/map'),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _VetMapSurface(
                state: state,
                builder: builder,
                mapStyle: _mapStyle,
                onMarkerTap: (vetId) {
                  ref.read(vetFinderSessionProvider.notifier).selectVet(vetId);
                  _openPreviewSheet(vetId, state.items);
                },
                onMapUnavailable: notifier.markMapUnavailable,
              ),
            ),
            Positioned(
              right: 16,
              top: 316,
              child: Column(
                children: [
                  _MapToolButton(
                    key: const Key('vet-map-current-location-button'),
                    icon: Icons.my_location_rounded,
                    semanticLabel: 'Lấy lại vị trí hiện tại',
                    onTap: () => notifier.refresh(forceLocationRefresh: true),
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
                onGetDirections: (vet) => launchVetDirections(context, vet),
                onCallNow: (vet) => launchVetCall(context, vet.phone),
                onRetry: () => notifier.refresh(forceLocationRefresh: true),
                onRetryMap: notifier.retryMap,
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
              top: 104,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _VetSearchBar(
                    onSearchTap: () => context.push('/vets/list'),
                    onFilterTap: () => context.push('/vets/list'),
                  ),
                  const SizedBox(height: 12),
                  _VetMapFilters(
                    radiusMeters: state.radiusMeters,
                    only24h: state.only24h,
                    openNow: state.openNow,
                    rating4Plus: state.minRating == 4,
                    onSelectNearest: () => notifier.selectRadius(3000),
                    onSelectFiveKm: () => notifier.selectRadius(5000),
                    onToggleOnly24h: notifier.toggleOnly24h,
                    onToggleOpenNow: notifier.toggleOpenNow,
                    onToggleRating4Plus: notifier.toggleRating4Plus,
                  ),
                  const SizedBox(height: 10),
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
    return Row(
      children: [
        const Icon(Icons.pets_rounded, color: AppColors.primary500, size: 24),
        const SizedBox(width: AppSpacing.s8),
        Text('PawMate', style: AppTextStyles.h2(color: AppColors.primary700)),
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
          child: Container(
            width: 44,
            height: 44,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.careGreenSoft,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Image.asset(
              'assets/images/pets/p1_05_kem.png',
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) {
                  return child;
                }
                return const Icon(
                  Icons.pets_rounded,
                  color: AppColors.deepGreen,
                  size: 22,
                );
              },
              errorBuilder: (_, _, _) => const Icon(
                Icons.pets_rounded,
                color: AppColors.deepGreen,
                size: 22,
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
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      elevation: 3,
      shadowColor: AppColors.shadow,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: onSearchTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
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

class _VetMapFilters extends StatelessWidget {
  const _VetMapFilters({
    required this.radiusMeters,
    required this.only24h,
    required this.openNow,
    required this.rating4Plus,
    required this.onSelectNearest,
    required this.onSelectFiveKm,
    required this.onToggleOnly24h,
    required this.onToggleOpenNow,
    required this.onToggleRating4Plus,
  });

  final int radiusMeters;
  final bool only24h;
  final bool openNow;
  final bool rating4Plus;
  final VoidCallback onSelectNearest;
  final VoidCallback onSelectFiveKm;
  final VoidCallback onToggleOnly24h;
  final VoidCallback onToggleOpenNow;
  final VoidCallback onToggleRating4Plus;

  @override
  Widget build(BuildContext context) {
    final primaryFilters = <Widget>[
      _MapPillButton(
        controlKey: const Key('vet-map-filter-nearest'),
        label: 'Gần nhất',
        selected: radiusMeters == 3000,
        icon: Icons.near_me_rounded,
        onTap: onSelectNearest,
      ),
      _MapPillButton(
        controlKey: const Key('vet-map-filter-24h'),
        label: '24/7',
        selected: only24h,
        onTap: onToggleOnly24h,
      ),
      _MapPillButton(
        controlKey: const Key('vet-map-filter-open-now'),
        label: 'Đang mở',
        selected: openNow,
        onTap: onToggleOpenNow,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // v0.30 deliberately shows three complete filters on narrow screens.
        // Hiding the lower-priority pair avoids the clipped empty fourth pill;
        // the full pair remains available on wider map layouts.
        if (constraints.maxWidth <= 400) {
          return Row(
            children: [
              for (var index = 0; index < primaryFilters.length; index++) ...[
                if (index > 0) const SizedBox(width: AppSpacing.s8),
                Expanded(child: primaryFilters[index]),
              ],
            ],
          );
        }

        return SizedBox(
          height: AppControlSize.minTouchTarget,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in primaryFilters) ...[
                  filter,
                  const SizedBox(width: AppSpacing.s8),
                ],
                _MapPillButton(
                  controlKey: const Key('vet-map-filter-5km'),
                  label: '5 km',
                  selected: radiusMeters == 5000,
                  onTap: onSelectFiveKm,
                ),
                const SizedBox(width: AppSpacing.s8),
                _MapPillButton(
                  controlKey: const Key('vet-map-filter-rating-4'),
                  label: 'Đánh giá 4+',
                  selected: rating4Plus,
                  onTap: onToggleRating4Plus,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LocationPermissionStrip extends StatelessWidget {
  const _LocationPermissionStrip({required this.onEnableTap});

  final VoidCallback onEnableTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('vet-map-location-banner'),
      constraints: const BoxConstraints(
        minHeight: AppControlSize.minTouchTarget,
      ),
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: AppColors.careGreenSoft.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: AppColors.deepGreen),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              'Bật định vị để tìm phòng khám gần nhất',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.captionStrong(color: AppColors.deepGreen),
            ),
          ),
          TextButton(
            onPressed: onEnableTap,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.deepGreen,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
              minimumSize: const Size(72, AppControlSize.minTouchTarget),
              textStyle: AppTextStyles.captionStrong(),
            ),
            child: const Text('Bật ngay'),
          ),
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
    return ColoredBox(
      color: AppColors.lightBeige,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
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
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
  });

  final VetMapState state;
  final String? selectedVetId;
  final VoidCallback onViewAll;
  final ValueChanged<VetSummary> onViewDetail;
  final ValueChanged<VetSummary> onGetDirections;
  final ValueChanged<VetSummary> onCallNow;
  final VoidCallback onRetry;
  final VoidCallback onRetryMap;

  @override
  Widget build(BuildContext context) {
    final compactHeight = MediaQuery.sizeOf(context).height < 700;
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
      constraints: BoxConstraints(maxHeight: compactHeight ? 230 : 390),
      padding: EdgeInsets.fromLTRB(
        compactHeight ? 16 : 20,
        compactHeight ? 8 : 10,
        compactHeight ? 16 : 20,
        compactHeight ? 12 : 18,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppShadows.raised,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PanelHandle(),
        const SizedBox(height: 18),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.h4(),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
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
    final showActionIcons = mediaSize.width >= 480;
    final compactHeight = mediaSize.height < 700;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PanelHandle(),
        SizedBox(height: compactHeight ? 8 : 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vet.name,
                    maxLines: compactHeight ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h3(),
                  ),
                  SizedBox(height: compactHeight ? 4 : 10),
                  Row(
                    children: [
                      _RatingBadge(vet: vet),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _reviewLabel(vet),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.captionStrong(),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compactHeight ? 4 : 10),
                  Row(
                    children: [
                      _StatusDot(open: vet.isOpen == true),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _openingCopy(vet),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.captionStrong(),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compactHeight ? 4 : 6),
                  Text(
                    vet.address,
                    maxLines: compactHeight ? 1 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.captionStrong(),
                  ),
                ],
              ),
            ),
            if (!compactHeight) ...[
              const SizedBox(width: 14),
              const _ClinicThumb(),
            ],
          ],
        ),
        if (!compactHeight) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _FeatureChip(
                  icon: Icons.location_on_outlined,
                  label: vet.distanceLabel ?? 'Gần bạn',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FeatureChip(
                  icon: Icons.medical_services_outlined,
                  label: vet.is24h == true ? 'Cấp cứu 24/7' : vet.statusLabel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FeatureChip(
                  icon: Icons.vaccines_outlined,
                  label: vet.displayServices.length > 1
                      ? vet.displayServices[1]
                      : vet.displayServices.first,
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: compactHeight ? 10 : 16),
        Row(
          children: [
            Expanded(
              child: PawMateButton(
                label: 'Gọi ngay',
                compact: true,
                leadingIcon: showActionIcons ? Icons.call_rounded : null,
                onPressed: onCallNow,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PawMateButton(
                label: 'Chỉ đường',
                compact: true,
                leadingIcon: showActionIcons
                    ? Icons.assistant_direction_outlined
                    : null,
                onPressed: onGetDirections,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PawMateButton(
                label: 'Chi tiết',
                compact: true,
                leadingIcon: showActionIcons
                    ? Icons.info_outline_rounded
                    : null,
                onPressed: onViewDetail,
                variant: PawMateButtonVariant.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _reviewLabel(VetSummary vet) {
    if (vet.reviewCount > 0) {
      return '(${vet.reviewCount}+ đánh giá)';
    }
    return 'Đang cập nhật đánh giá';
  }

  static String _openingCopy(VetSummary vet) {
    if (vet.is24h == true) {
      return 'Mở 24/7';
    }
    if (vet.isOpen == true) {
      return 'Đang mở cửa • Đóng lúc 21:00';
    }
    if (vet.isOpen == false) {
      return 'Tạm đóng';
    }
    return 'Đang cập nhật giờ mở cửa';
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

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.vet});

  final VetSummary vet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppColors.brown, size: 18),
          const SizedBox(width: 4),
          Text(
            vet.averageRating != null
                ? vet.averageRating!.toStringAsFixed(1)
                : '#${vet.seedRank}',
            style: AppTextStyles.captionStrong(color: AppColors.brown),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: open ? AppColors.success : AppColors.label,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ClinicThumb extends StatelessWidget {
  const _ClinicThumb();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Hình minh họa phòng khám thú y',
      child: Container(
        width: 84,
        height: 76,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: CustomPaint(painter: _ClinicThumbPainter()),
        ),
      ),
    );
  }
}

class _ClinicThumbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wall = Paint()..color = AppColors.lightBeige;
    final floor = Paint()..color = AppColors.brown.withValues(alpha: 0.45);
    final sofa = Paint()..color = AppColors.mint;
    final window = Paint()..color = AppColors.surface;

    canvas.drawRect(Offset.zero & size, wall);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.62, size.width, size.height * 0.38),
      floor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.25, 14, size.width * 0.5, 28),
        const Radius.circular(4),
      ),
      window,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(12, size.height * 0.52, size.width - 24, 22),
        const Radius.circular(8),
      ),
      sofa,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final showIcon = MediaQuery.sizeOf(context).width >= 420;
    return Container(
      height: 48,
      padding: EdgeInsets.symmetric(horizontal: showIcon ? 8 : 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showIcon) ...[
            Icon(icon, size: 18, color: AppColors.primary500),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              style: showIcon
                  ? AppTextStyles.captionStrong()
                  : AppTextStyles.micro(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPillButton extends StatelessWidget {
  const _MapPillButton({
    this.controlKey,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final Key? controlKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return PawMateChip(
      key: controlKey,
      label: label,
      selected: selected,
      onPressed: onTap,
      leadingIcon: icon,
    );
  }
}
