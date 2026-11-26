import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_auth_layout.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../data/auth_api.dart';
import 'auth_return_route.dart';

/// Post-register screen for link-based email verification: the user opens the
/// link in the email, then signs in. The backend confirms the link with the
/// auth provider at login, so no code is typed here.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({
    super.key,
    this.email,
    this.resendAvailableAt,
    this.returnTo,
    this.now,
  });

  final String? email;
  final DateTime? resendAvailableAt;
  final String? returnTo;
  final DateTime Function()? now;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _resendCooldown = Duration(seconds: 60);

  late DateTime _currentTime;
  late DateTime _resendAt;
  Timer? _timer;
  bool _isResending = false;
  String? _errorText;

  String get _email => widget.email?.trim() ?? '';
  DateTime _readNow() => widget.now?.call() ?? DateTime.now();

  int get _resendSecondsLeft {
    final milliseconds = _resendAt.difference(_currentTime).inMilliseconds;
    return milliseconds <= 0 ? 0 : (milliseconds + 999) ~/ 1000;
  }

  @override
  void initState() {
    super.initState();
    _currentTime = _readNow();
    _resendAt = widget.resendAvailableAt ?? _currentTime.add(_resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (mounted) setState(() => _currentTime = _readNow());
  }

  Future<void> _resend() async {
    if (_isResending || _email.isEmpty || _resendSecondsLeft > 0) return;
    setState(() {
      _isResending = true;
      _errorText = null;
    });
    try {
      final response = await ref
          .read(authApiProvider)
          .resendVerification(email: _email);
      if (!mounted) return;
      final now = _readNow();
      setState(() {
        _currentTime = now;
        _resendAt = response.resendAvailableAt ?? now.add(_resendCooldown);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(response.message)));
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _errorText = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorText = 'Không thể gửi lại email. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _openLogin() {
    context.go(
      Uri(
        path: '/auth/login',
        queryParameters: authQueryParameters(
          values: {if (_email.isNotEmpty) 'email': _email},
          returnTo: widget.returnTo,
        ),
      ).toString(),
    );
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
    final gap = PawMateAuthLayout.sectionGap(context, regular: 24, compact: 16);
    final size = PawMateAuthLayout.illustrationSize(context);
    final secondsLeft = _resendSecondsLeft;
    final canResend = secondsLeft == 0 && !_isResending && _email.isNotEmpty;
    return Scaffold(
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        key: const ValueKey('verify-email-back-button'),
                        tooltip: 'Quay lại đăng ký',
                        onPressed: _openRegister,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    SizedBox(height: gap),
                    Image.asset(
                      'assets/images/auth/otp_verification_dog.png',
                      height: size,
                      excludeFromSemantics: true,
                    ),
                    SizedBox(height: gap),
                    Text(
                      'Kiểm tra hộp thư của bạn',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h2(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _email.isEmpty
                          ? 'Mở email xác minh và bấm vào link trong đó, rồi quay lại đăng nhập.'
                          : 'Chúng tôi đã gửi link xác minh đến ${maskEmailForDisplay(_email)}. Mở email, bấm vào link, rồi quay lại đăng nhập.',
                      key: const ValueKey('verify-email-message'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyCompact(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorText!,
                        key: const ValueKey('verify-email-error'),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyCompact(
                          color: AppColors.error,
                        ),
                      ),
                    ],
                    SizedBox(height: gap),
                    TextButton(
                      key: const ValueKey('verify-email-resend-button'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(
                          AppControlSize.minTouchTarget,
                          AppControlSize.minTouchTarget,
                        ),
                      ),
                      onPressed: canResend ? _resend : null,
                      child: Text(
                        _isResending
                            ? 'Đang gửi...'
                            : secondsLeft == 0
                            ? 'Gửi lại email'
                            : 'Gửi lại email (${secondsLeft}s)',
                        style: AppTextStyles.label(
                          color: canResend
                              ? AppColors.primary500
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
              child: PawMateButton(
                key: const ValueKey('verify-email-login-button'),
                label: 'Tôi đã xác minh, đăng nhập',
                trailingIcon: Icons.chevron_right_rounded,
                compact: true,
                onPressed: _openLogin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String maskEmailForDisplay(String value) {
  final text = value.trim();
  final at = text.indexOf('@');
  if (at < 0) return text;
  final local = text.substring(0, at);
  final first = local.isEmpty ? '*' : local.substring(0, 1);
  return '$first***${text.substring(at)}';
}
