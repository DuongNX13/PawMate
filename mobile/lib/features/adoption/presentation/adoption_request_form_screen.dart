import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_fixed_cta_bar.dart';
import '../../../core/widgets/pawmate_page_scaffold.dart';
import '../../../core/widgets/pawmate_state_view.dart';
import '../../../core/widgets/pawmate_text_field.dart';
import '../../../core/widgets/pawmate_top_bar.dart';
import '../application/adoption_request_provider.dart';
import '../domain/adoption_models.dart';
import 'widgets/adoption_media_frame.dart';

class AdoptionRequestFormScreen extends ConsumerStatefulWidget {
  const AdoptionRequestFormScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<AdoptionRequestFormScreen> createState() =>
      _AdoptionRequestFormScreenState();
}

class _AdoptionRequestFormScreenState
    extends ConsumerState<AdoptionRequestFormScreen> {
  late final TextEditingController _carePlanController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _carePlanController = TextEditingController();
    _noteController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncControllers(ref.read(adoptionRequestProvider(widget.listingId)));
      }
    });
  }

  @override
  void dispose() {
    _carePlanController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;
    final state = ref.watch(adoptionRequestProvider(widget.listingId));
    _syncControllers(state);
    final notifier = ref.read(
      adoptionRequestProvider(widget.listingId).notifier,
    );
    final listing = state.listing;
    final requestAllowed =
        listing != null &&
        listing.status.isAvailable &&
        listing.viewerPermissions.canRequest;

    return PawMatePageScaffold(
      key: const Key('adoption-request-screen'),
      backgroundColor: AppColors.background,
      topBar: PawMateTopBar(
        title: usesExpandedTextLayout ? 'Nhận nuôi' : 'Yêu cầu nhận nuôi',
        semanticTitle: 'Yêu cầu nhận nuôi',
        showBackButton: true,
        leadingWidth: 48,
        titleSpacing: 0,
        onBack: () => _back(context),
      ),
      fixedCtaBar: state.listing == null || state.result != null
          ? null
          : PawMateFixedCtaBar(
              key: const Key('adoption-request-submit-cta'),
              primaryAction: PawMateAction(
                label: state.errorMessage != null && state.canSubmit
                    ? 'Gửi lại yêu cầu'
                    : 'Gửi yêu cầu',
                trailingIcon: Icons.arrow_forward_rounded,
                isLoading: state.isSubmitting,
                onPressed: state.isSubmitting || !requestAllowed
                    ? null
                    : notifier.submit,
                semanticLabel: state.errorMessage != null && state.canSubmit
                    ? 'Gửi lại yêu cầu nhận nuôi'
                    : 'Gửi yêu cầu nhận nuôi',
              ),
            ),
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AdoptionRequestState state,
    AdoptionRequestNotifier notifier,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.result case final result?) {
      return PawMateStateView(
        key: const Key('adoption-request-submitted'),
        type: PawMateStateType.success,
        icon: Icons.mark_email_read_outlined,
        title: 'Đã gửi yêu cầu',
        message:
            'Mái ấm sẽ xem xét thông tin của bạn. Bạn có thể trao đổi thêm trong cuộc trò chuyện riêng.',
        primaryActionLabel: 'Mở cuộc trò chuyện',
        onPrimaryAction: () =>
            context.push('/adoption/chat/${result.threadId}'),
        secondaryActionLabel: 'Xem đơn của tôi',
        onSecondaryAction: () => context.go('/adoption/requests'),
      );
    }
    if (state.listing == null) {
      return PawMateStateView(
        key: const Key('adoption-request-error'),
        type: state.errorMessage?.contains('kết nối') == true
            ? PawMateStateType.offline
            : PawMateStateType.error,
        title: 'Chưa mở được biểu mẫu',
        message: state.errorMessage ?? 'Vui lòng thử lại sau.',
        primaryActionLabel: 'Thử lại',
        onPrimaryAction: notifier.load,
        secondaryActionLabel: 'Quay lại',
        onSecondaryAction: () => _back(context),
      );
    }

    final listing = state.listing!;
    final canRequest =
        listing.status.isAvailable && listing.viewerPermissions.canRequest;
    return ListView(
      key: const Key('adoption-request-form'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s32 + AppControlSize.fixedCtaBarMinHeight,
      ),
      children: [
        _ListingSummary(listing: listing),
        if (!canRequest) ...[
          const SizedBox(height: AppSpacing.s16),
          _Notice(
            icon: Icons.info_outline,
            message: listing.status.isAvailable
                ? 'Tài khoản này chưa được phép gửi yêu cầu cho tin này.'
                : 'Tin này hiện không nhận thêm yêu cầu.',
          ),
        ],
        const SizedBox(height: AppSpacing.s12),
        _HousingPicker(
          key: const Key('adoption-request-living-condition-field'),
          value: _housingValue(state.draft.livingCondition),
          enabled: canRequest,
          errorText:
              state.showValidation && state.draft.livingCondition.trim().isEmpty
              ? 'Vui lòng mô tả môi trường sống.'
              : null,
          onChanged: notifier.setLivingCondition,
        ),
        const SizedBox(height: AppSpacing.s16),
        _ExperiencePicker(
          key: const Key('adoption-request-pet-experience-field'),
          value: _experienceValue(state.draft.petExperience),
          enabled: canRequest,
          showValidation: state.showValidation,
          onChanged: notifier.setPetExperience,
        ),
        const SizedBox(height: AppSpacing.s16),
        PawMateTextField(
          key: const Key('adoption-request-care-plan-field'),
          label: 'Người chăm sóc chính',
          controller: _carePlanController,
          hintText: 'Họ và tên...',
          maxLines: 1,
          maxLength: 500,
          counterText: '',
          isRequired: true,
          errorText: _errorFor(
            state,
            _carePlanController.text,
            'Vui lòng nhập tên người chăm sóc.',
          ),
          onChanged: notifier.setCarePlan,
        ),
        const SizedBox(height: AppSpacing.s16),
        PawMateTextField(
          key: const Key('adoption-request-note-field'),
          label: 'Thời gian dành cho bé hằng ngày',
          controller: _noteController,
          hintText: 'Mô tả ngắn gọn...',
          maxLines: 2,
          minLines: 2,
          maxLength: 1000,
          counterText: '',
          onChanged: notifier.setNote,
        ),
        const SizedBox(height: AppSpacing.s12),
        Semantics(
          container: true,
          child: InkWell(
            key: const Key('adoption-request-consent'),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: canRequest
                ? () => notifier.setCommitmentAccepted(
                    !state.draft.commitmentAccepted,
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox.square(
                    dimension: AppControlSize.minTouchTarget,
                    child: Checkbox(
                      value: state.draft.commitmentAccepted,
                      onChanged: canRequest
                          ? (value) =>
                                notifier.setCommitmentAccepted(value == true)
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.s8),
                      child: Text(
                        'Tôi cam kết cung cấp thông tin trung thực và sẵn sàng cho các cuộc phỏng vấn liên quan.',
                        style: AppTextStyles.bodyCompact(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (state.showValidation && !state.draft.commitmentAccepted)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.s12),
            child: Text(
              'Bạn cần xác nhận cam kết trước khi gửi.',
              style: AppTextStyles.caption(color: AppColors.error),
            ),
          ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.s12),
          _Notice(
            icon: state.duplicateActive
                ? Icons.info_outline
                : Icons.error_outline,
            message: state.errorMessage!,
            color: state.duplicateActive ? AppColors.brown : AppColors.error,
          ),
        ],
        if (state.draftPersistenceWarning != null) ...[
          const SizedBox(height: AppSpacing.s8),
          _Notice(
            icon: Icons.save_outlined,
            message: state.draftPersistenceWarning!,
            color: AppColors.brown,
          ),
        ],
      ],
    );
  }

  String? _errorFor(
    AdoptionRequestState state,
    String value,
    String emptyMessage,
  ) {
    if (!state.showValidation) return null;
    if (value.trim().isEmpty) return emptyMessage;
    if (value.trim().length > 500) return 'Không được vượt quá 500 ký tự.';
    return null;
  }

  void _syncControllers(AdoptionRequestState state) {
    final draft = state.draft;
    _setIfIdle(_carePlanController, draft.carePlan);
    _setIfIdle(_noteController, draft.note);
  }

  static String? _housingValue(String value) {
    final normalized = value.trim();
    return _HousingPicker.options.contains(normalized) ? normalized : null;
  }

  static String? _experienceValue(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    if (normalized == _ExperiencePicker.firstTime) return normalized;
    return _ExperiencePicker.experienced;
  }

  static void _setIfIdle(TextEditingController controller, String value) {
    if (controller.selection.isValid && !controller.selection.isCollapsed) {
      return;
    }
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  static void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/adoption');
    }
  }
}

class _HousingPicker extends StatelessWidget {
  const _HousingPicker({
    super.key,
    required this.value,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
  });

  static const options = <String>[
    'Căn hộ',
    'Nhà riêng',
    'Nhà có sân vườn',
    'Khác',
  ];

  final String? value;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Loại hình cư trú, bắt buộc',
      value: value ?? 'Chưa chọn',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RequiredLabel('Loại hình cư trú'),
          const SizedBox(height: AppSpacing.s8),
          Container(
            constraints: const BoxConstraints(
              minHeight: AppControlSize.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: errorText == null
                  ? null
                  : Border.all(color: AppColors.error),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.brown,
                ),
                hint: Text('Chọn loại hình', style: AppTextStyles.field()),
                style: AppTextStyles.field(),
                dropdownColor: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                onChanged: enabled
                    ? (next) {
                        if (next != null) onChanged(next);
                      }
                    : null,
                items: [
                  for (final option in options)
                    DropdownMenuItem(value: option, child: Text(option)),
                ],
              ),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: AppSpacing.s4),
            _ValidationText(errorText!),
          ],
        ],
      ),
    );
  }
}

class _ExperiencePicker extends StatelessWidget {
  const _ExperiencePicker({
    super.key,
    required this.value,
    required this.enabled,
    required this.showValidation,
    required this.onChanged,
  });

  static const firstTime = 'Lần đầu';
  static const experienced = 'Đã có kinh nghiệm';

  final String? value;
  final bool enabled;
  final bool showValidation;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [
      _ExperienceOption(
        label: firstTime,
        selected: value == firstTime,
        enabled: enabled,
        onTap: () => onChanged(firstTime),
      ),
      _ExperienceOption(
        label: experienced,
        selected: value == experienced,
        enabled: enabled,
        onTap: () => onChanged(experienced),
      ),
    ];
    final stack = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    return Semantics(
      container: true,
      label: 'Kinh nghiệm nuôi thú cưng, bắt buộc',
      value: value ?? 'Chưa chọn',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RequiredLabel('Kinh nghiệm nuôi thú cưng'),
          const SizedBox(height: AppSpacing.s8),
          if (stack)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                options.first,
                const SizedBox(height: AppSpacing.s8),
                options.last,
              ],
            )
          else
            Row(
              children: [
                Expanded(child: options.first),
                const SizedBox(width: AppSpacing.s8),
                Expanded(child: options.last),
              ],
            ),
          if (showValidation && value == null) ...[
            const SizedBox(height: AppSpacing.s4),
            const _ValidationText('Vui lòng chia sẻ kinh nghiệm của bạn.'),
          ],
        ],
      ),
    );
  }
}

class _ExperienceOption extends StatelessWidget {
  const _ExperienceOption({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled
        ? AppColors.primary700
        : PawMateStatusColors.of(context).disabledContent;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      child: Material(
        color: selected ? AppColors.surfaceContainer : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppControlSize.minTouchTarget,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: AppSpacing.s8,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.label(color: foreground),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: label,
      children: const [
        TextSpan(
          text: ' *',
          style: TextStyle(color: AppColors.error),
        ),
      ],
    ),
    style: AppTextStyles.label(),
  );
}

class _ValidationText extends StatelessWidget {
  const _ValidationText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) =>
      Text(message, style: AppTextStyles.caption(color: AppColors.error));
}

class _ListingSummary extends StatelessWidget {
  const _ListingSummary({required this.listing});

  final AdoptionListingDetail listing;

  @override
  Widget build(BuildContext context) {
    final stackIdentity = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final status = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        listing.status.label,
        maxLines: 1,
        style: AppTextStyles.captionStrong(color: AppColors.primary700),
      ),
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: AdoptionMediaFrame(
              media: listing.heroMedia,
              petName: listing.petName,
              species: listing.species,
              borderRadius: BorderRadius.circular(AppRadius.md),
              imageProvider: listing.heroMedia.publicUrl == null
                  ? const AssetImage(
                      'assets/images/pets/home_adoption_golden.png',
                    )
                  : null,
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stackIdentity) ...[
                  Text(
                    listing.petName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h4(),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Align(alignment: Alignment.centerLeft, child: status),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          listing.petName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.h4(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      status,
                    ],
                  ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  [
                    listing.breed ?? listing.species.label,
                    listing.ageLabel,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyCompact(
                    color: AppColors.textSecondary,
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

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.message,
    this.color = AppColors.error,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    container: true,
    label: message,
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyCompact(color: color),
            ),
          ),
        ],
      ),
    ),
  );
}
