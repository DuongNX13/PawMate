import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final slides = const [
      (
        title: 'Tim phong kham gan ban',
        body: 'Vet Finder la flow uu tien so 1 cua MVP.',
      ),
      (
        title: 'Luu ho so thu cung gon gang',
        body: 'Pet Profile va Health Record co san cho lan sau.',
      ),
      (
        title: 'Theo doi nhac lich cham soc',
        body:
            'Reminder co the bat dau voi in-app state truoc khi push san sang.',
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go('/auth/login'),
                  child: const Text('Bo qua'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  itemCount: slides.length,
                  itemBuilder: (context, index) {
                    final slide = slides[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pets,
                          size: 72,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
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
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go('/auth/login'),
                  child: const Text('Bat dau ngay'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
