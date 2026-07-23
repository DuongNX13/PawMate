import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/router/app_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/presentation/otp_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  test('production router exposes the canonical route inventory', () {
    final container = ProviderContainer();
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    addTearDown(container.dispose);

    final routeInventory = <String, String>{
      for (final route in RouteBase.routesRecursively(
        router.configuration.routes,
      ).whereType<GoRoute>())
        route.name!: route.path,
    };

    expect(routeInventory, <String, String>{
      'launch': '/launch',
      'onboarding': '/onboarding',
      'login': '/auth/login',
      'register': '/auth/register',
      'otp': '/auth/otp',
      'pets-home': '/pets',
      'pets-list': 'list',
      'adoption': '/adoption',
      'vets-map': '/vets/map',
      'vets-list': '/vets/list',
      'health': '/health',
      'health-reminders': 'reminders',
      'rescue': '/rescue',
      'rescue-map': 'map',
      'profile': '/profile',
      'profile-controls': 'controls',
      'profile-privacy': 'privacy',
      'notifications': '/notifications',
      'pets-create': '/pets/create',
      'pets-edit': '/pets/:id/edit',
      'pets-detail': '/pets/:id',
      'vets-detail': '/vets/:id',
      'health-event-create': '/health/events/new',
      'community': '/community',
      'rescue-create-details': '/rescue/create/details',
      'rescue-create': '/rescue/create',
      'rescue-comment': '/rescue/:caseId/comment',
      'rescue-status': '/rescue/:caseId/status',
      'rescue-discussion': '/rescue/:caseId/discussion',
      'rescue-case': '/rescue/:caseId',
    });
  });

  testWidgets('production login deep-link preserves email and verified state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await setTestViewport(tester, size: const Size(390, 844));
    final container = ProviderContainer();
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    addTearDown(container.dispose);

    router.go('/auth/login?email=nam%2Bqa%40example.com&verified=1');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final emailField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(emailField.controller?.text, 'nam+qa@example.com');
    expect(
      find.text('Email đã được xác minh. Bạn có thể đăng nhập ngay.'),
      findsOneWidget,
    );
    expect(router.routeInformationProvider.value.uri.path, '/auth/login');
    expectNoFlutterOverflow(tester);
  });

  testWidgets('production register deep-link prefills email only', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await setTestViewport(tester, size: const Size(390, 844));
    final container = ProviderContainer();
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    addTearDown(container.dispose);

    router.go('/auth/register?email=nam%2Bqa%40example.com');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields.first.controller?.text, 'nam+qa@example.com');
    expect(
      fields.skip(1).every((field) => field.controller?.text.isEmpty ?? true),
      isTrue,
    );
    expect(router.routeInformationProvider.value.uri.path, '/auth/register');
    expectNoFlutterOverflow(tester);
  });

  testWidgets('production OTP deep-link preserves verification timestamps', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await setTestViewport(tester, size: const Size(390, 844));
    final container = ProviderContainer();
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    addTearDown(container.dispose);
    final expiresAt = DateTime(2026, 7, 14, 18, 5);
    final resendAt = DateTime(2026, 7, 14, 18, 1);

    router.go(
      '/auth/otp?email=nam%40example.com&registrationId=user-1'
      '&expiresAt=${expiresAt.millisecondsSinceEpoch}'
      '&resendAt=${resendAt.millisecondsSinceEpoch}',
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    final otpScreen = tester.widget<OtpScreen>(find.byType(OtpScreen));
    expect(otpScreen.email, 'nam@example.com');
    expect(otpScreen.registrationId, 'user-1');
    expect(otpScreen.verificationExpiresAt, expiresAt);
    expect(otpScreen.resendAvailableAt, resendAt);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
