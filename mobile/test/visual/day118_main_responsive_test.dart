import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import 'package:pawmate_mobile/features/adoption/presentation/widgets/adoption_media_frame.dart';

import '../test_support/ui_test_helpers.dart';
import 'phase1_pet_golden_test.dart' as pets;
import 'phase1_home_profile_golden_test.dart' as home;
import 'day23_vet_finder_golden_test.dart' as vets;
import 'day24_vet_detail_review_golden_test.dart' as detail;
import 'day27_health_timeline_event_golden_test.dart' as health;
import 'day28_reminder_notification_golden_test.dart' as reminders;
import 'ui_v031_rescue_live_golden_test.dart' as rescue;
import 'ui_v031_rescue_case_detail_golden_test.dart' as rescue_detail;
import 'day44_rescue_map_golden_test.dart' as rescue_map;
import 'day46_rescue_status_discussion_golden_test.dart' as discussion;
import 'day54_adoption_golden_test.dart' as adoption;
import 'day55_adoption_request_chat_golden_test.dart' as chat;
import 'day60_health_preferences_golden_test.dart' as hub;

typedef _Pump = Future<void> Function(WidgetTester, Size);
final _families = <String, _Pump>{
  'P1-05': pets.pumpDay118PetList,
  'P1-07': home.pumpDay118Home,
  'P1-08': vets.pumpDay118VetMap,
  'P1-09': vets.pumpDay118VetList,
  'P1-10': detail.pumpDay118VetDetail,
  'P1-12': health.pumpDay118Timeline,
  'P1-14': reminders.pumpDay118Calendar,
  'P1-15': reminders.pumpDay118Notifications,
  'P1-16': home.pumpDay118Profile,
  'P2-01': rescue.pumpDay118RescueHome,
  'P2-04': rescue_detail.pumpDay118RescueDetail,
  'P2-05': rescue_map.pumpDay118RescueMap,
  'P2-08': discussion.pumpDay118Discussion,
  'P2-09': adoption.pumpDay118AdoptionDeck,
  'P2-10': adoption.pumpDay118AdoptionProfile,
  'P2-12': chat.pumpDay118Chat,
  'P2-13': hub.pumpDay118HealthHub,
};
const _viewports = [Size(360, 800), Size(390, 844), Size(430, 932)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  for (final family in _families.entries) {
    for (final viewport in _viewports) {
      final id =
          '${family.key}-${viewport.width.toInt()}x${viewport.height.toInt()}';
      testWidgets('D118 $id adaptive safe-area and scroll proof', (
        tester,
      ) async {
        // Actual FlutterView insets, not a transform or a screenshot crop.
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetPadding);
        await family.value(tester, viewport);
        await _ready(tester);
        await _capture(tester, '$id-top');
        expectNoFlutterOverflow(tester);
        _expectNav(tester, viewport);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/day118/$id.png'),
        );

        // The real owner's vertical scroll must consume content while the
        // immutable bottom navigation remains at physical bottom.
        final vertical = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        );
        if (vertical.evaluate().isNotEmpty) {
          final state = tester.state<ScrollableState>(vertical.first);
          final position = state.position;
          if (position.maxScrollExtent > 0) {
            // Sliver estimates settle after lazily building the final rows.
            // Re-read the observed extent rather than asserting an old estimate.
            for (var attempt = 0; attempt < 5; attempt++) {
              position.jumpTo(position.maxScrollExtent);
              await tester.pumpAndSettle();
              if (position.extentAfter < 0.5) break;
            }
            expect(position.extentAfter, lessThan(0.5));
            expectNoFlutterOverflow(tester);
            _expectNav(tester, viewport);
            await _capture(tester, '$id-end');
          }
        }
        _expectPrimaryLabels(tester);
      });
    }
  }

  for (final viewport in _viewports) {
    testWidgets('D118 P1-10-${viewport.width.toInt()} full metric label', (
      tester,
    ) async {
      await detail.pumpDay118VetDetail(tester, viewport);
      await _ready(tester);
      final label = find.text('KHOẢNG CÁCH');
      expect(label, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
        isFalse,
      );
      expectNoFlutterOverflow(tester);
    });
    testWidgets(
      'D118 P2-10-${viewport.width.toInt()} photo actions avoid notch',
      (tester) async {
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
        addTearDown(tester.view.resetViewPadding);
        addTearDown(tester.view.resetPadding);
        await adoption.pumpDay118AdoptionProfile(tester, viewport);
        await _ready(tester);
        for (final control in [
          find.byTooltip('Quay lại'),
          find.byKey(const Key('adoption-profile-share')),
        ]) {
          expect(control, findsOneWidget);
          expect(tester.getRect(control).top, greaterThanOrEqualTo(24));
          expect(control.hitTestable(), findsOneWidget);
        }
        expectNoFlutterOverflow(tester);
      },
    );
    testWidgets(
      'D118 P1-05-${viewport.width.toInt()} dynamic long collection reaches last pet',
      (tester) async {
        await pets.pumpDay118DynamicPets(tester, viewport);
        await _ready(tester);
        final scroll = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(
          find.text('Bạn nhỏ Mochi đáng yêu số 17'),
          500,
          scrollable: scroll,
          maxScrolls: 30,
        );
        await tester.pumpAndSettle();
        final last = find.text('Bạn nhỏ Mochi đáng yêu số 17');
        expect(last, findsOneWidget);
        final nav = tester.getRect(find.byType(PawMateBottomNav));
        expect(tester.getRect(last).bottom, lessThanOrEqualTo(nav.top));
        expectNoFlutterOverflow(tester);
        await _capture(tester, 'P1-05-${viewport.width.toInt()}-dynamic-end');
      },
    );
    for (final discussionMode in [false, true]) {
      final id =
          '${discussionMode ? 'P2-08' : 'P2-12'}-${viewport.width.toInt()}-IME';
      testWidgets(
        'D118 $id composer stays above keyboard and preserves long draft',
        (tester) async {
          await (discussionMode
              ? discussion.pumpDay118Discussion
              : chat.pumpDay118Chat)(tester, viewport);
          await _ready(tester);
          final field = find.byKey(
            Key(
              discussionMode
                  ? 'rescue-comment-field'
                  : 'adoption-chat-composer',
            ),
          );
          const body =
              'Mình muốn tìm hiểu thêm về sức khỏe của bé và lịch chăm sóc hằng ngày. Cảm ơn bạn đã hỗ trợ!';
          await tester.enterText(field, body);
          await setKeyboardInset(tester, bottom: 300);
          await tester.pumpAndSettle();
          final send = find.byKey(
            Key(discussionMode ? 'rescue-comment-send' : 'adoption-chat-send'),
          );
          final rect = tester.getRect(send);
          expect(rect.bottom, lessThanOrEqualTo(viewport.height - 300));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(send.hitTestable(), findsOneWidget);
          expect(tester.widget<TextField>(field).controller!.text, body);
          expectNoFlutterOverflow(tester);
          await _capture(tester, id);
          tester.view.viewInsets = const FakeViewPadding();
        },
      );
    }
    for (final profile in [false, true]) {
      final id =
          '${profile ? 'P2-10' : 'P2-09'}-${viewport.width.toInt()}x${viewport.height.toInt()}-hero';
      testWidgets('D118 $id preserves photo composition from real constraints', (
        tester,
      ) async {
        await (profile
            ? adoption.pumpDay118AdoptionProfile
            : adoption.pumpDay118AdoptionDeck)(tester, viewport);
        await _ready(tester);
        final frame = find.byType(AdoptionMediaFrame).first;
        final size = tester.getSize(frame);
        await _capture(tester, id);
        expect(
          size.width / size.height,
          closeTo(profile ? 390 / 412 : 356 / 326, 0.001),
          reason:
              'Photo stage adapts to available width, preserving the 390dp anchor crop; fixed height crops differently on small/large devices.',
        );
        expectNoFlutterOverflow(tester);
      });
    }
  }
}

void _expectNav(WidgetTester tester, Size size) {
  final nav = find.byType(PawMateBottomNav);
  if (nav.evaluate().isEmpty) return; // Detail routes intentionally omit shell.
  expect(nav, findsOneWidget);
  final bounds = tester.getRect(nav);
  expect(bounds.left, 0);
  expect(bounds.right, size.width);
  expect(
    bounds.bottom,
    size.height,
    reason: 'Nav must own the bottom safe-area once',
  );
  for (final destination in PawMateBottomNav.destinations) {
    final text = find.descendant(
      of: nav,
      matching: find.text(destination.label),
    );
    expect(text, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(text);
    expect(paragraph.didExceedMaxLines, isFalse, reason: destination.label);
    expect(tester.getRect(text).bottom, lessThanOrEqualTo(size.height - 34));
  }
}

void _expectPrimaryLabels(WidgetTester tester) {
  // Explicit critical action labels, not incidental ellipsized collection
  // previews. Hidden list rows are checked once reached by the scroll proof.
  for (final label in [
    'Gọi ngay',
    'Chỉ đường',
    'Gửi yêu cầu nhận nuôi',
    'Xác nhận',
    'Thêm thú cưng',
    'Xem thêm',
    'Tất cả',
    'Đọc hết',
  ]) {
    for (final element in find.text(label).evaluate()) {
      final paragraph = element.findRenderObject();
      if (paragraph is RenderParagraph && paragraph.hasSize) {
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: 'Critical CTA: $label',
        );
      }
    }
  }
}

Future<void> _ready(WidgetTester tester) async {
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final dir in ['assets/images', 'assets/icons']) {
      for (final file in Directory(
        dir,
      ).listSync(recursive: true).whereType<File>()) {
        final name = file.path.replaceAll(r'\', '/');
        if (!RegExp(r'\.(png|jpg|jpeg|webp)$').hasMatch(name)) continue;
        Object? error;
        await precacheImage(
          AssetImage(name),
          context,
          onError: (e, _) => error = e,
        );
        if (error != null) throw StateError('$name: $error');
      }
    }
  });
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String id) async {
  final output = Platform.environment['D118_SCREENSHOTS'];
  if (output == null || output.isEmpty) return;
  final handle = tester.ensureSemantics();
  await tester.pump();
  final context = tester.element(find.byType(MaterialApp));
  final media = MediaQuery.of(context);
  String? tree;
  void visit(PipelineOwner owner) {
    tree ??= owner.semanticsOwner?.rootSemanticsNode?.toStringDeep();
    owner.visitChildren(visit);
  }

  visit(tester.binding.rootPipelineOwner);
  if (tree == null) throw StateError('No semantics root');
  await tester.runAsync(() async {
    final image = await captureImage(context);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('No PNG');
    final dir = Directory(output)..createSync(recursive: true);
    for (final suffix in ['png', 'json', 'semantics.txt']) {
      if (File('${dir.path}/$id.$suffix').existsSync()) {
        throw StateError('Capture exists: $id');
      }
    }
    await File(
      '${dir.path}/$id.png',
    ).writeAsBytes(data.buffer.asUint8List(), flush: true);
    await File(
      '${dir.path}/$id.semantics.txt',
    ).writeAsString(tree!, flush: true);
    await File('${dir.path}/$id.json').writeAsString(
      jsonEncode({
        'id': id,
        'test': tester.testDescription,
        'width': image.width,
        'height': image.height,
        'top_safe_area': media.viewPadding.top,
        'bottom_safe_area': media.viewPadding.bottom,
        'kind':
            'production-owner-widget-declared-API-map-clock-doubles-not-native',
        'at': DateTime.now().toUtc().toIso8601String(),
      }),
      flush: true,
    );
    image.dispose();
  });
  handle.dispose();
}
