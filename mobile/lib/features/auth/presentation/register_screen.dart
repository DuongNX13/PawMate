import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_adaptive.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_text_field.dart';
import '../data/auth_api.dart';
import 'auth_qa_defaults.dart';
import 'auth_return_route.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.initialEmail, this.returnTo});

  final String? initialEmail;
  final String? returnTo;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _recoveryCtaAnchorKey = GlobalKey();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  String? _emailApiError;
  String? _passwordApiError;
  String? _generalError;

  bool get _canSubmit {
    if (_isSubmitting) {
      return false;
    }
    return _validateEmail(_emailController.text) == null &&
        _validatePhone(_phoneController.text) == null &&
        _validatePassword(_passwordController.text) == null &&
        _validateConfirmPassword(_confirmPasswordController.text) == null;
  }

  @override
  void initState() {
    super.initState();
    if (pawmateQaPrefillAuth) {
      _emailController.text = pawmateQaAuthEmail;
      _phoneController.text = '0901234567';
      _passwordController.text = pawmateQaAuthPassword;
      _confirmPasswordController.text = pawmateQaAuthPassword;
    } else {
      _emailController.text = widget.initialEmail?.trim() ?? '';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (email.isEmpty) {
      return 'Vui lòng nhập email';
    }
    if (email.length > 254) {
      return 'Email tối đa 254 ký tự';
    }
    if (!regex.hasMatch(email)) {
      return 'Email chưa đúng định dạng';
    }
    return _emailApiError;
  }

  String? _validatePhone(String? value) {
    final phone = (value ?? '').trim();
    if (phone.isEmpty) {
      return 'Vui lòng nhập số điện thoại';
    }
    if (!RegExp(r'^0[0-9]{9,10}$').hasMatch(phone)) {
      return 'Số điện thoại cần 10-11 chữ số và bắt đầu bằng 0';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 8) {
      return 'Mật khẩu tối thiểu 8 ký tự';
    }
    if (password.length > 64) {
      return 'Mật khẩu tối đa 64 ký tự';
    }
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    if (!hasLetter || !hasNumber) {
      return 'Mật khẩu cần có chữ và số';
    }
    return _passwordApiError;
  }

  String? _validateConfirmPassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Vui lòng nhập lại mật khẩu';
    }
    if (password.length > 64) {
      return 'Mật khẩu tối đa 64 ký tự';
    }
    if (password != _passwordController.text) {
      return 'Mật khẩu xác nhận không khớp';
    }
    return null;
  }

  void _onFieldChanged({bool email = false, bool password = false}) {
    setState(() {
      if (email) {
        _emailApiError = null;
      }
      if (password) {
        _passwordApiError = null;
      }
      _generalError = null;
    });
  }

  void _openLogin() {
    final email = _emailController.text.trim();
    context.go(
      Uri(
        path: '/auth/login',
        queryParameters: authQueryParameters(
          values: {if (email.isNotEmpty) 'email': email},
          returnTo: widget.returnTo,
        ),
      ).toString(),
    );
  }

  void _revealRecoveryCta() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final anchorContext = _recoveryCtaAnchorKey.currentContext;
      if (anchorContext == null) {
        return;
      }
      unawaited(
        Scrollable.ensureVisible(
          anchorContext,
          alignment: 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    setState(() {
      _emailApiError = null;
      _passwordApiError = null;
      _generalError = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final email = _emailController.text.trim();
      final response = await ref
          .read(authApiProvider)
          .register(
            email: email,
            password: _passwordController.text,
            phone: _phoneController.text.trim(),
          );
      if (!mounted) {
        return;
      }

      if (!response.requiresVerification) {
        context.go(
          Uri(
            path: '/auth/login',
            queryParameters: authQueryParameters(
              values: {'email': email, 'verified': '1'},
              returnTo: widget.returnTo,
            ),
          ).toString(),
        );
        return;
      }

      final now = DateTime.now();
      final expiresAt =
          response.verificationExpiresAt ?? now.add(const Duration(minutes: 5));
      final resendAt =
          response.resendAvailableAt ?? now.add(const Duration(seconds: 60));
      context.go(
        Uri(
          path: '/auth/otp',
          queryParameters: authQueryParameters(
            values: {
              'email': email,
              'registrationId': response.userId,
              'expiresAt': expiresAt.millisecondsSinceEpoch.toString(),
              'resendAt': resendAt.millisecondsSinceEpoch.toString(),
            },
            returnTo: widget.returnTo,
          ),
        ).toString(),
      );
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (error.field == 'email') {
          _emailApiError = error.message;
        } else if (error.field == 'password') {
          _passwordApiError = error.message;
        } else {
          _generalError = error.message;
        }
      });
      _formKey.currentState?.validate();
      _revealRecoveryCta();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _generalError = 'Không thể tạo tài khoản. Vui lòng thử lại.';
      });
      _revealRecoveryCta();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 224,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Semantics(
                        image: true,
                        label:
                            'Minh họa chó cưng chào đón người dùng tạo tài khoản',
                        child: ExcludeSemantics(
                          child: Image.asset(
                            'assets/images/auth/register_dog.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const ColoredBox(
                                  color: AppColors.careGreenSoft,
                                  child: Center(
                                    child: Icon(
                                      Icons.pets_rounded,
                                      size: 64,
                                      color: AppColors.primary500,
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      top: 16,
                      child: IconButtonTheme(
                        data: IconButtonThemeData(
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.white.withValues(
                              alpha: 0.84,
                            ),
                            minimumSize: const Size(
                              AppControlSize.minTouchTarget,
                              AppControlSize.minTouchTarget,
                            ),
                          ),
                        ),
                        child: PawMateAdaptiveBackButton(
                          enabled: !_isSubmitting,
                          onPressed: _openLogin,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Tạo tài khoản', style: AppTextStyles.h1()),
                      const SizedBox(height: 8),
                      Text(
                        'Hãy cùng bắt đầu hành trình chăm sóc thú cưng của bạn',
                        style: AppTextStyles.bodyStrong(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      PawMateTextField(
                        key: const ValueKey('register-email-field'),
                        label: 'Email',
                        isRequired: true,
                        enabled: !_isSubmitting,
                        controller: _emailController,
                        hintText: 'example@gmail.com',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        maxLength: 254,
                        validator: _validateEmail,
                        onChanged: (_) => _onFieldChanged(email: true),
                      ),
                      const SizedBox(height: 16),
                      PawMateTextField(
                        key: const ValueKey('register-phone-field'),
                        label: 'Số điện thoại',
                        isRequired: true,
                        enabled: !_isSubmitting,
                        controller: _phoneController,
                        hintText: '09xx xxx xxx',
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        maxLength: 11,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: _validatePhone,
                        onChanged: (_) => _onFieldChanged(),
                      ),
                      const SizedBox(height: 16),
                      PawMateTextField(
                        key: const ValueKey('register-password-field'),
                        label: 'Mật khẩu',
                        isRequired: true,
                        enabled: !_isSubmitting,
                        controller: _passwordController,
                        hintText: '••••••••',
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        maxLength: 64,
                        validator: _validatePassword,
                        suffixIcon: IconButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                          tooltip: _obscurePassword
                              ? 'Hiện mật khẩu'
                              : 'Ẩn mật khẩu',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                        onChanged: (_) => _onFieldChanged(password: true),
                      ),
                      const SizedBox(height: 16),
                      PawMateTextField(
                        key: const ValueKey('register-confirm-password-field'),
                        label: 'Nhập lại mật khẩu',
                        isRequired: true,
                        enabled: !_isSubmitting,
                        controller: _confirmPasswordController,
                        hintText: '••••••••',
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        maxLength: 64,
                        validator: _validateConfirmPassword,
                        suffixIcon: IconButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                          tooltip: _obscureConfirmPassword
                              ? 'Hiện mật khẩu xác nhận'
                              : 'Ẩn mật khẩu xác nhận',
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                        onChanged: (_) => _onFieldChanged(),
                        onSubmitted: (_) {
                          if (_canSubmit) {
                            _submit();
                          }
                        },
                      ),
                      if (_generalError != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          label: 'Lỗi đăng ký: $_generalError',
                          child: Container(
                            key: const ValueKey('register-general-error'),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorSoft,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.error),
                            ),
                            child: Text(
                              _generalError!,
                              style: AppTextStyles.body(
                                color: AppColors.error,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      KeyedSubtree(
                        key: _recoveryCtaAnchorKey,
                        child: PawMateButton(
                          key: const ValueKey('register-submit-button'),
                          label: 'Tạo tài khoản',
                          isLoading: _isSubmitting,
                          onPressed: _canSubmit ? _submit : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(
                            AppControlSize.minTouchTarget,
                            AppControlSize.minTouchTarget,
                          ),
                        ),
                        onPressed: _isSubmitting ? null : _openLogin,
                        child: Text.rich(
                          TextSpan(
                            text: 'Đã có tài khoản? ',
                            style: AppTextStyles.bodyStrong(
                              color: AppColors.label,
                            ),
                            children: [
                              TextSpan(
                                text: 'Đăng nhập ngay',
                                style: AppTextStyles.bodyStrong(
                                  color: AppColors.primary700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
