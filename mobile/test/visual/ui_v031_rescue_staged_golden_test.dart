import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';

import '../test_support/ui_test_helpers.dart';

const _goldenKey = Key('ui-v031-rescue-staged-golden-root');
const _viewports = [Size(360, 844), Size(390, 844), Size(430, 932)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  for (final viewport in _viewports) {
    final tag = '${viewport.width.toInt()}x${viewport.height.toInt()}';
    testWidgets('Rescue staged fail-closed golden at $tag', (tester) async {
      await setTestViewport(tester, size: viewport);
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        RepaintBoundary(
          key: _goldenKey,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await _precacheNavigationIcons(tester);

      expect(find.text('Đăng tin'), findsNothing);
      expect(find.text('Mochi đi lạc'), findsNothing);
      expect(find.text('Rescue chưa mở dữ liệu thật'), findsOneWidget);
      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/ui-v031-rescue/rescue-staged-$tag.png'),
      );
    });
  }
}

Future<void> _precacheNavigationIcons(WidgetTester tester) async {
  await tester.pump();
  final context = tester.element(find.byKey(_goldenKey));
  for (final destination in PawMateBottomNav.destinations) {
    await tester.runAsync(
      () => precacheImage(AssetImage(destination.iconAsset), context),
    );
  }
  await tester.pumpAndSettle();
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/rescue',
    routes: [
      GoRoute(
        path: '/rescue',
        builder: (context, state) => const RescueHomeScreen(),
      ),
      for (final path in const ['/pets', '/vets/list', '/health', '/profile'])
        GoRoute(path: path, builder: (context, state) => const Scaffold()),
    ],
  );
}
