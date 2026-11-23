import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_adaptive.dart';
import 'package:pawmate_mobile/features/auth/presentation/register_screen.dart';

import '../visual/day24_vet_detail_review_golden_test.dart'
    show pumpDay118VetDetail;

const _checkRecordedInsets = bool.fromEnvironment('D122_RETEST_BACK_INSETS');
const _loginRouteMarker = Key('day122-test-login-target');
const _openReview = Key('vet-detail-write-review-button');
const _reviewSubmit = Key('write-review-submit');

void main() {
  for (final surface in ['Register', 'Write Review']) {
    testWidgets('D122 Back $surface zero-inset control', (tester) async {
      await _checkBack(tester, surface, const Size(360, 800), 0);
    });
    if (_checkRecordedInsets) {
      for (final sample in [
        (size: const Size(360, 800), topPx: 136),
        (size: const Size(430, 932), topPx: 158),
      ]) {
        final tag =
            '${sample.size.width.toInt()}x${sample.size.height.toInt()}';
        testWidgets('D122 Back $surface $tag API35 geometry', (tester) async {
          await _checkBack(tester, surface, sample.size, sample.topPx);
        });
      }
    }
  }
}

Future<void> _checkBack(
  WidgetTester tester,
  String surface,
  Size size,
  int statusBarPx,
) async {
  final isRegister = surface == 'Register';
  if (isRegister) {
    await _pumpRegister(tester);
  } else {
    await pumpDay118VetDetail(tester, size);
  }
  const ratio = 3.0;
  tester.view.devicePixelRatio = ratio;
  tester.view.physicalSize = size * ratio;
  tester.view.viewPadding = FakeViewPadding(top: statusBarPx.toDouble());
  tester.view.padding = FakeViewPadding(top: statusBarPx.toDouble());
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
    tester.view.resetViewPadding();
    tester.view.resetPadding();
  });
  await tester.pumpAndSettle();

  if (!isRegister) {
    final cta = find.byKey(_openReview);
    await tester.scrollUntilVisible(
      cta,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(cta);
    await tester.pumpAndSettle();
    expect(cta.hitTestable(), findsOneWidget);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.byKey(_reviewSubmit), findsOneWidget);
  }

  final back = find.descendant(
    of: find.byType(PawMateAdaptiveBackButton),
    matching: find.byTooltip('Quay lại'),
  );
  expect(back, findsOneWidget);
  final hitbox = tester.getRect(back);
  expect(hitbox.width, greaterThanOrEqualTo(48));
  expect(hitbox.height, greaterThanOrEqualTo(48));
  final inset = MediaQuery.viewPaddingOf(tester.element(back)).top;
  // SafeArea may consume the inset in descendants of a correctly fixed screen.
  // The root view still has the system's unconsumed measurement.
  final systemInset = tester.view.viewPadding.top / ratio;
  expect(systemInset, statusBarPx / ratio);
  expect(inset, inInclusiveRange(0, systemInset));
  expect(
    hitbox.top,
    greaterThanOrEqualTo(systemInset),
    reason:
        'D122-VIS-001: entire $surface Quay lại hitbox must be below the '
        'API 35 status bar ($systemInset dp), not merely its visible portion',
  );
  expect(back.hitTestable(), findsOneWidget);
  await tester.tap(back);
  await tester.pumpAndSettle();
  if (isRegister) {
    expect(find.byKey(_loginRouteMarker), findsOneWidget);
  } else {
    expect(find.byKey(_reviewSubmit), findsNothing);
    expect(find.byKey(_openReview), findsOneWidget);
  }
  expect(tester.takeException(), isNull);
}

Future<void> _pumpRegister(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/auth/register',
    routes: [
      GoRoute(
        path: '/auth/register',
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (_, _) =>
            const Scaffold(body: SizedBox(key: _loginRouteMarker)),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
}
