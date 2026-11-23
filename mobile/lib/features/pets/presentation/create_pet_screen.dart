import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/media/image_picker_service.dart';
import '../../../core/widgets/pawmate_adaptive.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_fixed_cta_bar.dart';
import '../../../core/widgets/pawmate_skeleton.dart';
import '../../../core/widgets/pawmate_state_view.dart';
import '../application/pet_form_draft_provider.dart';
import '../application/pet_list_provider.dart';
import '../data/pet_api.dart';
import '../domain/pet_profile.dart';
import 'widgets/pet_avatar_media.dart';

class CreatePetScreen extends ConsumerStatefulWidget {
  const CreatePetScreen({this.petId, this.returnTo, super.key});

  final String? petId;
  final String? returnTo;

  @override
  ConsumerState<CreatePetScreen> createState() => _CreatePetScreenState();
}

class _CreatePetScreenState extends ConsumerState<CreatePetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  final _colorController = TextEditingController();
  final _microchipController = TextEditingController();
  String _species = 'dog';
  DateTime? _dateOfBirth;
  String? _avatarPath;
  String? _pendingAvatarPath;
  String? _resolvedPetId;
  bool _isSubmitting = false;
  bool _photoUploadFailed = false;
  bool _editRecordResolved = false;
  bool _isHydrating = false;
  String? _submitError;
  String? _avatarError;
  bool _pickingAvatar = false;

  @override
  void initState() {
    super.initState();
    final savedDraft = ref.read(petFormDraftProvider);
    final requestedPet = widget.petId == null
        ? null
        : ref.read(petByIdProvider(widget.petId!));
    if (widget.petId == null) {
      final initialDraft = savedDraft.petId == null && !savedDraft.isEmpty
          ? savedDraft
          : const PetFormDraft();
      _hydrateDraft(initialDraft);
      _editRecordResolved = true;
    } else if (requestedPet != null) {
      final initialDraft =
          savedDraft.petId == widget.petId && !savedDraft.isEmpty
          ? savedDraft
          : _draftFromPet(requestedPet);
      _hydrateDraft(initialDraft);
      _editRecordResolved = true;
    } else {
      _resolvedPetId = widget.petId;
    }

    for (final controller in [
      _nameController,
      _breedController,
      _weightController,
      _colorController,
      _microchipController,
    ]) {
      controller.addListener(_syncDraft);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editRecordResolved) {
        _syncDraft();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    _colorController.dispose();
    _microchipController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_pickingAvatar) return;
    _pickingAvatar = true;
    final picker = ref.read(imagePickerProvider);
    try {
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;
      setState(() {
        _avatarPath = file.path;
        _pendingAvatarPath = file.path;
        _avatarError = null;
      });
      _syncDraft();
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _avatarError =
            error.code == 'photo_access_denied' ||
                error.code == 'photo_access_restricted'
            ? 'Chưa có quyền truy cập ảnh. Hãy kiểm tra quyền trong cài đặt thiết bị rồi thử lại.'
            : 'Không thể chọn ảnh lúc này. Vui lòng thử lại.';
      });
    } finally {
      _pickingAvatar = false;
    }
  }

  Future<void> _pickDateOfBirth() async {
    final selectedDate = await showPawMateAdaptiveDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDate: _dateOfBirth ?? DateTime(2022, 4, 12),
      currentDate: DateTime.now(),
      title: 'Chọn ngày sinh',
    );
    if (selectedDate == null || !mounted) {
      return;
    }
    setState(() {
      _dateOfBirth = selectedDate;
    });
    _syncDraft();
  }

  String? _validateName(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Vui lòng nhập tên';
    }
    if (value!.trim().length > 50) {
      return 'Tên thú cưng không được quá 50 ký tự';
    }
    return null;
  }

  String? _validateBreed(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Vui lòng nhập giống loài';
    }
    if (value!.trim().length > 80) {
      return 'Giống loài không được quá 80 ký tự';
    }
    return null;
  }

  String? _validateWeight(String? value) {
    final rawValue = (value ?? '').trim();
    if (rawValue.isEmpty) {
      return null;
    }
    final weight = double.tryParse(rawValue);
    if (weight == null || weight < 0.1 || weight > 99.9) {
      return 'Cân nặng phải từ 0.1 đến 99.9 kg';
    }
    return null;
  }

  String? _validateColor(String? value) {
    final color = (value ?? '').trim();
    if (color.isEmpty) {
      return 'Vui lòng nhập màu lông';
    }
    if (color.length > 80) {
      return 'Màu lông không được quá 80 ký tự';
    }
    return null;
  }

  String? _validateMicrochip(String? value) {
    final microchip = (value ?? '').trim();
    if (microchip.isEmpty) {
      return null;
    }
    if (microchip.length > 32 ||
        !RegExp(r'^[A-Za-z0-9-]+$').hasMatch(microchip)) {
      return 'Microchip chỉ gồm chữ, số, dấu gạch ngang và tối đa 32 ký tự';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _photoUploadFailed = false;
      _submitError = null;
    });

    try {
      final notifier = ref.read(petListProvider.notifier);
      final weight = _weightController.text.trim().isEmpty
          ? null
          : double.parse(_weightController.text.trim());
      final microchip = _microchipController.text.trim().isEmpty
          ? null
          : _microchipController.text.trim();
      final existingPetId = _resolvedPetId;
      final String petId;

      if (existingPetId == null) {
        petId = await notifier.createPet(
          name: _nameController.text.trim(),
          species: _species,
          breed: _breedController.text.trim(),
          gender: 'unknown',
          dateOfBirth: _dateOfBirth,
          weightKg: weight,
          healthStatus: 'healthy',
          avatarPath: _pendingAvatarPath,
          color: _colorController.text.trim(),
          microchip: microchip,
          isNeutered: false,
        );
      } else {
        await notifier.updatePet(
          existingPetId,
          UpdatePetProfileInput(
            name: _nameController.text.trim(),
            species: _species,
            breed: _breedController.text.trim(),
            color: _colorController.text.trim(),
            dateOfBirth: _dateOfBirth,
            weightKg: weight,
            microchip: microchip,
          ),
          avatarPath: _pendingAvatarPath,
        );
        petId = existingPetId;
      }

      if (!mounted) {
        return;
      }
      ref.read(petFormDraftProvider.notifier).clear();
      context.go(_resolveReturnPath(petId));
    } on PetPhotoSaveException catch (error) {
      _resolvedPetId = error.petId;
      _syncDraft();
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _photoUploadFailed = true;
        _submitError =
            'Đã lưu hồ sơ nhưng chưa tải được ảnh. Bản nháp vẫn được giữ để bạn thử lại.';
      });
    } on PetApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _submitError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _submitError = 'Không thể lưu hồ sơ thú cưng. Vui lòng thử lại.';
      });
    }
  }

  void _discardPendingPhoto() {
    if (_isSubmitting || !_photoUploadFailed || _pendingAvatarPath == null) {
      return;
    }
    setState(() {
      _pendingAvatarPath = null;
      _avatarPath = null;
      _photoUploadFailed = false;
      _submitError = null;
      _avatarError = null;
    });
    _syncDraft();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(_resolveReturnPath(_resolvedPetId));
  }

  void _leaveUnresolvedEdit() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final requested = widget.returnTo?.trim();
    context.go(
      requested == '/pets' || requested == '/pets/list'
          ? requested!
          : '/pets/list',
    );
  }

  void _syncDraft() {
    if (_isHydrating || !_editRecordResolved) {
      return;
    }
    ref
        .read(petFormDraftProvider.notifier)
        .replace(
          PetFormDraft(
            petId: _resolvedPetId,
            avatarPath: _avatarPath,
            name: _nameController.text,
            species: _species,
            breed: _breedController.text,
            dateOfBirth: _dateOfBirth,
            weightText: _weightController.text,
            color: _colorController.text,
            microchip: _microchipController.text,
          ),
        );
  }

  void _hydrateDraft(PetFormDraft draft) {
    _isHydrating = true;
    _resolvedPetId = widget.petId ?? draft.petId;
    _avatarPath = draft.avatarPath;
    _pendingAvatarPath = _isLocalFilePath(draft.avatarPath)
        ? draft.avatarPath
        : null;
    _species = draft.species;
    _dateOfBirth = draft.dateOfBirth;
    _nameController.text = draft.name;
    _breedController.text = draft.breed;
    _weightController.text = draft.weightText;
    _colorController.text = draft.color;
    _microchipController.text = draft.microchip;
    _isHydrating = false;
  }

  String _resolveReturnPath(String? petId) {
    final requested = widget.returnTo?.trim();
    if (requested == '/pets' || requested == '/pets/list') {
      return requested!;
    }
    if (petId != null && petId.isNotEmpty) {
      return '/pets/$petId';
    }
    return '/pets/list';
  }

  static PetFormDraft _draftFromPet(PetProfile pet) {
    return PetFormDraft(
      petId: pet.id,
      avatarPath: pet.avatarPath,
      name: pet.name,
      species: pet.species,
      breed: pet.breed,
      dateOfBirth: pet.dateOfBirth,
      weightText: pet.weightKg?.toString() ?? '',
      color: pet.color ?? '',
      microchip: pet.microchip ?? '',
    );
  }

  static bool _isLocalFilePath(String? value) {
    if (value == null || value.trim().isEmpty) {
      return false;
    }
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('assets/')) {
      return false;
    }
    return File(value).isAbsolute;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.petId != null && !_editRecordResolved) {
      final cachedPet = ref.watch(petByIdProvider(widget.petId!));
      final backendPetsState = ref.watch(petBackendListProvider);
      final resolvedPet =
          cachedPet ??
          backendPetsState.maybeWhen(
            data: (pets) => _findPetById(pets, widget.petId!),
            orElse: () => null,
          );

      if (resolvedPet == null) {
        if (backendPetsState.isLoading) {
          return _PetEditResolutionScaffold.loading(
            onBack: _leaveUnresolvedEdit,
          );
        }
        if (backendPetsState.hasError) {
          return _PetEditResolutionScaffold.error(
            onBack: _leaveUnresolvedEdit,
            onRetry: () => ref.invalidate(petBackendListProvider),
          );
        }
        return _PetEditResolutionScaffold.notFound(
          onBack: _leaveUnresolvedEdit,
        );
      }

      final savedDraft = ref.read(petFormDraftProvider);
      final initialDraft =
          savedDraft.petId == widget.petId && !savedDraft.isEmpty
          ? savedDraft
          : _draftFromPet(resolvedPet);
      _hydrateDraft(initialDraft);
      _editRecordResolved = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncDraft();
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: PawMateFixedCtaBar(
        key: const Key('pet-form-save-button'),
        backgroundColor: AppColors.background,
        elevation: AppElevation.none,
        shadowColor: Colors.transparent,
        primaryAction: PawMateAction(
          label: _resolvedPetId == null ? 'Lưu hồ sơ' : 'Cập nhật hồ sơ',
          onPressed: _isSubmitting ? null : _submit,
          isLoading: _isSubmitting,
          trailingIcon: Icons.save_rounded,
          semanticLabel: _resolvedPetId == null
              ? 'Lưu hồ sơ thú cưng'
              : 'Cập nhật hồ sơ thú cưng',
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PetFormHeader(onBack: _goBack),
                      const SizedBox(height: 16),
                      Center(
                        child: _AvatarPicker(
                          avatarPath: _avatarPath,
                          onTap: _pickAvatar,
                        ),
                      ),
                      if (_avatarError != null) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: _PetFormError(message: _avatarError!),
                        ),
                      ],
                      const SizedBox(height: 32),
                      _PetTextField(
                        key: const Key('pet-form-name-field'),
                        controller: _nameController,
                        label: 'Tên thú cưng',
                        required: true,
                        hintText: 'Ví dụ: Bắp',
                        textInputAction: TextInputAction.next,
                        validator: _validateName,
                      ),
                      const SizedBox(height: 18),
                      _SpeciesSegmentedField(
                        value: _species,
                        onChanged: (value) {
                          setState(() {
                            _species = value;
                          });
                          _syncDraft();
                        },
                      ),
                      const SizedBox(height: 18),
                      _ResponsiveFieldGrid(
                        children: [
                          _PetTextField(
                            key: const Key('pet-form-breed-field'),
                            controller: _breedController,
                            label: 'Giống loài',
                            hintText: 'Golden Retriever',
                            textInputAction: TextInputAction.next,
                            validator: _validateBreed,
                            compact: true,
                          ),
                          _DateField(
                            selectedDate: _dateOfBirth,
                            onTap: _pickDateOfBirth,
                            compact: true,
                          ),
                          _PetTextField(
                            key: const Key('pet-form-weight-field'),
                            controller: _weightController,
                            label: 'Cân nặng (kg)',
                            hintText: '12.4',
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.next,
                            validator: _validateWeight,
                            compact: true,
                          ),
                          _PetTextField(
                            key: const Key('pet-form-color-field'),
                            controller: _colorController,
                            label: 'Màu lông',
                            hintText: 'Vàng kem',
                            textInputAction: TextInputAction.next,
                            validator: _validateColor,
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _PetTextField(
                        key: const Key('pet-form-microchip-field'),
                        controller: _microchipController,
                        label: 'Số Microchip (nếu có)',
                        hintText: 'MC-8293-128',
                        textInputAction: TextInputAction.done,
                        validator: _validateMicrochip,
                      ),
                      if (_submitError != null) ...[
                        const SizedBox(height: 16),
                        _PetFormError(message: _submitError!),
                      ],
                      if (_photoUploadFailed && _pendingAvatarPath != null) ...[
                        const SizedBox(height: 12),
                        PawMateButton(
                          label: 'Tải lại ảnh',
                          onPressed: _isSubmitting ? null : _submit,
                        ),
                        const SizedBox(height: 8),
                        PawMateButton(
                          label: 'Xóa ảnh',
                          variant: PawMateButtonVariant.secondary,
                          onPressed: _isSubmitting
                              ? null
                              : _discardPendingPhoto,
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

PetProfile? _findPetById(List<PetProfile> pets, String petId) {
  for (final pet in pets) {
    if (pet.id == petId) {
      return pet;
    }
  }
  return null;
}

class _PetEditResolutionScaffold extends StatelessWidget {
  const _PetEditResolutionScaffold._({
    required this.state,
    required this.onBack,
    this.onRetry,
  });

  factory _PetEditResolutionScaffold.loading({required VoidCallback onBack}) =>
      _PetEditResolutionScaffold._(state: 'loading', onBack: onBack);

  factory _PetEditResolutionScaffold.error({
    required VoidCallback onBack,
    required VoidCallback onRetry,
  }) => _PetEditResolutionScaffold._(
    state: 'error',
    onBack: onBack,
    onRetry: onRetry,
  );

  factory _PetEditResolutionScaffold.notFound({required VoidCallback onBack}) =>
      _PetEditResolutionScaffold._(state: 'not-found', onBack: onBack);

  final String state;
  final VoidCallback onBack;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isLoading = state == 'loading';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: onBack,
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text('Chỉnh sửa hồ sơ', style: AppTextStyles.appBarTitle()),
      ),
      body: isLoading
          ? const SingleChildScrollView(
              key: Key('pet-edit-loading-state'),
              padding: EdgeInsets.all(AppSpacing.s24),
              child: Column(
                children: [
                  PawMateSkeleton(width: 112, height: 112, circular: true),
                  SizedBox(height: AppSpacing.s24),
                  PawMateSkeleton(width: double.infinity, height: 56),
                  SizedBox(height: AppSpacing.s16),
                  PawMateSkeleton(width: double.infinity, height: 56),
                  SizedBox(height: AppSpacing.s16),
                  PawMateSkeleton(width: double.infinity, height: 56),
                ],
              ),
            )
          : PawMateStateView(
              key: Key(
                state == 'error'
                    ? 'pet-edit-error-state'
                    : 'pet-edit-not-found-state',
              ),
              type: state == 'error'
                  ? PawMateStateType.offline
                  : PawMateStateType.empty,
              title: state == 'error'
                  ? 'Chưa tải được hồ sơ'
                  : 'Hồ sơ không còn khả dụng',
              message: state == 'error'
                  ? 'Kiểm tra kết nối rồi thử tải lại trước khi chỉnh sửa.'
                  : 'Hồ sơ có thể đã được xóa hoặc không thuộc tài khoản này.',
              primaryActionLabel: state == 'error' ? 'Thử lại' : 'Về danh sách',
              onPrimaryAction: state == 'error' ? onRetry : onBack,
            ),
    );
  }
}

class _PetFormHeader extends StatelessWidget {
  const _PetFormHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;
    return Row(
      children: [
        IconButton(
          key: const Key('pet-form-back-button'),
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.textPrimary,
          tooltip: 'Quay lại',
        ),
        const SizedBox(width: 4),
        Expanded(
          child: usesExpandedTextLayout
              ? Semantics(
                  header: true,
                  label: 'Hồ sơ thú cưng',
                  child: ExcludeSemantics(
                    child: Text(
                      'Hồ sơ',
                      maxLines: null,
                      overflow: TextOverflow.visible,
                      style: AppTextStyles.appBarTitle(),
                    ),
                  ),
                )
              : Text(
                  'Hồ sơ thú cưng',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.appBarTitle(),
                ),
        ),
      ],
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({required this.avatarPath, required this.onTap});

  final String? avatarPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarPath?.trim().isNotEmpty == true;

    return InkWell(
      key: const Key('pet-form-avatar-picker'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(90),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainer,
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: ClipOval(
                  child: PetAvatarMedia(
                    source: avatarPath,
                    semanticLabel: hasAvatar ? 'Ảnh thú cưng đã chọn' : null,
                    fallback: const Icon(
                      Icons.pets_rounded,
                      color: AppColors.primary700,
                      size: 38,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: 10,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary700,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.soft,
                  ),
                  child: const Icon(
                    Icons.add_a_photo_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasAvatar ? 'Thay ảnh thú cưng' : 'Thêm ảnh thú cưng',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeciesSegmentedField extends StatelessWidget {
  const _SpeciesSegmentedField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: 'Loài'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppControlSize.minTouchTarget,
            ),
            child: SegmentedButton<String>(
              key: const Key('pet-form-species-segment'),
              showSelectedIcon: false,
              selected: {value},
              onSelectionChanged: (selection) => onChanged(selection.first),
              style: ButtonStyle(
                // Segment visuals may be 40dp, but each action must retain
                // the 48dp padded hit/semantics target on both endpoints.
                tapTargetSize: MaterialTapTargetSize.padded,
                minimumSize: const WidgetStatePropertyAll(
                  Size(0, AppControlSize.minTouchTarget),
                ),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.primary500;
                  }
                  return Colors.transparent;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return AppColors.textSecondary;
                }),
                side: const WidgetStatePropertyAll(BorderSide.none),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                textStyle: WidgetStatePropertyAll(AppTextStyles.label()),
                padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              ),
              segments: const [
                ButtonSegment(value: 'dog', label: Text('Chó')),
                ButtonSegment(value: 'cat', label: Text('Mèo')),
                ButtonSegment(value: 'other', label: Text('Khác')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResponsiveFieldGrid extends StatelessWidget {
  const _ResponsiveFieldGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const SizedBox(height: 14),
                children[index],
              ],
            ],
          );
        }

        return Column(
          children: [
            for (var rowStart = 0; rowStart < children.length; rowStart += 2)
              Padding(
                padding: EdgeInsets.only(top: rowStart == 0 ? 0 : 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: children[rowStart]),
                    const SizedBox(width: 14),
                    Expanded(child: children[rowStart + 1]),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.selectedDate,
    required this.onTap,
    this.compact = false,
  });

  final DateTime? selectedDate;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: 'Ngày sinh'),
        const SizedBox(height: 8),
        InkWell(
          key: const Key('pet-form-date-field'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InputDecorator(
            decoration: _inputDecoration(
              hintText: '12/04/2022',
              suffixIcon: const Icon(Icons.calendar_month_rounded),
              compact: compact,
            ),
            child: Text(
              selectedDate == null ? 'Chọn ngày' : _formatDate(selectedDate!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.field(
                color: selectedDate == null
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PetTextField extends StatelessWidget {
  const _PetTextField({
    super.key,
    required this.controller,
    required this.label,
    this.required = false,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.compact = false,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, required: required),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          style: AppTextStyles.field(),
          decoration: _inputDecoration(hintText: hintText, compact: compact),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final usesExpandedTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >
        AppControlSize.compactButtonMaxTextScale;
    return Text.rich(
      TextSpan(
        style: AppTextStyles.label(),
        text: label,
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.error),
            ),
        ],
      ),
      maxLines: usesExpandedTextLayout ? null : 1,
      overflow: usesExpandedTextLayout
          ? TextOverflow.visible
          : TextOverflow.ellipsis,
    );
  }
}

class _PetFormError extends StatelessWidget {
  const _PetFormError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        message,
        style: AppTextStyles.bodyStrong(color: AppColors.error),
      ),
    );
  }
}

InputDecoration _inputDecoration({
  String? hintText,
  Widget? suffixIcon,
  bool compact = false,
}) {
  return InputDecoration(
    hintText: hintText,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.surface,
    isDense: true,
    constraints: const BoxConstraints(minHeight: 52),
    contentPadding: EdgeInsets.symmetric(
      horizontal: compact ? 12 : 16,
      vertical: 13,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: const BorderSide(color: AppColors.primary500, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: const BorderSide(color: AppColors.error, width: 1.4),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      borderSide: const BorderSide(color: AppColors.error, width: 1.6),
    ),
    hintStyle: AppTextStyles.field(color: AppColors.textMuted),
    errorStyle: AppTextStyles.caption(
      color: AppColors.error,
    ).copyWith(height: 1.5),
  );
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}
