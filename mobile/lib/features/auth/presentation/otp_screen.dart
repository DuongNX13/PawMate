import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_adaptive.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../application/auth_session_coordinator.dart';
import '../data/auth_api.dart';
import 'auth_return_route.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    super.key,
    this.email,
    this.registrationId,
    this.verificationExpiresAt,
    this.resendAvailableAt,
    this.returnTo,
    this.now,
  });

  final String? email;
  final String? registrationId;
  final DateTime? verificationExpiresAt;
  final DateTime? resendAvailableAt;
  final String? returnTo;
  final DateTime Function()? now;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with WidgetsBindingObserver {
  static const _verificationTtl = Duration(minutes: 5);
  static const _resendCooldown = Duration(seconds: 60);

  late final TextEditingController _otpController;
  late DateTime _currentTime;
  late DateTime _expiresAt;
  late DateTime _resendAt;
  Timer? _timer;
  bool _isSubmitting = false;
  bool _isResending = false;
  bool _forceExpired = false;
  String? _errorText;

  String get _email => widget.email?.trim() ?? '';
  DateTime _readNow() => widget.now?.call() ?? DateTime.now();
  bool get _isExpired => _forceExpired || !_currentTime.isBefore(_expiresAt);
  bool get _canSubmit =>
      !_isExpired &&
      _otpController.text.length == 6 &&
      !_isSubmitting &&
      _email.isNotEmpty;

  int get _resendSecondsLeft {
    final milliseconds = _resendAt.difference(_currentTime).inMilliseconds;
    if (milliseconds <= 0) {
      return 0;
    }
    return (milliseconds + 999) ~/ 1000;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _otpController = TextEditingController();
    _currentTime = _readNow();
    _expiresAt =
        widget.verificationExpiresAt ?? _currentTime.add(_verificationTtl);
    _resendAt = widget.resendAvailableAt ?? _currentTime.add(_resendCooldown);
    _startClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncClock();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startClock() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _syncClock());
  }

  void _syncClock() {
    if (!mounted) {
      return;
    }
    final wasExpired = _isExpired;
    setState(() {
      _currentTime = _readNow();
      if (!wasExpired && _isExpired) {
        _errorText = 'Mã OTP đã hết hạn. Vui lòng gửi lại mã mới.';
      }
    });
  }

  Future<void> _persistAuthenticatedSession(AuthSession session) async {
    await ref.read(authSessionCoordinatorProvider).saveSession(session);
    ref.invalidate(authSessionSnapshotProvider);
  }

  Future<void> _submitOtp() async {
    if (_isSubmitting || _email.isEmpty) {
      return;
    }
    _syncClock();
    if (_isExpired) {
      setState(() {
        _forceExpired = true;
        _errorText = 'Mã OTP đã hết hạn. Vui lòng gửi lại mã mới.';
      });
      return;
    }
    if (_otpController.text.length != 6) {
      setState(() {
        _errorText = 'Mã OTP cần đủ 6 số. Vui lòng kiểm tra lại.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final response = await ref
          .read(authApiProvider)
          .verifyEmail(email: _email, token: _otpController.text);

      if (response.session != null) {
        await _persistAuthenticatedSession(response.session!);
      }
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(response.message)));
      if (response.session != null) {
        context.go(resolveAuthenticatedReturnRoute(widget.returnTo));
      } else {
        context.go(
          Uri(
            path: '/auth/login',
            queryParameters: authQueryParameters(
              values: {'email': _email, 'verified': '1'},
              returnTo: widget.returnTo,
            ),
          ).toString(),
        );
      }
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      final expired =
          error.code == 'AUTH_017' ||
          error.message.toLowerCase().contains('hết hạn');
      setState(() {
        _forceExpired = expired;
        _errorText = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText =
            'Xác minh chưa hoàn tất hoặc không thể lưu phiên đăng nhập. Vui lòng thử lại.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    _syncClock();
    if (_resendSecondsLeft != 0 || _isResending || _email.isEmpty) {
      return;
    }

    setState(() {
      _isResending = true;
      _errorText = null;
    });

    try {
      final response = await ref
          .read(authApiProvider)
          .resendVerification(email: _email);
      if (!mounted) {
        return;
      }

      if (response.verificationStatus == 'verified') {
        context.go(
          Uri(
            path: '/auth/login',
            queryParameters: authQueryParameters(
              values: {'email': _email, 'verified': '1'},
              returnTo: widget.returnTo,
            ),
          ).toString(),
        );
        return;
      }

      final now = _readNow();
      setState(() {
        _currentTime = now;
        _expiresAt =
            response.verificationExpiresAt ?? now.add(_verificationTtl);
        _resendAt = response.resendAvailableAt ?? now.add(_resendCooldown);
        _forceExpired = false;
        _errorText = null;
        _otpController.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(response.message)));
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorText = error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = 'Không thể gửi lại mã xác minh. Vui lòng thử lại.';
      });
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _openRegister() {
    context.go(
      Uri(
        path: '/auth/register',
        queryParameters: authQueryParameters(
          values: {if (_email.isNotEmpty) 'email': _email},
          returnTo: widget.returnTo,
        ),
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_email.isEmpty) {
      return _MissingEmailState(onRegister: _openRegister);
    }
    if (_isExpired) {
      return _ExpiredOtpState(
        email: _email,
        errorText: _errorText,
        isResending: _isResending,
        canResend: _resendSecondsLeft == 0,
        onResend: _resendOtp,
        onChangeEmail: _openRegister,
      );
    }
    return _buildOtpForm(context);
  }

  Widget _buildOtpForm(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OtpHeader(onBack: _openRegister),
                    const SizedBox(height: 24),
                    const _OtpIllustration(
                      assetPath: 'assets/images/auth/otp_verification_dog.png',
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Xác minh mã OTP',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h2(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Mã xác thực đã được gửi đến email ${_maskedDestination(_email)}. Vui lòng kiểm tra hộp thư của bạn.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    Semantics(
                      label: 'Nhập mã OTP gồm 6 chữ số',
                      textField: true,
                      child: PinCodeTextField(
                        key: const ValueKey('otp-code-field'),
                        appContext: context,
                        length: 6,
                        controller: _otpController,
                        autoDisposeControllers: false,
                        enabled: !_isSubmitting && !_isResending,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        autoFocus: true,
                        animationType: AnimationType.scale,
                        textStyle: AppTextStyles.h3(),
                        cursorColor: AppColors.primary500,
                        onChanged: (_) {
                          setState(() => _errorText = null);
                        },
                        onCompleted: (_) => setState(() {}),
                        pinTheme: PinTheme(
                          shape: PinCodeFieldShape.box,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          fieldHeight: 48,
                          fieldWidth: 44,
                          activeColor: AppColors.primary500,
                          selectedColor: AppColors.primary700,
                          inactiveColor: AppColors.borderStrong,
                          errorBorderColor: AppColors.error,
                        ),
                      ),
                    ),
                    _OtpErrorArea(errorText: _errorText),
                    const SizedBox(height: 12),
                    _ResendOtpRow(
                      secondsLeft: _resendSecondsLeft,
                      isResending: _isResending,
                      onResend: _resendSecondsLeft == 0 && !_isResending
                          ? _resendOtp
                          : null,
                    ),
                    const SizedBox(height: 24),
                    const _SystemReadyNote(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
              child: PawMateButton(
                key: const ValueKey('otp-confirm-button'),
                label: 'Xác minh',
                isLoading: _isSubmitting,
                trailingIcon: Icons.chevron_right_rounded,
                onPressed: _canSubmit ? _submitOtp : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingEmailState extends StatelessWidget {
  const _MissingEmailState({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OtpHeader(onBack: onRegister),
              const SizedBox(height: AppSpacing.s48),
              const _OtpIllustration(
                assetPath: 'assets/images/auth/otp_verification_dog.png',
              ),
              const SizedBox(height: 24),
              Text(
                'Không tìm thấy email cần xác minh',
                textAlign: TextAlign.center,
                style: AppTextStyles.h2(),
              ),
              const SizedBox(height: 12),
              Text(
                'Hãy đăng ký lại để nhận mã xác minh mới.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyStrong(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              PawMateButton(label: 'Quay lại đăng ký', onPressed: onRegister),
              const SizedBox(height: AppSpacing.s24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpiredOtpState extends StatelessWidget {
  const _ExpiredOtpState({
    required this.email,
    required this.errorText,
    required this.isResending,
    required this.canResend,
    required this.onResend,
    required this.onChangeEmail,
  });

  final String email;
  final String? errorText;
  final bool isResending;
  final bool canResend;
  final VoidCallback onResend;
  final VoidCallback onChangeEmail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('otp-expired-state'),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OtpHeader(onBack: onChangeEmail),
                    const SizedBox(height: 20),
                    const _OtpIllustration(
                      assetPath: 'assets/images/auth/otp_expired_dog.png',
                      size: 196,
                      circular: false,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Mã xác thực đã hết hạn',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h2(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Thời gian nhập mã đã kết thúc. Vui lòng gửi lại mã mới đến ${_maskedDestination(email)} để tiếp tục xác minh tài khoản.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        6,
                        (index) => Container(
                          width: 44,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.errorSoft),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            '-',
                            style: AppTextStyles.h3(color: AppColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _OtpErrorArea(
                      errorText:
                          errorText ??
                          'Mã OTP đã hết hiệu lực. Vui lòng thử lại.',
                    ),
                    const SizedBox(height: 20),
                    const _SystemReadyNote(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
              child: Column(
                children: [
                  PawMateButton(
                    key: const ValueKey('otp-resend-expired-button'),
                    label: 'Gửi lại mã',
                    isLoading: isResending,
                    onPressed: canResend && !isResending ? onResend : null,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey('otp-change-email-button'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(
                        AppControlSize.minTouchTarget,
                        AppControlSize.minTouchTarget,
                      ),
                    ),
                    onPressed: isResending ? null : onChangeEmail,
                    child: Text(
                      'Đổi địa chỉ email',
                      style: AppTextStyles.label(color: AppColors.primary500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpHeader extends StatelessWidget {
  const _OtpHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppControlSize.minTouchTarget,
      child: Row(
        children: [
          PawMateAdaptiveBackButton(onPressed: onBack),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              'Xác minh tài khoản',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h3(),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpIllustration extends StatelessWidget {
  const _OtpIllustration({
    required this.assetPath,
    this.size = 132,
    this.circular = true,
  });

  final String assetPath;
  final double size;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        color: AppColors.careGreenSoft,
        alignment: Alignment.center,
        child: const Icon(
          Icons.pets_rounded,
          size: 52,
          color: AppColors.primary500,
        ),
      ),
    );
    return Semantics(
      image: true,
      label: 'Minh họa chó cưng cho bước xác minh tài khoản',
      child: ExcludeSemantics(
        child: Center(
          child: circular
              ? ClipOval(child: image)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: image,
                ),
        ),
      ),
    );
  }
}

class _OtpErrorArea extends StatelessWidget {
  const _OtpErrorArea({required this.errorText});

  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final message = errorText ?? ' ';
    return Semantics(
      liveRegion: errorText != null,
      label: errorText == null ? null : 'Lỗi OTP: $errorText',
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        child: Row(
          key: ValueKey(message),
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: errorText == null ? Colors.transparent : AppColors.error,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.captionStrong(
                  color: errorText == null
                      ? Colors.transparent
                      : AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResendOtpRow extends StatelessWidget {
  const _ResendOtpRow({
    required this.secondsLeft,
    required this.isResending,
    required this.onResend,
  });

  final int secondsLeft;
  final bool isResending;
  final VoidCallback? onResend;

  @override
  Widget build(BuildContext context) {
    final resendText = secondsLeft == 0
        ? 'Gửi lại mã'
        : 'Gửi lại mã (${secondsLeft}s)';
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s4,
      children: [
        Text(
          'Không nhận được mã?',
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        TextButton(
          key: const ValueKey('otp-resend-button'),
          style: TextButton.styleFrom(
            minimumSize: const Size(
              AppControlSize.minTouchTarget,
              AppControlSize.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
          ),
          onPressed: onResend,
          child: Text(
            isResending ? 'Đang gửi...' : resendText,
            style: AppTextStyles.label(
              color: onResend == null && !isResending
                  ? AppColors.textMuted
                  : AppColors.primary500,
            ),
          ),
        ),
      ],
    );
  }
}

class _SystemReadyNote extends StatelessWidget {
  const _SystemReadyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.careGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'HỆ THỐNG ĐANG SẴN SÀNG',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.overline(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

String _maskedDestination(String value) {
  final text = value.trim();
  if (!text.contains('@')) {
    return text;
  }
  final parts = text.split('@');
  final local = parts.first;
  final domain = parts.length > 1 ? parts.last : '';
  final first = local.isEmpty ? '*' : local.substring(0, 1);
  return '$first***@$domain';
}
