import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  testWidgets('bottom nav keeps labeled 48dp targets at large text', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(320, 568));
    final semantics = tester.ensureSemantics();
    final router = GoRouter(
      initialLocation: '/health',
      routes: [
        _route('/pets', 'Pets target'),
        _route('/vets/list', 'Vets target'),
        _route('/health', 'Health target'),
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

    expect(find.text('Sức khỏe'), findsOneWidget);
    expect(tester, meetsGuideline(androidTapTargetGuideline));
    expect(tester, meetsGuideline(labeledTapTargetGuideline));
    expect(tester, meetsGuideline(textContrastGuideline));
    expectNoFlutterOverflow(tester);

    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Profile target'), findsOneWidget);

    semantics.dispose();
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
