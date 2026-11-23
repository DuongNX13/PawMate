import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_navigation.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_ui.dart';
import '../../preferences/application/preference_providers.dart';
import '../../preferences/data/preference_api.dart';
import '../../preferences/domain/preference_models.dart';
import '../data/privacy_guidance_share_service.dart';

class PrivacyDefaultsScreen extends ConsumerStatefulWidget {
  const PrivacyDefaultsScreen({super.key});

  @override
  ConsumerState<PrivacyDefaultsScreen> createState() =>
      _PrivacyDefaultsScreenState();
}

class _PrivacyDefaultsScreenState extends ConsumerState<PrivacyDefaultsScreen> {
  PrivacyDefaults? _draft;
  bool _dirty = false;
  bool _saving = false;
  String? _saveError;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(privacyDefaultsProvider);
    final lastSuccessful = ref
        .read(privacyDefaultsProvider.notifier)
        .lastSuccessful;
    final defaults = _draft ?? state.value ?? lastSuccessful;

    return PawMatePageScaffold(
      key: const Key('privacy-defaults-screen'),
      topBar: PawMateTopBar(
        title: 'Quyền riêng tư',
        titleSpacing: AppSpacing.s8,
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () =>
              PawMateNavigation.backOrGo(context, '/profile/controls'),
          icon: const BackButtonIcon(),
        ),
        actions: [
          IconButton(
            key: const Key('privacy-share-guidance'),
            tooltip: 'Chia sẻ hướng dẫn quyền riêng tư',
            onPressed: _sharePrivacyGuidance,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      fixedCtaBar: PawMateFixedCtaBar(
        primaryAction: PawMateAction(
          label: 'Lưu thay đổi',
          semanticLabel: 'Lưu cài đặt quyền riêng tư',
          isLoading: _saving,
          onPressed: defaults != null && _dirty && !_saving
              ? () => _save(defaults)
              : null,
        ),
      ),
      body: switch (defaults) {
        null when state.isLoading => const Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Đang tải cài đặt quyền riêng tư',
          ),
        ),
        null => PawMateStateView(
          type: PawMateStateType.error,
          title: 'Chưa tải được cài đặt',
          message: _preferenceError(state.error),
          primaryActionLabel: 'Thử lại',
          onPrimaryAction: () => ref.invalidate(privacyDefaultsProvider),
        ),
        final value => ListView(
          key: const Key('privacy-defaults-scroll'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s16,
            AppSpacing.s16,
            AppSpacing.s16,
            AppSpacing.s32,
          ),
          children: [
            const _SafetyCard(),
            if (state.isLoading) ...[
              const SizedBox(height: AppSpacing.s12),
              const LinearProgressIndicator(
                semanticsLabel: 'Đang lưu cài đặt quyền riêng tư',
              ),
            ],
            if (_saveError != null) ...[
              const SizedBox(height: AppSpacing.s12),
              _InlineError(message: _saveError!),
            ],
            const SizedBox(height: AppSpacing.s24),
            const _GroupTitle('Bản đồ & Địa chỉ'),
            const SizedBox(height: AppSpacing.s12),
            _SettingsGroup(
              children: [
                _PrivacySwitch(
                  key: const Key('privacy-hide-house-number'),
                  title: 'Ẩn địa chỉ chính xác',
                  description:
                      'Ưu tiên ẩn số nhà trong bản xem trước. Tin cứu hộ công khai chỉ hiển thị khu vực với bán kính riêng tư 500m. Vị trí chính xác không được công khai kể cả khi tắt tùy chọn này.',
                  value: value.hideHouseNumber,
                  onChanged: (enabled) =>
                      _update(value.copyWith(hideHouseNumber: enabled)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            const _GroupTitle('Liên lạc & Riêng tư'),
            const SizedBox(height: AppSpacing.s12),
            _SettingsGroup(
              children: [
                _PrivacySwitch(
                  key: const Key('privacy-show-phone'),
                  title: 'Hiển thị số điện thoại',
                  description:
                      'Khi tắt, app hỏi lại trước khi chia sẻ số điện thoại qua tin cứu hộ, bình luận hoặc chat.',
                  value: !value.hidePhoneByDefault,
                  onChanged: (enabled) =>
                      _update(value.copyWith(hidePhoneByDefault: !enabled)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            const _GroupTitle('Hình ảnh & Phương tiện'),
            const SizedBox(height: AppSpacing.s12),
            _SettingsGroup(
              children: [
                const _PrivacySwitch(
                  key: Key('privacy-strip-exif'),
                  title: 'Xóa dữ liệu EXIF',
                  description:
                      'Tự động gỡ vị trí GPS khỏi ảnh trước khi đăng lên tin cứu hộ.',
                  value: true,
                  enabled: false,
                  displayReadOnlyActive: true,
                ),
                _PrivacySwitch(
                  key: const Key('privacy-review-media'),
                  title: 'Duyệt nội dung đa phương tiện',
                  description:
                      'Luôn kiểm tra ảnh/video trước khi hiển thị cho người khác.',
                  value: value.reviewMediaBeforePublish,
                  onChanged: (enabled) => _update(
                    value.copyWith(reviewMediaBeforePublish: enabled),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            _ConsumerPreview(defaults: value),
          ],
        ),
      },
    );
  }

  void _update(PrivacyDefaults value) {
    setState(() {
      _draft = value;
      _dirty = true;
      _saveError = null;
    });
  }

  Future<void> _sharePrivacyGuidance() async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      await ref
          .read(privacyGuidanceShareSourceProvider)
          .shareGuidance(sharePositionOrigin: origin);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa thể mở bảng chia sẻ. Vui lòng thử lại.'),
        ),
      );
    }
    if (!mounted) return;
  }

  Future<void> _save(PrivacyDefaults value) async {
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final saved = await ref.read(privacyDefaultsProvider.notifier).save(value);
    if (!mounted) return;
    if (saved) {
      final authoritative = ref.read(privacyDefaultsProvider).requireValue;
      setState(() {
        _draft = authoritative;
        _dirty = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu cài đặt quyền riêng tư.')),
      );
      return;
    }
    setState(() {
      _saving = false;
      _saveError = _preferenceError(ref.read(privacyDefaultsProvider).error);
    });
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 118),
    padding: const EdgeInsets.all(AppSpacing.s16),
    decoration: BoxDecoration(
      color: AppColors.mint,
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: AppControlSize.minTouchTarget,
          height: AppControlSize.minTouchTarget,
          decoration: BoxDecoration(
            color: AppColors.deepGreen,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: AppColors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: AppSpacing.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'An toàn là ưu tiên',
                style: AppTextStyles.h4(color: AppColors.textPrimary),
              ),
              Text(
                'Các thiết lập này giúp bảo vệ thông tin cá nhân của bạn trong các hướng cứu hộ và tìm kiếm thú cưng.',
                style: AppTextStyles.body(color: AppColors.primary700),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: AppTextStyles.h4(color: AppColors.textPrimary));
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: AppColors.surfaceContainer),
    ),
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index < children.length - 1)
            const Divider(
              height: 1,
              indent: AppSpacing.s16,
              endIndent: AppSpacing.s16,
            ),
        ],
      ],
    ),
  );
}

class _PrivacySwitch extends StatelessWidget {
  const _PrivacySwitch({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    this.onChanged,
    this.enabled = true,
    this.displayReadOnlyActive = false,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final bool displayReadOnlyActive;

  @override
  Widget build(BuildContext context) {
    final contentPadding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.s16,
      vertical: AppSpacing.s8,
    );
    if (!enabled && displayReadOnlyActive) {
      return Semantics(
        toggled: value,
        enabled: false,
        label: '$title. $description',
        child: ListTile(
          contentPadding: contentPadding,
          minVerticalPadding: AppSpacing.s16,
          title: Text(title, style: AppTextStyles.label()),
          subtitle: Text(description, style: AppTextStyles.caption()),
          trailing: ExcludeSemantics(
            child: IgnorePointer(
              child: Switch.adaptive(value: value, onChanged: (_) {}),
            ),
          ),
        ),
      );
    }
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: '$title. $description',
      child: SwitchListTile.adaptive(
        contentPadding: contentPadding,
        minVerticalPadding: AppSpacing.s16,
        title: Text(title, style: AppTextStyles.label()),
        subtitle: Text(description, style: AppTextStyles.caption()),
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

class _ConsumerPreview extends StatelessWidget {
  const _ConsumerPreview({required this.defaults});

  final PrivacyDefaults defaults;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('privacy-consumer-preview'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('An toàn cộng đồng', style: AppTextStyles.h4()),
      const SizedBox(height: AppSpacing.s12),
      Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.surfaceContainer),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PreviewLine(
              label: 'Tin cứu hộ',
              value: defaults.hideHouseNumber
                  ? 'Ẩn số nhà'
                  : 'Giữ địa chỉ theo lựa chọn',
            ),
            _PreviewLine(
              label: 'Bình luận & chat',
              value: defaults.hidePhoneByDefault
                  ? 'Xác nhận khi có số điện thoại'
                  : 'Cho phép chia sẻ khi cần',
            ),
            _PreviewLine(
              label: 'Ảnh & video',
              value: defaults.reviewMediaBeforePublish
                  ? 'Kiểm tra trước khi gửi'
                  : 'Không yêu cầu bước xác nhận',
            ),
          ],
        ),
      ),
    ],
  );
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, size: 18, color: AppColors.deepGreen),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            '$label: $value',
            style: AppTextStyles.body(color: AppColors.textSecondary),
          ),
        ),
      ],
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

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
        const Icon(Icons.error_outline, color: AppColors.error),
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

String _preferenceError(Object? error) {
  if (error is PreferenceApiException) {
    if (error.statusCode == 401 || error.code == 'AUTH_REQUIRED') {
      return 'Phiên đăng nhập đã hết hạn.';
    }
    if (error.isVersionConflict) {
      return 'Cài đặt đã thay đổi ở thiết bị khác. Hãy tải lại rồi thử lại.';
    }
    if (error.code == 'NETWORK_OFFLINE') {
      return 'Không thể kết nối. Thay đổi trên màn hình vẫn được giữ.';
    }
    return error.message;
  }
  return 'Chưa thể lưu cài đặt. Thay đổi trên màn hình vẫn được giữ.';
}
