import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  static const _slides = [
    (
      title: 'Tìm phòng khám gần bạn',
      body: 'Xem nhanh bản đồ và chọn nơi phù hợp nhất cho thú cưng.',
      icon: Icons.map_outlined,
      accent: Color(0xFF2A8F7B),
    ),
    (
      title: 'Cộng đồng yêu thú cưng',
      body: 'Kết nối, chia sẻ và học hỏi từ người nuôi thú cưng khác.',
      icon: Icons.groups_outlined,
      accent: Color(0xFF3667D6),
    ),
    (
      title: 'Bảo vệ thú cưng bị lạc',
      body: 'Lưu thông tin quan trọng để tăng cơ hội tìm lại khi cần.',
      icon: Icons.shield_outlined,
      accent: Color(0xFFE17A35),
    ),
  ];

  Future<void> _finishOnboarding({required String nextRoute}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (!mounted) {
      return;
    }
    context.go(nextRoute);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'PawMate',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        _finishOnboarding(nextRoute: '/auth/login'),
                    child: const Text('Bỏ qua'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (value) => setState(() {
                    _currentIndex = value;
                  }),
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                slide.accent.withValues(alpha: 0.16),
                                slide.accent.withValues(alpha: 0.06),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(48),
                          ),
                          child: Icon(
                            slide.icon,
                            size: 88,
                            color: slide.accent,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          slide.title,
                          style: Theme.of(context).textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.body,
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (index) {
                  final isActive = _currentIndex == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _finishOnboarding(nextRoute: '/auth/login'),
                      child: const Text('Bỏ qua'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          _finishOnboarding(nextRoute: '/auth/register'),
                      child: const Text('Bắt đầu'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
