import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_fixed_cta_bar.dart';
import '../../../core/widgets/pawmate_page_scaffold.dart';
import '../../../core/widgets/pawmate_text_field.dart';
import '../../../core/widgets/pawmate_top_bar.dart';
import '../application/rescue_create_provider.dart';
import '../domain/rescue_draft_models.dart';

class RescueInfoFormScreen extends ConsumerStatefulWidget {
  const RescueInfoFormScreen({super.key});

  @override
  ConsumerState<RescueInfoFormScreen> createState() =>
      _RescueInfoFormScreenState();
}

class _RescueInfoFormScreenState extends ConsumerState<RescueInfoFormScreen> {
  late final TextEditingController _featuresController;
  late final TextEditingController _behaviorController;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(rescueCreateProvider).draft;
    _featuresController = TextEditingController(text: draft.identifyingFeatures)
      ..addListener(
        () => ref
            .read(rescueCreateProvider.notifier)
            .setIdentifyingFeatures(_featuresController.text),
      );
    _behaviorController = TextEditingController(text: draft.behaviorHint)
      ..addListener(
        () => ref
            .read(rescueCreateProvider.notifier)
            .setBehaviorHint(_behaviorController.text),
      );
  }

  @override
  void dispose() {
    _featuresController.dispose();
    _behaviorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rescueCreateProvider);
    final notifier = ref.read(rescueCreateProvider.notifier);

    return PawMatePageScaffold(
      topBar: PawMateTopBar(
        title: 'Thông tin chi tiết',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      fixedCtaBar: PawMateFixedCtaBar(
        key: const Key('rescue-info-publish-cta'),
        primaryAction: PawMateAction(
          label: 'Đăng tin tìm',
          onPressed: state.isBusy
              ? null
              : () async {
                  if (await notifier.publish() && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã đăng tin tìm thú cưng.'),
                      ),
                    );
                    context.go('/rescue');
                  }
                },
          isLoading: state.isBusy,
          trailingIcon: Icons.send_rounded,
          semanticLabel: 'Đăng tin tìm thú cưng',
        ),
      ),
      body: ListView(
        key: const Key('rescue-info-form'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s8,
          AppSpacing.s16,
          AppSpacing.s32,
        ),
        children: [
          const _ProgressHeader(),
          if (state.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.s16),
            _InfoError(message: state.errorMessage!),
          ],
          const SizedBox(height: AppSpacing.s24),
          PawMateTextField(
            key: const Key('rescue-info-identifying-features-field'),
            label: 'Đặc điểm nhận dạng',
            controller: _featuresController,
            hintText:
                'Ví dụ: Vòng cổ màu đỏ, có vết sẹo nhỏ ở tai trái, bốn chân trắng...',
            maxLines: 4,
            minLines: 3,
            maxLength: 500,
            isRequired: true,
          ),
          const SizedBox(height: AppSpacing.s16),
          PawMateTextField(
            key: const Key('rescue-info-behavior-field'),
            label: 'Tính cách / cách gọi',
            controller: _behaviorController,
            hintText: 'Ví dụ: Bé hiền, quen tên Mochi',
            maxLines: 3,
            maxLength: 500,
          ),
          const SizedBox(height: AppSpacing.s24),
          Text('Liên lạc & riêng tư', style: AppTextStyles.h4()),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Chọn cách bạn muốn nhận phản hồi. Số điện thoại không hiển thị công khai.',
            style: AppTextStyles.body(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s8),
          _ContactChoice(
            value: RescueContactPreference.inApp,
            selected: state.draft.contactPreference,
            title: 'Nhận tin nhắn trong app',
            message: 'Khuyến nghị · Không chia sẻ số điện thoại',
            onChanged: notifier.setContactPreference,
          ),
          const SizedBox(height: AppSpacing.s8),
          _ContactChoice(
            value: RescueContactPreference.phoneWithConsent,
            selected: state.draft.contactPreference,
            title: 'Cho phép gọi điện',
            message: 'Chỉ dùng khi bạn đã đồng ý chia sẻ với người liên hệ',
            onChanged: notifier.setContactPreference,
          ),
          const SizedBox(height: AppSpacing.s16),
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
                    'Vị trí chính xác chỉ phục vụ việc quản lý tin của bạn; cộng đồng chỉ thấy khu vực ước tính.',
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'BƯỚC 2/2',
              style: AppTextStyles.caption(
                color: AppColors.deepGreen,
              ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
            ),
          ),
          Flexible(
            child: Text(
              'Hoàn thiện hồ sơ',
              maxLines: 2,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption(),
            ),
          ),
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
      const SizedBox(height: AppSpacing.s16),
      Text(
        'Thêm vài chi tiết để bé dễ được nhận ra',
        style: AppTextStyles.pageTitle(),
      ),
    ],
  );
}

class _InfoError extends StatelessWidget {
  const _InfoError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
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
    selected: value == selected,
    button: true,
    child: InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: value == selected
              ? AppColors.surfaceContainer
              : AppColors.surface,
          border: Border.all(
            color: value == selected ? AppColors.deepGreen : AppColors.border,
            width: value == selected
                ? AppBorderWidth.emphasized
                : AppBorderWidth.hairline,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              value == selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: AppColors.deepGreen,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.label()),
                  const SizedBox(height: AppSpacing.s4),
                  Text(message, style: AppTextStyles.caption()),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
