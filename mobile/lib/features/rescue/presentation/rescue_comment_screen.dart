import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/media/image_picker_service.dart';
import '../../../core/widgets/pawmate_adaptive.dart';
import '../../../core/widgets/pawmate_page_scaffold.dart';
import '../../../core/widgets/pawmate_top_bar.dart';
import '../../preferences/application/preference_providers.dart';
import '../../preferences/application/privacy_surface_policy.dart';
import '../application/rescue_case_detail_provider.dart';
import '../application/rescue_comment_provider.dart';
import '../domain/rescue_case_models.dart';
import '../domain/rescue_comment_models.dart';

typedef RescueCommentMediaBuilder =
    Widget Function(BuildContext context, RescueCommentMedia media);

final rescueCommentMediaBuilderProvider = Provider<RescueCommentMediaBuilder>(
  (ref) => _defaultCommentMedia,
);

class RescueCommentScreen extends ConsumerStatefulWidget {
  const RescueCommentScreen({
    super.key,
    required this.caseId,
    this.discussionMode = false,
  });

  final String caseId;
  final bool discussionMode;

  @override
  ConsumerState<RescueCommentScreen> createState() =>
      _RescueCommentScreenState();
}

class _RescueCommentScreenState extends ConsumerState<RescueCommentScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(rescueCommentProvider(widget.caseId)).draftText;
    _controller = TextEditingController(text: draft)..addListener(_syncDraft);
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(rescueCommentProvider(widget.caseId).notifier).load();
      }
    });
  }

  @override
  void didUpdateWidget(covariant RescueCommentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.caseId != widget.caseId) {
      _controller.text = ref
          .read(rescueCommentProvider(widget.caseId))
          .draftText;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(rescueCommentProvider(widget.caseId).notifier).load();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_syncDraft)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _syncDraft() {
    ref
        .read(rescueCommentProvider(widget.caseId).notifier)
        .setDraftText(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rescueCommentProvider(widget.caseId));
    final notifier = ref.read(rescueCommentProvider(widget.caseId).notifier);
    final caseDetail = ref.watch(rescueCaseDetailProvider(widget.caseId));
    final detail = caseDetail.asData?.value;
    final now = ref.watch(rescueCommentClockProvider)();
    final privacyState = ref.watch(privacyDefaultsProvider);
    final privacyDefaults =
        privacyState.value ??
        ref.read(privacyDefaultsProvider.notifier).lastSuccessful;
    final privacyPolicy = privacyDefaults == null
        ? PrivacySurfacePolicy.defaultSafe
        : PrivacySurfacePolicy.fromDefaults(privacyDefaults);
    final isConstrainedAccessibilityLayout =
        MediaQuery.viewInsetsOf(context).bottom > 0 ||
        (MediaQuery.textScalerOf(context).scale(1) >= 1.3 &&
            MediaQuery.sizeOf(context).height <= 640);
    final hidePrivacySurfaceForIme =
        !widget.discussionMode &&
        isConstrainedAccessibilityLayout &&
        MediaQuery.viewInsetsOf(context).bottom > 0;
    final hideDiscussionSummaryForIme =
        widget.discussionMode &&
        isConstrainedAccessibilityLayout &&
        MediaQuery.viewInsetsOf(context).bottom > 0;
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;
    final topBarSubtitle = widget.discussionMode
        ? null
        : detail == null
        ? 'Chia sẻ thông tin an toàn'
        : [
            detail.petName,
            detail.breedOrColor ?? detail.species.label,
            detail.publicLocation.areaLabel,
            detail.status.label,
          ].join(' • ');
    final visibleTopBarSubtitle =
        !widget.discussionMode && usesExpandedTextLayout
        ? detail?.petName ?? 'An toàn'
        : topBarSubtitle;
    final topBarSemanticTitle = widget.discussionMode
        ? 'Thảo luận ca tìm'
        : usesExpandedTextLayout && topBarSubtitle != null
        ? 'Bình luận. $topBarSubtitle'
        : null;
    final headers = <Widget>[
      if (hideDiscussionSummaryForIme)
        Semantics(
          container: true,
          label: detail == null
              ? 'Tóm tắt ca tìm chưa sẵn sàng.'
              : _discussionCaseSummarySemanticsLabel(detail),
          child: const SizedBox.shrink(),
        )
      else if (widget.discussionMode)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s16,
            10,
            AppSpacing.s16,
            0,
          ),
          child: caseDetail.when(
            loading: () => const _DiscussionCaseSummaryLoading(),
            error: (_, _) => _DiscussionCaseSummaryUnavailable(
              onRetry: () =>
                  ref.invalidate(rescueCaseDetailProvider(widget.caseId)),
            ),
            data: (value) => _DiscussionCaseSummary(detail: value),
          ),
        )
      else if (hidePrivacySurfaceForIme)
        Semantics(
          container: true,
          label: _privacyWarningSemanticsLabel(privacyPolicy),
          value: privacyDefaults == null
              ? 'Đang dùng mức bảo vệ an toàn'
              : null,
          child: const SizedBox.shrink(),
        )
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s16,
            AppSpacing.s8,
            AppSpacing.s16,
            0,
          ),
          child: _PrivacyWarning(
            policy: privacyPolicy,
            isFallback: privacyDefaults == null,
            compact: isConstrainedAccessibilityLayout,
          ),
        ),
      if (state.commentsClosed)
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s16,
            AppSpacing.s8,
            AppSpacing.s16,
            0,
          ),
          child: _ClosedWarning(),
        ),
      if (state.errorMessage != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s16,
            AppSpacing.s8,
            AppSpacing.s16,
            0,
          ),
          child: _CommentError(
            message: state.errorMessage!,
            retryLabel: state.pendingSendKey != null
                ? 'Gửi lại'
                : 'Thử tải lại',
            onRetry: state.commentsClosed || state.hasFailedUpload
                ? null
                : state.pendingSendKey != null
                ? () => _sendDraft(state, privacyPolicy, notifier)
                : () => notifier.load(force: true),
            compact:
                isConstrainedAccessibilityLayout &&
                MediaQuery.viewInsetsOf(context).bottom > 0,
          ),
        ),
    ];

    return PawMatePageScaffold(
      layoutMode: widget.discussionMode
          ? PawMatePageLayoutMode.fullResponsive
          : PawMatePageLayoutMode.proportional,
      key: const Key('rescue-comment-screen'),
      backgroundColor: AppColors.background,
      topBar: PawMateTopBar(
        title: widget.discussionMode && usesExpandedTextLayout
            ? 'Trao đổi'
            : widget.discussionMode
            ? 'Thảo luận ca tìm'
            : 'Bình luận',
        semanticTitle: topBarSemanticTitle,
        titleColor: widget.discussionMode ? AppColors.deepGreen : null,
        subtitle: visibleTopBarSubtitle,
        showBackButton: true,
        onBack: () => _goBack(context),
        actions: widget.discussionMode
            ? [
                IconButton(
                  key: const Key('rescue-discussion-share'),
                  tooltip: 'Chia sẻ ca tìm',
                  onPressed: detail == null ? null : () => _shareCase(detail),
                  icon: const Icon(Icons.share_outlined),
                ),
              ]
            : [
                IconButton(
                  key: const Key('rescue-comment-open-discussion'),
                  tooltip: 'Mở trao đổi theo luồng',
                  onPressed: () => context.push(
                    '/rescue/${Uri.encodeComponent(widget.caseId)}/discussion',
                  ),
                  icon: const Icon(Icons.forum_outlined),
                ),
              ],
      ),
      body: Column(
        children: [
          if (isConstrainedAccessibilityLayout)
            Flexible(
              child: SingleChildScrollView(
                key: const Key('rescue-comment-recovery-scroll'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: headers,
                ),
              ),
            )
          else
            ...headers,
          Expanded(
            child: _CommentList(
              state: state,
              onRefresh: () => notifier.load(force: true),
              mediaBuilder: ref.watch(rescueCommentMediaBuilderProvider),
              discussionMode: widget.discussionMode,
              now: now,
              onReply: (comment) {
                notifier.setReplyTarget(comment);
                _focusNode.requestFocus();
              },
            ),
          ),
          _CommentComposer(
            controller: _controller,
            focusNode: _focusNode,
            state: state,
            onPickMedia: () => _showMediaPicker(context, notifier),
            onPickImage: () => _pickMedia(notifier, _CommentMediaChoice.image),
            onPickVideo: () => _pickMedia(notifier, _CommentMediaChoice.video),
            onRetryMedia: notifier.retryMedia,
            onRemoveMedia: notifier.removeMedia,
            onClearReply: notifier.clearReplyTarget,
            discussionMode: widget.discussionMode,
            compact: isConstrainedAccessibilityLayout,
            onSend: () => _sendDraft(state, privacyPolicy, notifier),
          ),
        ],
      ),
    );
  }

  Future<void> _sendDraft(
    RescueCommentState state,
    PrivacySurfacePolicy policy,
    RescueCommentNotifier notifier,
  ) async {
    if (await _sendWithPrivacyGuard(
          state: state,
          policy: policy,
          notifier: notifier,
        ) &&
        mounted) {
      _controller.clear();
      _focusNode.requestFocus();
    }
  }

  Future<bool> _sendWithPrivacyGuard({
    required RescueCommentState state,
    required PrivacySurfacePolicy policy,
    required RescueCommentNotifier notifier,
  }) async {
    final phoneConsent = policy.requiresPhoneConsent(state.draftText);
    final mediaReview = policy.requiresMediaReview(state.media);
    if (!phoneConsent && !mediaReview) return notifier.send();

    final confirmed = await showPawMateAdaptiveDialog<bool>(
      context: context,
      dialogKey: const Key('rescue-comment-privacy-confirmation'),
      title: 'Kiểm tra trước khi gửi',
      message: [
        if (phoneConsent)
          'Bình luận có thể chứa số điện thoại. Chỉ gửi nếu bạn đồng ý chia sẻ công khai.',
        if (mediaReview)
          'Hãy chắc chắn ảnh/video không chứa địa chỉ hoặc vị trí riêng tư.',
      ].join('\n\n'),
      actions: const [
        PawMateAdaptiveAction<bool>(label: 'Xem lại'),
        PawMateAdaptiveAction<bool>(
          key: Key('rescue-comment-privacy-confirm-send'),
          label: 'Tôi hiểu, gửi',
          value: true,
          isDefaultAction: true,
        ),
      ],
    );
    if (confirmed != true || !mounted) return false;
    return notifier.send();
  }

  Future<void> _showMediaPicker(
    BuildContext context,
    RescueCommentNotifier notifier,
  ) async {
    final selection = await showModalBottomSheet<_CommentMediaChoice>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const Key('rescue-comment-pick-image'),
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Chọn ảnh'),
                subtitle: const Text('JPEG, PNG hoặc WebP • tối đa 10 MB'),
                onTap: () => Navigator.pop(context, _CommentMediaChoice.image),
              ),
              ListTile(
                key: const Key('rescue-comment-pick-video'),
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Chọn video'),
                subtitle: const Text('MP4 • tối đa 50 MB'),
                onTap: () => Navigator.pop(context, _CommentMediaChoice.video),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || selection == null) return;
    await _pickMedia(notifier, selection);
  }

  Future<void> _pickMedia(
    RescueCommentNotifier notifier,
    _CommentMediaChoice selection,
  ) async {
    final picker = ref.read(imagePickerProvider);
    if (selection == _CommentMediaChoice.video) {
      await notifier.pickVideo(picker);
    } else {
      await notifier.pickImage(picker);
    }
  }

  Future<void> _shareCase(RescueCaseDetail detail) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'PawMate · ${detail.petName} đang cần được tìm tại khu vực '
              '${detail.publicLocation.areaLabel}.',
          subject: 'Cùng tìm ${detail.petName}',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa thể mở bảng chia sẻ. Vui lòng thử lại.'),
        ),
      );
    }
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/rescue/${Uri.encodeComponent(widget.caseId)}');
    }
  }
}

enum _CommentMediaChoice { image, video }

String _discussionCaseSummarySemanticsLabel(RescueCaseDetail detail) =>
    '${detail.petName}, ${detail.status.label}, mất lúc '
    '${_formatCommentCaseTime(detail.lostAt)}, khu vực ước tính '
    '${detail.publicLocation.areaLabel}';

class _DiscussionCaseSummary extends StatelessWidget {
  const _DiscussionCaseSummary({required this.detail});

  final RescueCaseDetail detail;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: _discussionCaseSummarySemanticsLabel(detail),
    child: ExcludeSemantics(
      child: Container(
        key: const Key('rescue-discussion-case-summary'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s16,
        ),
        decoration: BoxDecoration(
          // Figma v0.34 P2-08 case summary sits on the mint hero tint.
          color: AppColors.healthHeroSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox.square(
                dimension: 64,
                child: _DiscussionCaseImage(image: detail.primaryImage),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stackStatus =
                      MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
                      constraints.maxWidth < 220;
                  final title = Text(
                    detail.petName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h4(),
                  );
                  final status = Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.deepGreen,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      detail.status.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.micro(color: AppColors.white),
                    ),
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (stackStatus) ...[
                        title,
                        const SizedBox(height: AppSpacing.s4),
                        status,
                      ] else
                        Row(
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: AppSpacing.s8),
                            status,
                          ],
                        ),
                      const SizedBox(height: AppSpacing.s4),
                      _DiscussionCaseMeta(
                        icon: Icons.calendar_today_outlined,
                        text:
                            'Mất lúc ${_formatCommentCaseTime(detail.lostAt)}',
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      _DiscussionCaseMeta(
                        icon: Icons.location_on,
                        text: detail.publicLocation.areaLabel,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DiscussionCaseMeta extends StatelessWidget {
  const _DiscussionCaseMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 14, color: AppColors.deepGreen),
      const SizedBox(width: AppSpacing.s4),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption(color: AppColors.brown),
        ),
      ),
    ],
  );
}

class _DiscussionCaseImage extends StatelessWidget {
  const _DiscussionCaseImage({required this.image});

  final RescuePublicMedia? image;

  @override
  Widget build(BuildContext context) {
    final media = image;
    if (media == null) return _fallback();
    if (media.publicUrl.scheme == 'asset') {
      return Image.asset(
        media.publicUrl.toString().substring('asset:'.length),
        key: const Key('rescue-discussion-case-image'),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return Image.network(
      media.publicUrl.toString(),
      key: const Key('rescue-discussion-case-image'),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() => const ColoredBox(
    color: AppColors.surfaceContainer,
    child: Center(
      child: Icon(Icons.pets, color: AppColors.deepGreen, size: 30),
    ),
  );
}

class _DiscussionCaseSummaryLoading extends StatelessWidget {
  const _DiscussionCaseSummaryLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 96,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
      ),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _DiscussionCaseSummaryUnavailable extends StatelessWidget {
  const _DiscussionCaseSummaryUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    height: 96,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        const Expanded(child: Text('Chưa tải được thông tin ca tìm.')),
        TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );
}

String _privacyWarningSemanticsLabel(PrivacySurfacePolicy policy) =>
    'Lưu ý riêng tư. '
    '${policy.hidePhoneByDefault ? 'PawMate sẽ yêu cầu xác nhận nếu bình luận có số điện thoại.' : 'Bạn đã cho phép chia sẻ số điện thoại khi cần.'} '
    '${policy.reviewMediaBeforePublish ? 'Ảnh và video cần được kiểm tra trước khi gửi.' : 'Không đăng vị trí chính xác.'}';

class _PrivacyWarning extends StatelessWidget {
  const _PrivacyWarning({
    required this.policy,
    required this.isFallback,
    this.compact = false,
  });

  final PrivacySurfacePolicy policy;
  final bool isFallback;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: _privacyWarningSemanticsLabel(policy),
      value: isFallback ? 'Đang dùng mức bảo vệ an toàn' : null,
      child: ExcludeSemantics(
        child: Container(
          key: const Key('rescue-comment-privacy-warning'),
          padding: compact
              ? const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s8,
                )
              : const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.privacy_tip_outlined,
                color: AppColors.deepGreen,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  compact
                      ? 'Lưu ý riêng tư'
                      : '${policy.hidePhoneByDefault ? 'Không chia sẻ số nhà, số điện thoại công khai.' : 'Chỉ chia sẻ số điện thoại khi thật sự cần.'} '
                            '${policy.reviewMediaBeforePublish ? 'Kiểm tra ảnh/video trước khi gửi.' : 'Không đăng vị trí chính xác.'}',
                  maxLines: compact ? 1 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: AppTextStyles.caption(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClosedWarning extends StatelessWidget {
  const _ClosedWarning();

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      key: const Key('rescue-comment-closed-warning'),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.brown),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              'Ca cứu hộ đã đóng bình luận. Nội dung chưa gửi vẫn được giữ.',
              style: AppTextStyles.captionStrong(color: AppColors.brown),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CommentError extends StatelessWidget {
  const _CommentError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.compact = false,
  });

  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      key: const Key('rescue-comment-error'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s12,
        AppSpacing.s8,
        AppSpacing.s8,
        AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              message,
              maxLines: compact ? 1 : 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption(color: AppColors.error),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: compact
                  ? TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s4,
                      ),
                    )
                  : null,
              child: Text(retryLabel, maxLines: 1),
            ),
        ],
      ),
    ),
  );
}

class _CommentList extends StatelessWidget {
  const _CommentList({
    required this.state,
    required this.onRefresh,
    required this.mediaBuilder,
    required this.discussionMode,
    required this.now,
    required this.onReply,
  });

  final RescueCommentState state;
  final Future<void> Function() onRefresh;
  final RescueCommentMediaBuilder mediaBuilder;
  final bool discussionMode;
  final DateTime now;
  final ValueChanged<RescueComment> onReply;

  @override
  Widget build(BuildContext context) {
    if (state.status == RescueCommentLoadStatus.loading &&
        state.comments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == RescueCommentLoadStatus.error &&
        state.comments.isEmpty) {
      return _CommentEmpty(
        icon: Icons.cloud_off_outlined,
        title: 'Chưa tải được bình luận',
        message: 'Kéo xuống hoặc chọn Thử tải lại.',
      );
    }
    if (state.comments.isEmpty) {
      return const _CommentEmpty(
        icon: Icons.forum_outlined,
        title: 'Chưa có bình luận',
        message: 'Hãy chia sẻ manh mối đầu tiên, không kèm vị trí riêng tư.',
      );
    }
    final displayComments = discussionMode
        ? state.comments
        : state.comments.reversed.toList(growable: false);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        key: const Key('rescue-comment-list'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s16,
          AppSpacing.s16,
          AppSpacing.s24,
        ),
        itemCount: displayComments.length + (state.isStale ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s12),
        itemBuilder: (context, index) {
          if (state.isStale && index == 0) {
            return const _StaleNotice();
          }
          final comment = displayComments[index - (state.isStale ? 1 : 0)];
          final parent = comment.replyToCommentId == null
              ? null
              : state.comments
                    .where(
                      (candidate) =>
                          candidate.commentId == comment.replyToCommentId,
                    )
                    .firstOrNull;
          return _CommentCard(
            comment: comment,
            parent: parent,
            mediaBuilder: mediaBuilder,
            discussionMode: discussionMode,
            now: now,
            repliesEnabled: !state.commentsClosed,
            onReply: () => onReply(comment),
          );
        },
      ),
    );
  }
}

class _CommentEmpty extends StatelessWidget {
  const _CommentEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: ConstrainedBox(
        // The parent `Expanded` can legitimately receive zero height when
        // large text leaves the composer as the only visible surface. Never
        // derive a negative BoxConstraints minimum from that state.
        constraints: BoxConstraints(
          minHeight: constraints.hasBoundedHeight
              ? math.max(0, constraints.maxHeight - 48)
              : 0,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: AppColors.deepGreen),
              const SizedBox(height: AppSpacing.s12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.h4(),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StaleNotice extends StatelessWidget {
  const _StaleNotice();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('rescue-comment-stale-notice'),
    padding: const EdgeInsets.all(AppSpacing.s8),
    decoration: BoxDecoration(
      color: AppColors.warningSoft,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Text(
      'Đang hiển thị bản cập nhật trước. Kéo xuống để thử lại.',
      style: AppTextStyles.caption(color: AppColors.brown),
    ),
  );
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.comment,
    required this.mediaBuilder,
    required this.discussionMode,
    required this.now,
    required this.repliesEnabled,
    required this.onReply,
    this.parent,
  });

  final RescueComment comment;
  final RescueComment? parent;
  final RescueCommentMediaBuilder mediaBuilder;
  final bool discussionMode;
  final DateTime now;
  final bool repliesEnabled;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final hidden =
        comment.moderationState == RescueCommentModerationState.hidden;
    final hasMedia = !hidden && comment.media.isNotEmpty;
    if (discussionMode) {
      return _DiscussionCommentCard(
        comment: comment,
        parent: parent,
        mediaBuilder: mediaBuilder,
        repliesEnabled: repliesEnabled,
        onReply: onReply,
        onOptions: () => _showCommentOptions(context),
        now: now,
      );
    }
    return Semantics(
      container: true,
      label: hidden
          ? 'Bình luận của ${comment.author.displayName} đã được ẩn'
          : '${comment.author.displayName}, ${_formatRelativeTime(comment.createdAt, now)}, ${comment.body}',
      child: Padding(
        padding: EdgeInsets.only(
          left: discussionMode && comment.replyToCommentId != null
              ? AppSpacing.s24
              : 0,
        ),
        child: Container(
          key: ValueKey('rescue-comment-${comment.commentId}'),
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: hasMedia ? Colors.transparent : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: hasMedia
                ? null
                : Border.all(
                    color: comment.isOptimistic
                        ? AppColors.mint
                        : AppColors.border,
                  ),
            boxShadow: hasMedia ? null : AppShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (discussionMode && comment.replyToCommentId != null) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      size: 18,
                      color: AppColors.deepGreen,
                    ),
                    const SizedBox(width: AppSpacing.s4),
                    Expanded(
                      child: Text(
                        parent == null
                            ? 'Phản hồi một bình luận trước'
                            : 'Phản hồi ${parent!.author.displayName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.captionStrong(
                          color: AppColors.deepGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
              ],
              Row(
                children: [
                  _CommentAvatar(author: comment.author),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment.author.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.cardTitle(),
                        ),
                        Text(
                          comment.isOptimistic
                              ? 'Đang gửi…'
                              : _formatRelativeTime(comment.createdAt, now),
                          style: AppTextStyles.caption(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ModerationBadge(comment: comment),
                  IconButton(
                    key: ValueKey(
                      'rescue-comment-options-${comment.commentId}',
                    ),
                    tooltip: 'Tùy chọn bình luận',
                    onPressed: () => _showCommentOptions(context),
                    icon: const Icon(Icons.more_vert_rounded),
                    color: AppColors.brown,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                hidden ? 'Nội dung này đã được ẩn.' : comment.body,
                style: AppTextStyles.body(
                  color: hidden ? AppColors.textMuted : AppColors.textPrimary,
                ),
              ),
              if (!hidden && comment.media.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s12),
                for (final media in comment.media) ...[
                  mediaBuilder(context, media),
                  const SizedBox(height: AppSpacing.s8),
                ],
              ],
              if (comment.isOptimistic && comment.optimisticMediaCount > 0) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'Đang gửi ${comment.optimisticMediaCount} tệp đính kèm',
                  style: AppTextStyles.caption(color: AppColors.deepGreen),
                ),
              ],
              if (discussionMode &&
                  repliesEnabled &&
                  !hidden &&
                  !comment.isOptimistic) ...[
                const SizedBox(height: AppSpacing.s8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: ValueKey('rescue-comment-reply-${comment.commentId}'),
                    onPressed: onReply,
                    icon: const Icon(Icons.reply_rounded, size: 18),
                    label: const Text('Phản hồi'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCommentOptions(BuildContext context) async {
    await showPawMateAdaptiveDialog<void>(
      context: context,
      title: 'Tùy chọn bình luận',
      message:
          'Bạn có thể báo cáo nội dung không phù hợp trong bước kiểm duyệt tiếp theo.',
      actions: const [
        PawMateAdaptiveAction<void>(label: 'Đóng', isDefaultAction: true),
      ],
    );
  }
}

class _DiscussionCommentCard extends StatelessWidget {
  const _DiscussionCommentCard({
    required this.comment,
    required this.parent,
    required this.mediaBuilder,
    required this.repliesEnabled,
    required this.onReply,
    required this.onOptions,
    required this.now,
  });

  final RescueComment comment;
  final RescueComment? parent;
  final RescueCommentMediaBuilder mediaBuilder;
  final bool repliesEnabled;
  final VoidCallback onReply;
  final VoidCallback onOptions;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final hidden =
        comment.moderationState == RescueCommentModerationState.hidden;
    final hasMedia = !hidden && comment.media.isNotEmpty;
    final isReply = comment.replyToCommentId != null;
    return Semantics(
      container: true,
      label: hidden
          ? 'Bình luận của ${comment.author.displayName} đã được ẩn'
          : '${comment.author.displayName}, ${comment.body}',
      child: Padding(
        padding: EdgeInsets.only(left: isReply ? AppSpacing.s48 : 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CommentAvatar(author: comment.author, radius: isReply ? 16 : 20),
            SizedBox(width: isReply ? AppSpacing.s8 : 28),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    key: ValueKey('rescue-comment-${comment.commentId}'),
                    // Figma v0.34 P2-08: every comment is a 12pt bubble;
                    // replies use the mint tint (D123-IOS-UI-008).
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s16,
                      AppSpacing.s8,
                      AppSpacing.s4,
                      AppSpacing.s12,
                    ),
                    decoration: BoxDecoration(
                      color: isReply
                          ? AppColors.healthHeroSoft
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: comment.isOptimistic
                          ? Border.all(color: AppColors.mint)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isReply)
                          Opacity(
                            opacity: 0,
                            child: SizedBox(
                              height: 0,
                              child: Text(
                                parent == null
                                    ? 'Phản hồi một bình luận trước'
                                    : 'Phản hồi ${parent!.author.displayName}',
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                comment.author.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.cardTitle(
                                  color:
                                      comment.author.displayName.contains(
                                        'Chủ tin',
                                      )
                                      ? AppColors.deepGreen
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              key: ValueKey(
                                'rescue-comment-options-${comment.commentId}',
                              ),
                              tooltip: 'Tùy chọn bình luận',
                              onPressed: onOptions,
                              icon: const Icon(Icons.more_vert_rounded),
                              color: AppColors.brown,
                            ),
                          ],
                        ),
                        Text(
                          hidden ? 'Nội dung này đã được ẩn.' : comment.body,
                          style: AppTextStyles.body(
                            color: hidden
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (hasMedia) ...[
                          const SizedBox(height: AppSpacing.s8),
                          for (final media in comment.media) ...[
                            mediaBuilder(context, media),
                            const SizedBox(height: AppSpacing.s4),
                          ],
                        ],
                      ],
                    ),
                  ),
                  if (repliesEnabled && !hidden && !comment.isOptimistic)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.s12,
                        children: [
                          Text(
                            _formatRelativeTime(comment.createdAt, now),
                            style: AppTextStyles.caption(
                              color: AppColors.textMuted,
                            ),
                          ),
                          TextButton(
                            key: ValueKey(
                              'rescue-comment-reply-${comment.commentId}',
                            ),
                            onPressed: onReply,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s4,
                              ),
                            ),
                            child: const Text('Trả lời'),
                          ),
                        ],
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

class _CommentAvatar extends StatelessWidget {
  const _CommentAvatar({required this.author, this.radius = 22});

  final RescueCommentAuthor author;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = author.displayName.trim().isEmpty
        ? '?'
        : author.displayName.trim().characters.first.toUpperCase();
    final avatar = author.avatarUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.mint,
      foregroundColor: AppColors.deepGreen,
      backgroundImage: avatar == null || avatar.scheme == 'asset'
          ? null
          : NetworkImage(avatar.toString()),
      onBackgroundImageError: avatar == null || avatar.scheme == 'asset'
          ? null
          : (_, _) {},
      child: avatar?.scheme == 'asset'
          ? ClipOval(
              child: Image.asset(
                avatar.toString().substring('asset:'.length),
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Text(
                  initial,
                  style: AppTextStyles.h4(color: AppColors.deepGreen),
                ),
              ),
            )
          : avatar == null
          ? Text(initial, style: AppTextStyles.h4(color: AppColors.deepGreen))
          : null,
    );
  }
}

class _ModerationBadge extends StatelessWidget {
  const _ModerationBadge({required this.comment});

  final RescueComment comment;

  @override
  Widget build(BuildContext context) {
    if (comment.moderationState == RescueCommentModerationState.visible &&
        !comment.isOptimistic) {
      return const SizedBox.shrink();
    }
    final label = comment.isOptimistic
        ? 'ĐANG GỬI'
        : comment.moderationState.label.toUpperCase();
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.micro(color: AppColors.deepGreen),
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.focusNode,
    required this.state,
    required this.onPickMedia,
    required this.onPickImage,
    required this.onPickVideo,
    required this.onRetryMedia,
    required this.onRemoveMedia,
    required this.onClearReply,
    required this.onSend,
    required this.discussionMode,
    this.compact = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final RescueCommentState state;
  final VoidCallback onPickMedia;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;
  final ValueChanged<String> onRetryMedia;
  final ValueChanged<String> onRemoveMedia;
  final VoidCallback onClearReply;
  final VoidCallback onSend;
  final bool discussionMode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('rescue-comment-composer'),
      color: AppColors.surface,
      elevation: AppElevation.floating,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s12,
            compact ? AppSpacing.s4 : AppSpacing.s8,
            AppSpacing.s12,
            compact ? AppSpacing.s4 : AppSpacing.s8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.replyToCommentId != null) ...[
                Container(
                  key: const Key('rescue-comment-reply-banner'),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s12,
                    AppSpacing.s8,
                    AppSpacing.s4,
                    AppSpacing.s8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.reply_rounded,
                        size: 18,
                        color: AppColors.deepGreen,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          'Đang phản hồi ${state.replyToDisplayName ?? 'bình luận'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.captionStrong(
                            color: AppColors.deepGreen,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('rescue-comment-clear-reply'),
                        tooltip: 'Hủy phản hồi',
                        onPressed: state.isSending ? null : onClearReply,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
              ],
              if (state.media.isNotEmpty) ...[
                SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(1) > 1.3
                      ? 104
                      : 74,
                  child: ListView.separated(
                    key: const Key('rescue-comment-media-list'),
                    scrollDirection: Axis.horizontal,
                    itemCount: state.media.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.s8),
                    itemBuilder: (context, index) {
                      final media = state.media[index];
                      return _DraftMediaTile(
                        media: media,
                        onRetry: () => onRetryMedia(media.localId),
                        onRemove: () => onRemoveMedia(media.localId),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (discussionMode) ...[
                    _ComposerMediaButton(
                      key: const Key('rescue-comment-attach-image'),
                      tooltip: 'Đính kèm ảnh',
                      icon: Icons.image_outlined,
                      enabled:
                          !state.commentsClosed &&
                          !state.isSending &&
                          state.media.length < 5,
                      onPressed: onPickImage,
                    ),
                    _ComposerMediaButton(
                      key: const Key('rescue-comment-attach-video'),
                      tooltip: 'Đính kèm video',
                      icon: Icons.videocam_outlined,
                      enabled:
                          !state.commentsClosed &&
                          !state.isSending &&
                          state.media.length < 5,
                      onPressed: onPickVideo,
                    ),
                  ] else
                    Semantics(
                      button: true,
                      enabled:
                          !state.commentsClosed &&
                          !state.isSending &&
                          state.media.length < 5,
                      label: 'Đính kèm ảnh hoặc video',
                      onTap:
                          !state.commentsClosed &&
                              !state.isSending &&
                              state.media.length < 5
                          ? onPickMedia
                          : null,
                      child: ExcludeSemantics(
                        child: IconButton(
                          key: const Key('rescue-comment-attach'),
                          tooltip: 'Đính kèm ảnh hoặc video',
                          onPressed:
                              !state.commentsClosed &&
                                  !state.isSending &&
                                  state.media.length < 5
                              ? onPickMedia
                              : null,
                          icon: const Icon(Icons.attach_file_rounded),
                          color: AppColors.deepGreen,
                        ),
                      ),
                    ),
                  const SizedBox(width: AppSpacing.s4),
                  Expanded(
                    child: Semantics(
                      textField: true,
                      enabled: !state.commentsClosed,
                      label: 'Nội dung bình luận, tối đa 500 ký tự',
                      child: TextField(
                        key: const Key('rescue-comment-field'),
                        controller: controller,
                        focusNode: focusNode,
                        enabled: !state.commentsClosed,
                        minLines: 1,
                        maxLines: compact ? 1 : 4,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: discussionMode
                              ? 'Viết bình luận…'
                              : 'Chia sẻ manh mối an toàn…',
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.s12,
                            vertical: compact ? AppSpacing.s8 : AppSpacing.s12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  Semantics(
                    button: true,
                    enabled: state.canSend,
                    label: 'Gửi bình luận',
                    onTap: state.canSend ? onSend : null,
                    value: state.isSending ? 'Đang gửi' : null,
                    liveRegion: state.isSending,
                    child: ExcludeSemantics(
                      child: IconButton.filled(
                        key: const Key('rescue-comment-send'),
                        tooltip: 'Gửi bình luận',
                        onPressed: state.canSend ? onSend : null,
                        icon: state.isSending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        color: AppColors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.deepGreen,
                          disabledBackgroundColor: AppColors.surfaceVariant,
                          minimumSize: const Size.square(
                            AppControlSize.minTouchTarget,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerMediaButton extends StatelessWidget {
  const _ComposerMediaButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    label: tooltip,
    onTap: enabled ? onPressed : null,
    child: ExcludeSemantics(
      child: IconButton(
        tooltip: tooltip,
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon),
        color: AppColors.deepGreen,
      ),
    ),
  );
}

class _DraftMediaTile extends StatelessWidget {
  const _DraftMediaTile({
    required this.media,
    required this.onRetry,
    required this.onRemove,
  });

  final RescueCommentDraftMedia media;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (media.status) {
      RescueCommentUploadStatus.pending => 'Đang chờ',
      RescueCommentUploadStatus.uploading =>
        '${(media.progress * 100).round()}%',
      RescueCommentUploadStatus.uploaded => 'Đã tải',
      RescueCommentUploadStatus.failed => 'Tải lỗi',
    };
    return Semantics(
      container: true,
      label: '${media.isVideo ? 'Video' : 'Ảnh'} đính kèm, $statusText',
      child: Container(
        key: ValueKey('rescue-comment-media-${media.localId}'),
        width: media.status == RescueCommentUploadStatus.failed ? 288 : 200,
        padding: const EdgeInsets.all(AppSpacing.s8),
        decoration: BoxDecoration(
          color: media.status == RescueCommentUploadStatus.failed
              ? AppColors.errorSoft
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _LocalMediaPreview(media: media),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media.isVideo ? 'Video MP4' : 'Ảnh',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.captionStrong(),
                  ),
                  Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.micro(
                      color: media.status == RescueCommentUploadStatus.failed
                          ? AppColors.error
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (media.status == RescueCommentUploadStatus.failed)
              IconButton(
                tooltip: 'Thử tải lại',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
              ),
            if (media.status != RescueCommentUploadStatus.uploading)
              IconButton(
                tooltip: 'Xóa tệp',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _LocalMediaPreview extends StatelessWidget {
  const _LocalMediaPreview({required this.media});

  final RescueCommentDraftMedia media;

  @override
  Widget build(BuildContext context) {
    if (media.isVideo) {
      return const SizedBox.square(
        dimension: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
          ),
          child: Icon(Icons.play_arrow_rounded, color: AppColors.deepGreen),
        ),
      );
    }
    final file = File(media.path);
    if (!file.existsSync()) {
      return const SizedBox.square(
        dimension: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
          ),
          child: Icon(Icons.image_outlined, color: AppColors.deepGreen),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Image.file(
        file,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}

Widget _defaultCommentMedia(BuildContext context, RescueCommentMedia media) {
  if (media.isVideo) {
    return Container(
      key: ValueKey('rescue-comment-video-${media.mediaId}'),
      height: 168,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_circle_outline_rounded,
            size: 48,
            color: AppColors.deepGreen,
          ),
          SizedBox(height: AppSpacing.s8),
          Text('Video đính kèm'),
        ],
      ),
    );
  }
  final sourceWidth = media.width;
  final sourceHeight = media.height;
  final aspectRatio =
      sourceWidth != null &&
          sourceHeight != null &&
          sourceWidth > 0 &&
          sourceHeight > 0
      ? (sourceWidth / sourceHeight).clamp(0.75, 16 / 9).toDouble()
      : 1.0;
  return ClipRRect(
    key: ValueKey('rescue-comment-image-${media.mediaId}'),
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: AspectRatio(
      aspectRatio: aspectRatio,
      child: media.publicUrl.scheme == 'asset'
          ? Image.asset(
              media.publicUrl.toString().substring('asset:'.length),
              width: double.infinity,
              fit: BoxFit.cover,
              semanticLabel: 'Ảnh đính kèm bình luận',
              errorBuilder: (_, _, _) => _commentMediaFallback(),
            )
          : Image.network(
              media.publicUrl.toString(),
              width: double.infinity,
              fit: BoxFit.cover,
              semanticLabel: 'Ảnh đính kèm bình luận',
              errorBuilder: (_, _, _) => _commentMediaFallback(),
            ),
    ),
  );
}

Widget _commentMediaFallback() => Container(
  color: AppColors.surfaceContainer,
  alignment: Alignment.center,
  child: const Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
);

String _formatRelativeTime(DateTime value, DateTime now) {
  final delta = now.toUtc().difference(value.toUtc());
  if (delta.isNegative || delta.inMinutes < 1) return 'Vừa xong';
  if (delta.inMinutes < 60) return '${delta.inMinutes} phút trước';
  if (delta.inHours < 24) return '${delta.inHours} giờ trước';
  if (delta.inDays < 7) return '${delta.inDays} ngày trước';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}

String _formatCommentCaseTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}, '
      '${two(local.day)}/${two(local.month)}/${local.year}';
}
