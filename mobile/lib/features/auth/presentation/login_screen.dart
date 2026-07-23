import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_text_field.dart';
import '../application/auth_session_coordinator.dart';
import '../data/auth_api.dart';
import 'auth_return_route.dart';
import 'auth_qa_defaults.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.initialEmail,
    this.showVerifiedMessage = false,
    this.returnTo,
  });

  final String? initialEmail;
  final bool showVerifiedMessage;
  final String? returnTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _qaSmokeStarted = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _emailController.text =
        widget.initialEmail?.trim() ??
        (pawmateQaPrefillAuth ? pawmateQaAuthEmail : '');
    if (pawmateQaPrefillAuth) {
      _passwordController.text = pawmateQaAuthPassword;
    }
    if (pawmateQaAutorunAuthSmoke) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runQaAuthSmoke();
      });
    }
    if (widget.showVerifiedMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email đã được xác minh. Bạn có thể đăng nhập ngay.'),
          ),
        );
      });
    }
  }

  Future<void> _runQaAuthSmoke() async {
    if (_qaSmokeStarted || _isSubmitting || !mounted) {
      return;
    }
    _qaSmokeStarted = true;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      await ref
          .read(authApiProvider)
          .register(email: email, password: password, phone: '0901234567');
    } on AuthApiException catch (error) {
      if (error.code != 'AUTH_001') {
        if (mounted) {
          messenger.showSnackBar(SnackBar(content: Text(error.message)));
        }
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('QA register smoke failed. Continuing to login.'),
          ),
        );
      }
    }

    try {
      final session = await ref
          .read(authApiProvider)
          .login(email: email, password: password);
      await _persistAuthenticatedSession(session);
      if (mounted) {
        context.go(_postLoginRoute);
      }
    } on AuthApiException catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('QA auth smoke failed. Check Appetize Network Logs.'),
          ),
        );
      }
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (email.isEmpty) {
      return 'Vui lòng nhập email';
    }
    if (!regex.hasMatch(email)) {
      return 'Email chưa đúng định dạng';
    }
    if (email.length > 254) {
      return 'Email tối đa 254 ký tự';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    return null;
  }

  void _openRegister() {
    final email = _emailController.text.trim();
    context.go(
      Uri(
        path: '/auth/register',
        queryParameters: authQueryParameters(
          values: {if (email.isNotEmpty) 'email': email},
          returnTo: widget.returnTo,
        ),
      ).toString(),
    );
  }

  Future<void> _persistAuthenticatedSession(AuthSession session) async {
    await ref.read(authSessionCoordinatorProvider).saveSession(session);
    ref.invalidate(authSessionSnapshotProvider);
  }

  String get _postLoginRoute =>
      resolveAuthenticatedReturnRoute(widget.returnTo);

  Future<void> _submitLogin() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isSubmitting) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final email = _emailController.text.trim();

    try {
      final session = await ref
          .read(authApiProvider)
          .login(email: email, password: _passwordController.text);
      await _persistAuthenticatedSession(session);
      if (!mounted) {
        return;
      }
      context.go(_postLoginRoute);
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == 'AUTH_006') {
        setState(() {
          _errorText = error.message;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${error.message} Hãy nhập mã OTP để xác minh tài khoản.',
            ),
          ),
        );
        context.go(
          Uri(
            path: '/auth/otp',
            queryParameters: authQueryParameters(
              values: {'email': email},
              returnTo: widget.returnTo,
            ),
          ).toString(),
        );
      } else {
        setState(() {
          _errorText = error.message;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Đăng nhập thất bại. Vui lòng thử lại.')),
      );
      setState(() {
        _errorText = 'Đăng nhập chưa hoàn tất. Vui lòng thử lại.';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _AuthHero(
                imageAsset: 'assets/images/auth/login_vet_dog.png',
                height: 300,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Mừng bạn đã trở lại',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h1(color: AppColors.primary500),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Đăng nhập để theo dõi sức khỏe thú cưng của bạn.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyStrong(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 40),
                      _LoginErrorBanner(message: _errorText!),
                    ] else
                      const SizedBox(height: 40),
                    Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PawMateTextField(
                            key: const Key('login-email-field'),
                            controller: _emailController,
                            label: 'Email',
                            hintText: 'example@gmail.com',
                            isRequired: true,
                            showRequiredIndicator: false,
                            enabled: !_isSubmitting,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: _validateEmail,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(254),
                            ],
                          ),
                          const SizedBox(height: 18),
                          PawMateTextField(
                            key: const Key('login-password-field'),
                            controller: _passwordController,
                            label: 'Mật khẩu',
                            hintText: '••••••••',
                            isRequired: true,
                            showRequiredIndicator: false,
                            enabled: !_isSubmitting,
                            labelTrailing: TextButton(
                              key: const Key('login-forgot-password'),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(
                                  AppControlSize.minTouchTarget,
                                  AppControlSize.minTouchTarget,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                              ),
                              onPressed: _isSubmitting
                                  ? null
                                  : () => ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Luồng quên mật khẩu sẽ nối tiếp sau MVP lõi.',
                                            ),
                                          ),
                                        ),
                              child: Text(
                                'Quên mật khẩu?',
                                style: AppTextStyles.label(
                                  color: AppColors.primary500,
                                ),
                              ),
                            ),
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submitLogin(),
                            validator: _validatePassword,
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Hiện mật khẩu'
                                  : 'Ẩn mật khẩu',
                              onPressed: _isSubmitting
                                  ? null
                                  : () => setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    }),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 34),
                    PawMateButton(
                      key: const Key('login-submit-button'),
                      label: 'Đăng nhập',
                      isLoading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _submitLogin,
                    ),
                    const SizedBox(height: 22),
                    TextButton(
                      key: const Key('login-register-cta'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onPressed: _isSubmitting ? null : _openRegister,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Text(
                            'Bạn chưa có tài khoản?',
                            style: AppTextStyles.bodyStrong(
                              color: AppColors.label,
                            ),
                          ),
                          Text(
                            'Đăng ký ngay',
                            style: AppTextStyles.bodyStrong(
                              color: AppColors.primary700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({required this.imageAsset, required this.height});

  final String imageAsset;
  final double height;

  @override
  Widget build(BuildContext context) {
    const semanticLabel =
        'Minh họa bác sĩ thú y đang chăm sóc chó cưng cho màn đăng nhập';
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: Image.asset(
            imageAsset,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const ColoredBox(
              color: AppColors.careGreenSoft,
              child: Center(
                child: Icon(
                  Icons.health_and_safety_outlined,
                  size: 64,
                  color: AppColors.primary500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginErrorBanner extends StatelessWidget {
  const _LoginErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Lỗi đăng nhập: $message',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.errorSoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.error),
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
      ),
    );
  }
}
