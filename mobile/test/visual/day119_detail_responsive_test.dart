import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/features/pets/presentation/create_pet_screen.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../test_support/day119_detail_support.dart';
import '../test_support/ui_test_helpers.dart';

const _sizes = [Size(360, 800), Size(390, 844), Size(430, 932)];
const _families = ['DT-01', 'DT-03', 'DT-04', 'DT-05'];
Finder get _marker => find.byKey(ValueKey('rescue-marker-$day119FirstCaseId'));
Finder get _selected => find.byKey(const Key('rescue-selected-case-card'));
Finder get _toggle => find.byKey(const Key('rescue-load-more'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  for (final size in _sizes) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    for (final family in _families) {
      final id = '$family-$tag';
      testWidgets('D119 $id adaptive detail safe-area and golden', (
        tester,
      ) async {
        await pumpDay119(tester, family, size);
        if (family == 'DT-04') await _expand(tester);
        if (family == 'DT-05') await _select(tester);
        expectNoFlutterOverflow(tester);
        _nav(tester, size);
        await captureDay119(tester, '$id-top');
        await expectLater(
          find.byKey(day119Root),
          matchesGoldenFile('goldens/day119/$id.png'),
        );
        await _end(tester);
        _nav(tester, size);
        _labels(tester);
        expectNoFlutterOverflow(tester);
        await captureDay119(tester, '$id-end');
      });
    }

    testWidgets('D119 DT-01-$tag long identity safe bottom and edit return', (
      tester,
    ) async {
      final h = await pumpDay119(tester, 'DT-01', size, longContent: true);
      final avatar = tester.getRect(find.byKey(const Key('pet-detail-avatar')));
      expect(avatar.width, closeTo(avatar.height, .01));
      _notTruncated(tester, day119LongPetName);
      await _end(tester);
      final cta = find.text('Quay lại danh sách');
      expect(cta.hitTestable(), findsOneWidget);
      expect(
        tester
            .getRect(
              find.ancestor(of: cta, matching: find.byType(PawMateButton)),
            )
            .bottom,
        lessThanOrEqualTo(size.height - 34),
        reason: 'Pet detail return CTA must remain above home indicator',
      );
      await captureDay119(tester, 'DT-01-$tag-long-end');
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final offset = scroll.position.pixels;
      await tester.tap(find.byKey(const Key('pet-detail-edit-button')));
      await tester.pumpAndSettle();
      final editor = find.byType(CreatePetScreen);
      expect(editor, findsOneWidget);
      final route = GoRouterState.of(tester.element(editor));
      expect(route.uri.path, '/pets/mochi/edit');
      expect(route.uri.queryParameters['returnTo'], '/pets/mochi');
      h.router.pop();
      await tester.pumpAndSettle();
      expect(h.router.routeInformationProvider.value.uri.path, '/pets/mochi');
      expect(scroll.position.pixels, closeTo(offset, .1));
      expect(find.text(day119LongPetName), findsOneWidget);
      expectNoFlutterOverflow(tester);
    });

    testWidgets('D119 DT-03-$tag dynamic requests status copy and last CTA', (
      tester,
    ) async {
      await pumpDay119(tester, 'DT-03', size, longContent: true);
      expect(find.text('12 đơn đang được theo dõi'), findsOneWidget);
      for (final i in [0, 1, 2, 3, 4, 11]) {
        final card = find.byKey(Key('my-adoption-request-request-$i'));
        await tester.scrollUntilVisible(
          card,
          220,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 60,
        );
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        final name = '$day119LongPetName — đơn ${i + 1}';
        _notTruncated(tester, name);
        _labels(tester);
        expectNoFlutterOverflow(tester);
      }
      await _end(tester);
      final last = find.byKey(const Key('my-adoption-request-chat-request-11'));
      expect(last.hitTestable(), findsOneWidget);
      expect(tester.getRect(last).bottom, lessThanOrEqualTo(size.height - 34));
      await captureDay119(tester, 'DT-03-$tag-dynamic-end');
    });

    testWidgets('D119 DT-04-$tag five cases collapse and detail back context', (
      tester,
    ) async {
      final h = await pumpDay119(tester, 'DT-04', size);
      await _expand(tester);
      await _end(tester);
      expect(find.text('Mây'), findsOneWidget);
      expect(find.text('Thu gọn').hitTestable(), findsOneWidget);
      _nav(tester, size);
      final state = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final before = state.position.pixels;
      await tester.ensureVisible(find.text('Mây'));
      await tester.tap(find.text('Mây'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('rescue-case-detail-screen')),
        findsOneWidget,
      );
      h.router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Thu gọn'), findsOneWidget);
      expect(state.position.pixels, closeTo(before, .1));
      await tester.tap(_toggle);
      await tester.pumpAndSettle();
      expect(find.text('Mây'), findsNothing);
      expect(find.text('Xem thêm'), findsOneWidget);
      await _top(tester);
      final map = find.byKey(const Key('rescue-map-preview'));
      expect(tester.getSize(map).height, greaterThanOrEqualTo(208));
      _nav(tester, size);
      expectNoFlutterOverflow(tester);
      await captureDay119(tester, 'DT-04-$tag-recollapsed');
    });

    testWidgets(
      'D119 DT-05-$tag long selected card detail back filter and close',
      (tester) async {
        final h = await pumpDay119(tester, 'DT-05', size, longContent: true);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(RescueHomeScreen)),
        );
        await container
            .read(rescueHomeProvider.notifier)
            .applyFilter(RescueHomeFilter.dogs);
        await tester.pumpAndSettle();
        await _select(tester);
        _notTruncated(tester, day119LongPetName, within: _selected);
        final cta = find.byKey(const Key('rescue-selected-details'));
        expect(cta.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(cta).bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(PawMateBottomNav)).top),
        );
        _nav(tester, size);
        await captureDay119(tester, 'DT-05-$tag-long-selected');
        final state = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        final offset = state.position.pixels;
        await tester.tap(cta);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('rescue-case-detail-screen')),
          findsOneWidget,
        );
        expect(h.source.detailCaseIds, [day119FirstCaseId]);
        h.router.pop();
        await tester.pumpAndSettle();
        expect(_selected, findsOneWidget);
        expect(state.position.pixels, closeTo(offset, .1));
        expect(
          container.read(rescueHomeProvider).filter,
          RescueHomeFilter.dogs,
        );
        final close = find.byKey(const Key('rescue-selected-close'));
        await tester.ensureVisible(close);
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(_selected, findsNothing);
        _nav(tester, size);
        expectNoFlutterOverflow(tester);
      },
    );

    testWidgets('D119 DT-05-$tag deleted detail returns selected context', (
      tester,
    ) async {
      final h = await pumpDay119(
        tester,
        'DT-05',
        size,
        detailError: const RescueApiException(
          'Tin báo không còn tồn tại.',
          statusCode: 404,
          code: 'RESCUE_CASE_NOT_FOUND',
        ),
      );
      await _select(tester);
      await tester.tap(find.byKey(const Key('rescue-selected-details')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('rescue-detail-unavailable')),
        findsOneWidget,
      );
      h.router.pop();
      await tester.pumpAndSettle();
      expect(_selected, findsOneWidget);
      _nav(tester, size);
      expectNoFlutterOverflow(tester);
    });
  }
}

Future<void> _expand(WidgetTester tester) async {
  await tester.ensureVisible(_toggle);
  await tester.pumpAndSettle();
  await tester.tap(_toggle);
  await tester.pumpAndSettle();
  expect(find.text('Thu gọn'), findsOneWidget);
}

Future<void> _select(WidgetTester tester) async {
  await tester.ensureVisible(_marker);
  await tester.pumpAndSettle();
  await tester.tap(_marker);
  await tester.pumpAndSettle();
  expect(_selected, findsOneWidget);
  final cta = find.byKey(const Key('rescue-selected-details'));
  await Scrollable.ensureVisible(tester.element(cta), alignment: .9);
  await tester.pumpAndSettle();
}

Future<void> _end(WidgetTester tester) async {
  final scroll = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  );
  if (scroll.evaluate().isEmpty) return;
  final p = tester.state<ScrollableState>(scroll.first).position;
  for (var i = 0; i < 5; i++) {
    p.jumpTo(p.maxScrollExtent);
    await tester.pumpAndSettle();
    if (p.extentAfter < .5) break;
  }
  expect(p.extentAfter, lessThan(.5));
}

Future<void> _top(WidgetTester tester) async {
  tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
}

void _nav(WidgetTester tester, Size size) {
  final nav = find.byType(PawMateBottomNav);
  if (nav.evaluate().isEmpty) return;
  expect(nav, findsOneWidget);
  expect(tester.getRect(nav).bottom, size.height);
  for (final d in PawMateBottomNav.destinations) {
    final t = find.descendant(of: nav, matching: find.text(d.label));
    expect(t, findsOneWidget);
    expect(tester.getRect(t).bottom, lessThanOrEqualTo(size.height - 34));
    expect(tester.renderObject<RenderParagraph>(t).didExceedMaxLines, isFalse);
  }
}

void _notTruncated(WidgetTester tester, String label, {Finder? within}) {
  final f = within == null
      ? find.text(label)
      : find.descendant(of: within, matching: find.text(label));
  expect(f, findsOneWidget);
  expect(
    tester.renderObject<RenderParagraph>(f).didExceedMaxLines,
    isFalse,
    reason: label,
  );
}

void _labels(WidgetTester tester) {
  for (final text in [
    'Quay lại danh sách',
    'Xem hồ sơ',
    'Nhắn mái ấm',
    'Khám phá bé khác',
    'Xem chi tiết',
    'Thu gọn',
    'Xem thêm',
    'Đang xem xét',
    'Đã chấp thuận',
    'Không phù hợp',
  ]) {
    for (final e in find.text(text).evaluate()) {
      final r = e.findRenderObject();
      if (r is RenderParagraph && r.hasSize) {
        expect(r.didExceedMaxLines, isFalse, reason: text);
      }
    }
  }
}
