import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/presentation/login_screen.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  testWidgets('login register CTA wraps cleanly at large text', (tester) async {
    await setTestViewport(tester, size: const Size(320, 568));
    final router = GoRouter(
      initialLocation: '/auth/login',
      routes: [
        GoRoute(
          path: '/auth/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/auth/register',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Register target'))),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        builder: testTextScaleBuilder(1.5),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đăng ký ngay'), findsOneWidget);
    expectNoFlutterOverflow(tester);

    await tester.ensureVisible(find.byKey(const Key('login-register-cta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('login-register-cta')));
    await tester.pumpAndSettle();

    expect(find.text('Register target'), findsOneWidget);
  });
}
