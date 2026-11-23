import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/media/image_picker_service.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_fixed_cta_bar.dart';
import '../../../core/widgets/pawmate_page_scaffold.dart';
import '../../../core/widgets/pawmate_text_field.dart';
import '../../../core/widgets/pawmate_top_bar.dart';
import '../../preferences/application/preference_providers.dart';
import '../../preferences/application/privacy_surface_policy.dart';
import '../application/rescue_create_provider.dart';
import '../domain/rescue_draft_models.dart';
import 'rescue_location_picker_sheet.dart';

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
    final draft = state.draft;

    return PawMatePageScaffold(
      topBar: PawMateTopBar(
        title: usesExpandedTextLayout ? 'Tạo tin' : 'Tạo tin báo mất',
        semanticTitle: 'Tạo tin báo mất',
        showBackButton: true,
        centerTitle: true,
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
          0,
          AppSpacing.s16,
          AppSpacing.s32,
        ),
        children: [
          if (state.errorMessage != null) ...[
            _FormError(message: state.errorMessage!),
            const SizedBox(height: AppSpacing.s16),
          ],
          _MediaSection(
            media: draft.media,
            onAdd: () => _showMediaPicker(context, notifier),
            onRemove: notifier.removeMedia,
          ),
          const SizedBox(height: AppSpacing.s32),
          PawMateTextField(
            key: const Key('rescue-create-pet-name-field'),
            label: 'Tên thú cưng',
            controller: _nameController,
            hintText: 'VD: Mochi',
            isRequired: true,
            showRequiredIndicator: false,
            textInputAction: TextInputAction.next,
            maxLength: 50,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s16,
            ),
          ),
          const SizedBox(height: 20),
          Text('Loài', style: AppTextStyles.label()),
          const SizedBox(height: AppSpacing.s8),
          _SpeciesSelector(
            value: draft.species,
            onChanged: notifier.setSpecies,
          ),
          const SizedBox(height: 20),
          PawMateTextField(
            key: const Key('rescue-create-breed-field'),
            label: 'Giống / màu lông',
            controller: _breedController,
            hintText: 'VD: Poodle, trắng kem',
            isRequired: true,
            showRequiredIndicator: false,
            textInputAction: TextInputAction.done,
            maxLength: 100,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s16,
            ),
          ),
          const SizedBox(height: 20),
          Text('Khu vực mất', style: AppTextStyles.label()),
          const SizedBox(height: AppSpacing.s8),
          _LocationCard(
            location: draft.exactLocation,
            onTap: () => _pickLocation(context, notifier),
          ),
          const SizedBox(height: AppSpacing.s24),
          _LostAtField(
            value: draft.lostAt,
            onTap: () => _pickLostAt(context, notifier),
          ),
          const SizedBox(height: AppSpacing.s16),
          _PrivacyDefaultsNotice(
            hideHouseNumber: state.hideHouseNumber,
            isFallback: privacyDefaults == null,
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
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (context) => RescueLocationPickerSheet(
        initialLocation: notifier.draft.exactLocation,
      ),
    );
    if (mounted && location != null) notifier.setLocation(location);
  }
}

class _PrivacyDefaultsNotice extends StatelessWidget {
  const _PrivacyDefaultsNotice({
    required this.hideHouseNumber,
    required this.isFallback,
  });

  final bool hideHouseNumber;
  final bool isFallback;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: isFallback,
    label:
        'Quyền riêng tư đang áp dụng. Vị trí chính xác chỉ lưu riêng cho chủ tin. Cộng đồng chỉ thấy khu vực ước tính. Ảnh và video luôn được loại bỏ metadata vị trí.',
    child: ExcludeSemantics(
      child: Container(
        key: const Key('rescue-create-privacy-defaults'),
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.shield_outlined,
              color: AppColors.deepGreen,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                '${hideHouseNumber ? 'Ưu tiên ẩn số nhà trong bản xem trước.' : 'Địa chỉ gợi nhớ chỉ được lưu ở vùng riêng tư của chủ tin.'} '
                'Cộng đồng luôn chỉ thấy khu vực ước tính. '
                'Metadata vị trí trong ảnh/video luôn được loại bỏ.'
                '${isFallback ? ' Đang dùng mức bảo vệ an toàn trong lúc tải cài đặt.' : ''}',
                style: AppTextStyles.caption(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MediaSection extends StatelessWidget {
  const _MediaSection({
    required this.media,
    required this.onAdd,
    required this.onRemove,
  });

  final List<RescueDraftMedia> media;
  final VoidCallback onAdd;
  final ValueChanged<RescueDraftMedia> onRemove;

  @override
  Widget build(BuildContext context) {
    final canAdd = media.length < RescueMediaPolicy.maxItems;
    return Semantics(
      container: true,
      label:
          'Ảnh hoặc video, ${media.length} trên ${RescueMediaPolicy.maxItems} tệp',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Ảnh/Video', style: AppTextStyles.h4())),
              PawMateButton(
                label: 'Tải lên',
                onPressed: canAdd ? onAdd : null,
                leadingIcon: Icons.add_a_photo_outlined,
                fullWidth: false,
                compact: true,
                semanticLabel: canAdd
                    ? 'Tải ảnh hoặc video lên'
                    : 'Đã đủ 5 ảnh hoặc video',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: media.length + (canAdd ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s12),
              itemBuilder: (context, index) {
                if (index == media.length) {
                  return _AddMediaTile(onTap: onAdd);
                }
                final item = media[index];
                return _MediaPreviewTile(
                  key: ValueKey('rescue-create-media-preview-$index'),
                  media: item,
                  onRemove: () => onRemove(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMediaTile extends StatelessWidget {
  const _AddMediaTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconOnly = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Semantics(
      button: true,
      label: 'Thêm ảnh hoặc video',
      onTap: onTap,
      child: Material(
        key: const Key('rescue-create-media-upload'),
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: SizedBox.square(
            dimension: 112,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.brown,
                  size: 28,
                ),
                if (!iconOnly) ...[
                  const SizedBox(height: AppSpacing.s8),
                  Text('Ảnh/Video', style: AppTextStyles.caption()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaPreviewTile extends StatelessWidget {
  const _MediaPreviewTile({
    super.key,
    required this.media,
    required this.onRemove,
  });

  final RescueDraftMedia media;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final embeddedRemoveControl = media.path.startsWith('asset:');
    return SizedBox.square(
      dimension: 112,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: media.mimeType == 'video/mp4'
                ? const ColoredBox(
                    color: AppColors.surfaceContainer,
                    child: Icon(
                      Icons.play_circle_outline_rounded,
                      color: AppColors.deepGreen,
                      size: 42,
                    ),
                  )
                : _DraftImage(path: media.path),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Semantics(
              button: true,
              label: 'Xóa ảnh hoặc video',
              onTap: onRemove,
              child: ExcludeSemantics(
                child: SizedBox.square(
                  dimension: AppControlSize.minTouchTarget,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onRemove,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: embeddedRemoveControl
                          ? const SizedBox.expand()
                          : Align(
                              alignment: Alignment.topRight,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: const BoxDecoration(
                                  color: AppColors.scrim,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftImage extends StatelessWidget {
  const _DraftImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext context, Object error, StackTrace? stack) =>
        const ColoredBox(
          color: AppColors.surfaceContainer,
          child: Icon(
            Icons.broken_image_outlined,
            color: AppColors.deepGreen,
            size: 36,
          ),
        );
    final image = path.startsWith('asset:')
        ? Image.asset(
            path.substring('asset:'.length),
            fit: BoxFit.cover,
            errorBuilder: fallback,
          )
        : Image.file(File(path), fit: BoxFit.cover, errorBuilder: fallback);
    return image;
  }
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
  Widget build(BuildContext context) => Row(
    children: [
      for (
        var index = 0;
        index < RescueDraftSpecies.values.length;
        index++
      ) ...[
        if (index > 0) const SizedBox(width: AppSpacing.s8),
        Expanded(
          flex: value == RescueDraftSpecies.values[index] ? 2 : 1,
          child: _SpeciesOption(
            species: RescueDraftSpecies.values[index],
            selected: value == RescueDraftSpecies.values[index],
            onTap: () => onChanged(RescueDraftSpecies.values[index]),
          ),
        ),
      ],
    ],
  );
}

class _SpeciesOption extends StatelessWidget {
  const _SpeciesOption({
    required this.species,
    required this.selected,
    required this.onTap,
  });

  final RescueDraftSpecies species;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: species.label,
    onTap: onTap,
    child: Material(
      color: selected ? AppColors.deepGreen : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.deepGreen : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: SizedBox(
          height: AppControlSize.minTouchTarget,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.pets_rounded,
                size: 20,
                color: selected ? AppColors.white : AppColors.deepGreen,
              ),
              const SizedBox(width: AppSpacing.s8),
              Flexible(
                child: Text(
                  species.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label(
                    color: selected ? AppColors.white : AppColors.brown,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.location, required this.onTap});

  final RescueDraftLocation? location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: location == null
        ? 'Chọn khu vực mất trên bản đồ'
        : 'Đã chọn ${location!.formattedAddress ?? 'khu vực mất'}, chạm để thay đổi',
    onTap: onTap,
    child: Material(
      key: const Key('rescue-create-location-card'),
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AspectRatio(
          aspectRatio: 356 / 159,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/rescue/p2_02_map.png',
                  fit: BoxFit.cover,
                ),
                if (location != null)
                  Align(
                    alignment: const Alignment(0, 0.65),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: AppControlSize.compactButtonVisualHeight,
                        maxWidth: 220,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Đã chọn khu vực',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.buttonCompact(
                          color: AppColors.deepGreen,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
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

String _formatDateTime(DateTime value) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)} ${two(value.day)}/${two(value.month)}/${value.year}';
}
