import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_fixed_cta_bar.dart';
import '../../../core/widgets/pawmate_page_scaffold.dart';
import '../../../core/widgets/pawmate_state_view.dart';
import '../../../core/widgets/pawmate_top_bar.dart';
import '../application/rescue_case_detail_provider.dart';
import '../application/rescue_comment_provider.dart';
import '../application/rescue_sync_coordinator.dart';
import '../application/rescue_status_provider.dart';
import '../domain/rescue_case_models.dart';

class RescueStatusScreen extends ConsumerWidget {
  const RescueStatusScreen({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;
    final detail = ref.watch(rescueCaseDetailProvider(caseId));
    final status = ref.watch(rescueStatusProvider(caseId));
    final notifier = ref.read(rescueStatusProvider(caseId).notifier);

    return PawMatePageScaffold(
      key: const Key('rescue-status-screen'),
      backgroundColor: AppColors.background,
      topBar: PawMateTopBar(
        title: usesExpandedTextLayout ? 'Trạng thái' : 'Cập nhật trạng thái',
        semanticTitle: 'Cập nhật trạng thái',
        eyebrow: 'PawMate',
        showBackButton: true,
        onBack: () => _goBack(context),
        centerTitle: true,
      ),
      body: detail.when(
        loading: () => const PawMateStateView(
          key: Key('rescue-status-loading'),
          type: PawMateStateType.empty,
          title: 'Đang tải ca cứu hộ',
          message: 'Đang kiểm tra quyền và trạng thái…',
          icon: Icons.hourglass_top_rounded,
        ),
        error: (error, _) => PawMateStateView(
          key: const Key('rescue-status-load-error'),
          type: PawMateStateType.error,
          title: 'Chưa tải được ca cứu hộ',
          message: 'Vui lòng kiểm tra kết nối rồi thử lại.',
          primaryActionLabel: 'Thử tải lại',
          onPrimaryAction: () =>
              ref.invalidate(rescueCaseDetailProvider(caseId)),
        ),
        data: (value) {
          final updated = status.updatedDetail;
          if (status.submitState == RescueStatusSubmitState.success &&
              updated != null) {
            return _StatusSuccess(
              detail: updated,
              onOpenCase: () =>
                  context.go('/rescue/${Uri.encodeComponent(updated.caseId)}'),
              onOpenList: () => context.go('/rescue'),
            );
          }
          if (!value.viewerPermissions.canUpdateStatus) {
            return _OwnerOnlyState(
              alreadyFound: value.status == RescueCaseStatus.found,
              onOpenCase: () =>
                  context.go('/rescue/${Uri.encodeComponent(value.caseId)}'),
            );
          }
          return _StatusForm(
            detail: value,
            state: status,
            onConfirmedChanged: notifier.setConfirmedSafe,
            onRefresh: () {
              notifier.prepareForRefresh();
              ref.invalidate(rescueCaseDetailProvider(caseId));
            },
            onSubmit: () async {
              final updated = await notifier.submit(value);
              if (updated == null || !context.mounted) return;
              _synchronize(ref, updated);
            },
          );
        },
      ),
    );
  }

  void _synchronize(WidgetRef ref, RescueCaseDetail detail) {
    ref.read(rescueSyncCoordinatorProvider).synchronizeStatus(detail);
    ref.read(rescueCommentProvider(caseId).notifier).markClosed();
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/rescue/${Uri.encodeComponent(caseId)}');
    }
  }
}

class _StatusForm extends StatelessWidget {
  const _StatusForm({
    required this.detail,
    required this.state,
    required this.onConfirmedChanged,
    required this.onRefresh,
    required this.onSubmit,
  });

  final RescueCaseDetail detail;
  final RescueStatusState state;
  final ValueChanged<bool> onConfirmedChanged;
  final VoidCallback onRefresh;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const Key('rescue-status-scroll'),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s4,
              AppSpacing.s16,
              AppSpacing.s24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PetSummary(detail: detail),
                const SizedBox(height: 20),
                const _OwnerNotice(),
                const SizedBox(height: AppSpacing.s12),
                _StatusTransition(detail: detail),
                const SizedBox(height: AppSpacing.s24),
                const Text(
                  'Thông tin thay đổi',
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                const _ConsequenceRow(
                  index: 1,
                  text:
                      'Bài đăng sẽ được lưu lại làm kỷ niệm trong kho lưu trữ của bạn.',
                ),
                const _ConsequenceRow(
                  index: 2,
                  text:
                      'Trạng thái trên bản đồ và danh sách sẽ chuyển sang “Đã thấy”.',
                ),
                const _ConsequenceRow(
                  index: 3,
                  text:
                      'Cộng đồng vẫn có thể xem các bình luận cũ nhưng không thể báo tin mới.',
                ),
                const SizedBox(height: AppSpacing.s12),
                Semantics(
                  checked: state.confirmedSafe,
                  label: 'Xác nhận ${detail.petName} đã về an toàn',
                  child: CheckboxListTile(
                    key: const Key('rescue-status-confirm-safe'),
                    value: state.confirmedSafe,
                    onChanged: state.isSubmitting || state.needsRefresh
                        ? null
                        : (value) => onConfirmedChanged(value ?? false),
                    title: Text(
                      'Tôi xác nhận ${detail.petName} đã về an toàn',
                      style: AppTextStyles.bodyStrong(),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                    ),
                  ),
                ),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.s12),
                  _StatusError(
                    message: state.errorMessage!,
                    needsRefresh: state.needsRefresh,
                    onRefresh: onRefresh,
                  ),
                ],
              ],
            ),
          ),
        ),
        PawMateFixedCtaBar(
          primaryAction: PawMateAction(
            label: 'Lưu trạng thái',
            icon: Icons.save_outlined,
            onPressed: state.canSubmit ? onSubmit : null,
            isLoading: state.isSubmitting,
          ),
          backgroundColor: AppColors.background,
          elevation: AppElevation.none,
        ),
      ],
    );
  }
}

class _PetSummary extends StatelessWidget {
  const _PetSummary({required this.detail});

  final RescueCaseDetail detail;

  @override
  Widget build(BuildContext context) {
    final image = detail.primaryImage;
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final thumbnail = Container(
      width: 64,
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: _StatusPetImage(image: image),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(detail.petName, style: AppTextStyles.h4()),
        Text(
          '${detail.breedOrColor ?? detail.species.label} • ${detail.publicLocation.areaLabel}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        Text(
          'mất lúc ${_formatLostTime(detail.lostAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption(
            color: AppColors.textMuted,
          ).copyWith(fontSize: 11),
        ),
      ],
    );
    return Semantics(
      label:
          '${detail.petName}, ${detail.species.label}, ${detail.status.label}, khu vực ước tính ${detail.publicLocation.areaLabel}, mất lúc ${_formatLostTime(detail.lostAt)}',
      child: ExcludeSemantics(
        child: Container(
          key: const Key('rescue-status-pet-summary'),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: 18,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.35)),
            boxShadow: AppShadows.soft,
          ),
          child: usesExpandedTextLayout
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        thumbnail,
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(child: details),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Padding(
                      padding: const EdgeInsets.only(left: 76),
                      child: _StatusPill(status: detail.status),
                    ),
                  ],
                )
              : Row(
                  children: [
                    thumbnail,
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(child: details),
                    _StatusPill(status: detail.status),
                  ],
                ),
        ),
      ),
    );
  }
}

class _OwnerNotice extends StatelessWidget {
  const _OwnerNotice();

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 226),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.visibility_outlined,
              size: 18,
              color: AppColors.brown,
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Flexible(
            child: Text(
              'Chỉ chủ bài viết mới thấy thao tác này',
              style: AppTextStyles.caption(color: AppColors.brown),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatusTransition extends StatelessWidget {
  const _StatusTransition({required this.detail});

  final RescueCaseDetail detail;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('rescue-status-transition'),
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.s24,
      AppSpacing.s24,
      AppSpacing.s24,
      AppSpacing.s32,
    ),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: AppColors.border.withValues(alpha: 0.35)),
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(
              width: 96,
              child: _TransitionState(
                icon: Icons.question_mark_rounded,
                label: 'Chưa thấy',
                color: AppColors.deepGreen,
                background: AppColors.surfaceMuted,
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: AppColors.brown),
            const SizedBox(
              width: 96,
              child: _TransitionState(
                icon: Icons.check_rounded,
                label: 'Đã thấy',
                color: AppColors.deepGreen,
                background: AppColors.mint,
                emphasized: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(height: 1, color: AppColors.surfaceContainer),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.celebration_outlined,
              size: 24,
              color: AppColors.brown,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                'Bạn đã tìm thấy ${detail.petName}? Chúc mừng gia đình mình nhé!',
                style: AppTextStyles.body(color: AppColors.brown),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _TransitionState extends StatelessWidget {
  const _TransitionState({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: emphasized ? Border.all(color: color, width: 2) : null,
        ),
        child: Icon(icon, color: color, size: 32),
      ),
      const SizedBox(height: AppSpacing.s4),
      Text(label, style: AppTextStyles.bodyStrong(color: color)),
    ],
  );
}

class _ConsequenceRow extends StatelessWidget {
  const _ConsequenceRow({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.surfaceVariant,
          foregroundColor: AppColors.brown,
          child: Text('$index', style: AppTextStyles.captionStrong()),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(child: Text(text, style: AppTextStyles.body())),
      ],
    ),
  );
}

class _StatusError extends StatelessWidget {
  const _StatusError({
    required this.message,
    required this.needsRefresh,
    required this.onRefresh,
  });

  final String message;
  final bool needsRefresh;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('rescue-status-error'),
    padding: const EdgeInsets.all(AppSpacing.s12),
    decoration: BoxDecoration(
      color: AppColors.errorSoft,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.caption(color: AppColors.error),
          ),
        ),
        if (needsRefresh)
          TextButton(onPressed: onRefresh, child: const Text('Tải lại')),
      ],
    ),
  );
}

class _OwnerOnlyState extends StatelessWidget {
  const _OwnerOnlyState({required this.alreadyFound, required this.onOpenCase});

  final bool alreadyFound;
  final VoidCallback onOpenCase;

  @override
  Widget build(BuildContext context) => PawMateStateView(
    key: const Key('rescue-status-owner-only'),
    type: alreadyFound ? PawMateStateType.success : PawMateStateType.empty,
    icon: alreadyFound ? Icons.check_circle_outline : Icons.lock_outline,
    title: alreadyFound
        ? 'Ca cứu hộ đã ở trạng thái Đã thấy'
        : 'Chỉ dành cho chủ bài viết',
    message: alreadyFound
        ? 'Không có luồng mở lại. Bạn vẫn có thể xem lịch sử và bình luận cũ.'
        : 'Quyền cập nhật trạng thái được kiểm tra lại trên máy chủ.',
    primaryActionLabel: 'Về bài đăng',
    onPrimaryAction: onOpenCase,
  );
}

class _StatusSuccess extends StatelessWidget {
  const _StatusSuccess({
    required this.detail,
    required this.onOpenCase,
    required this.onOpenList,
  });

  final RescueCaseDetail detail;
  final VoidCallback onOpenCase;
  final VoidCallback onOpenList;

  @override
  Widget build(BuildContext context) => PawMateStateView(
    key: const Key('rescue-status-success'),
    type: PawMateStateType.success,
    icon: Icons.check_circle_outline,
    title: 'Đã cập nhật thành “Đã thấy”',
    message:
        '${detail.petName} đã được đồng bộ trên danh sách, bản đồ và bài đăng.',
    primaryActionLabel: 'Về bài đăng',
    onPrimaryAction: onOpenCase,
    secondaryActionLabel: 'Xem danh sách',
    onSecondaryAction: onOpenList,
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final RescueCaseStatus status;

  @override
  Widget build(BuildContext context) {
    final found = status == RescueCaseStatus.found;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: found ? AppColors.lightBeige : AppColors.deepGreen,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: AppTextStyles.captionStrong(
          color: found ? AppColors.deepGreen : AppColors.white,
        ),
      ),
    );
  }
}

class _StatusPetImage extends StatelessWidget {
  const _StatusPetImage({required this.image});

  final RescuePublicMedia? image;

  @override
  Widget build(BuildContext context) {
    final media = image;
    if (media == null) return _fallback();
    if (media.publicUrl.scheme == 'asset') {
      return Image.asset(
        media.publicUrl.toString().substring('asset:'.length),
        key: const Key('rescue-status-pet-image'),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return Image.network(
      media.publicUrl.toString(),
      key: const Key('rescue-status-pet-image'),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() => const ColoredBox(
    color: AppColors.surfaceContainer,
    child: Center(
      child: Icon(Icons.pets, color: AppColors.deepGreen, size: 32),
    ),
  );
}

String _formatLostTime(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)} '
      '${two(local.day)}/${two(local.month)}/${local.year}';
}
