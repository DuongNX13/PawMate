import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/app_navigation.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_ui.dart';
import '../../preferences/application/preference_providers.dart';
import '../../preferences/data/preference_api.dart';
import '../../preferences/domain/preference_models.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key, this.timePicker});

  final Future<TimeOfDay?> Function(
    BuildContext context,
    TimeOfDay initialTime,
    String title,
  )?
  timePicker;

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  NotificationPreferences? _draft;
  bool _dirty = false;
  bool _saving = false;
  String? _saveError;

  @override
  Widget build(BuildContext context) {
    final preferencesState = ref.watch(notificationPreferencesProvider);
    final lastSuccessful = ref
        .read(notificationPreferencesProvider.notifier)
        .lastSuccessful;
    final preferences = _draft ?? preferencesState.value ?? lastSuccessful;

    return PawMatePageScaffold(
      topBar: PawMateTopBar(
        title: 'Cài đặt thông báo',
        leading: IconButton(
          tooltip: 'Quay lại',
          color: AppColors.textPrimary,
          onPressed: () =>
              PawMateNavigation.backOrGo(context, '/profile/controls'),
          icon: const BackButtonIcon(),
        ),
      ),
      fixedCtaBar: PawMateFixedCtaBar(
        primaryAction: PawMateAction(
          label: 'Lưu thay đổi',
          semanticLabel: 'Lưu cài đặt thông báo',
          isLoading: _saving,
          onPressed: preferences != null && _dirty && !_saving
              ? () => _save(preferences)
              : null,
        ),
      ),
      body: switch (preferences) {
        null when preferencesState.isLoading => Center(
          child: Semantics(
            label: 'Đang tải cài đặt thông báo',
            liveRegion: true,
            child: const CircularProgressIndicator(),
          ),
        ),
        null => PawMateStateView(
          type: PawMateStateType.error,
          title: 'Chưa tải được cài đặt',
          message: _preferenceError(preferencesState.error),
          primaryActionLabel: 'Thử lại',
          onPrimaryAction: () =>
              ref.invalidate(notificationPreferencesProvider),
        ),
        final value => _PreferencesForm(
          preferences: value,
          isRefreshing: preferencesState.isLoading,
          errorMessage: _saveError,
          onChanged: _updateDraft,
          onPickQuietStart: () => _pickQuietTime(value, isStart: true),
          onPickQuietEnd: () => _pickQuietTime(value, isStart: false),
        ),
      },
    );
  }

  void _updateDraft(NotificationPreferences value) {
    setState(() {
      _draft = value;
      _dirty = true;
      _saveError = null;
    });
  }

  Future<void> _pickQuietTime(
    NotificationPreferences value, {
    required bool isStart,
  }) async {
    final current = _parseTime(
      isStart ? value.quietHoursStart : value.quietHoursEnd,
      fallback: isStart
          ? const TimeOfDay(hour: 22, minute: 0)
          : const TimeOfDay(hour: 7, minute: 0),
    );
    final title = isStart ? 'Chọn giờ bắt đầu' : 'Chọn giờ kết thúc';
    final injectedPicker = widget.timePicker;
    final TimeOfDay? selected;
    if (injectedPicker != null) {
      selected = await injectedPicker(context, current, title);
    } else {
      selected = await showPawMateAdaptiveTimePicker(
        context: context,
        initialTime: current,
        title: title,
      );
    }
    if (selected == null || !mounted) return;
    final formatted = _formatTime(selected);
    final other = isStart ? value.quietHoursEnd : value.quietHoursStart;
    if (formatted == other) {
      setState(() {
        _saveError = 'Giờ bắt đầu và kết thúc phải khác nhau.';
      });
      return;
    }
    _updateDraft(
      value.copyWith(
        quietHoursStart: isStart ? formatted : null,
        quietHoursEnd: isStart ? null : formatted,
      ),
    );
  }

  Future<void> _save(NotificationPreferences value) async {
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final saved = await ref
        .read(notificationPreferencesProvider.notifier)
        .save(value);
    if (!mounted) return;
    if (saved) {
      final authoritative = ref
          .read(notificationPreferencesProvider)
          .requireValue;
      setState(() {
        _draft = authoritative;
        _dirty = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu cài đặt thông báo.')),
      );
      return;
    }
    final error = ref.read(notificationPreferencesProvider).error;
    setState(() {
      _saving = false;
      _saveError = _preferenceError(error);
    });
  }
}

class _PreferencesForm extends StatelessWidget {
  const _PreferencesForm({
    required this.preferences,
    required this.isRefreshing,
    required this.errorMessage,
    required this.onChanged,
    required this.onPickQuietStart,
    required this.onPickQuietEnd,
  });

  final NotificationPreferences preferences;
  final bool isRefreshing;
  final String? errorMessage;
  final ValueChanged<NotificationPreferences> onChanged;
  final VoidCallback onPickQuietStart;
  final VoidCallback onPickQuietEnd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('notification-preferences-scroll'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s32,
      ),
      children: [
        const _PermissionInfoCard(),
        if (isRefreshing) ...[
          const SizedBox(height: AppSpacing.s12),
          const LinearProgressIndicator(
            semanticsLabel: 'Đang lưu cài đặt thông báo',
          ),
        ],
        if (errorMessage != null) ...[
          const SizedBox(height: AppSpacing.s12),
          _InlineError(message: errorMessage!),
        ],
        const SizedBox(height: AppSpacing.s24),
        const _GroupTitle('CỨU HỘ & CỘNG ĐỒNG'),
        const SizedBox(height: AppSpacing.s12),
        _PreferenceGroup(
          children: [
            _PreferenceCheckbox(
              key: const Key('preference-nearby-lost-cases'),
              minHeight: 92,
              title: 'Tin báo cứu hộ gần đây',
              description:
                  'Cập nhật các trường hợp thú cưng bị lạc gần vị trí của bạn.',
              value: preferences.nearbyLostCases,
              onChanged: (value) =>
                  onChanged(preferences.copyWith(nearbyLostCases: value)),
            ),
            _PreferenceCheckbox(
              key: const Key('preference-chat-messages'),
              minHeight: 92,
              title: 'Bình luận và tin nhắn',
              description:
                  'Thông báo khi có người gửi bình luận hoặc tin nhắn mới.',
              value: preferences.chatMessages,
              onChanged: (value) =>
                  onChanged(preferences.copyWith(chatMessages: value)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        const _GroupTitle('CÁ NHÂN & NHẬN NUÔI'),
        const SizedBox(height: AppSpacing.s12),
        _PreferenceGroup(
          children: [
            _PreferenceCheckbox(
              key: const Key('preference-adoption-updates'),
              title: 'Cập nhật nhận nuôi',
              description: 'Tiến trình hồ sơ và thông tin từ trạm cứu hộ.',
              value: preferences.adoptionUpdates,
              onChanged: (value) =>
                  onChanged(preferences.copyWith(adoptionUpdates: value)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        const _GroupTitle('TÙY CHỌN KHÁC'),
        const SizedBox(height: AppSpacing.s12),
        _PreferenceGroup(
          children: [
            _PreferenceCheckbox(
              key: const Key('preference-quiet-hours'),
              title: 'Giờ yên tĩnh',
              description:
                  'Tạm dừng thông báo trong khoảng thời gian nghỉ ngơi.',
              value: preferences.quietHoursEnabled,
              onChanged: (value) {
                onChanged(
                  value
                      ? preferences.copyWith(
                          quietHoursEnabled: true,
                          quietHoursStart:
                              preferences.quietHoursStart ?? '22:00',
                          quietHoursEnd: preferences.quietHoursEnd ?? '07:00',
                        )
                      : preferences.copyWith(
                          quietHoursEnabled: false,
                          clearQuietHours: true,
                        ),
                );
              },
            ),
            if (preferences.quietHoursEnabled)
              _QuietHoursRange(
                start: preferences.quietHoursStart ?? '22:00',
                end: preferences.quietHoursEnd ?? '07:00',
                onPickStart: onPickQuietStart,
                onPickEnd: onPickQuietEnd,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s24),
        const _QuietHoursIllustration(),
      ],
    );
  }
}

class _PermissionInfoCard extends StatelessWidget {
  const _PermissionInfoCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Thông tin quyền hệ thống. Để nhận thông báo, hãy cấp quyền thông báo cho PawMate trong cài đặt điện thoại.',
      child: PawMateCard(
        backgroundColor: AppColors.mint,
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ExcludeSemantics(
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary500,
                child: Icon(Icons.info_outline, color: AppColors.white),
              ),
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  'Để nhận được thông báo, vui lòng đảm bảo bạn đã cấp quyền '
                  'thông báo cho PawMate trong cài đặt hệ thống của điện thoại.',
                  style: AppTextStyles.body(color: AppColors.primary700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final status = PawMateStatusColors.of(context);
    return Semantics(
      liveRegion: true,
      label: 'Lỗi lưu cài đặt. $message',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: status.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: status.error),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.captionStrong(color: status.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.overline(color: AppColors.textMuted),
    );
  }
}

class _PreferenceGroup extends StatelessWidget {
  const _PreferenceGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PawMateCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _PreferenceCheckbox extends StatelessWidget {
  const _PreferenceCheckbox({
    super.key,
    this.minHeight = AppControlSize.minTouchTarget,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final double minHeight;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s12,
              AppSpacing.s8,
              AppSpacing.s12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.label()),
                      const SizedBox(height: AppSpacing.s4),
                      Text(description, style: AppTextStyles.caption()),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Checkbox(
                  value: value,
                  semanticLabel: title,
                  onChanged: (next) => onChanged(next ?? !value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuietHoursRange extends StatelessWidget {
  const _QuietHoursRange({
    required this.start,
    required this.end,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final String start;
  final String end;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        0,
        AppSpacing.s16,
        AppSpacing.s16,
      ),
      padding: const EdgeInsets.all(AppSpacing.s8),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TimeButton(
              key: const Key('quiet-hours-start'),
              label: 'BẮT ĐẦU',
              value: start,
              onPressed: onPickStart,
            ),
          ),
          const SizedBox(
            height: 36,
            child: VerticalDivider(color: AppColors.border),
          ),
          Expanded(
            child: _TimeButton(
              key: const Key('quiet-hours-end'),
              label: 'KẾT THÚC',
              value: end,
              onPressed: onPickEnd,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    super.key,
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label $value',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppControlSize.minTouchTarget,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Text(label, style: AppTextStyles.micro()),
              ),
              const SizedBox(height: AppSpacing.s4),
              ExcludeSemantics(
                child: Text(
                  value,
                  style: AppTextStyles.h4(color: AppColors.primary500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuietHoursIllustration extends StatelessWidget {
  const _QuietHoursIllustration();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Thú cưng nghỉ ngơi yên tĩnh',
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.surfaceContainer, AppColors.primaryAccent],
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Row(
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.bedtime_outlined,
                size: 42,
                color: AppColors.primary700,
              ),
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  'Đảm bảo giấc ngủ ngon cho thú cưng',
                  style: AppTextStyles.label(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TimeOfDay _parseTime(String? value, {required TimeOfDay fallback}) {
  final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value ?? '');
  if (match == null) return fallback;
  return TimeOfDay(
    hour: int.parse(match.group(1)!),
    minute: int.parse(match.group(2)!),
  );
}

String _formatTime(TimeOfDay value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

String _preferenceError(Object? error) {
  if (error is PreferenceApiException) return error.message;
  return 'Không thể tải hoặc lưu cài đặt. Vui lòng thử lại.';
}
