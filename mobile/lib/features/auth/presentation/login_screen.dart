import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../data/auth_api.dart';
import '../data/auth_session_store.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.initialEmail,
    this.showVerifiedMessage = false,
  });

  final String? initialEmail;
  final bool showVerifiedMessage;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail?.trim() ?? '';
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
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    return null;
  }

  Future<void> _submitLogin() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isSubmitting) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final email = _emailController.text.trim();

    try {
      final session = await ref
          .read(authApiProvider)
          .login(email: email, password: _passwordController.text);
      await ref.read(authSessionStoreProvider).save(session);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasActiveSession', true);
      if (!mounted) {
        return;
      }
      context.go('/pets');
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == 'AUTH_006') {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${error.message} Hãy nhập mã OTP để xác minh tài khoản.',
            ),
          ),
        );
        context.go('/auth/otp?email=${Uri.encodeComponent(email)}');
      } else {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Đăng nhập thất bại. Vui lòng thử lại.')),
      );
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

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.hero),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              children: [
                const SizedBox(height: 8),
                const _AuthHero(
                  title: 'Chào mừng trở lại!',
                  subtitle:
                      'Đăng nhập để tiếp tục chăm sóc những người bạn bốn chân của bạn.',
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EMAIL', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: _validateEmail,
                        decoration: const InputDecoration(
                          hintText: 'abc@gmail.com',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'MẬT KHẨU',
                              style: theme.textTheme.labelMedium,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Luồng quên mật khẩu sẽ nối tiếp sau MVP lõi.',
                                    ),
                                  ),
                                ),
                            child: const Text('Quên mật khẩu?'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submitLogin(),
                        validator: _validatePassword,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() {
                              _obscurePassword = !_obscurePassword;
                            }),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                PrimaryGradientButton(
                  label: _isSubmitting ? 'Đang đăng nhập...' : 'Đăng nhập',
                  onPressed: _isSubmitting ? null : _submitLogin,
                ),
                const SizedBox(height: 20),
                Text.rich(
                  TextSpan(
                    text: 'MVP hiện tại ưu tiên đăng nhập bằng email. ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: 'Google và Apple sẽ mở lại ở phase sau.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.secondary500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => context.go('/auth/register'),
                  child: Text.rich(
                    TextSpan(
                      text: 'Chưa có tài khoản? ',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.label,
                      ),
                      children: [
                        TextSpan(
                          text: 'Đăng ký ngay',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.primary700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 56),
                const _PetFooterIllustration(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          left: -48,
          top: 20,
          child: Container(
            width: 160,
            height: 160,
            decoration: const BoxDecoration(
              color: Color(0x1A9FCAFE),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          right: -10,
          top: -12,
          child: Container(
            width: 172,
            height: 172,
            decoration: const BoxDecoration(
              color: Color(0x1AFF8A5B),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(34),
                boxShadow: AppShadows.soft,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.pets_rounded, size: 54, color: Colors.white),
                  Positioned(
                    right: -10,
                    bottom: -8,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD1E4FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 20,
                        color: Color(0xFF174976),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              title,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.label,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }
}

class _PetFooterIllustration extends StatelessWidget {
  const _PetFooterIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      alignment: Alignment.bottomCenter,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: const [
          _PetShadowIcon(icon: Icons.pets_outlined, size: 56),
          SizedBox(width: 24),
          _PetShadowIcon(icon: Icons.pets_rounded, size: 110),
          SizedBox(width: 24),
          _PetShadowIcon(icon: Icons.pets_outlined, size: 48),
        ],
      ),
    );
  }
}

class _PetShadowIcon extends StatelessWidget {
  const _PetShadowIcon({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 24,
      height: size + 24,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        shape: BoxShape.circle,
        boxShadow: AppShadows.soft,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size, color: const Color(0xFFA6A9AF)),
    );
  }
}
