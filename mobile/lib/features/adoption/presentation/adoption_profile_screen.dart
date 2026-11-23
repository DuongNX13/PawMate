import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_card.dart';
import '../../../core/widgets/pawmate_fixed_cta_bar.dart';
import '../../../core/widgets/pawmate_page_scaffold.dart';
import '../../../core/widgets/pawmate_skeleton.dart';
import '../../../core/widgets/pawmate_state_view.dart';
import '../application/adoption_profile_provider.dart';
import '../application/adoption_saved_listings_provider.dart';
import '../data/adoption_api.dart';
import '../data/adoption_share_service.dart';
import '../domain/adoption_models.dart';
import 'widgets/adoption_media_frame.dart';

class AdoptionProfileScreen extends ConsumerWidget {
  const AdoptionProfileScreen({
    super.key,
    required this.listingId,
    this.heroImageProvider,
  });

  final String listingId;
  final ImageProvider<Object>? heroImageProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(adoptionProfileProvider(listingId));
    final detail = profile.asData?.value;
    final savedIds =
        ref.watch(adoptionSavedListingsProvider).asData?.value ??
        const <String>{};
    final isSaved = savedIds.contains(listingId);
    final isSavePending = ref.watch(
      adoptionSavedListingPendingProvider(listingId),
    );

    return PawMatePageScaffold(
      layoutMode: PawMatePageLayoutMode.fullResponsive,
      key: const Key('adoption-profile-screen'),
      fixedFooter: detail == null
          ? null
          : _ProfileActionsBar(
              primaryAction: _requestAction(context, detail),
              secondaryAction: _saveAction(
                context,
                ref,
                detail,
                isSaved,
                isSavePending,
              ),
            ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          profile.when(
            skipLoadingOnRefresh: true,
            data: (value) => _ProfileContent(
              detail: value,
              heroImageProvider: heroImageProvider,
            ),
            loading: () => const _ProfileLoading(),
            error: (error, _) => _ProfileError(
              unavailable: error is AdoptionApiException && error.isUnavailable,
              message: _errorMessage(error),
              onRetry: () => ref.invalidate(adoptionProfileProvider(listingId)),
              onBack: () => _back(context),
            ),
          ),
          if (detail != null)
            Positioned(
              top: MediaQuery.viewPaddingOf(context).top + AppSpacing.s8,
              left: AppSpacing.s16,
              child: _ProfileCircleAction(
                tooltip: 'Quay lại',
                icon: Icons.arrow_back,
                onPressed: () => _back(context),
              ),
            ),
          Positioned(
            top: MediaQuery.viewPaddingOf(context).top + AppSpacing.s8,
            right: AppSpacing.s16,
            child: _ProfileShareAction(detail: detail),
          ),
          const IgnorePointer(
            child: Opacity(opacity: 0, child: Text('Hồ sơ nhận nuôi')),
          ),
          if (detail != null)
            Positioned(
              left: 0,
              top: 0,
              child: Semantics(
                container: true,
                image: true,
                label:
                    heroImageProvider != null ||
                        detail.heroMedia.publicUrl != null
                    ? 'Ảnh đại diện của ${detail.petName}'
                    : 'Chưa có ảnh của ${detail.petName}',
                child: const SizedBox.square(dimension: 1),
              ),
            ),
        ],
      ),
      backgroundColor: AppColors.background,
      safeAreaPolicy: PawMateSafeAreaPolicy.none,
    );
  }

  PawMateAction _requestAction(
    BuildContext context,
    AdoptionListingDetail detail,
  ) {
    final canRequest =
        detail.status.isAvailable &&
        detail.viewerPermissions.canRequest &&
        !detail.viewerPermissions.canManageListing;
    final requestLabel = switch ((
      detail.viewerPermissions.canManageListing,
      detail.status.isAvailable,
      detail.viewerPermissions.canRequest,
    )) {
      (true, _, _) => 'Đây là tin của bạn',
      (_, false, _) => 'Không còn nhận yêu cầu',
      (_, _, false) => 'Chưa thể gửi yêu cầu',
      _ => 'Gửi yêu cầu nhận nuôi',
    };
    return PawMateAction(
      label: requestLabel,
      semanticLabel: canRequest
          ? 'Mở biểu mẫu gửi yêu cầu nhận nuôi ${detail.petName}'
          : requestLabel,
      icon: Icons.send_rounded,
      onPressed: canRequest
          ? () => context.push('/adoption/${detail.listingId}/request')
          : null,
    );
  }

  PawMateAction _saveAction(
    BuildContext context,
    WidgetRef ref,
    AdoptionListingDetail detail,
    bool isSaved,
    bool isSavePending,
  ) {
    return PawMateAction(
      label: isSavePending
          ? 'Đang cập nhật'
          : isSaved
          ? 'Đã lưu trên máy'
          : 'Lưu trên máy',
      semanticLabel: isSavePending
          ? 'Đang cập nhật danh sách lưu trên thiết bị này'
          : isSaved
          ? 'Bỏ hồ sơ ${detail.petName} khỏi danh sách lưu trên thiết bị này'
          : 'Lưu hồ sơ ${detail.petName} trên thiết bị này',
      icon: isSaved ? Icons.favorite : Icons.favorite_border,
      variant: PawMateButtonVariant.secondary,
      isLoading: isSavePending,
      onPressed: isSavePending
          ? null
          : () => _toggleSaved(context, ref, detail, isSaved),
    );
  }

  static void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/adoption');
    }
  }

  static Future<void> _toggleSaved(
    BuildContext context,
    WidgetRef ref,
    AdoptionListingDetail detail,
    bool wasSaved,
  ) async {
    if (ref.read(adoptionSavedListingPendingProvider(detail.listingId))) return;
    try {
      await ref
          .read(adoptionSavedListingsProvider.notifier)
          .toggle(detail.listingId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              wasSaved
                  ? 'Đã bỏ ${detail.petName} khỏi danh sách lưu trên thiết bị này.'
                  : 'Đã lưu ${detail.petName} trên thiết bị này. Dữ liệu chưa đồng bộ tài khoản.',
            ),
          ),
        );
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không lưu được trên thiết bị. Vui lòng thử lại.'),
        ),
      );
    }
  }

  static String _errorMessage(Object error) {
    if (error is AdoptionApiException) return error.message;
    return 'Không tải được hồ sơ nhận nuôi. Vui lòng thử lại.';
  }
}

class _ProfileCircleAction extends StatelessWidget {
  const _ProfileCircleAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background.withValues(alpha: .94),
      shape: const CircleBorder(),
      elevation: AppElevation.none,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.brown),
        constraints: const BoxConstraints.tightFor(
          width: AppControlSize.minTouchTarget,
          height: AppControlSize.minTouchTarget,
        ),
      ),
    );
  }
}

class _ProfileActionsBar extends StatelessWidget {
  const _ProfileActionsBar({
    required this.primaryAction,
    required this.secondaryAction,
  });

  final PawMateAction primaryAction;
  final PawMateAction secondaryAction;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final stacked =
        MediaQuery.sizeOf(context).width < 360 ||
        textScaler.scale(1) > AppControlSize.compactButtonMaxTextScale;
    final hiddenLabel = Opacity(opacity: 0, child: Text(secondaryAction.label));
    final secondary = Semantics(
      button: true,
      enabled: secondaryAction.onPressed != null && !secondaryAction.isLoading,
      label: secondaryAction.semanticLabel ?? secondaryAction.label,
      child: ExcludeSemantics(
        child: Stack(
          alignment: Alignment.center,
          children: [
            hiddenLabel,
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('adoption-profile-save-action'),
                onTap: secondaryAction.onPressed,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.primary700),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: secondaryAction.isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          secondaryAction.icon ?? Icons.favorite_border,
                          color: AppColors.primary700,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final primary = _ProfilePrimaryAction(action: primaryAction);
    final content = stacked
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              secondary,
              const SizedBox(height: AppSpacing.s8),
              primary,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 56, child: secondary),
              const SizedBox(width: AppSpacing.s12),
              Expanded(child: primary),
            ],
          );
    return Material(
      key: const Key('adoption-profile-actions'),
      color: AppColors.background,
      elevation: AppElevation.none,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.s24,
          AppSpacing.s12,
          AppSpacing.s24,
          AppSpacing.s24,
        ),
        child: content,
      ),
    );
  }
}

class _ProfilePrimaryAction extends StatelessWidget {
  const _ProfilePrimaryAction({required this.action});

  final PawMateAction action;

  @override
  Widget build(BuildContext context) {
    final enabled = action.onPressed != null && !action.isLoading;
    final background = action.variant == PawMateButtonVariant.secondary
        ? AppColors.surface
        : AppColors.primary700;
    final foreground = action.variant == PawMateButtonVariant.secondary
        ? AppColors.primary700
        : Colors.white;
    return Semantics(
      button: true,
      enabled: enabled,
      label: action.semanticLabel ?? action.label,
      value: action.isLoading ? 'Đang xử lý' : null,
      onTap: enabled ? action.onPressed : null,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: enabled ? action.onPressed : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
              decoration: BoxDecoration(
                color: enabled ? background : AppColors.surfaceVariant,
                border: Border.all(
                  color: action.variant == PawMateButtonVariant.secondary
                      ? AppColors.primary700
                      : Colors.transparent,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow:
                    enabled && action.variant == PawMateButtonVariant.primary
                    ? AppShadows.soft
                    : null,
              ),
              alignment: Alignment.center,
              child: action.isLoading
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (action.icon != null) ...[
                          Icon(action.icon, size: 20, color: foreground),
                          const SizedBox(width: AppSpacing.s8),
                        ],
                        Flexible(
                          child: Text(
                            action.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.button(color: foreground),
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

class _ProfileShareAction extends ConsumerStatefulWidget {
  const _ProfileShareAction({required this.detail});

  final AdoptionListingDetail? detail;

  @override
  ConsumerState<_ProfileShareAction> createState() =>
      _ProfileShareActionState();
}

class _ProfileShareActionState extends ConsumerState<_ProfileShareAction> {
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background.withValues(alpha: .94),
      shape: const CircleBorder(),
      child: IconButton(
        key: const Key('adoption-profile-share'),
        tooltip: _isSharing ? 'Đang mở bảng chia sẻ' : 'Chia sẻ hồ sơ',
        onPressed: widget.detail == null || _isSharing ? null : _share,
        constraints: const BoxConstraints.tightFor(
          width: AppControlSize.minTouchTarget,
          height: AppControlSize.minTouchTarget,
        ),
        icon: _isSharing
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.share_outlined),
      ),
    );
  }

  Future<void> _share() async {
    final detail = widget.detail;
    if (detail == null || _isSharing) return;

    setState(() => _isSharing = true);
    try {
      final renderObject = context.findRenderObject();
      final viewport = MediaQuery.sizeOf(context);
      final sharePositionOrigin =
          renderObject is RenderBox && renderObject.hasSize
          ? renderObject.localToGlobal(Offset.zero) & renderObject.size
          : Rect.fromCenter(
              center: Offset(viewport.width / 2, viewport.height / 2),
              width: 1,
              height: 1,
            );
      await ref
          .read(adoptionShareSourceProvider)
          .shareProfile(detail, sharePositionOrigin: sharePositionOrigin);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không mở được bảng chia sẻ. Vui lòng thử lại.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.detail, this.heroImageProvider});

  final AdoptionListingDetail detail;
  final ImageProvider<Object>? heroImageProvider;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final width = MediaQuery.sizeOf(context).width;
    final compactBadges =
        textScale <= AppControlSize.compactButtonMaxTextScale && width >= 360;
    return ListView(
      key: const Key('adoption-profile-content'),
      padding: EdgeInsets.only(bottom: AppSpacing.s32),
      children: [
        AspectRatio(
          // Keep the 390×412 anchor's focal crop on small and large phones.
          aspectRatio: 390 / 412,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: AdoptionMediaFrame(
                  key: const Key('adoption-profile-media'),
                  media: detail.heroMedia,
                  petName: detail.petName,
                  species: detail.species,
                  imageProvider: heroImageProvider,
                  borderRadius: BorderRadius.zero,
                ),
              ),
              Positioned(
                left: AppSpacing.s16,
                right: AppSpacing.s16,
                bottom: AppSpacing.s16,
                child: _HeroStatusLabel(status: detail.status),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s24,
            AppSpacing.s8,
            AppSpacing.s24,
            AppSpacing.s32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(detail.petName, style: AppTextStyles.h2()),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  _StatusPill(status: detail.status),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(_subtitle(detail), style: AppTextStyles.bodyStrong()),
              if (detail.traits.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s32),
                _ProfileTraits(traits: detail.traits.take(3).toList()),
              ],
              const SizedBox(height: 36),
              if (compactBadges)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _BadgeCard(
                        key: const Key('adoption-profile-health'),
                        title: 'Sức khỏe',
                        icon: Icons.medical_services_outlined,
                        badges: detail.healthBadges,
                        emptyMessage: 'Chưa có dữ liệu y tế được xác nhận.',
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: _BadgeCard(
                        key: const Key('adoption-profile-verification'),
                        title: 'Xác thực',
                        icon: Icons.verified_user_outlined,
                        badges: detail.verificationBadges,
                        emptyMessage: 'Chưa có thông tin xác minh.',
                        compact: true,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _BadgeCard(
                      key: const Key('adoption-profile-health'),
                      title: 'Sức khỏe',
                      icon: Icons.medical_services_outlined,
                      badges: detail.healthBadges,
                      emptyMessage: 'Chưa có dữ liệu y tế được xác nhận.',
                      compact: false,
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    _BadgeCard(
                      key: const Key('adoption-profile-verification'),
                      title: 'Xác thực',
                      icon: Icons.verified_user_outlined,
                      badges: detail.verificationBadges,
                      emptyMessage: 'Chưa có thông tin xác minh.',
                      compact: false,
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.s16),
              Text(
                detail.description ?? 'Chưa có mô tả bổ sung cho hồ sơ này.',
                style: AppTextStyles.body(),
              ),
              if (!detail.status.isAvailable ||
                  !detail.viewerPermissions.canRequest ||
                  detail.viewerPermissions.canManageListing) ...[
                const SizedBox(height: AppSpacing.s12),
                _AvailabilityNotice(detail: detail),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _subtitle(AdoptionListingDetail detail) {
    return [detail.breed ?? detail.species.label, detail.ageLabel].join(' · ');
  }
}

class _HeroStatusLabel extends StatelessWidget {
  const _HeroStatusLabel({required this.status});

  final AdoptionListingStatus status;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.brown.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
          child: Text(
            status.isAvailable
                ? 'Đang tìm mái ấm'
                : status == AdoptionListingStatus.pending
                ? 'Đang xét duyệt'
                : status.label,
            style: AppTextStyles.captionStrong(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _TraitItem extends StatelessWidget {
  const _TraitItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final icon = switch (label.toLowerCase()) {
      final value when value.contains('năng động') => Icons.bolt,
      final value when value.contains('dễ gần') || value.contains('quấn') =>
        Icons.favorite,
      _ => Icons.sentiment_satisfied_alt_outlined,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.primary700),
        const SizedBox(width: AppSpacing.s8),
        Text(label, style: AppTextStyles.bodyCompact()),
      ],
    );
  }
}

class _ProfileTraits extends StatelessWidget {
  const _ProfileTraits({required this.traits});

  final List<String> traits;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.textScalerOf(context).scale(1) <=
            AppControlSize.compactButtonMaxTextScale &&
        MediaQuery.sizeOf(context).width >= 360 &&
        traits.length > 1;
    if (!compact) {
      return Wrap(
        spacing: AppSpacing.s24,
        runSpacing: AppSpacing.s12,
        children: [for (final trait in traits) _TraitItem(label: trait)],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TraitItem(label: traits[0]),
              const SizedBox(width: 56),
              _TraitItem(label: traits[1]),
            ],
          ),
          if (traits.length > 2) ...[
            const SizedBox(height: AppSpacing.s24),
            _TraitItem(label: traits[2]),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final AdoptionListingStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = PawMateStatusColors.of(context);
    final available = status.isAvailable;
    return Semantics(
      label: 'Trạng thái: ${status.label}',
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: available ? colors.successContainer : colors.warningContainer,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: Colors.transparent),
        ),
        child: Text(
          available
              ? status.label
              : status == AdoptionListingStatus.pending
              ? 'Đang xét duyệt'
              : status.label,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: AppTextStyles.captionStrong(
            color: available ? colors.success : colors.warning,
          ),
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    super.key,
    required this.title,
    required this.icon,
    required this.badges,
    required this.emptyMessage,
    this.compact = false,
  });

  final String title;
  final IconData icon;
  final List<String> badges;
  final String emptyMessage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final card = PawMateCard(
      backgroundColor: AppColors.surfaceContainer,
      margin: EdgeInsets.zero,
      padding: compact
          ? const EdgeInsets.all(AppSpacing.s12)
          : const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary700, size: compact ? 20 : 24),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  title,
                  style: compact
                      ? AppTextStyles.bodyStrong()
                      : AppTextStyles.h4(),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          if (badges.isEmpty)
            Text(emptyMessage, style: AppTextStyles.bodyCompact())
          else
            Column(
              children: [
                for (var index = 0; index < badges.length; index++) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.s8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.check_circle,
                          size: 18,
                          color: AppColors.primary700,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          badges[index],
                          style: compact
                              ? AppTextStyles.caption()
                              : AppTextStyles.bodyCompact(),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
        ],
      ),
    );
    return compact
        ? ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 136),
            child: card,
          )
        : card;
  }
}

class _AvailabilityNotice extends StatelessWidget {
  const _AvailabilityNotice({required this.detail});

  final AdoptionListingDetail detail;

  @override
  Widget build(BuildContext context) {
    final message = detail.viewerPermissions.canManageListing
        ? 'Đây là tin do bạn quản lý. Yêu cầu nhận nuôi chỉ dành cho người xem khác.'
        : !detail.status.isAvailable
        ? 'Hồ sơ hiện ở trạng thái “${detail.status.label}” nên không nhận thêm yêu cầu.'
        : 'Tài khoản này chưa được phép gửi yêu cầu cho hồ sơ hiện tại.';
    return PawMateCard(
      backgroundColor: PawMateStatusColors.of(context).warningContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: PawMateStatusColors.of(context).warning,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(child: Text(message, style: AppTextStyles.bodyCompact())),
        ],
      ),
    );
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('adoption-profile-loading'),
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: const [
        PawMateSkeleton(width: double.infinity, height: 288),
        SizedBox(height: AppSpacing.s16),
        PawMateSkeleton(width: 180, height: 32),
        SizedBox(height: AppSpacing.s8),
        PawMateSkeleton(width: 250, height: 20),
        SizedBox(height: AppSpacing.s24),
        PawMateSkeleton(width: double.infinity, height: 120),
        SizedBox(height: AppSpacing.s12),
        PawMateSkeleton(width: double.infinity, height: 120),
      ],
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({
    required this.unavailable,
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final bool unavailable;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return PawMateStateView(
      type: unavailable ? PawMateStateType.empty : PawMateStateType.error,
      title: unavailable ? 'Không còn hồ sơ này' : 'Chưa tải được hồ sơ',
      message: message,
      primaryActionLabel: unavailable ? 'Về danh sách nhận nuôi' : 'Thử lại',
      onPrimaryAction: unavailable ? onBack : onRetry,
      secondaryActionLabel: unavailable ? null : 'Về danh sách nhận nuôi',
      onSecondaryAction: unavailable ? null : onBack,
    );
  }
}
