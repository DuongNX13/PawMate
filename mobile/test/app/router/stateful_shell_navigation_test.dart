import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/router/app_navigation.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  testWidgets(
    'five shell branches retain child history and active-tab reselect pops home',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final router = _buildShellRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/pets');
      expect(find.text('Home root · reselect 0'), findsOneWidget);
      expect(tester.takeException(), isNull);

      router.go('/pets/list');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/pets/list');
      expect(find.text('Home child'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Vet'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/vets/map');
      expect(find.text('Vet root · reselect 0'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Home'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/pets/list',
        reason: 'Switching branches must restore the Home child navigator.',
      );

      await tester.tap(find.bySemanticsLabel('Home'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/pets');
      expect(find.text('Home root · reselect 1'), findsOneWidget);

      for (final destination in const <(String, String, String)>[
        ('Health', '/health', 'Health root · reselect'),
        ('Rescue', '/rescue', 'Rescue root · reselect'),
        ('Profile', '/profile', 'Profile root · reselect'),
        ('Vet', '/vets/map', 'Vet root · reselect'),
      ]) {
        await tester.tap(find.bySemanticsLabel(destination.$1));
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          destination.$2,
          reason: '${destination.$1} must select its canonical shell root.',
        );
        expect(find.textContaining(destination.$3), findsOneWidget);
      }

      expect(tester.takeException(), isNull);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets(
    'Android back at a shell root delegates to the system exit path',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final router = _buildShellRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(router.canPop(), isFalse);
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isFalse);
      expect(router.routeInformationProvider.value.uri.path, '/pets');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reselecting a visible branch root scrolls primary content to top',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final router = _buildShellRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      final list = find.byKey(const Key('home-primary-scroll'));
      await tester.drag(list, const Offset(0, -600));
      await tester.pumpAndSettle();
      var position = tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)),
          )
          .position;
      expect(position.pixels, greaterThan(100));

      await tester.tap(find.bySemanticsLabel('Home'));
      await tester.pumpAndSettle();

      position = tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)),
          )
          .position;
      expect(position.pixels, 0);
      expect(find.text('Home root · reselect 1'), findsOneWidget);
    },
  );

  testWidgets(
    'iOS full-screen route uses a swipe-back-capable Cupertino page',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final router = _buildAdaptiveRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.iOS),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open detail'));
      await tester.pumpAndSettle();

      final route = ModalRoute.of(tester.element(find.text('Detail')));
      expect(route?.settings, isA<CupertinoPage<void>>());
      expect((route! as PageRoute<void>).popGestureEnabled, isTrue);
      expect(router.canPop(), isTrue);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Open detail'), findsOneWidget);
    },
  );

  testWidgets('Android full-screen route uses a Material page', (tester) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final router = _buildAdaptiveRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();

    expect(
      ModalRoute.of(tester.element(find.text('Detail')))?.settings,
      isA<MaterialPage<void>>(),
    );
  });
}

GoRouter _buildShellRouter() {
  final branchKeys = List.generate(
    5,
    (index) => GlobalKey<NavigatorState>(debugLabel: 'test-branch-$index'),
  );
  assert(branchKeys.toSet().length == 5);

  return GoRouter(
    initialLocation: '/pets',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            PawMateStatefulNavigationHost(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: branchKeys[0],
            routes: [
              GoRoute(
                path: '/pets',
                builder: (context, state) => _BranchScreen(
                  label: 'Home root',
                  currentRoute: state.uri.path,
                  childLocation: '/pets/list',
                ),
                routes: [
                  GoRoute(
                    path: 'list',
                    builder: (context, state) => _BranchScreen(
                      label: 'Home child',
                      currentRoute: state.uri.path,
                    ),
                  ),
                ],
              ),
            ],
          ),
          _branch(branchKeys[1], '/vets/map', 'Vet root'),
          _branch(branchKeys[2], '/health', 'Health root'),
          _branch(branchKeys[3], '/rescue', 'Rescue root'),
          _branch(branchKeys[4], '/profile', 'Profile root'),
        ],
      ),
    ],
  );
}

StatefulShellBranch _branch(
  GlobalKey<NavigatorState> key,
  String path,
  String label,
) {
  return StatefulShellBranch(
    navigatorKey: key,
    routes: [
      GoRoute(
        path: path,
        builder: (context, state) =>
            _BranchScreen(label: label, currentRoute: state.uri.path),
      ),
    ],
  );
}

GoRouter _buildAdaptiveRouter() {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => context.push('/detail'),
              child: const Text('Open detail'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/detail',
        pageBuilder: (context, state) => PawMateNavigation.adaptivePage(
          context: context,
          state: state,
          child: const Scaffold(body: Center(child: Text('Detail'))),
        ),
      ),
    ],
  );
}

class _BranchScreen extends StatelessWidget {
  const _BranchScreen({
    required this.label,
    required this.currentRoute,
    this.childLocation,
  });

  final String label;
  final String currentRoute;
  final String? childLocation;

  @override
  Widget build(BuildContext context) {
    final serial =
        PawMateNavigationScope.maybeOf(context)?.reselectController.serial ?? 0;
    final contents = <Widget>[
      Text('$label · reselect $serial'),
      if (label == 'Home child') const Text('Home child'),
      if (childLocation case final location?)
        FilledButton(
          onPressed: () => context.push(location),
          child: const Text('Open home child'),
        ),
    ];
    return Scaffold(
      body: label == 'Home root'
          ? ListView(
              key: const Key('home-primary-scroll'),
              padding: const EdgeInsets.all(24),
              children: [
                ...contents,
                const SizedBox(height: 1200),
                const Text('Home end'),
              ],
            )
          : Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: contents),
            ),
      bottomNavigationBar: PawMateBottomNav(currentRoute: currentRoute),
    );
  }
}
