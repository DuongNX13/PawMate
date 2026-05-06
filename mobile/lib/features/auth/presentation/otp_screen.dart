import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../data/auth_api.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  late final TextEditingController _otpController;
  Timer? _timer;
  int _secondsLeft = 60;
  bool _isSubmitting = false;
  bool _isResending = false;

  String get _email => widget.email?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _otpController = TextEditingController();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _secondsLeft = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft == 0) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft -= 1;
      });
    });
    setState(() {});
  }

  Future<void> _submitOtp() async {
    if (_otpController.text.length != 6 || _isSubmitting || _email.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await ref
          .read(authApiProvider)
          .verifyEmail(email: _email, token: _otpController.text);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(response.message)));
      context.go('/auth/login?email=${Uri.encodeComponent(_email)}&verified=1');
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xác minh thất bại. Vui lòng thử lại.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_secondsLeft != 0 || _isResending || _email.isEmpty) {
      return;
    }

    setState(() {
      _isResending = true;
    });

    try {
      final message = await ref
          .read(authApiProvider)
          .resendVerification(email: _email);

      _otpController.clear();
      _startCountdown();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể gửi lại mã xác minh.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_email.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Xác minh OTP')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Không tìm thấy email cần xác minh. Hãy đăng ký lại để nhận mã mới.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/auth/register'),
                  child: const Text('Quay lại đăng ký'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Xác minh OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Nhập mã OTP gồm 6 số đã được gửi tới $_email.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Nếu link email bị lỗi hoặc hết hạn, bạn vẫn có thể xác minh bằng mã này.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            PinCodeTextField(
              appContext: context,
              length: 6,
              controller: _otpController,
              keyboardType: TextInputType.number,
              autoFocus: true,
              animationType: AnimationType.scale,
              onChanged: (_) {},
              onCompleted: (_) => _submitOtp(),
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(8),
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveColor: Theme.of(context).colorScheme.outline,
                selectedColor: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _submitOtp,
              child: Text(_isSubmitting ? 'Đang xác minh...' : 'Xác minh'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _secondsLeft == 0
                      ? 'Bạn có thể gửi lại mã mới'
                      : 'Gửi lại sau ${_secondsLeft}s',
                ),
                TextButton(
                  onPressed: _secondsLeft == 0 && !_isResending
                      ? _resendOtp
                      : null,
                  child: Text(_isResending ? 'Đang gửi...' : 'Gửi lại mã'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
