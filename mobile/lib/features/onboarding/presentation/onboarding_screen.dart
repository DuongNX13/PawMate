import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/media/image_picker_service.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_text_field.dart';
import '../../../core/widgets/pawmate_toast.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _petNameKey = 'onboardingDraftPetName';
  static const _breedKey = 'onboardingDraftBreed';
  static const _ageKey = 'onboardingDraftAge';
  static const _photoPathKey = 'onboardingDraftPhotoPath';

  final _formKey = GlobalKey<FormState>();
  final _petNameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();

  String? _photoPath;
  String? _draftError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreDraft());
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      _petNameController.text = prefs.getString(_petNameKey) ?? '';
      _breedController.text = prefs.getString(_breedKey) ?? '';
      _ageController.text = prefs.getString(_ageKey) ?? '';
      final savedPhotoPath = prefs.getString(_photoPathKey);
      setState(() {
        _photoPath = _isReadableFile(savedPhotoPath) ? savedPhotoPath : null;
        _draftError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _draftError =
            'Không thể khôi phục thông tin đã nhập. Bạn vẫn có thể tiếp tục.';
      });
    }
  }

  bool _isReadableFile(String? path) {
    if (path == null || path.trim().isEmpty) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final photo = await ref
          .read(imagePickerProvider)
          .pickImage(
            source: ImageSource.gallery,
            imageQuality: 90,
            maxWidth: 1600,
          );
      if (photo == null || !mounted) return;

      setState(() {
        _photoPath = photo.path;
        _draftError = null;
      });
      await _persistDraft(markOnboardingSeen: false);
    } catch (_) {
      if (!mounted) return;
      PawMateToast.show(
        context,
        message: 'Không thể mở ảnh đã chọn. Vui lòng thử lại.',
        type: PawMateToastType.error,
      );
    }
  }

  String? _validatePetName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'Vui lòng nhập tên thú cưng';
    if (name.length > 50) return 'Tên thú cưng tối đa 50 ký tự';
    return null;
  }

  String? _validateBreed(String? value) {
    if ((value ?? '').trim().length > 80) return 'Giống tối đa 80 ký tự';
    return null;
  }

  String? _validateAge(String? value) {
    final ageText = (value ?? '').trim();
    if (ageText.isEmpty) return null;
    final age = int.tryParse(ageText);
    if (age == null || age < 0 || age > 50) {
      return 'Tuổi phải là số từ 0 đến 50';
    }
    return null;
  }

  Future<void> _persistDraft({required bool markOnboardingSeen}) async {
    final prefs = await SharedPreferences.getInstance();
    final draftResults = <bool>[
      await prefs.setString(_petNameKey, _petNameController.text.trim()),
      await prefs.setString(_breedKey, _breedController.text.trim()),
      await prefs.setString(_ageKey, _ageController.text.trim()),
      if (_photoPath == null || _photoPath!.trim().isEmpty)
        await prefs.remove(_photoPathKey)
      else
        await prefs.setString(_photoPathKey, _photoPath!),
    ];
    if (draftResults.any((saved) => !saved)) {
      throw StateError('Unable to persist onboarding draft.');
    }
    if (markOnboardingSeen && !await prefs.setBool('hasSeenOnboarding', true)) {
      throw StateError('Unable to finish onboarding.');
    }
  }

  Future<void> _finishOnboarding({
    required String nextRoute,
    required bool validate,
  }) async {
    if (_isSubmitting) return;
    if (validate && !(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _draftError = null;
    });

    try {
      await _persistDraft(markOnboardingSeen: true);
      if (mounted) context.go(nextRoute);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _draftError =
            'Chưa thể lưu thông tin của bạn. Vui lòng thử lại để tránh mất dữ liệu.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _petNameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Widget _buildHeroImage(File? selectedPhoto) {
    const semanticLabel = 'Minh họa chó cưng cho bước thiết lập hồ sơ thú cưng';
    final fallback = Image.asset(
      'assets/images/auth/onboarding_dog.png',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const _AuthImageFallback(
        icon: Icons.pets_rounded,
        semanticLabel: semanticLabel,
      ),
    );
    final image = selectedPhoto == null
        ? fallback
        : Image.file(
            selectedPhoto,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
          );

    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: image),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedPhoto = _photoPath == null ? null : File(_photoPath!);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              SizedBox(
                height: 334,
                child: Stack(
                  children: [
                    Positioned.fill(child: _buildHeroImage(selectedPhoto)),
                    Positioned(
                      right: 24,
                      bottom: 28,
                      child: SizedBox.square(
                        dimension: 54,
                        child: Material(
                          color: AppColors.surface,
                          shape: const CircleBorder(),
                          elevation: 8,
                          shadowColor: AppColors.shadow,
                          child: IconButton(
                            key: const Key('onboarding-photo-picker'),
                            tooltip: 'Thêm ảnh thú cưng',
                            padding: EdgeInsets.zero,
                            onPressed: _isSubmitting
                                ? null
                                : () => unawaited(_pickPhoto()),
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                              size: 22,
                              color: AppColors.primary500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -12),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 34, 20, 28),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Hãy cùng làm quen với bạn thân của bạn',
                          style: AppTextStyles.h1(color: AppColors.primary500),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Hãy chia sẻ một chút về bé để chúng tôi có thể chăm sóc bé tốt nhất.',
                          style: AppTextStyles.bodyStrong(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 48),
                        PawMateTextField(
                          key: const Key('onboarding-pet-name-field'),
                          controller: _petNameController,
                          label: 'TÊN THÚ CƯNG',
                          hintText: 'vd: LuLu',
                          isRequired: true,
                          showRequiredIndicator: false,
                          enabled: !_isSubmitting,
                          fillColor: AppColors.surfaceMuted,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          textInputAction: TextInputAction.next,
                          validator: _validatePetName,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(50),
                          ],
                        ),
                        const SizedBox(height: 24),
                        PawMateTextField(
                          key: const Key('onboarding-breed-field'),
                          controller: _breedController,
                          label: 'GIỐNG',
                          hintText: 'vd: Golden',
                          enabled: !_isSubmitting,
                          fillColor: AppColors.surfaceMuted,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          textInputAction: TextInputAction.next,
                          validator: _validateBreed,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(80),
                          ],
                        ),
                        const SizedBox(height: 24),
                        PawMateTextField(
                          key: const Key('onboarding-age-field'),
                          controller: _ageController,
                          label: 'TUỔI (NĂM)',
                          hintText: 'vd: 2',
                          enabled: !_isSubmitting,
                          fillColor: AppColors.surfaceMuted,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          validator: _validateAge,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                        ),
                        if (_draftError != null) ...[
                          const SizedBox(height: 18),
                          _OnboardingErrorBanner(message: _draftError!),
                        ],
                        const SizedBox(height: 26),
                        PawMateButton(
                          key: const ValueKey('onboarding-continue-button'),
                          label: 'Tiếp tục',
                          isLoading: _isSubmitting,
                          onPressed: _isSubmitting
                              ? null
                              : () => unawaited(
                                  _finishOnboarding(
                                    nextRoute: '/auth/register',
                                    validate: true,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 10),
                        PawMateButton(
                          key: const ValueKey('onboarding-login-button'),
                          label: 'Bỏ qua và đăng nhập',
                          variant: PawMateButtonVariant.ghost,
                          onPressed: _isSubmitting
                              ? null
                              : () => unawaited(
                                  _finishOnboarding(
                                    nextRoute: '/auth/login',
                                    validate: false,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingErrorBanner extends StatelessWidget {
  const _OnboardingErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.errorSoft,
          border: Border.all(color: AppColors.error),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.body(
                  color: AppColors.error,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthImageFallback extends StatelessWidget {
  const _AuthImageFallback({required this.icon, required this.semanticLabel});

  final IconData icon;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: ColoredBox(
          color: AppColors.careGreenSoft,
          child: Center(
            child: Icon(icon, size: 64, color: AppColors.primary500),
          ),
        ),
      ),
    );
  }
}
