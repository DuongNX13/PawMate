import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/media/image_picker_service.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_card.dart';
import '../../../core/widgets/pawmate_fixed_cta_bar.dart';
import '../../../core/widgets/pawmate_page_scaffold.dart';
import '../../../core/widgets/pawmate_text_field.dart';
import '../../../core/widgets/pawmate_top_bar.dart';
import '../../../core/widgets/pawmate_upload_tile.dart';
import '../application/rescue_create_provider.dart';
import '../domain/rescue_draft_models.dart';

class RescueCreateScreen extends ConsumerStatefulWidget {
  const RescueCreateScreen({super.key});

  @override
  ConsumerState<RescueCreateScreen> createState() => _RescueCreateScreenState();
}

class _RescueCreateScreenState extends ConsumerState<RescueCreateScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _breedController;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(rescueCreateProvider).draft;
    _nameController = TextEditingController(text: draft.petName)
      ..addListener(
        () => ref
            .read(rescueCreateProvider.notifier)
            .setPetName(_nameController.text),
      );
    _breedController = TextEditingController(text: draft.breedOrColor)
      ..addListener(
        () => ref
            .read(rescueCreateProvider.notifier)
            .setBreedOrColor(_breedController.text),
      );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rescueCreateProvider);
    final notifier = ref.read(rescueCreateProvider.notifier);
    final draft = state.draft;
    final firstMedia = draft.media.isEmpty ? null : draft.media.first;

    return PawMatePageScaffold(
      topBar: PawMateTopBar(
        title: 'Tạo tin báo mất',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      fixedCtaBar: PawMateFixedCtaBar(
        key: const Key('rescue-create-continue-cta'),
        primaryAction: PawMateAction(
          label: 'Tiếp tục',
          onPressed: state.isBusy
              ? null
              : () async {
                  if (await notifier.continueToDetails() && context.mounted) {
                    context.push('/rescue/create/details');
                  }
                },
          isLoading: state.isBusy,
          trailingIcon: Icons.arrow_forward_rounded,
          semanticLabel: 'Tiếp tục sang thông tin chi tiết',
        ),
      ),
      body: ListView(
        key: const Key('rescue-create-form'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s8,
          AppSpacing.s16,
          AppSpacing.s32,
        ),
        children: [
          const _FormIntro(
            eyebrow: 'BƯỚC 1/2',
            title: 'Giúp mọi người nhận ra bé',
            message:
                'Thêm thông tin rõ ràng để người nhìn thấy có thể liên hệ an toàn.',
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.s16),
            _FormError(message: state.errorMessage!),
          ],
          const SizedBox(height: AppSpacing.s24),
          Text('Ảnh thú cưng', style: AppTextStyles.h4()),
          const SizedBox(height: AppSpacing.s8),
          PawMateUploadTile(
            key: const Key('rescue-create-media-upload'),
            label: firstMedia == null ? 'Thêm ảnh đầu tiên' : 'Ảnh thú cưng',
            acceptedMediaLabel: 'JPEG, PNG, WebP ≤10 MB · MP4 ≤50 MB',
            state: firstMedia == null
                ? PawMateUploadState.empty
                : PawMateUploadState.uploaded,
            preview: firstMedia == null
                ? null
                : _LocalMediaPreview(path: firstMedia.path),
            onPick: () => _showMediaPicker(context, notifier),
            onRemove: firstMedia == null
                ? null
                : () => notifier.removeMedia(firstMedia),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            '${draft.media.length}/5 tệp · Ảnh sẽ được kiểm tra trước khi đăng',
            style: AppTextStyles.caption(),
          ),
          const SizedBox(height: AppSpacing.s24),
          PawMateTextField(
            key: const Key('rescue-create-pet-name-field'),
            label: 'Tên thú cưng',
            controller: _nameController,
            hintText: 'Ví dụ: Mochi',
            isRequired: true,
            textInputAction: TextInputAction.next,
            maxLength: 50,
          ),
          const SizedBox(height: AppSpacing.s16),
          Text('Loài', style: AppTextStyles.label()),
          const SizedBox(height: AppSpacing.s8),
          _SpeciesSelector(
            value: draft.species,
            onChanged: notifier.setSpecies,
          ),
          const SizedBox(height: AppSpacing.s16),
          PawMateTextField(
            key: const Key('rescue-create-breed-field'),
            label: 'Giống / màu lông',
            controller: _breedController,
            hintText: 'Ví dụ: Poodle, trắng kem',
            isRequired: true,
            textInputAction: TextInputAction.done,
            maxLength: 100,
          ),
          const SizedBox(height: AppSpacing.s24),
          Text('Khu vực và thời gian thất lạc', style: AppTextStyles.h4()),
          const SizedBox(height: AppSpacing.s8),
          _LocationCard(
            location: draft.exactLocation,
            onTap: () => _pickLocation(context, notifier),
          ),
          const SizedBox(height: AppSpacing.s12),
          _LostAtField(
            value: draft.lostAt,
            onTap: () => _pickLostAt(context, notifier),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLostAt(
    BuildContext context,
    RescueCreateNotifier notifier,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      initialDate: notifier.draft.lostAt ?? now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: AppColors.deepGreen),
        ),
        child: child!,
      ),
    );
    if (!context.mounted || picked == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        notifier.draft.lostAt ?? DateTime.now(),
      ),
    );
    if (!context.mounted || time == null) return;
    notifier.setLostAt(
      DateTime(picked.year, picked.month, picked.day, time.hour, time.minute),
    );
  }

  Future<void> _showMediaPicker(
    BuildContext context,
    RescueCreateNotifier notifier,
  ) async {
    final choice = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn ảnh'),
              onTap: () => Navigator.pop(context, false),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Chọn video MP4'),
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    final picker = ref.read(imagePickerProvider);
    if (choice == true) {
      await notifier.pickVideo(picker);
    } else if (choice == false) {
      await notifier.pickMedia(picker);
    }
  }

  Future<void> _pickLocation(
    BuildContext context,
    RescueCreateNotifier notifier,
  ) async {
    final location = await showModalBottomSheet<RescueDraftLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => const _LocationPickerSheet(),
    );
    if (location != null) notifier.setLocation(location);
  }
}

class _FormIntro extends StatelessWidget {
  const _FormIntro({
    required this.eyebrow,
    required this.title,
    required this.message,
  });

  final String eyebrow;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: AppTextStyles.caption(
          color: AppColors.deepGreen,
        ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8),
      ),
      const SizedBox(height: AppSpacing.s8),
      Text(title, style: AppTextStyles.pageTitle()),
      const SizedBox(height: AppSpacing.s4),
      Text(message, style: AppTextStyles.body(color: AppColors.textSecondary)),
    ],
  );
}

class _FormError extends StatelessWidget {
  const _FormError({required this.message});

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

class _SpeciesSelector extends StatelessWidget {
  const _SpeciesSelector({required this.value, required this.onChanged});

  final RescueDraftSpecies value;
  final ValueChanged<RescueDraftSpecies> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.s8,
    runSpacing: AppSpacing.s8,
    children: [
      for (final species in RescueDraftSpecies.values)
        Semantics(
          selected: value == species,
          button: true,
          label: species.label,
          child: ChoiceChip(
            label: Text(species.label),
            selected: value == species,
            onSelected: (_) => onChanged(species),
            selectedColor: AppColors.mint,
            labelStyle: AppTextStyles.label(
              color: value == species ? AppColors.deepGreen : AppColors.brown,
            ),
          ),
        ),
    ],
  );
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.location, required this.onTap});

  final RescueDraftLocation? location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PawMateCard(
    key: const Key('rescue-create-location-card'),
    onTap: onTap,
    padding: const EdgeInsets.all(AppSpacing.s12),
    child: Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.location_on_outlined,
            color: AppColors.deepGreen,
            size: 32,
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                location == null ? 'Chọn trên bản đồ' : 'Đã chọn khu vực',
                style: AppTextStyles.label(),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                location?.formattedAddress ??
                    'Vị trí chính xác chỉ dùng cho người tạo tin',
                style: AppTextStyles.bodyCompact(),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.brown),
      ],
    ),
  );
}

class _LostAtField extends StatelessWidget {
  const _LostAtField({required this.value, required this.onTap});

  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: const Key('rescue-create-lost-at-field'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: InputDecorator(
      decoration: const InputDecoration(labelText: 'Thời gian thất lạc *'),
      child: Row(
        children: [
          const Icon(Icons.schedule_outlined, color: AppColors.deepGreen),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              value == null ? 'Chọn giờ và ngày' : _formatDateTime(value!),
              style: AppTextStyles.field(
                color: value == null
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
              ),
            ),
          ),
          const Icon(Icons.edit_calendar_outlined, color: AppColors.brown),
        ],
      ),
    ),
  );
}

class _LocationPickerSheet extends StatelessWidget {
  const _LocationPickerSheet();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Chọn khu vực thất lạc', style: AppTextStyles.h3()),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'PawMate chỉ hiển thị khu vực ước tính cho cộng đồng. Vị trí chính xác được giữ riêng trong bản nháp của bạn.',
            style: AppTextStyles.body(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s16),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.map_outlined,
              size: 56,
              color: AppColors.deepGreen,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          PawMateButton(
            label: 'Dùng khu vực hiện tại',
            onPressed: () => Navigator.pop(
              context,
              const RescueDraftLocation(
                latitude: 10.7769,
                longitude: 106.7009,
                formattedAddress: 'Khu vực Quận 1, TP. Hồ Chí Minh',
              ),
            ),
            trailingIcon: Icons.check_rounded,
          ),
        ],
      ),
    ),
  );
}

class _LocalMediaPreview extends StatelessWidget {
  const _LocalMediaPreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    child: Image.asset(
      'assets/images/pets/pet-golden.png',
      height: 120,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        height: 120,
        color: AppColors.surfaceContainer,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, size: 40),
      ),
    ),
  );
}

String _formatDateTime(DateTime value) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)} ${two(value.day)}/${two(value.month)}/${value.year}';
}
