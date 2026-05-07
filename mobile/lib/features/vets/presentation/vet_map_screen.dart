import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_bottom_nav.dart';
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
    final theme = Theme.of(context);
    final state = ref.watch(vetMapProvider);
    final builder = ref.watch(vetMapCanvasBuilderProvider);

    return Scaffold(
      bottomNavigationBar: const PawMateBottomNav(currentRoute: '/vets/list'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/vets/list'),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'PawMate',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.primary500,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => ref
                        .read(vetMapProvider.notifier)
                        .refresh(forceLocationRefresh: true),
                    icon: const Icon(Icons.my_location_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Vet Finder',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.secondary500,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Phòng khám gần bạn',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Map tab dùng dữ liệu nearby thật của Day 3. Marker, bottom sheet và radius filter đang chạy trên cùng contract backend.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              _RadiusSelector(
                radiusMeters: state.radiusMeters,
                onSelected: (radius) =>
                    ref.read(vetMapProvider.notifier).selectRadius(radius),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _mapStyle = _mapStyle == VetMapStyle.standard
                              ? VetMapStyle.night
                              : VetMapStyle.standard;
                        });
                      },
                      icon: const Icon(Icons.layers_outlined),
                      label: Text(_mapStyle.label),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => ref
                          .read(vetMapProvider.notifier)
                          .refresh(forceLocationRefresh: true),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tải lại'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (state.status == VetMapStatus.loading)
                const _MapInfoCard(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (state.status == VetMapStatus.permissionDenied)
                _MapStateCard(
                  title: 'Chưa có quyền vị trí',
                  description:
                      state.message ??
                      'PawMate cần quyền vị trí để tìm phòng khám quanh bạn.',
                  actionLabel: 'Thử lại',
                  onPressed: () => ref
                      .read(vetMapProvider.notifier)
                      .refresh(forceLocationRefresh: true),
                )
              else if (state.status == VetMapStatus.locationServicesDisabled)
                _MapStateCard(
                  title: 'Thiết bị đang tắt định vị',
                  description:
                      state.message ??
                      'Hãy bật dịch vụ vị trí rồi tải lại để lấy nearby thật.',
                  actionLabel: 'Tải lại',
                  onPressed: () => ref
                      .read(vetMapProvider.notifier)
                      .refresh(forceLocationRefresh: true),
                )
              else if (state.status == VetMapStatus.error)
                _MapStateCard(
                  title: 'Không tải được nearby',
                  description:
                      state.message ??
                      'Có lỗi khi tải dữ liệu phòng khám gần bạn.',
                  actionLabel: 'Thử lại',
                  onPressed: () => ref.read(vetMapProvider.notifier).refresh(),
                )
              else if (state.center != null) ...[
                SizedBox(
                  height: 320,
                  child: builder(
                    state.center!,
                    state.items,
                    _mapStyle,
                    (vetId) => _openPreviewSheet(vetId, state.items),
                  ),
                ),
                const SizedBox(height: 18),
                _MapInfoCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.status == VetMapStatus.empty
                              ? 'Không có phòng khám trong bán kính ${_radiusLabel(state.radiusMeters)}.'
                              : '${state.items.length} phòng khám trong bán kính ${_radiusLabel(state.radiusMeters)}.',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        state.status == VetMapStatus.empty ? 'Empty' : 'Live',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: state.status == VetMapStatus.empty
                              ? AppColors.textSecondary
                              : AppColors.primary700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                for (final vet in state.items.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _NearbyVetTile(
                      vet: vet,
                      onTap: () => _openPreviewSheet(vet.id, state.items),
                    ),
                  ),
              ] else
                _MapStateCard(
                  title: 'Map chưa có dữ liệu',
                  description:
                      'Hãy tải lại để lấy vị trí hiện tại và phòng khám lân cận.',
                  actionLabel: 'Tải lại',
                  onPressed: () => ref
                      .read(vetMapProvider.notifier)
                      .refresh(forceLocationRefresh: true),
                ),
            ],
          ),
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
      showDragHandle: false,
      backgroundColor: AppColors.surface,
      builder: (context) => VetPreviewSheet(
        vet: target,
        onViewDetail: () {
          Navigator.of(context).pop();
          this.context.go('/vets/${target.id}');
        },
        onGetDirections: () => launchVetDirections(context, target),
        onCallNow: () => launchVetCall(context, target.phone),
      ),
    );
  }

  static String _radiusLabel(int radiusMeters) {
    if (radiusMeters >= 1000) {
      return '${radiusMeters ~/ 1000}km';
    }
    return '${radiusMeters}m';
  }
}

class _RadiusSelector extends StatelessWidget {
  const _RadiusSelector({required this.radiusMeters, required this.onSelected});

  final int radiusMeters;
  final ValueChanged<int> onSelected;

  static const _options = [1000, 3000, 5000, 10000];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final option = _options[index];
          final selected = option == radiusMeters;

          return ChoiceChip(
            label: Text(option >= 1000 ? '${option ~/ 1000} km' : '$option m'),
            selected: selected,
            onSelected: (_) => onSelected(option),
            showCheckmark: false,
            selectedColor: AppColors.primarySoft,
            side: BorderSide(
              color: selected ? Colors.transparent : AppColors.border,
            ),
          );
        },
      ),
    );
  }
}

class _NearbyVetTile extends StatelessWidget {
  const _NearbyVetTile({required this.vet, required this.onTap});

  final VetSummary vet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE4D5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pets_rounded,
                color: AppColors.primary500,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${vet.distanceLabel ?? 'N/A'} • ${vet.address}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
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

class _MapInfoCard extends StatelessWidget {
  const _MapInfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.soft,
      ),
      child: child,
    );
  }
}

class _MapStateCard extends StatelessWidget {
  const _MapStateCard({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _MapInfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
