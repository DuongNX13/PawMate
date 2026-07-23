import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  test(
    'active route matching accepts descendants and rejects near-prefixes',
    () {
      final byLabel = {
        for (final destination in PawMateBottomNav.destinations)
          destination.label: destination,
      };

      expect(byLabel['Home']!.isActive('/pets/list'), isTrue);
      expect(byLabel['Vet']!.isActive('/vets/map'), isTrue);
      expect(byLabel['Health']!.isActive('/health/events/new'), isTrue);
      expect(byLabel['Rescue']!.isActive('/rescue/cases/123'), isTrue);
      expect(byLabel['Profile']!.isActive('/profile/privacy'), isTrue);

      expect(byLabel['Home']!.isActive('/petstore'), isFalse);
      expect(byLabel['Vet']!.isActive('/veterans'), isFalse);
      expect(byLabel['Health']!.isActive('/healthcare'), isFalse);
      expect(byLabel['Rescue']!.isActive('/rescuers'), isFalse);
      expect(byLabel['Profile']!.isActive('/profiles'), isFalse);
    },
  );

  testWidgets('bottom nav keeps Phase 1 shell labels and routes', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final router = GoRouter(
      initialLocation: '/pets',
      routes: [
        _route('/pets', 'Home target'),
        _route('/vets/map', 'Vet target'),
        _route('/health', 'Health target'),
        _route('/rescue', 'Rescue target'),
        _route('/profile', 'Profile target'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    for (final label in ['Home', 'Vet', 'Health', 'Rescue', 'Profile']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Home target'), findsOneWidget);

    await tester.tap(find.text('Vet'));
    await tester.pumpAndSettle();
    expect(find.text('Vet target'), findsOneWidget);

    await tester.tap(find.text('Health'));
    await tester.pumpAndSettle();
    expect(find.text('Health target'), findsOneWidget);

    await tester.tap(find.text('Rescue'));
    await tester.pumpAndSettle();
    expect(find.text('Rescue target'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile target'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Home target'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('bottom nav uses v0.27 icon assets and active colors', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final router = GoRouter(
      initialLocation: '/pets',
      routes: [
        _route('/pets', 'Home target'),
        _route('/vets/map', 'Vet target'),
        _route('/health', 'Health target'),
        _route('/rescue', 'Rescue target'),
        _route('/profile', 'Profile target'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(
      _imageIconFor(tester, 'assets/icons/navigation/home.png').color,
      Colors.white,
    );
    expect(
      _imageIconFor(tester, 'assets/icons/navigation/rescue.png').color,
      AppColors.navInactiveIcon,
    );
    expect(tester.widget<Text>(find.text('Home')).style?.color, Colors.white);
    expect(
      tester.widget<Text>(find.text('Rescue')).style?.color,
      AppColors.navInactiveLabel,
    );

    await tester.tap(find.text('Rescue'));
    await tester.pumpAndSettle();

    expect(
      _imageIconFor(tester, 'assets/icons/navigation/home.png').color,
      AppColors.navInactiveIcon,
    );
    expect(
      _imageIconFor(tester, 'assets/icons/navigation/rescue.png').color,
      Colors.white,
    );
    expect(tester.widget<Text>(find.text('Rescue')).style?.color, Colors.white);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('bottom nav keeps labeled 48dp targets at large text', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(320, 568));
    final semantics = tester.ensureSemantics();
    final router = GoRouter(
      initialLocation: '/health',
      routes: [
        _route('/pets', 'Pets target'),
        _route('/vets/map', 'Vets target'),
        _route('/health', 'Health target'),
        _route('/rescue', 'Rescue target'),
        _route('/profile', 'Profile target'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(useMaterial3: true),
        builder: testTextScaleBuilder(1.3),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Health'), findsOneWidget);
    expect(find.text('Rescue'), findsOneWidget);
    expect(tester, meetsGuideline(androidTapTargetGuideline));
    expect(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(tester, meetsGuideline(textContrastGuideline));
    expectNoFlutterOverflow(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile target'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('bottom nav grows at 2.0 text scale without shrinking labels', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(320, 568));
    final router = GoRouter(
      initialLocation: '/health',
      routes: [
        _route('/pets', 'Pets target'),
        _route('/vets/map', 'Vets target'),
        _route('/health', 'Health target'),
        _route('/rescue', 'Rescue target'),
        _route('/profile', 'Profile target'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        builder: testTextScaleBuilder(2),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(PawMateBottomNav)).height,
      greaterThan(AppControlSize.bottomNavHeight),
    );
    expect(find.byType(FittedBox), findsNothing);
    for (final label in ['Home', 'Vet', 'Health', 'Rescue', 'Profile']) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
      expect(tester.widget<Text>(find.text(label)).maxLines, 2);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
    }
    expectNoFlutterOverflow(tester);
  });
}

GoRoute _route(String path, String label) {
  return GoRoute(
    path: path,
    builder: (context, state) => Scaffold(
      body: Center(child: Text(label)),
      bottomNavigationBar: PawMateBottomNav(currentRoute: path),
    ),
  );
}

ImageIcon _imageIconFor(WidgetTester tester, String assetName) {
  return tester.widget<ImageIcon>(
    find.byWidgetPredicate(
      (widget) =>
          widget is ImageIcon &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == assetName,
    ),
  );
}
