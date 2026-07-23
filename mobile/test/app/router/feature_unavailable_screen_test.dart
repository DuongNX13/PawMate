import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/router/feature_unavailable_screen.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';

void main() {
  testWidgets('primary fallback action returns to the declared safe route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/unavailable',
      routes: [
        GoRoute(
          path: '/unavailable',
          builder: (context, state) => const FeatureUnavailableScreen(
            title: 'Tính năng đang tắt',
            message: 'Vui lòng quay lại màn an toàn.',
            fallbackLocation: '/home',
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('Trang chủ')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tính năng đang tắt'), findsWidgets);
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();

    expect(find.text('Trang chủ'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/home');
  });
}
