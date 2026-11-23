import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_tokens.dart';

class PawMateTextField extends StatelessWidget {
  const PawMateTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.hintText,
    this.helperText,
    this.errorText,
    this.counterText,
    this.labelTrailing,
    this.labelStyle,
    this.labelSpacing = AppSpacing.s8,
    this.fillColor,
    this.contentPadding,
    this.isRequired = false,
    this.showRequiredIndicator = true,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.focusNode,
    this.autofocus = false,
    this.onChanged,
    this.onTap,
    this.onSubmitted,
    this.validator,
    this.inputFormatters,
    this.autovalidateMode,
  }) : assert(
         controller == null || initialValue == null,
         'controller and initialValue cannot both be provided',
       );

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? counterText;
  final Widget? labelTrailing;
  final TextStyle? labelStyle;
  final double labelSpacing;
  final Color? fillColor;
  final EdgeInsetsGeometry? contentPadding;
  final bool isRequired;
  final bool showRequiredIndicator;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final AutovalidateMode? autovalidateMode;

  @override
  Widget build(BuildContext context) {
    final status = PawMateStatusColors.of(context);
    final field = TextFormField(
      controller: controller,
      initialValue: initialValue,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: obscureText ? 1 : maxLines,
      minLines: obscureText ? 1 : minLines,
      maxLength: maxLength,
      focusNode: focusNode,
      autofocus: autofocus,
      onChanged: onChanged,
      onTap: onTap,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      inputFormatters: inputFormatters,
      autovalidateMode: autovalidateMode,
      style: AppTextStyles.field(),
      decoration: InputDecoration(
        hintText: hintText,
        helperText: helperText,
        errorText: errorText,
        counterText: counterText,
        fillColor: fillColor,
        contentPadding: contentPadding,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        prefixIconConstraints: const BoxConstraints(
          minWidth: AppControlSize.minTouchTarget,
          minHeight: AppControlSize.minTouchTarget,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: AppControlSize.minTouchTarget,
          minHeight: AppControlSize.minTouchTarget,
        ),
      ),
    );

    final labelText = ExcludeSemantics(
      child: Text.rich(
        TextSpan(
          text: label,
          children: [
            if (isRequired && showRequiredIndicator)
              TextSpan(
                text: ' *',
                style: TextStyle(color: status.error),
              ),
          ],
        ),
        style: labelStyle ?? AppTextStyles.label(),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (labelTrailing == null)
          labelText
        else
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s4,
            children: [labelText, labelTrailing!],
          ),
        SizedBox(height: labelSpacing),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppControlSize.inputHeight,
          ),
          // Name the native editable surface, not a second text-field
          // wrapper around the visible label and optional label action.
          // Editing value, role and actions remain owned by TextFormField.
          child: Semantics(
            label: isRequired ? '$label, bắt buộc' : label,
            child: field,
          ),
        ),
      ],
    );
  }
}
