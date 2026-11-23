import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';

import '../test_support/ui_test_helpers.dart';
import 'phase1_entry_golden_test.dart' as entry;
import 'phase1_register_otp_golden_test.dart' as auth;
import 'phase1_pet_golden_test.dart' as pet;
import 'day91_pet_detail_edit_golden_test.dart' as edit;
import 'day24_vet_detail_review_golden_test.dart' as vet;
import 'day27_health_timeline_event_golden_test.dart' as health;
import 'day28_reminder_notification_golden_test.dart' as reminder;
import 'ui_v031_rescue_create_golden_test.dart' as rescue;
import 'day45_rescue_comment_golden_test.dart' as comment;
import 'day46_rescue_status_discussion_golden_test.dart' as status;
import 'day55_adoption_request_chat_golden_test.dart' as request;
import 'day60_health_preferences_golden_test.dart' as notification;
import 'day61_profile_privacy_golden_test.dart' as privacy;
import 'day102_report_review_golden_test.dart' as review;
import 'day103_location_picker_golden_test.dart' as location;
import 'day54_adoption_golden_test.dart' as filter;

const families = [
  'P1-01',
  'P1-02',
  'P1-03',
  'P1-04',
  'P1-06',
  'P1-11',
  'P1-13',
  'P2-02',
  'P2-03',
  'P2-06',
  'P2-07',
  'P2-11',
  'P2-14',
  'P2-15',
  'P2-16',
  'DT-02',
  'DT-06',
  'DT-07',
  'DT-08',
  'DT-09',
  'DT-10',
];
const endpoints = [Size(360, 800), Size(430, 932)];
const imeFamilies = [
  'P1-01',
  'P1-02',
  'P1-03',
  'P1-04',
  'P1-06',
  'P1-11',
  'P1-13',
  'P2-02',
  'P2-03',
  'P2-06',
  'P2-11',
  'DT-02',
  'DT-06',
  'DT-09',
];
const actionKeys = {
  'P1-01': 'onboarding-continue-button',
  'P1-02': 'login-submit-button',
  'P1-03': 'register-submit-button',
  'P1-04': 'otp-confirm-button',
  'P1-06': 'pet-form-save-button',
  'P1-11': 'write-review-submit',
  'P1-13': 'add-health-save-button',
  'P2-02': 'rescue-create-continue-cta',
  'P2-03': 'rescue-info-publish-cta',
  'P2-06': 'rescue-comment-send',
  'P2-11': 'adoption-request-submit-cta',
  'DT-02': 'pet-form-save-button',
  'DT-06': 'reminder-create-save-button',
  'DT-09': 'rescue-location-confirm',
  'DT-10': 'adoption-apply-filters',
  'P2-16': 'profile-controls-delete-account',
};

Future<void> pumpFamily(WidgetTester t, String family, Size size) async {
  switch (family) {
    case 'P1-01':
      await entry.pumpDay120Entry(t, size, login: false);
    case 'P1-02':
      await entry.pumpDay120Entry(t, size, login: true);
    case 'P1-03':
      await auth.pumpDay120Auth(t, size, otp: false);
    case 'P1-04':
      await auth.pumpDay120Auth(t, size, otp: true);
    case 'P1-06':
      await pet.pumpDay120PetCreate(t, size);
    case 'P1-11':
      await vet.pumpDay120VetSheet(t, size, list: false);
    case 'P1-13':
      await health.pumpDay120HealthEvent(t, size);
    case 'P2-02':
      await rescue.pumpDay120RescueForm(t, size, info: false);
    case 'P2-03':
      await rescue.pumpDay120RescueForm(t, size, info: true);
    case 'P2-06':
      await comment.pumpDay120Comment(t, size);
    case 'P2-07':
      await status.pumpDay120Status(t, size);
    case 'P2-11':
      await request.pumpDay120AdoptionRequest(t, size);
    case 'P2-14':
      await notification.pumpDay120NotificationPreferences(t, size);
    case 'P2-15':
      await privacy.pumpDay120Privacy(t, size, controls: false);
    case 'P2-16':
      await privacy.pumpDay120Privacy(t, size, controls: true);
    case 'DT-02':
      await edit.pumpDay120PetEdit(t, size);
    case 'DT-06':
      await reminder.pumpDay120Reminder(t, size);
    case 'DT-07':
      await vet.pumpDay120VetSheet(t, size, list: true);
    case 'DT-08':
      await review.pumpDay120ReportReview(t, size);
    case 'DT-09':
      await location.pumpDay120Location(t, size);
    case 'DT-10':
      await filter.pumpDay120AdoptionFilter(t, size);
    default:
      throw StateError(family);
  }
  t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
  t.view.padding = const FakeViewPadding(top: 24, bottom: 34);
  addTearDown(t.view.resetViewPadding);
  addTearDown(t.view.resetPadding);
  FocusManager.instance.primaryFocus?.unfocus();
  final context = t.element(find.byType(MaterialApp));
  await t.runAsync(() async {
    for (final folder in ['assets/images', 'assets/icons']) {
      for (final file in Directory(
        folder,
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
  // OTP's PinCodeTextField has a continuously animated empty-cell treatment.
  // As in its original fixture, advance a bounded frame window, not settle.
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });
  for (final size in endpoints) {
    testWidgets(
      'D120 species padded edge selects cat at ${size.width.toInt()}x${size.height.toInt()}',
      (t) async {
        await pumpFamily(t, 'P1-06', size);
        final segment = find.widgetWithText(TextButton, 'Mèo');
        expect(segment, findsOneWidget);
        await t.ensureVisible(segment);
        await t.pump(const Duration(milliseconds: 400));
        final rect = t.getRect(segment);
        expect(rect.height, greaterThanOrEqualTo(48));
        // Exercise the padded hit surface, not just the visible 40dp capsule.
        await t.tapAt(Offset(rect.center.dx, rect.bottom - 1));
        await t.pump(const Duration(milliseconds: 400));
        final control = t.widget<SegmentedButton<String>>(
          find.byKey(const Key('pet-form-species-segment')),
        );
        expect(control.selected, {'cat'});
        expectNoFlutterOverflow(t);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      },
    );
  }
  for (final size in endpoints) {
    for (final family in families) {
      final id = '$family-${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('D120 $id composition safe-area targets and golden', (
        t,
      ) async {
        await pumpFamily(t, family, size);
        expectNoFlutterOverflow(t);
        _geometry(t, size);
        await _capture(t, '$id-top');
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/day120/$id.png'),
        );
        await _end(t);
        await _actionVisible(t, family, size, keyboard: false);
        _geometry(t, size);
        expectNoFlutterOverflow(t);
        await _capture(t, '$id-end');
        // Dispose the OTP timer and asynchronous sheets before fixture teardown.
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      });
    }
    for (final family in imeFamilies) {
      final id = '$family-${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('D120 $id IME scroll retains draft and reachable CTA', (
        t,
      ) async {
        await pumpFamily(t, family, size);
        final fields = find
            .byType(EditableText)
            .evaluate()
            .where((e) => ModalRoute.of(e)?.isCurrent != false)
            .toList();
        expect(
          fields,
          isNotEmpty,
          reason: 'Must exercise a real production input',
        );
        final element = fields.last;
        final field = find.byElementPredicate((e) => identical(e, element));
        await t.ensureVisible(field);
        await t.showKeyboard(field);
        await t.pump(const Duration(milliseconds: 400));
        final before = (element.widget as EditableText).controller.text;
        t.view.viewInsets = const FakeViewPadding(bottom: 300);
        t.view.padding = const FakeViewPadding(top: 24);
        await t.pump(const Duration(milliseconds: 400));
        await _end(t);
        await _actionVisible(t, family, size, keyboard: true);
        _geometry(t, size);
        expectNoFlutterOverflow(t);
        expect((element.widget as EditableText).controller.text, before);
        await _capture(t, '$id-ime');
        FocusManager.instance.primaryFocus?.unfocus();
        t.testTextInput.hide();
        t.view.viewInsets = const FakeViewPadding();
        t.view.padding = const FakeViewPadding(top: 24, bottom: 34);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      });
    }
  }
}

Future<void> _actionVisible(
  WidgetTester t,
  String family,
  Size size, {
  required bool keyboard,
}) async {
  Finder action;
  if (actionKeys.containsKey(family)) {
    action = find.byKey(Key(actionKeys[family]!));
  } else if (family == 'P2-07') {
    action = find.widgetWithText(PawMateButton, 'Lưu trạng thái');
  } else if (family == 'P2-14' || family == 'P2-15') {
    action = find.widgetWithText(PawMateButton, 'Lưu thay đổi');
  } else if (family == 'DT-08') {
    action = find.byKey(const Key('rescue-review-back'));
  } else if (family == 'DT-07') {
    // A read-only list with no next cursor deliberately has no fabricated CTA.
    expect(find.byKey(const Key('review-list-item-review-1')), findsOneWidget);
    return;
  } else {
    throw StateError('Missing action owner: $family');
  }
  expect(action, findsOneWidget);
  final nested = find.descendant(
    of: action,
    matching: find.byType(PawMateButton),
  );
  if (nested.evaluate().length == 1) action = nested;
  await t.ensureVisible(action);
  await t.pump(const Duration(milliseconds: 400));
  final rect = t.getRect(action);
  expect(
    rect.top,
    greaterThanOrEqualTo(24),
    reason: 'CTA must be reachable below status bar',
  );
  expect(
    rect.bottom,
    lessThanOrEqualTo(size.height - (keyboard ? 300 : 34) + .1),
    reason: 'CTA above keyboard/home indicator: $family',
  );
  for (final e
      in find.descendant(of: action, matching: find.byType(Text)).evaluate()) {
    final render = e.renderObject;
    if (render is RenderParagraph) {
      expect(
        render.didExceedMaxLines,
        isFalse,
        reason: 'Important CTA must not truncate',
      );
    }
  }
}

void _geometry(WidgetTester t, Size size) {
  for (final e
      in find
          .byWidgetPredicate(
            (w) =>
                w is ButtonStyleButton ||
                w is IconButton ||
                w is FilterChip ||
                w is ChoiceChip,
          )
          .evaluate()) {
    if (ModalRoute.of(e)?.isCurrent == false) continue;
    final f = find.byElementPredicate((candidate) => identical(candidate, e));
    if (f.hitTestable().evaluate().isEmpty) continue;
    final rect = t.getRect(f);
    expect(
      rect.width,
      greaterThanOrEqualTo(48),
      reason: 'Native touch width ${e.widget.key ?? e.widget.runtimeType}',
    );
    expect(
      rect.height,
      greaterThanOrEqualTo(48),
      reason: 'Native touch height ${e.widget.key ?? e.widget.runtimeType}',
    );
  }
  for (final e in find.byType(PawMateButton).evaluate()) {
    final render = e.renderObject;
    if (render is! RenderBox || !render.hasSize) continue;
    final rect = render.localToGlobal(Offset.zero) & render.size;
    if (rect.bottom <= 24 || rect.top >= size.height - 34) continue;
    expect(rect.width, greaterThanOrEqualTo(48), reason: 'Button target width');
    expect(
      rect.height,
      greaterThanOrEqualTo(48),
      reason: 'Button target height',
    );
    expect(rect.left, greaterThanOrEqualTo(-.1));
    expect(rect.right, lessThanOrEqualTo(size.width + .1));
  }
  for (final e in find.byType(Text).evaluate()) {
    if (ModalRoute.of(e)?.isCurrent == false) continue;
    final p = e.renderObject;
    if (p is! RenderParagraph || !p.hasSize) continue;
    // Floating input labels use a paint transform; include both transformed
    // corners instead of adding an unscaled paragraph width to a scaled origin.
    final r = Rect.fromPoints(
      p.localToGlobal(Offset.zero),
      p.localToGlobal(p.size.bottomRight(Offset.zero)),
    );
    if (r.bottom <= 24 || r.top >= size.height - 34) continue;
    expect(r.left, greaterThanOrEqualTo(-.1));
    expect(
      r.right,
      lessThanOrEqualTo(size.width + .1),
      reason: (e.widget as Text).data,
    );
  }
  final nav = find.byType(PawMateBottomNav);
  if (nav.evaluate().isNotEmpty) {
    expect(t.getRect(nav.last).bottom, closeTo(size.height, .1));
  }
}

Future<void> _end(WidgetTester t) async {
  // Only the current route's vertical scrollables: never move the obscured
  // route behind a sheet or turn a horizontal chip list into a layout proof.
  for (final e in find.byType(Scrollable).evaluate().toList().reversed) {
    final state = (e as StatefulElement).state as ScrollableState;
    if (state.position.axis != Axis.vertical) continue;
    for (var i = 0; i < 4; i++) {
      state.position.jumpTo(state.position.maxScrollExtent);
      await t.pump(const Duration(milliseconds: 400));
    }
  }
}

Future<void> _capture(WidgetTester t, String id) async {
  final out = Platform.environment['D120_SCREENSHOTS'];
  if (out == null || out.isEmpty) return;
  final handle = t.ensureSemantics();
  await t.pump();
  String? tree;
  void visit(PipelineOwner o) {
    tree ??= o.semanticsOwner?.rootSemanticsNode?.toStringDeep();
    o.visitChildren(visit);
  }

  visit(t.binding.rootPipelineOwner);
  if (tree == null) throw StateError('No semantics');
  await t.runAsync(() async {
    final image = await captureImage(t.element(find.byType(MaterialApp)));
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(out).createSync(recursive: true);
    final base = '$out/$id';
    for (final ext in ['png', 'json', 'semantics.txt']) {
      if (File('$base.$ext').existsSync()) {
        throw StateError('Immutable capture $base');
      }
    }
    File('$base.png').writeAsBytesSync(data!.buffer.asUint8List());
    File('$base.semantics.txt').writeAsStringSync(tree!);
    File('$base.json').writeAsStringSync(
      jsonEncode({
        'id': id,
        'test': t.testDescription,
        'at': DateTime.now().toUtc().toIso8601String(),
        'width': image.width,
        'height': image.height,
        'top_safe_area': 24,
        'bottom_safe_area': 34,
        'kind': 'WIDGET_API_MAP_CLOCK_DOUBLES_NOT_NATIVE',
      }),
    );
    image.dispose();
  });
  handle.dispose();
}
