import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../application/rescue_create_provider.dart';
import '../domain/rescue_draft_models.dart';

/// Owner-only review. Exact coordinates are deliberately never rendered here.
Future<bool?> showRescueReportReview(BuildContext context) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: AppColors.background,
    builder: (_) => const RescueReportReviewSheet(),
  );
}

class RescueReportReviewSheet extends ConsumerWidget {
  const RescueReportReviewSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rescueCreateProvider);
    final notifier = ref.read(rescueCreateProvider.notifier);
    final draft = state.draft;
    final errors = notifier.reviewErrors;
    final busy = state.isBusy;
    final date = draft.lostAt?.toLocal();
    return PopScope(
      canPop: !busy,
      child: FractionallySizedBox(
        heightFactor: .94,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            key: const Key('rescue-report-review-sheet'),
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Semantics(
                  header: true,
                  child: Text(
                    'Kiểm tra tin báo mất',
                    style: AppTextStyles.h3(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Xem lại thông tin để giúp bé sớm trở về nhà.',
                  style: AppTextStyles.bodyCompact(),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        draft.petName.trim().isEmpty
                            ? 'Chưa có tên thú cưng'
                            : draft.petName,
                        style: AppTextStyles.h4(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${draft.species.label} · ${draft.breedOrColor}',
                        style: AppTextStyles.bodyCompact(),
                      ),
                      _ReviewField(
                        'Thời gian thất lạc',
                        date == null
                            ? 'Chưa chọn'
                            : '${date.day}/${date.month}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                      ),
                      _ReviewField(
                        'Đặc điểm nhận dạng',
                        draft.identifyingFeatures,
                      ),
                      _ReviewField(
                        'Cách gọi / Biệt danh & tính cách',
                        draft.behaviorHint,
                      ),
                      _ReviewField(
                        'Ảnh / video đã chọn',
                        '${draft.media.length} tệp — quay lại để kiểm tra nội dung',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Liên lạc & riêng tư', style: AppTextStyles.h4()),
                SwitchListTile.adaptive(
                  key: const Key('rescue-review-phone'),
                  contentPadding: EdgeInsets.zero,
                  value:
                      draft.contactPreference ==
                      RescueContactPreference.phoneWithConsent,
                  onChanged: busy
                      ? null
                      : (value) => notifier.setContactPreference(
                          value
                              ? RescueContactPreference.phoneWithConsent
                              : RescueContactPreference.inApp,
                        ),
                  title: const Text('Cho phép liên hệ qua điện thoại'),
                  subtitle: const Text(
                    'Tắt: chỉ liên hệ trong PawMate. Bật khi bạn đồng ý chia sẻ qua luồng liên hệ.',
                  ),
                ),
                SwitchListTile.adaptive(
                  key: const Key('rescue-review-location'),
                  contentPadding: EdgeInsets.zero,
                  value: state.hideHouseNumber,
                  onChanged: busy ? null : notifier.setHideHouseNumber,
                  title: const Text('Ẩn số nhà trong bản xem trước'),
                  subtitle: const Text(
                    'Địa chỉ chính xác chỉ lưu riêng cho chủ tin; cộng đồng luôn chỉ thấy khu vực ước tính.',
                  ),
                ),
                if (state.reviewMediaBeforePublish)
                  CheckboxListTile(
                    key: const Key('rescue-review-media'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: state.mediaReviewConfirmed,
                    onChanged: busy
                        ? null
                        : (value) => notifier.confirmMediaReview(value == true),
                    title: const Text('Tôi đã kiểm tra ảnh/video'),
                    subtitle: const Text(
                      'Không chứa số điện thoại, số nhà hoặc thông tin riêng tư.',
                    ),
                  ),
                if (errors.isNotEmpty)
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      key: const Key('rescue-review-validation'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorSoft,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cần kiểm tra trước khi đăng',
                            style: AppTextStyles.bodyStrong(
                              color: AppColors.error,
                            ),
                          ),
                          for (final error in errors)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                error,
                                style: AppTextStyles.bodyCompact(
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (state.errorMessage != null && errors.isEmpty)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        state.errorMessage!,
                        style: AppTextStyles.bodyCompact(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                PawMateButton(
                  key: const Key('rescue-review-confirm'),
                  label: 'Xác nhận đăng tin',
                  isLoading: busy,
                  onPressed: busy || errors.isNotEmpty
                      ? null
                      : () async {
                          if (!notifier.confirmReportReview()) return;
                          final published = await notifier.publish();
                          if (published && context.mounted) {
                            Navigator.of(context).pop(true);
                          }
                        },
                ),
                const SizedBox(height: 8),
                PawMateButton(
                  key: const Key('rescue-review-back'),
                  label: 'Quay lại chỉnh sửa',
                  variant: PawMateButtonVariant.secondary,
                  onPressed: busy
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewField extends StatelessWidget {
  const _ReviewField(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label()),
        const SizedBox(height: 4),
        Text(
          value.trim().isEmpty ? 'Chưa cung cấp' : value,
          style: AppTextStyles.bodyCompact(),
        ),
      ],
    ),
  );
}
