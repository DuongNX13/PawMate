import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_adaptive.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_card.dart';
import '../../../core/widgets/pawmate_fixed_cta_bar.dart';
import '../../../core/widgets/pawmate_page_scaffold.dart';
import '../../../core/widgets/pawmate_skeleton.dart';
import '../../../core/widgets/pawmate_state_view.dart';
import '../../../core/widgets/pawmate_top_bar.dart';
import '../application/rescue_case_detail_provider.dart';
import '../data/rescue_api.dart';
import '../data/rescue_case_share_service.dart';
import '../domain/rescue_case_models.dart';

class RescueCaseDetailScreen extends ConsumerStatefulWidget {
  const RescueCaseDetailScreen({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<RescueCaseDetailScreen> createState() =>
      _RescueCaseDetailScreenState();
}

class _RescueCaseDetailScreenState
    extends ConsumerState<RescueCaseDetailScreen> {
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;
    final detail = ref.watch(rescueCaseDetailProvider(widget.caseId));
    final loadedDetail = detail.asData?.value;
    return PawMatePageScaffold(
      layoutMode: PawMatePageLayoutMode.fullResponsive,
      key: const Key('rescue-case-detail-screen'),
      backgroundColor: AppColors.background,
      topBar: PawMateTopBar(
        title: usesExpandedTextLayout ? 'Tin báo' : 'Chi tiết tin báo',
        semanticTitle: 'Chi tiết tin báo',
        showBackButton: true,
        centerTitle: true,
        onBack: () => _goBack(context),
        actions: [
          IconButton(
            key: const Key('rescue-detail-share'),
            tooltip: _isSharing ? 'Đang mở bảng chia sẻ' : 'Chia sẻ tin báo',
            onPressed: loadedDetail == null || _isSharing
                ? null
                : () => _share(loadedDetail),
            icon: _isSharing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined),
          ),
        ],
      ),
      fixedCtaBar: loadedDetail?.viewerPermissions.canComment == true
          ? PawMateFixedCtaBar(
              key: const Key('rescue-detail-comment-bar'),
              primaryAction: PawMateAction(
                label: 'Bình luận',
                icon: Icons.chat_bubble_rounded,
                semanticLabel: 'Bình luận về tin báo này',
                onPressed: () =>
                    context.push('/rescue/${widget.caseId}/comment'),
              ),
            )
          : null,
      body: detail.when(
        skipLoadingOnRefresh: true,
        data: (value) => _DetailContent(
          detail: value,
          onOpenMap: () => context.push('/rescue/map'),
          onUpdateStatus: value.viewerPermissions.canUpdateStatus
              ? () => context.push('/rescue/${widget.caseId}/status')
              : null,
          onReport: () => _showReportHelp(context),
        ),
        loading: () => const _DetailLoading(),
        error: (error, _) => _DetailError(
          unavailable: _isUnavailable(error),
          message: _errorMessage(error),
          onRetry: () =>
              ref.invalidate(rescueCaseDetailProvider(widget.caseId)),
          onBack: () => _goBack(context),
        ),
      ),
    );
  }

  static void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/rescue');
    }
  }

  static bool _isUnavailable(Object error) {
    return error is RescueApiException &&
        (error.statusCode == 404 || error.code == 'RESCUE_CASE_NOT_FOUND');
  }

  static String _errorMessage(Object error) {
    if (error is RescueApiException) return error.message;
    return 'Không tải được chi tiết tin báo. Vui lòng thử lại.';
  }

  Future<void> _share(RescueCaseDetail detail) async {
    if (_isSharing) return;

    setState(() => _isSharing = true);
    try {
      final renderObject = context.findRenderObject();
      final viewport = MediaQuery.sizeOf(context);
      final origin = renderObject is RenderBox && renderObject.hasSize
          ? renderObject.localToGlobal(Offset.zero) & renderObject.size
          : Rect.fromCenter(
              center: Offset(viewport.width / 2, viewport.height / 2),
              width: 1,
              height: 1,
            );
      await ref
          .read(rescueCaseShareSourceProvider)
          .shareCase(detail, sharePositionOrigin: origin);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa thể mở bảng chia sẻ. Vui lòng thử lại.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  static Future<void> _showReportHelp(BuildContext context) async {
    await showPawMateAdaptiveDialog<void>(
      context: context,
      title: 'Báo cáo tin không phù hợp',
      message:
          'Tính năng gửi báo cáo sẽ mở ở bước kiểm duyệt tiếp theo. Nếu có nguy hiểm khẩn cấp, hãy liên hệ cơ quan địa phương.',
      actions: const [
        PawMateAdaptiveAction<void>(label: 'Đã hiểu', isDefaultAction: true),
      ],
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.detail,
    required this.onOpenMap,
    required this.onUpdateStatus,
    required this.onReport,
  });

  final RescueCaseDetail detail;
  final VoidCallback onOpenMap;
  final VoidCallback? onUpdateStatus;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('rescue-detail-content'),
      padding: const EdgeInsets.fromLTRB(18, 9, 18, AppSpacing.s32),
      children: [
        _Hero(detail: detail),
        const SizedBox(height: 26),
        _PetInformation(detail: detail),
        const SizedBox(height: AppSpacing.s12),
        _LocationCard(detail: detail, onTap: onOpenMap),
        const SizedBox(height: AppSpacing.s12),
        _PrivacyCard(
          canViewPrivateContact: detail.viewerPermissions.canViewPrivateContact,
        ),
        const SizedBox(height: AppSpacing.s12),
        _CommunityCard(commentCount: detail.commentCount),
        if (onUpdateStatus != null) ...[
          const SizedBox(height: AppSpacing.s12),
          PawMateCard(
            key: const Key('rescue-detail-owner-actions'),
            backgroundColor: AppColors.surfaceContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Dành cho chủ tin', style: AppTextStyles.h4()),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Cập nhật ngay khi đã tìm thấy bé để cộng đồng biết tin.',
                  style: AppTextStyles.bodyCompact(),
                ),
                const SizedBox(height: AppSpacing.s12),
                PawMateButton(
                  key: const Key('rescue-detail-update-status'),
                  label: 'Cập nhật trạng thái',
                  onPressed: onUpdateStatus,
                  variant: PawMateButtonVariant.secondary,
                  leadingIcon: Icons.task_alt_outlined,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s12),
        PawMateButton(
          key: const Key('rescue-detail-report'),
          label: 'Báo cáo tin',
          onPressed: onReport,
          variant: PawMateButtonVariant.ghost,
          leadingIcon: Icons.flag_outlined,
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.detail});

  final RescueCaseDetail detail;

  @override
  Widget build(BuildContext context) {
    final image = detail.primaryImage;
    final isBundledDesignAsset = image?.publicUrl.scheme == 'asset';
    final placeholder = ColoredBox(
      color: AppColors.surfaceContainer,
      child: Center(
        child: Icon(
          detail.species == RescueSpecies.cat ? Icons.pets : Icons.pets_rounded,
          size: 64,
          color: AppColors.primary700,
        ),
      ),
    );
    return Semantics(
      container: true,
      label:
          '${detail.petName}, ${detail.status.label}, ${detail.publicLocation.areaLabel}',
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image == null)
                placeholder
              else if (isBundledDesignAsset)
                Image.asset(
                  image.publicUrl.toString().substring('asset:'.length),
                  fit: BoxFit.cover,
                  semanticLabel: 'Ảnh ${detail.petName}',
                  errorBuilder: (_, _, _) => placeholder,
                )
              else
                Image.network(
                  image.publicUrl.toString(),
                  fit: BoxFit.cover,
                  semanticLabel: 'Ảnh ${detail.petName}',
                  errorBuilder: (_, _, _) => placeholder,
                ),
              if (!isBundledDesignAsset)
                Positioned(
                  left: AppSpacing.s16,
                  top: AppSpacing.s16,
                  child: _HeroStatus(
                    status: detail.status,
                    lostAt: detail.lostAt,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PetInformation extends StatelessWidget {
  const _PetInformation({required this.detail});

  final RescueCaseDetail detail;

  @override
  Widget build(BuildContext context) {
    final breedOrColor = detail.breedOrColor ?? 'Chưa cập nhật';
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final stackMetadata = textScale > AppControlSize.compactButtonMaxTextScale;
    return Container(
      key: const Key('rescue-detail-pet-information'),
      constraints: const BoxConstraints(minHeight: 365),
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail.petName, style: AppTextStyles.h2()),
          const SizedBox(height: AppSpacing.s4),
          Text(
            [
              breedOrColor,
              if (detail.ageLabel case final String value) value,
            ].join(' · '),
            style: AppTextStyles.bodyStrong(color: AppColors.primary700),
          ),
          const SizedBox(height: AppSpacing.s24),
          if (stackMetadata)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InformationTile(label: 'Loại', value: detail.species.label),
                const SizedBox(height: AppSpacing.s12),
                _InformationTile(label: 'Giống/Màu', value: breedOrColor),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _InformationTile(
                    label: 'Loại',
                    value: detail.species.label,
                  ),
                ),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: _InformationTile(
                    label: 'Giống/Màu',
                    value: breedOrColor,
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.s16),
          _InformationTile(
            label: 'Đặc điểm nhận dạng',
            value: detail.identifyingFeatures,
          ),
          if (detail.behaviorHint case final String hint) ...[
            const SizedBox(height: AppSpacing.s16),
            _InformationTile(label: 'Tính cách và lưu ý', value: hint),
          ],
        ],
      ),
    );
  }
}

class _InformationTile extends StatelessWidget {
  const _InformationTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: AppColors.lightBeige,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTextStyles.micro()),
          const SizedBox(height: AppSpacing.s4),
          Text(value, style: AppTextStyles.label()),
        ],
      ),
    );
  }
}

class _HeroStatus extends StatelessWidget {
  const _HeroStatus({required this.status, required this.lostAt});

  final RescueCaseStatus status;
  final DateTime lostAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusChip(status: status, onHero: true),
        const SizedBox(height: AppSpacing.s8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s4,
          ),
          decoration: BoxDecoration(
            color: AppColors.brown.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            'Mất lúc ${_formatDateTime(lostAt).replaceFirst(' · ', ' ')}',
            style: AppTextStyles.micro(color: AppColors.white),
          ),
        ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.detail, required this.onTap});

  final RescueCaseDetail detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PawMateCard(
      key: const Key('rescue-detail-location'),
      onTap: onTap,
      semanticLabel:
          'Xem khu vực ước tính ${detail.publicLocation.areaLabel} trên bản đồ',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_outlined, color: AppColors.primary700),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Khu vực nhìn thấy lần cuối', style: AppTextStyles.h4()),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  detail.publicLocation.areaLabel,
                  style: AppTextStyles.bodyStrong(),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Vị trí đã được làm mờ trong bán kính khoảng ${detail.publicLocation.privacyRadiusMeters} m.',
                  style: AppTextStyles.caption(),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          const Icon(Icons.chevron_right_rounded, color: AppColors.primary700),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.canViewPrivateContact});

  final bool canViewPrivateContact;

  @override
  Widget build(BuildContext context) {
    final colors = PawMateStatusColors.of(context);
    return PawMateCard(
      key: const Key('rescue-detail-privacy'),
      backgroundColor: colors.infoContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined, color: colors.info),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Liên hệ an toàn', style: AppTextStyles.bodyStrong()),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  canViewPrivateContact
                      ? 'Thông tin riêng tư chỉ mở trong luồng liên hệ được xác thực; màn công khai này không hiển thị số điện thoại hay địa chỉ chính xác.'
                      : 'Trao đổi trong PawMate. Số điện thoại, địa chỉ và vị trí chính xác không được hiển thị công khai.',
                  style: AppTextStyles.bodyCompact(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({required this.commentCount});

  final int commentCount;

  @override
  Widget build(BuildContext context) {
    return PawMateCard(
      key: const Key('rescue-detail-community'),
      child: Row(
        children: [
          const Icon(
            Icons.forum_outlined,
            color: AppColors.primary700,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cộng đồng đang hỗ trợ', style: AppTextStyles.h4()),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  commentCount == 0
                      ? 'Chưa có bình luận.'
                      : '$commentCount bình luận đã được chia sẻ.',
                  style: AppTextStyles.bodyCompact(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.onHero = false});

  final RescueCaseStatus status;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final found = status == RescueCaseStatus.found;
    final colors = PawMateStatusColors.of(context);
    return IntrinsicWidth(
      child: Container(
        constraints: const BoxConstraints(minWidth: 88, minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onHero
              ? (found ? colors.success : AppColors.brown)
              : (found ? colors.successContainer : colors.warningContainer),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: onHero
              ? null
              : Border.all(color: found ? colors.success : colors.warning),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onHero) ...[
              const Icon(Icons.error_rounded, color: AppColors.white, size: 16),
              const SizedBox(width: AppSpacing.s8),
            ],
            Text(
              onHero ? status.label.toUpperCase() : status.label,
              style: AppTextStyles.captionStrong(
                color: onHero
                    ? AppColors.white
                    : (found ? colors.success : colors.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLoading extends StatelessWidget {
  const _DetailLoading();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PawMateSkeleton(
            width: double.infinity,
            height: 316,
            borderRadius: AppRadius.md,
          ),
          SizedBox(height: AppSpacing.s16),
          PawMateSkeleton(
            width: double.infinity,
            height: 160,
            borderRadius: AppRadius.md,
          ),
          SizedBox(height: AppSpacing.s12),
          PawMateSkeleton(
            width: double.infinity,
            height: 112,
            borderRadius: AppRadius.md,
          ),
        ],
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({
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
      key: Key(
        unavailable ? 'rescue-detail-unavailable' : 'rescue-detail-error',
      ),
      type: unavailable ? PawMateStateType.empty : PawMateStateType.error,
      icon: unavailable ? Icons.search_off_outlined : Icons.cloud_off_outlined,
      title: unavailable
          ? 'Tin báo không còn khả dụng'
          : 'Chưa tải được tin báo',
      message: unavailable
          ? 'Tin có thể đã được gỡ hoặc không còn được chia sẻ. $message'
          : message,
      primaryActionLabel: unavailable ? 'Quay lại' : 'Thử lại',
      onPrimaryAction: unavailable ? onBack : onRetry,
      secondaryActionLabel: unavailable ? null : 'Quay lại',
      onSecondaryAction: unavailable ? null : onBack,
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)} · '
      '${two(local.day)}/${two(local.month)}/${local.year}';
}
