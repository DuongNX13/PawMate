import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';

class PawMateAdaptiveBackButton extends StatelessWidget {
  const PawMateAdaptiveBackButton({
    super.key,
    this.onPressed,
    this.semanticLabel = 'Quay lại',
    this.enabled = true,
  });

  final VoidCallback? onPressed;
  final String semanticLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled
          ? onPressed ?? () => Navigator.maybePop(context)
          : null,
      tooltip: semanticLabel,
      icon: const BackButtonIcon(),
    );
  }
}

@immutable
class PawMateAdaptiveAction<T> {
  const PawMateAdaptiveAction({
    this.key,
    required this.label,
    this.value,
    this.icon,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
  });

  final Key? key;
  final String label;
  final T? value;
  final IconData? icon;
  final bool isDefaultAction;
  final bool isDestructiveAction;
}

Future<T?> showPawMateAdaptiveDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  required List<PawMateAdaptiveAction<T>> actions,
  bool? barrierDismissible,
}) {
  final isCupertino = _usesCupertino(context);
  return showAdaptiveDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: PawMateStatusColors.of(context).scrim,
    builder: (dialogContext) {
      if (isCupertino) {
        return CupertinoAlertDialog(
          title: Text(title, style: AppTextStyles.h4()),
          content: message == null
              ? null
              : Text(message, style: AppTextStyles.body()),
          actions: [
            for (final action in actions)
              CupertinoDialogAction(
                isDefaultAction: action.isDefaultAction,
                isDestructiveAction: action.isDestructiveAction,
                onPressed: () => Navigator.of(dialogContext).pop(action.value),
                child: Text(
                  action.label,
                  style: AppTextStyles.label(
                    color: action.isDestructiveAction
                        ? PawMateStatusColors.of(dialogContext).error
                        : AppColors.primary700,
                  ),
                ),
              ),
          ],
        );
      }

      return AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          for (final action in actions)
            TextButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(action.value),
              icon: action.icon == null
                  ? const SizedBox.shrink()
                  : Icon(action.icon),
              label: Text(action.label),
              style: action.isDestructiveAction
                  ? TextButton.styleFrom(
                      foregroundColor: PawMateStatusColors.of(
                        dialogContext,
                      ).error,
                    )
                  : null,
            ),
        ],
      );
    },
  );
}

Future<DateTime?> showPawMateAdaptiveDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? currentDate,
  String title = 'Chọn ngày',
  String cancelLabel = 'Hủy',
  String confirmLabel = 'Xong',
}) {
  if (!_usesCupertino(context)) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      currentDate: currentDate,
      helpText: title,
      cancelText: cancelLabel,
      confirmText: confirmLabel,
    );
  }

  var selected = initialDate;
  return showCupertinoModalPopup<DateTime>(
    context: context,
    barrierColor: PawMateStatusColors.of(context).scrim,
    semanticsDismissible: true,
    builder: (popupContext) => _CupertinoPickerSheet(
      title: title,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
      onCancel: () => Navigator.of(popupContext).pop(),
      onConfirm: () => Navigator.of(popupContext).pop(selected),
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        initialDateTime: initialDate,
        minimumDate: firstDate,
        maximumDate: lastDate,
        backgroundColor: AppColors.surface,
        onDateTimeChanged: (value) => selected = value,
      ),
    ),
  );
}

Future<TimeOfDay?> showPawMateAdaptiveTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String title = 'Chọn giờ',
  String cancelLabel = 'Hủy',
  String confirmLabel = 'Xong',
}) {
  if (!_usesCupertino(context)) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: title,
      cancelText: cancelLabel,
      confirmText: confirmLabel,
    );
  }

  var selected = initialTime;
  final initialDateTime = DateTime(
    2000,
    1,
    1,
    initialTime.hour,
    initialTime.minute,
  );
  return showCupertinoModalPopup<TimeOfDay>(
    context: context,
    barrierColor: PawMateStatusColors.of(context).scrim,
    semanticsDismissible: true,
    builder: (popupContext) => _CupertinoPickerSheet(
      title: title,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
      onCancel: () => Navigator.of(popupContext).pop(),
      onConfirm: () => Navigator.of(popupContext).pop(selected),
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        initialDateTime: initialDateTime,
        use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        backgroundColor: AppColors.surface,
        onDateTimeChanged: (value) {
          selected = TimeOfDay(hour: value.hour, minute: value.minute);
        },
      ),
    ),
  );
}

Future<T?> showPawMateAdaptiveActionSheet<T>({
  required BuildContext context,
  String? title,
  String? message,
  required List<PawMateAdaptiveAction<T>> actions,
  String cancelLabel = 'Hủy',
}) {
  if (_usesCupertino(context)) {
    return showCupertinoModalPopup<T>(
      context: context,
      barrierColor: PawMateStatusColors.of(context).scrim,
      semanticsDismissible: true,
      builder: (sheetContext) => CupertinoActionSheet(
        title: title == null ? null : Text(title, style: AppTextStyles.h4()),
        message: message == null
            ? null
            : Text(message, style: AppTextStyles.body()),
        actions: [
          for (final action in actions)
            CupertinoActionSheetAction(
              key: action.key,
              isDefaultAction: action.isDefaultAction,
              isDestructiveAction: action.isDestructiveAction,
              onPressed: () => Navigator.of(sheetContext).pop(action.value),
              child: Text(
                action.label,
                style: AppTextStyles.bodyStrong(
                  color: action.isDestructiveAction
                      ? PawMateStatusColors.of(sheetContext).error
                      : AppColors.primary700,
                ),
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(cancelLabel, style: AppTextStyles.bodyStrong()),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    barrierColor: PawMateStatusColors.of(context).scrim,
    builder: (sheetContext) => _MaterialActionSheet<T>(
      title: title,
      message: message,
      actions: actions,
      cancelLabel: cancelLabel,
    ),
  );
}

bool _usesCupertino(BuildContext context) =>
    switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };

class _CupertinoPickerSheet extends StatelessWidget {
  const _CupertinoPickerSheet({
    required this.title,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    required this.child,
  });

  final String title;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 340,
          child: Column(
            children: [
              SizedBox(
                height: AppControlSize.minTouchTarget,
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s16,
                        ),
                        onPressed: onCancel,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            cancelLabel,
                            style: AppTextStyles.label(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.label(),
                      ),
                    ),
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s16,
                        ),
                        onPressed: onConfirm,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            confirmLabel,
                            style: AppTextStyles.label(
                              color: AppColors.primary700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: AppBorderWidth.hairline),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialActionSheet<T> extends StatelessWidget {
  const _MaterialActionSheet({
    required this.title,
    required this.message,
    required this.actions,
    required this.cancelLabel,
  });

  final String? title;
  final String? message;
  final List<PawMateAdaptiveAction<T>> actions;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final status = PawMateStatusColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        0,
        AppSpacing.s16,
        AppSpacing.s16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) Text(title!, style: AppTextStyles.h4()),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(message!, style: AppTextStyles.bodyCompact()),
          ],
          if (title != null || message != null)
            const SizedBox(height: AppSpacing.s12),
          for (final action in actions)
            ListTile(
              key: action.key,
              minTileHeight: AppControlSize.minTouchTarget,
              leading: action.icon == null ? null : Icon(action.icon),
              title: Text(
                action.label,
                style: AppTextStyles.bodyStrong(
                  color: action.isDestructiveAction
                      ? status.error
                      : AppColors.textPrimary,
                ),
              ),
              onTap: () => Navigator.of(context).pop(action.value),
            ),
          const Divider(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(cancelLabel),
          ),
        ],
      ),
    );
  }
}
