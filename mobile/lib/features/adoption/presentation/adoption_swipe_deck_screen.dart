import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_card.dart';
import '../../../core/widgets/pawmate_chip.dart';
import '../../../core/widgets/pawmate_page_scaffold.dart';
import '../../../core/widgets/pawmate_skeleton.dart';
import '../../../core/widgets/pawmate_state_view.dart';
import '../../../core/widgets/pawmate_top_bar.dart';
import '../application/adoption_deck_provider.dart';
import '../domain/adoption_models.dart';
import 'widgets/adoption_media_frame.dart';

class AdoptionSwipeDeckScreen extends ConsumerStatefulWidget {
  const AdoptionSwipeDeckScreen({super.key, this.heroImageProvider});

  final ImageProvider<Object>? heroImageProvider;

  @override
  ConsumerState<AdoptionSwipeDeckScreen> createState() =>
      _AdoptionSwipeDeckScreenState();
}

class _AdoptionSwipeDeckScreenState
    extends ConsumerState<AdoptionSwipeDeckScreen> {
  late final AdoptionDeckNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(adoptionDeckProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifier.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adoptionDeckProvider);
    final current = state.currentListing;

    return PawMatePageScaffold(
      layoutMode: PawMatePageLayoutMode.fullResponsive,
      key: const Key('adoption-swipe-deck-screen'),
      backgroundColor: AppColors.background,
      topBar: PawMateTopBar(
        title: 'PawMate',
        brandTitle: true,
        titleStyle: AppTextStyles.h2(color: AppColors.primary700),
        leadingWidth: 48,
        leading: Semantics(
          image: true,
          label: 'PawMate',
          child: Icon(Icons.pets, color: AppColors.primary700, size: 30),
        ),
        actions: [
          _AdoptionLocationControl(
            label: state.filter.coordinates == null
                ? 'Theo gợi ý'
                : 'Bán kính ${_formatDistance(state.filter.distanceKm ?? 5)}',
            selected: state.filter.coordinates != null,
            onPressed: state.isInteractionLocked
                ? null
                : () => _showFilters(context, state.filter),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s16),
            child: IconButton(
              key: const Key('adoption-filter-button'),
              tooltip: 'Lọc hồ sơ nhận nuôi',
              onPressed: state.isInteractionLocked
                  ? null
                  : () => _showFilters(context, state.filter),
              icon: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
      bottomNavCurrentRoute: '/pets',
      body: RefreshIndicator(
        key: const Key('adoption-deck-refresh'),
        color: AppColors.primary700,
        onRefresh: () => _notifier.refresh(clearItems: false),
        child: ListView(
          key: const Key('adoption-deck-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s16,
            1,
            AppSpacing.s16,
            AppSpacing.s32,
          ),
          children: [
            if (state.isRefreshing || state.isLoadingMore || state.isLocating)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.s8),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (state.isStale)
              const _InlineNotice(
                key: Key('adoption-stale-notice'),
                icon: Icons.cloud_off_outlined,
                message:
                    'Đang hiển thị dữ liệu gần nhất. Kéo xuống để thử kết nối lại.',
              ),
            if (state.message != null) ...[
              _InlineNotice(
                key: const Key('adoption-state-message'),
                icon: Icons.info_outline,
                message: state.message!,
              ),
              const SizedBox(height: AppSpacing.s12),
            ],
            if ((state.status == AdoptionDeckStatus.initial ||
                    state.status == AdoptionDeckStatus.loading) &&
                current == null)
              const _DeckLoading()
            else if (state.status == AdoptionDeckStatus.error &&
                current == null)
              _DeckStatePanel(
                type: PawMateStateType.error,
                title: 'Chưa tải được hồ sơ',
                message:
                    state.message ??
                    'Không tải được danh sách nhận nuôi. Vui lòng thử lại.',
                primaryLabel: 'Thử lại',
                onPrimary: () => _notifier.refresh(clearItems: true),
              )
            else if (state.status == AdoptionDeckStatus.empty)
              _DeckStatePanel(
                type: PawMateStateType.empty,
                title: 'Chưa có hồ sơ phù hợp',
                message:
                    'Thử bỏ bớt bộ lọc hoặc quay lại sau để xem hồ sơ mới.',
                primaryLabel: 'Xóa bộ lọc',
                onPrimary: _clearFilters,
              )
            else if (current == null && (state.isLoadingMore || state.hasMore))
              const _DeckPageLoading()
            else if (state.status == AdoptionDeckStatus.exhausted ||
                current == null)
              _DeckStatePanel(
                type: PawMateStateType.success,
                title: 'Bạn đã xem hết rồi',
                message:
                    'PawMate sẽ bổ sung hồ sơ mới khi các bé sẵn sàng tìm nhà.',
                primaryLabel: 'Tải lại',
                onPrimary: () => _notifier.refresh(clearItems: true),
              )
            else ...[
              _SwipeCard(
                listing: current,
                heroImageProvider: widget.heroImageProvider,
                enabled: !state.isInteractionLocked,
                onSkip: _skip,
                onOpenProfile: () =>
                    context.push('/adoption/${current.listingId}'),
                onLike: _like,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _skip() async {
    final skipped = await _notifier.skipCurrentWithUndo();
    if (!mounted || !skipped) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: const Text('Đã bỏ qua hồ sơ.'),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () {
              final restored = _notifier.undoLastSkip();
              if (!restored || !mounted) return;
              messenger.showSnackBar(
                const SnackBar(content: Text('Đã khôi phục hồ sơ.')),
              );
            },
          ),
        ),
      );
  }

  Future<void> _like() async {
    final listing = await _notifier.likeCurrent();
    if (!mounted || listing == null) return;
    await context.push('/adoption/${listing.listingId}');
  }

  Future<void> _clearFilters() async {
    await _notifier.clearFilters();
  }

  Future<void> _showFilters(
    BuildContext context,
    AdoptionDeckFilter current,
  ) async {
    var draftSpecies = current.species;
    var draftAgeGroup = current.ageGroup;
    var draftDistanceKm = current.distanceKm;
    var isApplying = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          key: const Key('adoption-filter-sheet'),
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s4,
              AppSpacing.s16,
              AppSpacing.s24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Lọc hồ sơ nhận nuôi', style: AppTextStyles.h3()),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Chọn tiêu chí rồi bấm Áp dụng. PawMate chỉ xin vị trí khi bạn lọc theo khoảng cách.',
                  style: AppTextStyles.bodyCompact(),
                ),
                const SizedBox(height: AppSpacing.s12),
                PawMateButton(
                  key: const Key('adoption-my-requests-button'),
                  label: 'Đơn nhận nuôi của tôi',
                  semanticLabel: 'Xem đơn nhận nuôi của tôi',
                  variant: PawMateButtonVariant.secondary,
                  compact: true,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    context.push('/adoption/requests');
                  },
                ),
                const SizedBox(height: AppSpacing.s24),
                Text('Loài', style: AppTextStyles.label()),
                const SizedBox(height: AppSpacing.s8),
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    _SpeciesFilterChip(
                      label: 'Tất cả',
                      selected: draftSpecies == null,
                      onPressed: () => setSheetState(() => draftSpecies = null),
                    ),
                    for (final species in AdoptionSpecies.values)
                      _SpeciesFilterChip(
                        label: species.label,
                        selected: draftSpecies == species,
                        onPressed: () =>
                            setSheetState(() => draftSpecies = species),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s24),
                Text('Độ tuổi', style: AppTextStyles.label()),
                const SizedBox(height: AppSpacing.s8),
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    _SpeciesFilterChip(
                      label: 'Tất cả',
                      selected: draftAgeGroup == null,
                      onPressed: () =>
                          setSheetState(() => draftAgeGroup = null),
                    ),
                    for (final ageGroup in AdoptionAgeGroup.values)
                      _SpeciesFilterChip(
                        label: ageGroup.label,
                        selected: draftAgeGroup == ageGroup,
                        onPressed: () =>
                            setSheetState(() => draftAgeGroup = ageGroup),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s24),
                Text('Khoảng cách', style: AppTextStyles.label()),
                const SizedBox(height: AppSpacing.s8),
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    _SpeciesFilterChip(
                      label: 'Tất cả',
                      selected: draftDistanceKm == null,
                      onPressed: () =>
                          setSheetState(() => draftDistanceKm = null),
                    ),
                    for (final distance in const [5.0, 10.0, 25.0])
                      _SpeciesFilterChip(
                        label: '${distance.toInt()} km',
                        selected: draftDistanceKm == distance,
                        onPressed: () =>
                            setSheetState(() => draftDistanceKm = distance),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s24),
                PawMateButton(
                  key: const Key('adoption-apply-filters'),
                  label: isApplying ? 'Đang áp dụng…' : 'Áp dụng bộ lọc',
                  leadingIcon: Icons.tune,
                  onPressed: isApplying
                      ? null
                      : () async {
                          setSheetState(() => isApplying = true);
                          final applied = await _notifier.applyFilterDraft(
                            species: draftSpecies,
                            ageGroup: draftAgeGroup,
                            distanceKm: draftDistanceKm,
                          );
                          if (!sheetContext.mounted) return;
                          if (applied) {
                            Navigator.of(sheetContext).pop();
                          } else {
                            setSheetState(() => isApplying = false);
                          }
                        },
                ),
                const SizedBox(height: AppSpacing.s8),
                PawMateButton(
                  key: const Key('adoption-clear-filters'),
                  label: 'Xóa bộ lọc',
                  leadingIcon: Icons.filter_alt_off_outlined,
                  variant: PawMateButtonVariant.secondary,
                  onPressed: isApplying
                      ? null
                      : () async {
                          setSheetState(() => isApplying = true);
                          await _notifier.clearFilters();
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDistance(double distanceKm) {
    final integer = distanceKm.round();
    return '${distanceKm == integer ? integer : distanceKm.toStringAsFixed(1)}km';
  }
}

class _AdoptionLocationControl extends StatelessWidget {
  const _AdoptionLocationControl({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
        MediaQuery.sizeOf(context).width < 360;
    if (compact) {
      return IconButton(
        key: const Key('adoption-location-chip'),
        tooltip: 'Vị trí: $label',
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: selected ? AppColors.surfaceContainer : null,
          foregroundColor: selected ? AppColors.primary700 : AppColors.brown,
          minimumSize: const Size.square(AppControlSize.minTouchTarget),
        ),
        icon: const Icon(Icons.location_on_outlined),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.s16),
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        selected: selected,
        label: selected ? '$label, đang bật' : '$label, chưa bật',
        child: ExcludeSemantics(
          child: Center(
            child: SizedBox(
              height: AppControlSize.minTouchTarget,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: InkWell(
                  key: const Key('adoption-location-chip'),
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Center(
                    child: Container(
                      height: AppControlSize.compactButtonVisualHeight,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppColors.primary700,
                          ),
                          const SizedBox(width: AppSpacing.s4),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.micro(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _SwipeCard extends StatelessWidget {
  const _SwipeCard({
    required this.listing,
    required this.heroImageProvider,
    required this.enabled,
    required this.onSkip,
    required this.onOpenProfile,
    required this.onLike,
  });

  final AdoptionListingSummary listing;
  final ImageProvider<Object>? heroImageProvider;
  final bool enabled;
  final Future<void> Function() onSkip;
  final VoidCallback onOpenProfile;
  final Future<void> Function() onLike;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final card = PawMateCard(
      key: ValueKey('adoption-card-${listing.listingId}'),
      variant: PawMateCardVariant.raised,
      padding: EdgeInsets.zero,
      semanticLabel:
          '${listing.petName}, ${listing.breed ?? listing.species.label}, ${listing.ageLabel}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            // The 358dp anchor card has a 1dp border on each side: the actual
            // approved photo stage is 356×326, not the outer card bounds.
            // Only media adapts; text, actions and touch targets do not scale.
            aspectRatio: 356 / 326,
            child: AdoptionMediaFrame(
              media: listing.heroMedia,
              petName: listing.petName,
              species: listing.species,
              imageProvider: heroImageProvider,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.md),
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 90),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: 20,
            ),
            color: AppColors.brown.withValues(alpha: 0.92),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${listing.petName}, ${listing.ageLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h3(color: AppColors.white),
                ),
                const SizedBox(height: AppSpacing.s4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (listing.breed ?? listing.species.label).toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.micro(color: AppColors.white),
                      ),
                    ),
                    if (listing.distanceKm != null) ...[
                      const Icon(
                        Icons.near_me_rounded,
                        size: 15,
                        color: AppColors.white,
                      ),
                      const SizedBox(width: AppSpacing.s4),
                      Text(
                        'Cách bạn ${listing.distanceKm!.toStringAsFixed(1)} km',
                        style: AppTextStyles.caption(color: AppColors.white),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 116),
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s16,
              AppSpacing.s16,
              10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    for (final trait in listing.traits.take(3))
                      _AdoptionTraitChip(label: trait),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  '${listing.petName} đang chờ một mái ấm yêu thương. '
                  'Hãy xem hồ sơ để hiểu tính cách và nhu cầu chăm sóc của bé.',
                  maxLines: MediaQuery.textScalerOf(context).scale(1) > 1.3
                      ? null
                      : 3,
                  overflow: MediaQuery.textScalerOf(context).scale(1) > 1.3
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: AppTextStyles.bodyCompact().copyWith(height: 18 / 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      key: ValueKey('adoption-swipe-${listing.listingId}'),
      container: true,
      customSemanticsActions: enabled
          ? {
              const CustomSemanticsAction(label: 'Bỏ qua'): onSkip,
              const CustomSemanticsAction(label: 'Xem hồ sơ'): onOpenProfile,
              const CustomSemanticsAction(label: 'Quan tâm'): onLike,
            }
          : const {},
      child: Dismissible(
        key: ValueKey('adoption-dismissible-${listing.listingId}'),
        direction: enabled
            ? DismissDirection.horizontal
            : DismissDirection.none,
        resizeDuration: reduceMotion ? Duration.zero : AppMotion.standard,
        movementDuration: reduceMotion ? Duration.zero : AppMotion.deliberate,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            await onLike();
          } else {
            await onSkip();
          }
          // The provider owns removal/restoration so Dismissible never mutates
          // an already-updated list independently.
          return false;
        },
        background: const _SwipeBackground(
          alignment: Alignment.centerLeft,
          icon: Icons.favorite_rounded,
          label: 'Quan tâm',
          color: AppColors.primary700,
        ),
        secondaryBackground: const _SwipeBackground(
          alignment: Alignment.centerRight,
          icon: Icons.close_rounded,
          label: 'Bỏ qua',
          color: AppColors.brown,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            card,
            const SizedBox(height: AppSpacing.s4),
            Semantics(
              label: 'Vuốt phải để xem hồ sơ, vuốt trái để bỏ qua',
              child: ExcludeSemantics(
                child: TextButton.icon(
                  key: const Key('adoption-swipe-guidance'),
                  onPressed: enabled ? onOpenProfile : null,
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  label: const Text('VUỐT PHẢI ĐỂ XEM HỒ SƠ'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brown,
                    textStyle: AppTextStyles.label(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RoundAction(
                  key: const Key('adoption-skip-action'),
                  icon: Icons.close_rounded,
                  tooltip: 'Bỏ qua',
                  foreground: AppColors.brown,
                  onPressed: enabled ? onSkip : null,
                ),
                _RoundAction(
                  key: const Key('adoption-profile-action'),
                  icon: Icons.info_rounded,
                  tooltip: 'Xem hồ sơ',
                  foreground: AppColors.white,
                  background: AppColors.brown,
                  compact: true,
                  onPressed: enabled ? onOpenProfile : null,
                ),
                _RoundAction(
                  key: const Key('adoption-like-action'),
                  icon: Icons.favorite_rounded,
                  tooltip: 'Quan tâm và xem hồ sơ',
                  foreground: AppColors.white,
                  background: AppColors.primary700,
                  onPressed: enabled ? onLike : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdoptionTraitChip extends StatelessWidget {
  const _AdoptionTraitChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 28),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
    decoration: BoxDecoration(
      color: AppColors.mint.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      border: Border.all(color: AppColors.border),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.caption(color: AppColors.primary700),
    ),
  );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.foreground,
    required this.onPressed,
    this.background = AppColors.surface,
    this.compact = false,
  });

  final IconData icon;
  final String tooltip;
  final Color foreground;
  final Color background;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 48.0 : 58.0;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: SizedBox.square(
          dimension: size,
          child: IconButton(
            onPressed: onPressed,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: AppControlSize.minTouchTarget,
              minHeight: AppControlSize.minTouchTarget,
            ),
            style: IconButton.styleFrom(
              fixedSize: Size.square(size),
              backgroundColor: background,
              foregroundColor: foreground,
              disabledBackgroundColor: PawMateStatusColors.of(
                context,
              ).disabledContainer,
              disabledForegroundColor: PawMateStatusColors.of(
                context,
              ).disabledContent,
              side: BorderSide(color: foreground),
            ),
            icon: Icon(icon),
          ),
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.color,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.white),
          const SizedBox(width: AppSpacing.s8),
          Text(label, style: AppTextStyles.button()),
        ],
      ),
    );
  }
}

class _SpeciesFilterChip extends StatelessWidget {
  const _SpeciesFilterChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PawMateChip(
      label: label,
      selected: selected,
      variant: PawMateChipVariant.choice,
      onPressed: onPressed,
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: PawMateCard(
        backgroundColor: AppColors.surfaceContainer,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.primary700),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: Text(message, style: AppTextStyles.bodyCompact())),
          ],
        ),
      ),
    );
  }
}

class _DeckLoading extends StatelessWidget {
  const _DeckLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      key: Key('adoption-deck-loading'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PawMateSkeleton(width: double.infinity, height: 286),
        SizedBox(height: AppSpacing.s12),
        PawMateSkeleton(width: 220, height: 28),
        SizedBox(height: AppSpacing.s8),
        PawMateSkeleton(width: 150, height: 18),
        SizedBox(height: AppSpacing.s12),
        PawMateSkeleton(width: double.infinity, height: 64),
      ],
    );
  }
}

class _DeckPageLoading extends StatelessWidget {
  const _DeckPageLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('adoption-deck-loading-more'),
      liveRegion: true,
      label: 'Đang tải thêm hồ sơ nhận nuôi',
      child: SizedBox(
        height: 480,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                'Đang tìm thêm hồ sơ phù hợp…',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyStrong(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckStatePanel extends StatelessWidget {
  const _DeckStatePanel({
    required this.type,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final PawMateStateType type;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 480,
      child: PawMateStateView(
        type: type,
        title: title,
        message: message,
        primaryActionLabel: primaryLabel,
        onPrimaryAction: onPrimary,
      ),
    );
  }
}
