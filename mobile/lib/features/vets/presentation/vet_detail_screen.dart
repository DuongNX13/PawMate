import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/app_navigation.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/media/image_picker_service.dart';
import '../../../core/widgets/pawmate_adaptive.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_chip.dart';
import '../../../core/widgets/pawmate_fixed_cta_bar.dart';
import '../application/vet_providers.dart';
import '../data/vet_api.dart';
import '../domain/vet_models.dart';
import 'vet_actions.dart';

class VetDetailScreen extends ConsumerWidget {
  const VetDetailScreen({
    super.key,
    required this.vetId,
    this.returnPath = '/vets/list',
  });

  final String vetId;
  final String returnPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vetAsync = ref.watch(vetDetailProvider(vetId));

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: vetAsync.maybeWhen(
        data: (vet) => _VetDetailCtaBar(vet: vet),
        orElse: () => null,
      ),
      body: SafeArea(
        child: vetAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _VetStateCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Không tải được chi tiết phòng khám',
                  style: AppTextStyles.h4(),
                ),
                const SizedBox(height: 8),
                Text(error.toString(), style: AppTextStyles.bodyCompact()),
                const SizedBox(height: 16),
                PawMateButton(
                  label: 'Thử lại',
                  fullWidth: false,
                  variant: PawMateButtonVariant.secondary,
                  onPressed: () => ref.invalidate(vetDetailProvider(vetId)),
                ),
              ],
            ),
          ),
          data: (vet) {
            final reviewsAsync = ref.watch(vetReviewListProvider(vet.id));

            return ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.s24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
                  child: _VetDetailHeader(
                    onBack: () =>
                        PawMateNavigation.backOrGo(context, returnPath),
                    onShare: () => _copyVetDetails(context, vet),
                  ),
                ),
                _HeroCard(vet: vet),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vet.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h2(),
                      ),
                      const SizedBox(height: 10),
                      _VetStatusLine(vet: vet),
                      const SizedBox(height: 24),
                      _QuickFactsCard(vet: vet),
                      const SizedBox(height: 20),
                      _AddressCard(vet: vet),
                      const SizedBox(height: 30),
                      Text('Dịch vụ cung cấp', style: AppTextStyles.h3()),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: vet.displayServices
                            .take(5)
                            .map((service) => _ServiceChip(label: service))
                            .toList(),
                      ),
                      const SizedBox(height: 18),
                      PawMateButton(
                        key: const Key('vet-detail-write-review-button'),
                        label: 'Viết đánh giá',
                        fullWidth: false,
                        variant: PawMateButtonVariant.secondary,
                        onPressed: () => _openWriteReview(context, ref, vet),
                        leadingIcon: Icons.rate_review_outlined,
                      ),
                      const SizedBox(height: 34),
                      Text('Đánh giá gần đây', style: AppTextStyles.h3()),
                      const SizedBox(height: 16),
                      _ReviewPreviewCard(vet: vet, reviewsAsync: reviewsAsync),
                      const SizedBox(height: 18),
                      _SourceAttributionCard(vet: vet),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static Future<void> _openWriteReview(
    BuildContext context,
    WidgetRef ref,
    VetDetail vet,
  ) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WriteReviewSheet(vet: vet),
    );

    if (submitted != true || !context.mounted) {
      return;
    }

    ref.invalidate(vetReviewListProvider(vet.id));
    ref.invalidate(vetDetailProvider(vet.id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đánh giá đã được gửi thành công.')),
    );
  }

  static Future<void> _copyVetDetails(
    BuildContext context,
    VetDetail vet,
  ) async {
    final address = [
      vet.address,
      vet.district,
      vet.city,
    ].where((part) => part.trim().isNotEmpty).join(', ');
    final details = [
      vet.name,
      if (address.isNotEmpty) address,
      if (vet.phone.trim().isNotEmpty) vet.phone,
      if ((vet.website ?? '').trim().isNotEmpty) vet.website!.trim(),
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: details));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép thông tin phòng khám để chia sẻ.'),
      ),
    );
  }
}

class _WriteReviewSheet extends ConsumerStatefulWidget {
  const _WriteReviewSheet({required this.vet});

  final VetDetail vet;

  @override
  ConsumerState<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<_WriteReviewSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final List<XFile> _selectedPhotos = [];
  int _rating = 0;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  String? _validateBody(String? value) {
    final body = (value ?? '').trim();
    if (body.isNotEmpty && body.length < 10) {
      return 'Nội dung cần ít nhất 10 ký tự nếu được nhập.';
    }
    return null;
  }

  String _resolveContentType(XFile photo) {
    final mimeType = photo.mimeType?.trim().toLowerCase();
    if (mimeType == 'image/jpeg' ||
        mimeType == 'image/png' ||
        mimeType == 'image/webp') {
      return mimeType!;
    }

    final name = (photo.name.isNotEmpty ? photo.name : photo.path)
        .toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (name.endsWith('.png')) {
      return 'image/png';
    }
    if (name.endsWith('.webp')) {
      return 'image/webp';
    }

    throw const VetApiException('Ảnh đánh giá chỉ hỗ trợ JPEG, PNG hoặc WEBP.');
  }

  Future<void> _pickPhoto() async {
    if (_selectedPhotos.length >= 3 || _isSubmitting) {
      return;
    }

    final picker = ref.read(imagePickerProvider);
    final photo = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (photo == null || !mounted) {
      return;
    }

    setState(() {
      _selectedPhotos.add(photo);
      _errorMessage = null;
    });
  }

  Future<List<String>> _uploadSelectedPhotos(String accessToken) async {
    final urls = <String>[];
    for (final photo in _selectedPhotos) {
      final bytes = await photo.readAsBytes();
      final result = await ref
          .read(vetApiProvider)
          .uploadReviewPhoto(
            widget.vet.id,
            UploadReviewPhotoInput(
              fileName: photo.name.isNotEmpty ? photo.name : 'review-photo',
              contentType: _resolveContentType(photo),
              base64Data: base64Encode(bytes),
            ),
            accessToken: accessToken,
          );
      urls.add(result.url);
    }

    return urls;
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() {
        _errorMessage = 'Vui lòng chọn số sao trước khi gửi.';
      });
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false) || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final accessToken = await ref.read(vetReviewAccessTokenProvider.future);
      if (accessToken == null || accessToken.trim().isEmpty) {
        throw const VetApiException('Bạn cần đăng nhập để gửi đánh giá.');
      }

      final photoUrls = await _uploadSelectedPhotos(accessToken);

      await ref
          .read(vetApiProvider)
          .createReview(
            widget.vet.id,
            CreateVetReviewInput(
              rating: _rating,
              title: _titleController.text,
              body: _bodyController.text,
              photoUrls: photoUrls,
            ),
            accessToken: accessToken,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on VetApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Không gửi được đánh giá. Vui lòng thử lại.';
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
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Viết đánh giá', style: AppTextStyles.h3()),
                    const SizedBox(height: AppSpacing.s16),
                    _ReviewClinicSummary(vet: widget.vet),
                    const SizedBox(height: AppSpacing.s24),
                    Center(
                      child: Text(
                        'Chất lượng dịch vụ',
                        style: AppTextStyles.h4(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final value = index + 1;
                        return IconButton(
                          key: Key('write-review-star-$value'),
                          onPressed: _isSubmitting
                              ? null
                              : () => setState(() {
                                  _rating = value;
                                  _errorMessage = null;
                                }),
                          icon: Icon(
                            value <= _rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: AppColors.brown,
                            size: 32,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('write-review-title-field'),
                      controller: _titleController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Tiêu đề',
                        hintText: 'Ví dụ: Chăm sóc rất kỹ',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('write-review-body-field'),
                      controller: _bodyController,
                      minLines: 4,
                      maxLines: 6,
                      validator: _validateBody,
                      decoration: const InputDecoration(
                        labelText: 'Nội dung',
                        hintText:
                            'Chia sẻ trải nghiệm sau khi sử dụng dịch vụ.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ReviewPhotoPicker(
                      photos: _selectedPhotos,
                      isSubmitting: _isSubmitting,
                      onPickPhoto: _pickPhoto,
                      onRemovePhoto: (index) {
                        if (_isSubmitting) {
                          return;
                        }
                        setState(() {
                          _selectedPhotos.removeAt(index);
                        });
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        key: const Key('write-review-error'),
                        style: AppTextStyles.bodyStrong(color: AppColors.error),
                      ),
                    ],
                    const SizedBox(height: 20),
                    PawMateButton(
                      key: const Key('write-review-submit'),
                      label: _isSubmitting ? 'Đang gửi...' : 'Gửi đánh giá',
                      onPressed: _isSubmitting ? null : _submit,
                      isLoading: _isSubmitting,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewClinicSummary extends StatelessWidget {
  const _ReviewClinicSummary({required this.vet});

  final VetDetail vet;

  @override
  Widget build(BuildContext context) {
    final rating = vet.averageRating?.toStringAsFixed(1) ?? 'Mới';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Semantics(
            image: true,
            label: 'Hình đại diện mặc định của phòng khám',
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.local_hospital_outlined,
                color: AppColors.deepGreen,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vet.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardTitle(),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  '★ $rating • ${vet.city}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.captionStrong(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewPhotoPicker extends StatelessWidget {
  const _ReviewPhotoPicker({
    required this.photos,
    required this.isSubmitting,
    required this.onPickPhoto,
    required this.onRemovePhoto,
  });

  final List<XFile> photos;
  final bool isSubmitting;
  final VoidCallback onPickPhoto;
  final ValueChanged<int> onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hình ảnh đính kèm', style: AppTextStyles.h4()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ...photos.asMap().entries.map(
              (entry) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(entry.value.path),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Semantics(
                      button: true,
                      label: 'Xóa ảnh đánh giá',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: Key('write-review-remove-photo-${entry.key}'),
                          onTap: () => onRemovePhoto(entry.key),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 18,
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
            ),
            if (photos.length < 3)
              Semantics(
                button: true,
                enabled: !isSubmitting,
                label: 'Thêm ảnh đánh giá',
                child: InkWell(
                  key: const Key('write-review-add-photo'),
                  onTap: isSubmitting ? null : onPickPhoto,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppColors.primary500,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Tối đa 3 ảnh, mỗi ảnh dưới 5MB.', style: AppTextStyles.caption()),
      ],
    );
  }
}

class _VetDetailHeader extends StatelessWidget {
  const _VetDetailHeader({required this.onBack, required this.onShare});

  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: PawMateAdaptiveBackButton(onPressed: onBack),
          ),
          Text('PawMate', style: AppTextStyles.h2(color: AppColors.primary700)),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: onShare,
              icon: const Icon(Icons.share_outlined, size: 28),
              tooltip: 'Chia sẻ',
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.vet});

  final VetDetail vet;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 238,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Semantics(
              image: true,
              label: 'Hình minh họa phòng khám ${vet.name}',
              child: CustomPaint(painter: _ClinicHeroPainter()),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.05),
                    Colors.black.withValues(alpha: 0.34),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 22,
            bottom: -28,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: AppShadows.soft,
              ),
              child: Text(
                vet.averageRating != null
                    ? '⭐ ${vet.averageRating!.toStringAsFixed(1)} (${vet.reviewCount}+)'
                    : 'Top #${vet.seedRank}',
                style: AppTextStyles.label(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClinicHeroPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.mint, AppColors.lightBeige],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final ground = Paint()..color = AppColors.brown.withValues(alpha: 0.58);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.74, size.width, size.height * 0.26),
      ground,
    );

    final wall = Paint()..color = AppColors.lightBeige;
    final glass = Paint()..color = AppColors.mint.withValues(alpha: 0.86);
    final roof = Paint()..color = AppColors.deepGreen;
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.12);

    final building = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.12,
        size.height * 0.28,
        size.width * 0.78,
        size.height * 0.46,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(building.shift(const Offset(0, 8)), shadow);
    canvas.drawRRect(building, wall);

    final roofPath = Path()
      ..moveTo(size.width * 0.10, size.height * 0.27)
      ..lineTo(size.width * 0.84, size.height * 0.18)
      ..lineTo(size.width * 0.92, size.height * 0.30)
      ..lineTo(size.width * 0.16, size.height * 0.38)
      ..close();
    canvas.drawPath(roofPath, roof);

    for (var i = 0; i < 4; i++) {
      final left = size.width * (0.20 + i * 0.145);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            left,
            size.height * 0.42,
            size.width * 0.10,
            size.height * 0.22,
          ),
          const Radius.circular(2),
        ),
        glass,
      );
    }

    final door = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.62,
        size.height * 0.42,
        size.width * 0.10,
        size.height * 0.30,
      ),
      const Radius.circular(2),
    );
    canvas.drawRRect(door, glass);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'PetHome',
        style: AppTextStyles.pageTitle(color: AppColors.deepGreen),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(size.width * 0.30, size.height * 0.32));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _VetStatusLine extends StatelessWidget {
  const _VetStatusLine({required this.vet});

  final VetDetail vet;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            color: AppColors.deepGreen,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '${vet.statusLabel} • ${_openingSummary(vet)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label(),
          ),
        ),
      ],
    );
  }
}

class _QuickFactsCard extends StatelessWidget {
  const _QuickFactsCard({required this.vet});

  final VetDetail vet;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricTile(
            icon: Icons.location_on_outlined,
            value: vet.distanceLabel ?? '1.2 km',
            label: 'KHOẢNG CÁCH',
            emphasized: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricTile(
            icon: Icons.emergency_outlined,
            value: vet.is24h == true ? 'Cấp cứu\n24/7' : vet.statusLabel,
            label: vet.is24h == true ? 'SẴN SÀNG' : 'TRẠNG THÁI',
            emphasized: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricTile(
            icon: Icons.vaccines_outlined,
            value: vet.displayServices.isNotEmpty
                ? vet.displayServices.first
                : 'Tiêm phòng',
            label: 'CÓ SẴN',
            emphasized: false,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.emphasized,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final color = emphasized ? AppColors.primary700 : AppColors.textPrimary;

    return Container(
      height: 126,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: emphasized ? AppColors.surfaceContainer : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: emphasized ? AppColors.border : Colors.transparent,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label(color: color),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.micro(),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.vet});

  final VetDetail vet;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.location_on_outlined,
            color: AppColors.primary500,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '${vet.address}\n${vet.district}, ${vet.city}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyStrong(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _VetDetailCtaBar extends StatelessWidget {
  const _VetDetailCtaBar({required this.vet});

  final VetDetail vet;

  @override
  Widget build(BuildContext context) {
    return PawMateFixedCtaBar(
      primaryAction: PawMateAction(
        label: 'Gọi ngay',
        icon: Icons.phone_outlined,
        onPressed: () => launchVetCall(context, vet.phone),
      ),
      secondaryAction: PawMateAction(
        label: 'Chỉ đường',
        icon: Icons.directions_outlined,
        variant: PawMateButtonVariant.secondary,
        onPressed: () => launchVetDirections(context, vet),
      ),
    );
  }
}

String _openingSummary(VetDetail vet) {
  if (vet.is24h == true) {
    return 'Mở 24/7';
  }

  final match = RegExp(
    r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})',
  ).firstMatch(vet.openingNote);
  if (match != null) {
    return 'Đóng lúc ${match.group(2)}';
  }

  if (vet.isOpen == true) {
    return 'Đang mở cửa';
  }
  if (vet.isOpen == false) {
    return 'Tạm đóng';
  }

  return 'Giờ đang cập nhật';
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return PawMateChip(
      label: label,
      variant: PawMateChipVariant.status,
      enabled: true,
    );
  }
}

class _ReviewPreviewCard extends ConsumerWidget {
  const _ReviewPreviewCard({required this.vet, required this.reviewsAsync});

  final VetDetail vet;
  final AsyncValue<VetReviewResult> reviewsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingLabel = vet.averageRating != null
        ? '${vet.averageRating!.toStringAsFixed(1)} sao'
        : 'Đang chờ đánh giá thật';
    final body = vet.reviewCount > 0
        ? 'Hiện có ${vet.reviewCount} lượt đánh giá đã được kiểm duyệt. Bạn có thể xem chi tiết hoặc gửi đánh giá của mình.'
        : 'Chưa có đánh giá nào cho phòng khám này. Hãy là người đầu tiên chia sẻ trải nghiệm.';

    final liveBody = reviewsAsync.maybeWhen(
      loading: () => 'Đang tải đánh giá thật từ PawMate...',
      error: (error, _) => 'Chưa tải được đánh giá: $error',
      data: (reviews) {
        final latestReview = reviews.items.isNotEmpty
            ? reviews.items.first
            : null;
        if (latestReview == null) {
          return 'Chưa có đánh giá PawMate cho ${vet.name}. Form đánh giá đã sẵn sàng để nhận đánh giá đầu tiên.';
        }

        return '${latestReview.starLabel} ${latestReview.title ?? latestReview.reviewer.displayName}\n${latestReview.body ?? 'Người dùng chưa nhập nội dung chi tiết.'}\n${reviews.summary.reviewCount} đánh giá - ${latestReview.helpfulCount} hữu ích';
      },
      orElse: () => body,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Đánh giá PawMate • $ratingLabel', style: AppTextStyles.h4()),
          const SizedBox(height: 10),
          Text(liveBody, style: AppTextStyles.bodyCompact()),
          reviewsAsync.maybeWhen(
            data: (reviews) {
              final latestReview = reviews.items.isNotEmpty
                  ? reviews.items.first
                  : null;
              if (latestReview == null && reviews.summary.reviewCount == 0) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RatingDistributionChart(summary: reviews.summary),
                    if (latestReview != null) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            key: const Key('review-helpful-button'),
                            onPressed: () =>
                                _toggleHelpful(context, ref, latestReview.id),
                            icon: const Icon(Icons.thumb_up_alt_outlined),
                            label: Text(
                              'Hữu ích (${latestReview.helpfulCount})',
                            ),
                          ),
                          TextButton.icon(
                            key: const Key('review-report-button'),
                            onPressed: () =>
                                _openReportSheet(context, ref, latestReview.id),
                            icon: const Icon(Icons.flag_outlined),
                            label: const Text('Báo cáo'),
                          ),
                        ],
                      ),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const Key('review-list-open-button'),
                        onPressed: reviews.items.isEmpty
                            ? null
                            : () => _openReviewListSheet(context, reviews),
                        icon: const Icon(Icons.format_list_bulleted_rounded),
                        label: const Text('Xem danh sách đánh giá'),
                      ),
                    ),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _openReviewListSheet(
    BuildContext context,
    VetReviewResult initialResult,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewListSheet(vet: vet, initialResult: initialResult),
    );
  }

  Future<String> _requireAccessToken(WidgetRef ref) async {
    final accessToken = await ref.read(vetReviewAccessTokenProvider.future);
    if (accessToken == null || accessToken.trim().isEmpty) {
      throw const VetApiException('Bạn cần đăng nhập để tiếp tục.');
    }

    return accessToken;
  }

  Future<void> _toggleHelpful(
    BuildContext context,
    WidgetRef ref,
    String reviewId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final accessToken = await _requireAccessToken(ref);
      await ref
          .read(vetApiProvider)
          .toggleHelpful(reviewId, accessToken: accessToken);
      ref.invalidate(vetReviewListProvider(vet.id));
    } on VetApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Không cập nhật được lượt hữu ích.')),
      );
    }
  }

  Future<void> _openReportSheet(
    BuildContext context,
    WidgetRef ref,
    String reviewId,
  ) async {
    final reported = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportReviewSheet(reviewId: reviewId),
    );

    if (reported == true && context.mounted) {
      ref.invalidate(vetReviewListProvider(vet.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Báo cáo đã được gửi.')));
    }
  }
}

class _RatingDistributionChart extends StatelessWidget {
  const _RatingDistributionChart({required this.summary});

  final VetReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    var maxCount = 0;
    for (final count in summary.distribution.values) {
      if (count > maxCount) {
        maxCount = count;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          summary.averageRating == null
              ? 'Chưa có điểm trung bình'
              : '${summary.averageRating!.toStringAsFixed(1)} / 5 từ ${summary.reviewCount} đánh giá',
          style: AppTextStyles.label(),
        ),
        const SizedBox(height: 10),
        ...[5, 4, 3, 2, 1].map((rating) {
          final count = summary.distribution[rating] ?? 0;
          final widthFactor = maxCount == 0 ? 0.0 : count / maxCount;

          return Padding(
            key: Key('rating-row-$rating'),
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text('$rating★', style: AppTextStyles.captionStrong()),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      height: 8,
                      color: AppColors.border.withValues(alpha: 0.55),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: widthFactor,
                        child: Container(color: AppColors.primary500),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  child: Text(
                    '$count',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.caption(),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _ReviewListSheet extends ConsumerStatefulWidget {
  const _ReviewListSheet({required this.vet, required this.initialResult});

  final VetDetail vet;
  final VetReviewResult initialResult;

  @override
  ConsumerState<_ReviewListSheet> createState() => _ReviewListSheetState();
}

class _ReviewListSheetState extends ConsumerState<_ReviewListSheet> {
  late final List<VetReview> _items;
  late VetReviewSummary _summary;
  String? _nextCursor;
  bool _isLoadingMore = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _items = [...widget.initialResult.items];
    _summary = widget.initialResult.summary;
    _nextCursor = widget.initialResult.nextCursor;
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _isLoadingMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(vetApiProvider)
          .listReviews(
            widget.vet.id,
            request: VetReviewListRequest(cursor: cursor),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _items.addAll(result.items);
        _summary = result.summary;
        _nextCursor = result.nextCursor;
      });
    } on VetApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Không tải thêm được đánh giá. Vui lòng thử lại.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Đánh giá ${widget.vet.name}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h3(),
            ),
            const SizedBox(height: 14),
            _RatingDistributionChart(summary: _summary),
            const SizedBox(height: 12),
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Text(
                        'Chưa có đánh giá nào.',
                        style: AppTextStyles.bodyCompact(),
                      ),
                    )
                  : ListView.separated(
                      itemBuilder: (context, index) =>
                          _ReviewListTile(review: _items[index]),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemCount: _items.length,
                    ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                key: const Key('review-list-load-error'),
                style: AppTextStyles.bodyStrong(color: AppColors.error),
              ),
            ],
            if (_nextCursor != null) ...[
              const SizedBox(height: 12),
              PawMateButton(
                key: const Key('review-load-more-button'),
                label: _isLoadingMore ? 'Đang tải...' : 'Tải thêm đánh giá',
                onPressed: _isLoadingMore ? null : _loadMore,
                isLoading: _isLoadingMore,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewListTile extends StatelessWidget {
  const _ReviewListTile({required this.review});

  final VetReview review;

  @override
  Widget build(BuildContext context) {
    final body = review.body?.trim();

    return Container(
      key: Key('review-list-item-${review.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${review.starLabel} ${review.title ?? review.reviewer.displayName}',
            style: AppTextStyles.label(),
          ),
          if (body != null && body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(body, style: AppTextStyles.bodyCompact()),
          ],
          const SizedBox(height: 8),
          Text(
            '${review.reviewer.displayName} • ${review.helpfulCount} hữu ích',
            style: AppTextStyles.captionStrong(),
          ),
        ],
      ),
    );
  }
}

class _ReportReviewSheet extends ConsumerStatefulWidget {
  const _ReportReviewSheet({required this.reviewId});

  final String reviewId;

  @override
  ConsumerState<_ReportReviewSheet> createState() => _ReportReviewSheetState();
}

class _ReportReviewSheetState extends ConsumerState<_ReportReviewSheet> {
  final _descriptionController = TextEditingController();
  String _reason = 'spam';
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final accessToken = await ref.read(vetReviewAccessTokenProvider.future);
      if (accessToken == null || accessToken.trim().isEmpty) {
        throw const VetApiException('Bạn cần đăng nhập để báo cáo đánh giá.');
      }

      await ref
          .read(vetApiProvider)
          .reportReview(
            widget.reviewId,
            reason: _reason,
            description: _descriptionController.text,
            accessToken: accessToken,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on VetApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Không gửi được báo cáo. Vui lòng thử lại.';
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
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    const reasons = {
      'spam': 'Spam / quảng cáo',
      'false_information': 'Sai sự thật',
      'abusive': 'Nội dung xấu',
      'off_topic': 'Không liên quan',
      'other': 'Lý do khác',
    };

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.86),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Báo cáo đánh giá', style: AppTextStyles.h3()),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: reasons.entries
                        .map(
                          (entry) => PawMateChip(
                            key: Key('report-reason-${entry.key}'),
                            label: entry.value,
                            selected: _reason == entry.key,
                            enabled: !_isSubmitting,
                            variant: PawMateChipVariant.choice,
                            onPressed: _isSubmitting
                                ? null
                                : () {
                                    setState(() {
                                      _reason = entry.key;
                                    });
                                  },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('report-description-field'),
                    controller: _descriptionController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả thêm',
                      hintText: 'Bổ sung chi tiết nếu cần.',
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      key: const Key('report-review-error'),
                      style: AppTextStyles.bodyStrong(color: AppColors.error),
                    ),
                  ],
                  const SizedBox(height: 18),
                  PawMateButton(
                    key: const Key('report-review-submit'),
                    label: _isSubmitting ? 'Đang gửi...' : 'Gửi báo cáo',
                    onPressed: _isSubmitting ? null : _submitReport,
                    isLoading: _isSubmitting,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceAttributionCard extends StatelessWidget {
  const _SourceAttributionCard({required this.vet});

  final VetDetail vet;

  @override
  Widget build(BuildContext context) {
    final website = vet.website?.trim();
    final sourceMeta = <String>[
      'Nguồn kiểm duyệt: ${vet.source.list}',
      if (website != null && website.isNotEmpty) website,
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.mint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sourceMeta,
            style: AppTextStyles.captionStrong(color: AppColors.primary700),
          ),
          const SizedBox(height: 8),
          Text(vet.source.selectionReason, style: AppTextStyles.bodyCompact()),
        ],
      ),
    );
  }
}

class _VetStateCard extends StatelessWidget {
  const _VetStateCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadows.soft,
          ),
          child: child,
        ),
      ),
    );
  }
}
