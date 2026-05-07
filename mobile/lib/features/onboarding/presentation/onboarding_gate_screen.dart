import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingGateScreen extends StatefulWidget {
  const OnboardingGateScreen({super.key});

  @override
  State<OnboardingGateScreen> createState() => _OnboardingGateScreenState();
}

class _OnboardingGateScreenState extends State<OnboardingGateScreen> {
  @override
  void initState() {
    super.initState();
    _resolveInitialRoute();
  }

  Future<void> _resolveInitialRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    final hasActiveSession = prefs.getBool('hasActiveSession') ?? false;
    if (!mounted) {
      return;
    }
    if (hasActiveSession) {
      context.go('/pets');
      return;
    }
    context.go(hasSeenOnboarding ? '/auth/login' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
