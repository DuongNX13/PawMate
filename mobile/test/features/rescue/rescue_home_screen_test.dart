import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  testWidgets('rescue home fails closed without fabricated cases', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final router = GoRouter(
      initialLocation: '/rescue',
      routes: [
        GoRoute(
          path: '/rescue',
          builder: (context, state) => const RescueHomeScreen(),
        ),
        _targetRoute('/pets', 'Home target'),
        _targetRoute('/vets/list', 'Vet target'),
        _targetRoute('/health', 'Health target'),
        _targetRoute('/profile', 'Profile target'),
        _targetRoute('/notifications', 'Notification target'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cứu hộ thú cưng'), findsOneWidget);
    expect(find.text('Rescue chưa mở dữ liệu thật'), findsOneWidget);
    expect(find.textContaining('không tải ca cứu hộ'), findsOneWidget);
    expect(find.text('Bảo mật Bắp trong 2 phút'), findsNothing);
    expect(find.text('Mochi đi lạc'), findsNothing);
    expect(find.text('Đăng tin'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Vet'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expect(find.text('Rescue'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('rescue-notifications-button'))),
      const Size(48, 48),
    );
    await tester.tap(
      find.byKey(const ValueKey('rescue-notifications-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Notification target'), findsOneWidget);
    router.go('/rescue');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('rescue-safety-note')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Không công khai vị trí chính xác'),
      findsOneWidget,
    );
    expectNoFlutterOverflow(tester);
  });

  testWidgets('rescue home keeps readable layout at large text', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: testTextScaleBuilder(1.3),
        home: const RescueHomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cứu hộ thú cưng'), findsOneWidget);
    expect(find.text('Rescue chưa mở dữ liệu thật'), findsOneWidget);
    expect(find.text('Rescue'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('rescue staged copy stays honest when rollout flags are on', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const RescueHomeScreen(browseEnabled: true, createEnabled: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Cờ xem và tạo tin đã bật'), findsOneWidget);
    expect(find.textContaining('không hiển thị ca mẫu'), findsOneWidget);
    expect(find.text('Đăng tin'), findsNothing);
    expectNoFlutterOverflow(tester);
  });
}

GoRoute _targetRoute(String path, String label) {
  return GoRoute(
    path: path,
    builder: (context, state) => Scaffold(body: Center(child: Text(label))),
  );
}
