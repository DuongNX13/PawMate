// Test-only entry recipes. Native callers restore real metrics before actions.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';

import '../test/features/rescue/day102_report_review_test.dart' as review;
import '../test/test_support/day119_detail_support.dart' as detail;

const closureDogAvatar = 'assets/images/pets/home_adoption_golden.png';
const closureReviewKey = Key('rescue-report-review-sheet');

/// Bind a dog photograph to dog metadata without changing sealed fixtures.
Future<detail.Day119Harness> pumpClosurePet(
  WidgetTester tester,
  Size size, {
  bool edit = false,
  VoidCallback? restoreNativeMetrics,
}) async {
  final pet = detail.day119Pet().copyWith(avatarPath: closureDogAvatar);
  final harness = await detail.pumpDay119(
    tester,
    'DT-01',
    size,
    pets: AsyncValue.data([pet]),
  );
  if (edit) {
    harness.router.go('/pets/mochi/edit');
    await tester.pumpAndSettle();
  }
  restoreNativeMetrics?.call();
  await tester.pumpAndSettle();
  return harness;
}

/// Tap the actual actionable descendant, never the padded CTA-bar centre.
Future<void> pumpClosureReportReview(
  WidgetTester tester,
  Size size, {
  double scale = 1,
  VoidCallback? restoreNativeMetrics,
}) async {
  final source = review.ReviewWriteSource();
  await review.pumpReviewForm(
    tester,
    source,
    size: size,
    scale: scale,
    seed: true,
    localPrivacy: true,
  );
  restoreNativeMetrics?.call();
  await tester.pumpAndSettle();
  final publish = find.descendant(
    of: find.byKey(const Key('rescue-info-publish-cta')),
    matching: find.byWidgetPredicate(
      (widget) => widget is PawMateButton && widget.label == 'Đăng tin tìm',
    ),
  );
  expect(publish, findsOneWidget);
  expect(publish.hitTestable(), findsOneWidget);
  await tester.tap(publish, warnIfMissed: true);
  await tester.pumpAndSettle();
  expect(find.byKey(closureReviewKey), findsOneWidget);
  expect(find.text('Kiểm tra tin báo mất'), findsOneWidget);
  expect(source.publishes, 0, reason: 'Opening review must not publish');
}

/// Resolve the scroll container by content ownership, not global tree order.
Finder closureScrollFor(WidgetTester tester, Finder content) {
  expect(content, findsOneWidget, reason: 'Scroll target must be unique');
  final state = Scrollable.maybeOf(tester.element(content));
  if (state == null) {
    throw StateError('No owning scrollable for the selected content');
  }
  return find.byWidgetPredicate(
    (widget) => identical(widget, state.widget),
    description: 'Exact scrollable owning selected content',
  );
}

Future<void> closureScrollToEnd(WidgetTester tester, Finder content) async {
  final scroll = closureScrollFor(tester, content);
  expect(scroll, findsOneWidget);
  final state = tester.state<ScrollableState>(scroll);
  state.position.jumpTo(state.position.maxScrollExtent);
  await tester.pumpAndSettle();
  expect(state.position.pixels, closeTo(state.position.maxScrollExtent, .5));
}

/// Overlapping checkpoints cover middle content; retain the owning state even
/// when lazy-list children are recycled. This is not a TalkBack input driver.
Future<void> closureSweep(
  WidgetTester tester,
  Finder content, {
  required Future<void> Function(int index, double offset) capture,
}) async {
  final state = tester.state<ScrollableState>(
    closureScrollFor(tester, content),
  );
  state.position.jumpTo(state.position.minScrollExtent);
  await tester.pumpAndSettle();
  for (var page = 0; page < 60; page++) {
    final position = state.position;
    expect(position.viewportDimension, greaterThan(0));
    await capture(page, position.pixels);
    if (position.pixels >= position.maxScrollExtent - .5) return;
    final next = (position.pixels + position.viewportDimension * .7).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next <= position.pixels) throw StateError('Scroll made no progress');
    position.jumpTo(next);
    await tester.pumpAndSettle();
  }
  throw StateError('Bounded sweep exceeded 60 checkpoints');
}
