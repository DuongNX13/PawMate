import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_fixed_cta_bar.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_page_scaffold.dart';
import '../../../core/widgets/pawmate_text_field.dart';
import '../../../core/widgets/pawmate_top_bar.dart';
import '../../preferences/application/preference_providers.dart';
import '../../preferences/application/privacy_surface_policy.dart';
import '../application/rescue_create_provider.dart';
import '../application/rescue_sync_coordinator.dart';
import '../domain/rescue_draft_models.dart';
import 'rescue_report_review_sheet.dart';

class RescueInfoFormScreen extends ConsumerStatefulWidget {
  const RescueInfoFormScreen({super.key});

  @override
  ConsumerState<RescueInfoFormScreen> createState() =>
      _RescueInfoFormScreenState();
}

class _RescueInfoFormScreenState extends ConsumerState<RescueInfoFormScreen> {
  late final TextEditingController _featuresController;
  late final TextEditingController _behaviorController;
  String? _personality;
  bool _reviewOpen = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(rescueCreateProvider).draft;
    final behavior = _parseBehaviorHint(draft.behaviorHint);
    _featuresController = TextEditingController(text: draft.identifyingFeatures)
      ..addListener(
        () => ref
            .read(rescueCreateProvider.notifier)
            .setIdentifyingFeatures(_featuresController.text),
      );
    _personality = behavior.personality;
    _behaviorController = TextEditingController(text: behavior.nickname)
      ..addListener(_syncBehaviorHint);
  }

  @override
  void dispose() {
    _featuresController.dispose();
    _behaviorController.dispose();
    super.dispose();
  }

  void _syncBehaviorHint() {
    final nickname = _behaviorController.text.trim();
    final personality = _personality;
    final value = [
      if (nickname.isNotEmpty) nickname,
      if (personality != null) 'Tính cách: $personality',
    ].join('\n');
    ref.read(rescueCreateProvider.notifier).setBehaviorHint(value);
  }

  @override
  Widget build(BuildContext context) {
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;
    final state = ref.watch(rescueCreateProvider);
    final notifier = ref.read(rescueCreateProvider.notifier);
    final privacyState = ref.watch(privacyDefaultsProvider);
    final privacyDefaults =
        privacyState.value ??
        ref.read(privacyDefaultsProvider.notifier).lastSuccessful;
    final privacyPolicy = privacyDefaults == null
        ? PrivacySurfacePolicy.defaultSafe
        : PrivacySurfacePolicy.fromDefaults(privacyDefaults);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) notifier.applyPrivacyPolicy(privacyPolicy);
    });

    return PawMatePageScaffold(
      topBar: PawMateTopBar(
        title: usesExpandedTextLayout ? 'Chi tiết' : 'Thông tin chi tiết',
        semanticTitle: 'Thông tin chi tiết',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      fixedCtaBar: PawMateFixedCtaBar(
        key: const Key('rescue-info-publish-cta'),
        primaryAction: PawMateAction(
          label: state.errorMessage == null ? 'Đăng tin tìm' : 'Đăng lại',
          onPressed: state.isBusy || _reviewOpen
              ? null
              : () async {
                  setState(() => _reviewOpen = true);
                  final published = await showRescueReportReview(context);
                  if (mounted) setState(() => _reviewOpen = false);
                  if (published == true && context.mounted) {
                    final publishedCase = ref
                        .read(rescueCreateProvider)
                        .publishedCase;
                    if (publishedCase != null) {
                      await ref
                          .read(rescueSyncCoordinatorProvider)
                          .synchronizePublished(publishedCase);
                    }
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã đăng tin tìm thú cưng.'),
                      ),
                    );
                    notifier.completePublishedFlow();
                    context.go('/rescue');
                  }
                },
          isLoading: state.isBusy,
          trailingIcon: Icons.send_rounded,
          semanticLabel: 'Đăng tin tìm thú cưng',
        ),
        secondaryAction: state.errorMessage == null
            ? null
            : PawMateAction(
                label: 'Lưu nháp',
                variant: PawMateButtonVariant.secondary,
                semanticLabel: 'Lưu bản nháp, không đăng tin',
                onPressed: state.isBusy || _reviewOpen
                    ? null
                    : () async {
                        if (await notifier.saveDraft() && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Đã lưu bản nháp. Tin chưa được đăng.',
                              ),
                            ),
                          );
                        }
                      },
              ),
      ),
      body: ListView(
        key: const Key('rescue-info-form'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s24,
          AppSpacing.s8,
          AppSpacing.s24,
          AppSpacing.s32 + AppControlSize.fixedCtaBarMinHeight,
        ),
        children: [
          const _ProgressHeader(),
          if (state.errorMessage != null && !_reviewOpen) ...[
            const SizedBox(height: AppSpacing.s16),
            _InfoError(message: state.errorMessage!),
          ],
          const SizedBox(height: AppSpacing.s16),
          PawMateTextField(
            key: const Key('rescue-info-identifying-features-field'),
            label: 'Đặc điểm nhận dạng',
            controller: _featuresController,
            hintText:
                'Ví dụ: Vòng cổ màu đỏ, có vết sẹo nhỏ ở\ntai trái, bốn chân trắng...',
            maxLines: 4,
            minLines: 3,
            maxLength: 500,
            isRequired: true,
            showRequiredIndicator: false,
            counterText: '',
            contentPadding: const EdgeInsets.all(AppSpacing.s16),
          ),
          const SizedBox(height: AppSpacing.s48),
          PawMateTextField(
            key: const Key('rescue-info-behavior-field'),
            label: 'Cách gọi / Biệt danh',
            controller: _behaviorController,
            hintText: 'Nhập tên bé thường gọi...',
            maxLines: 1,
            maxLength: 500,
            counterText: '',
            labelSpacing: AppSpacing.s12,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s16,
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          _PersonalityField(
            value: _personality,
            onChanged: (value) {
              setState(() => _personality = value);
              _syncBehaviorHint();
            },
          ),
          const SizedBox(height: 50),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Liên lạc & Riêng tư', style: AppTextStyles.h4()),
                const SizedBox(height: 20),
                _ContactChoice(
                  value: RescueContactPreference.phoneWithConsent,
                  selected: state.draft.contactPreference,
                  title: 'Công khai số điện thoại',
                  message: 'Giúp người dẫn gọi trực tiếp cho bạn',
                  onChanged: notifier.setContactPreference,
                ),
                const SizedBox(height: 20),
                _ContactChoice(
                  value: RescueContactPreference.inApp,
                  selected: state.draft.contactPreference,
                  title: 'Nhận tin nhắn trực tiếp',
                  message: 'Nhận tin nhắn qua ứng dụng PawMate',
                  onChanged: notifier.setContactPreference,
                ),
              ],
            ),
          ),
          if (state.reviewMediaBeforePublish &&
              state.draft.media.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s16),
            Semantics(
              checked: state.mediaReviewConfirmed,
              label:
                  'Xác nhận đã kiểm tra ảnh và video, không chứa thông tin riêng tư',
              child: CheckboxListTile(
                key: const Key('rescue-info-media-review-confirmation'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                ),
                tileColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  side: const BorderSide(color: AppColors.border),
                ),
                value: state.mediaReviewConfirmed,
                onChanged: (value) =>
                    notifier.confirmMediaReview(value == true),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Tôi đã kiểm tra ảnh/video',
                  style: AppTextStyles.label(),
                ),
                subtitle: Text(
                  'Không có số điện thoại, địa chỉ hoặc vị trí riêng tư trong nội dung.',
                  style: AppTextStyles.caption(),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s32),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline, color: AppColors.deepGreen),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    'Vị trí chính xác chỉ phục vụ việc quản lý tin; cộng đồng chỉ thấy khu vực ước tính. '
                    'Metadata vị trí trong ảnh/video luôn được loại bỏ.'
                    '${privacyDefaults == null ? ' Đang dùng mức bảo vệ an toàn trong lúc tải cài đặt.' : ''}',
                    style: AppTextStyles.bodyCompact(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader();

  @override
  Widget build(BuildContext context) {
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;
    final step = Text(
      'BƯỚC 2/2',
      style: AppTextStyles.caption(
        color: AppColors.deepGreen,
      ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
    );
    final completion = Text(
      'Hoàn thiện hồ sơ',
      maxLines: usesExpandedTextLayout ? null : 2,
      textAlign: usesExpandedTextLayout ? TextAlign.start : TextAlign.end,
      overflow: usesExpandedTextLayout ? null : TextOverflow.ellipsis,
      style: AppTextStyles.caption(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (usesExpandedTextLayout)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              step,
              const SizedBox(height: AppSpacing.s4),
              completion,
            ],
          )
        else
          Row(
            children: [
              Expanded(child: step),
              Flexible(child: completion),
            ],
          ),
        const SizedBox(height: AppSpacing.s8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: const LinearProgressIndicator(
            minHeight: 8,
            value: 1,
            color: AppColors.deepGreen,
            backgroundColor: AppColors.mint,
          ),
        ),
      ],
    );
  }
}

class _PersonalityField extends StatelessWidget {
  const _PersonalityField({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Tính cách',
    value: value ?? 'Chưa chọn',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tính cách', style: AppTextStyles.label()),
        const SizedBox(height: AppSpacing.s16),
        DropdownButtonFormField<String>(
          key: const Key('rescue-info-personality-field'),
          initialValue: value,
          isExpanded: true,
          hint: Text('Chọn tính cách của bé', style: AppTextStyles.field()),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.brown,
          ),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s16,
            ),
          ),
          items: const ['Hiền', 'Năng động', 'Nhút nhát', 'Dễ hoảng sợ']
              .map(
                (label) => DropdownMenuItem(value: label, child: Text(label)),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _InfoError extends StatelessWidget {
  const _InfoError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.error),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body(color: AppColors.error),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ContactChoice extends StatelessWidget {
  const _ContactChoice({
    required this.value,
    required this.selected,
    required this.title,
    required this.message,
    required this.onChanged,
  });

  final RescueContactPreference value;
  final RescueContactPreference selected;
  final String title;
  final String message;
  final ValueChanged<RescueContactPreference> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: value == selected,
    inMutuallyExclusiveGroup: true,
    label: title,
    value: message,
    onTap: () => onChanged(value),
    child: ExcludeSemantics(
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyStrong()),
                  const SizedBox(height: AppSpacing.s4),
                  Text(message, style: AppTextStyles.caption()),
                ],
              ),
            ),
            Switch.adaptive(
              value: value == selected,
              activeTrackColor: AppColors.deepGreen,
              onChanged: (_) => onChanged(value),
            ),
          ],
        ),
      ),
    ),
  );
}

({String nickname, String? personality}) _parseBehaviorHint(String value) {
  const marker = '\nTính cách: ';
  final markerIndex = value.indexOf(marker);
  if (markerIndex < 0) return (nickname: value, personality: null);
  return (
    nickname: value.substring(0, markerIndex),
    personality: value.substring(markerIndex + marker.length).trim(),
  );
}
