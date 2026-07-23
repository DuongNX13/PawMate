import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../auth/application/auth_session_coordinator.dart';

class OnboardingGateScreen extends ConsumerStatefulWidget {
  const OnboardingGateScreen({super.key});

  @override
  ConsumerState<OnboardingGateScreen> createState() =>
      _OnboardingGateScreenState();
}

class _OnboardingGateScreenState extends ConsumerState<OnboardingGateScreen> {
  @override
  void initState() {
    super.initState();
    _resolveInitialRoute();
  }

  Future<void> _resolveInitialRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    var hasValidSession = false;
    try {
      hasValidSession =
          await ref.read(authSessionSnapshotProvider.future) != null;
    } on Object {
      // Fail closed when secure persistence or server validation is unavailable.
    }
    if (!mounted) {
      return;
    }
    if (hasValidSession) {
      context.go('/pets');
      return;
    }
    context.go(hasSeenOnboarding ? '/auth/login' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: 'Đang kiểm tra phiên đăng nhập',
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: AppControlSize.minTouchTarget,
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.s8),
                      child: CircularProgressIndicator(
                        color: AppColors.primary500,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    'Đang chuẩn bị PawMate...',
                    style: AppTextStyles.bodyStrong(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
