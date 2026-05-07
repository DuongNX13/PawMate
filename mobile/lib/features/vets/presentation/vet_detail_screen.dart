import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/media/image_picker_service.dart';
import '../../../core/widgets/pawmate_bottom_nav.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../application/vet_providers.dart';
import '../data/vet_api.dart';
import '../domain/vet_models.dart';
import 'vet_actions.dart';

class VetDetailScreen extends ConsumerWidget {
  const VetDetailScreen({super.key, required this.vetId});

  final String vetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vetAsync = ref.watch(vetDetailProvider(vetId));

    return Scaffold(
      bottomNavigationBar: const PawMateBottomNav(currentRoute: '/vets/list'),
      body: SafeArea(
        child: vetAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _VetStateCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Không tải được chi tiết phòng khám',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(error.toString(), style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref.invalidate(vetDetailProvider(vetId)),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
          data: (vet) {
            final reviewsAsync = ref.watch(vetReviewListProvider(vet.id));

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 132),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/vets/list'),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'PawMate',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.primary500,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => context.go('/vets/list'),
                      icon: const Icon(Icons.search_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'PHÒNG KHÁM',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.secondary500,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  vet.name,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  vet.displaySummary,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 28),
                _HeroCard(vet: vet),
                const SizedBox(height: 18),
                _QuickFactsCard(vet: vet),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Gọi ngay',
                        background: AppColors.primary500,
                        textColor: Colors.white,
                        onTap: () => launchVetCall(context, vet.phone),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        label: 'Chỉ đường',
                        background: AppColors.secondarySoft,
                        textColor: AppColors.secondary500,
                        onTap: () => launchVetDirections(context, vet),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        key: const Key('vet-detail-write-review-button'),
                        label: 'Đánh giá',
                        background: AppColors.tertiarySoft,
                        textColor: const Color(0xFF7A6420),
                        onTap: () => _openWriteReview(context, ref, vet),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: vet.displayServices
                      .take(3)
                      .map(
                        (service) => _ServiceChip(
                          label: service,
                          background: service == vet.displayServices.first
                              ? AppColors.primarySoft
                              : AppColors.secondarySoft,
                          textColor: service == vet.displayServices.first
                              ? AppColors.primary700
                              : AppColors.secondary500,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 34),
                Text(
                  'Đánh giá gần đây',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _ReviewPreviewCard(vet: vet, reviewsAsync: reviewsAsync),
                const SizedBox(height: 18),
                _SourceAttributionCard(vet: vet),
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
      const SnackBar(content: Text('Review đã được gửi thành công.')),
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

    throw const VetApiException('Ảnh review chỉ hỗ trợ JPEG, PNG hoặc WEBP.');
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
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
                Text(
                  'Viết đánh giá',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.vet.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
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
                        color: const Color(0xFFFFB547),
                        size: 34,
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
                    hintText: 'Chia sẻ trải nghiệm sau khi sử dụng dịch vụ.',
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
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                PrimaryGradientButton(
                  key: const Key('write-review-submit'),
                  label: _isSubmitting ? 'Đang gửi...' : 'Gửi đánh giá',
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hình ảnh đính kèm',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
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
                    right: 4,
                    top: 4,
                    child: InkWell(
                      key: Key('write-review-remove-photo-${entry.key}'),
                      onTap: () => onRemovePhoto(entry.key),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (photos.length < 3)
              InkWell(
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
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Tối đa 3 ảnh, mỗi ảnh dưới 5MB.',
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.vet});

  final VetDetail vet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = <String>[
      ...vet.displayServices.take(2),
      vet.district,
    ].where((value) => value.trim().isNotEmpty).join(' • ');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.soft,
      ),
      child: Stack(
        children: [
          Positioned(
            right: 16,
            top: 0,
            child: Container(
              width: 148,
              height: 148,
              decoration: const BoxDecoration(
                color: Color(0xFFFCE1D4),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 40,
            top: 40,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: Color(0xFFA8C5F1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroBadge(
                label: vet.averageRating != null
                    ? '★ ${vet.averageRating!.toStringAsFixed(1)}'
                    : 'Top #${vet.seedRank}',
              ),
              const SizedBox(height: 42),
              SizedBox(
                width: 220,
                child: Text(
                  vet.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 240,
                child: Text(
                  meta,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickFactsCard extends StatelessWidget {
  const _QuickFactsCard({required this.vet});

  final VetDetail vet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final website = vet.website?.trim();
    final utilityLine = <String>[
      vet.phone,
      if (website != null && website.isNotEmpty) website,
      if (website == null || website.isEmpty) ...vet.displayServices.take(2),
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${vet.address} • ${_openingSummary(vet)}',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            utilityLine,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _openingSummary(VetDetail vet) {
    if (vet.is24h == true) {
      return 'Mở 24/7';
    }

    final match = RegExp(
      r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})',
    ).firstMatch(vet.openingNote);
    if (match != null) {
      return 'Mở đến ${match.group(2)}';
    }

    if (vet.isOpen == true) {
      return 'Đang mở cửa';
    }
    if (vet.isOpen == false) {
      return 'Tạm đóng';
    }

    return 'Giờ đang cập nhật';
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.background,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        height: 78,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({
    required this.label,
    required this.background,
    required this.textColor,
  });

  final String label;
  final Color background;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReviewPreviewCard extends ConsumerWidget {
  const _ReviewPreviewCard({required this.vet, required this.reviewsAsync});

  final VetDetail vet;
  final AsyncValue<VetReviewResult> reviewsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ratingLabel = vet.averageRating != null
        ? '${vet.averageRating!.toStringAsFixed(1)} sao'
        : 'Đang chờ review thật';
    final body = vet.reviewCount > 0
        ? 'Hiện có ${vet.reviewCount} lượt đánh giá trong nguồn kiểm duyệt. Khu vực này đã được khóa layout để nối review thật ở Day 4 mà không lệch màn.'
        : 'Khối review đã được chừa đúng vị trí theo Figma. Khi bật dữ liệu thật, card này sẽ nhận review mới nhất mà không cần refactor vet detail.';

    final liveBody = reviewsAsync.maybeWhen(
      loading: () => 'Đang tải review thật từ PawMate...',
      error: (error, _) => 'Chưa tải được review: $error',
      data: (reviews) {
        final latestReview = reviews.items.isNotEmpty
            ? reviews.items.first
            : null;
        if (latestReview == null) {
          return 'Chưa có review PawMate cho ${vet.name}. Form đánh giá đã sẵn sàng để nhận review đầu tiên.';
        }

        return '${latestReview.starLabel} ${latestReview.title ?? latestReview.reviewer.displayName}\n${latestReview.body ?? 'Người dùng chưa nhập nội dung chi tiết.'}\n${reviews.summary.reviewCount} review - ${latestReview.helpfulCount} hữu ích';
      },
      orElse: () => body,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đánh giá PawMate • $ratingLabel',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            liveBody,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
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
                        label: const Text('Xem danh sách review'),
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
    final theme = Theme.of(context);
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
              : '${summary.averageRating!.toStringAsFixed(1)} / 5 từ ${summary.reviewCount} review',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
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
                  child: Text(
                    '$rating★',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
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
        _errorMessage = 'Không tải thêm được review. Vui lòng thử lại.';
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
    final theme = Theme.of(context);

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
              'Review ${widget.vet.name}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _RatingDistributionChart(summary: _summary),
            const SizedBox(height: 12),
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Text(
                        'Chưa có review nào.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
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
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (_nextCursor != null) ...[
              const SizedBox(height: 12),
              PrimaryGradientButton(
                key: const Key('review-load-more-button'),
                label: _isLoadingMore ? 'Đang tải...' : 'Tải thêm review',
                onPressed: _isLoadingMore ? null : _loadMore,
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
    final theme = Theme.of(context);
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
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (body != null && body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${review.reviewer.displayName} • ${review.helpfulCount} hữu ích',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
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
        throw const VetApiException('Bạn cần đăng nhập để báo cáo review.');
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
    final theme = Theme.of(context);
    const reasons = {
      'spam': 'Spam / quảng cáo',
      'false_information': 'Sai sự thật',
      'abusive': 'Nội dung xấu',
      'off_topic': 'Không liên quan',
      'other': 'Lý do khác',
    };

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Báo cáo review',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: reasons.entries
                  .map(
                    (entry) => ChoiceChip(
                      key: Key('report-reason-${entry.key}'),
                      label: Text(entry.value),
                      selected: _reason == entry.key,
                      onSelected: _isSubmitting
                          ? null
                          : (selected) {
                              if (!selected) {
                                return;
                              }
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
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 18),
            PrimaryGradientButton(
              key: const Key('report-review-submit'),
              label: _isSubmitting ? 'Đang gửi...' : 'Gửi báo cáo',
              onPressed: _isSubmitting ? null : _submitReport,
            ),
          ],
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
    final theme = Theme.of(context);
    final website = vet.website?.trim();
    final sourceMeta = <String>[
      'Nguồn kiểm duyệt: ${vet.source.list}',
      if (website != null && website.isNotEmpty) website,
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFE5D5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sourceMeta,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.primary700,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            vet.source.selectionReason,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.tertiarySoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: const Color(0xFF8A6B1D),
          fontWeight: FontWeight.w800,
        ),
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
