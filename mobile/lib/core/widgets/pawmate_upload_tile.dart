import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';

enum PawMateUploadState { empty, uploading, uploaded, error, disabled }

class PawMateUploadTile extends StatelessWidget {
  const PawMateUploadTile({
    super.key,
    required this.label,
    required this.state,
    this.onPick,
    this.onRetry,
    this.onRemove,
    this.preview,
    this.progress,
    this.errorMessage,
    this.acceptedMediaLabel = 'Ảnh hoặc video',
  });

  final String label;
  final PawMateUploadState state;
  final VoidCallback? onPick;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;
  final Widget? preview;
  final double? progress;
  final String? errorMessage;
  final String acceptedMediaLabel;

  bool get _isEnabled => state != PawMateUploadState.disabled;

  VoidCallback? get _primaryAction => switch (state) {
    PawMateUploadState.error => onRetry,
    PawMateUploadState.uploading || PawMateUploadState.disabled => null,
    PawMateUploadState.empty || PawMateUploadState.uploaded => onPick,
  };

  @override
  Widget build(BuildContext context) {
    final status = PawMateStatusColors.of(context);
    final border = state == PawMateUploadState.error
        ? status.error
        : AppColors.borderStrong;
    const background = AppColors.surface;

    final tile = Semantics(
      container: true,
      button: _primaryAction != null,
      enabled: _isEnabled,
      label: _semanticLabel,
      value: _semanticValue,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: _primaryAction,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              constraints: const BoxConstraints(minHeight: 120),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: background,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: _buildContent(context),
              ),
            ),
          ),
        ),
      ),
    );

    if (state != PawMateUploadState.uploaded || onRemove == null) {
      return tile;
    }

    return Stack(
      children: [
        tile,
        Positioned(
          top: AppSpacing.s4,
          right: AppSpacing.s4,
          child: Semantics(
            button: true,
            enabled: true,
            label: 'Xóa tệp đã tải lên',
            child: ExcludeSemantics(
              child: IconButton(
                onPressed: onRemove,
                tooltip: 'Xóa tệp đã tải lên',
                icon: const Icon(Icons.close),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) => switch (state) {
    PawMateUploadState.empty => _UploadMessage(
      icon: Icons.add_photo_alternate_outlined,
      title: label,
      message: acceptedMediaLabel,
      color: AppColors.primary700,
    ),
    PawMateUploadState.uploading => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LinearProgressIndicator(
          value: progress,
          color: AppColors.primary500,
          backgroundColor: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        const SizedBox(height: AppSpacing.s12),
        Text('Đang tải $label', style: AppTextStyles.label()),
      ],
    ),
    PawMateUploadState.uploaded =>
      preview ??
          _UploadMessage(
            icon: Icons.check_circle_outline,
            title: 'Đã tải $label',
            message: 'Chạm để thay thế',
            color: AppColors.careGreenStrong,
          ),
    PawMateUploadState.error => _UploadMessage(
      icon: Icons.error_outline,
      title: 'Tải lên thất bại',
      message: errorMessage ?? 'Chạm để thử lại',
      color: AppColors.error,
    ),
    PawMateUploadState.disabled => _UploadMessage(
      icon: Icons.image_not_supported_outlined,
      title: label,
      message: 'Tạm thời không khả dụng',
      color: AppColors.textMuted,
    ),
  };

  String get _semanticLabel => switch (state) {
    PawMateUploadState.empty => '$label, thêm $acceptedMediaLabel',
    PawMateUploadState.uploading => '$label, đang tải lên',
    PawMateUploadState.uploaded => '$label, đã tải lên',
    PawMateUploadState.error => '$label, tải lên thất bại, thử lại',
    PawMateUploadState.disabled => '$label, không khả dụng',
  };

  String? get _semanticValue =>
      state == PawMateUploadState.uploading && progress != null
      ? '${(progress! * 100).round()} phần trăm'
      : null;
}

class _UploadMessage extends StatelessWidget {
  const _UploadMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: AppSpacing.s8),
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.label(color: color),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.caption(),
        ),
      ],
    );
  }
}
