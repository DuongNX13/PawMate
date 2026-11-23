import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/notifications/application/notification_providers.dart';
import 'package:pawmate_mobile/features/notifications/domain/pawmate_notification.dart';
import 'package:pawmate_mobile/features/notifications/presentation/notification_center_screen.dart';
import 'package:pawmate_mobile/features/vets/application/vet_map_provider.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_map_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_screen.dart';

import '../test_support/day119_detail_support.dart';
import '../test_support/ui_test_helpers.dart';
import 'day120_support_scaling_test.dart' as support;
import 'day55_adoption_request_chat_golden_test.dart' as chat;

const stressFamilies = [
  'Onboarding',
  'PetEdit',
  'VetMap',
  'Notifications',
  'RescueExpanded',
  'RescueSelected',
  'ShelterChat',
  'MyRequests',
];

/// State double only: no GPS, permission controller, API or tile proof.
class _VetFixture extends VetMapNotifier {
  int retries = 0;
  @override
  VetMapState build() => const VetMapState(
    status: VetMapStatus.permissionDenied,
    hasLoadedAtLeastOnce: true,
  );
  @override
  Future<void> initialize() async {}
  @override
  Future<void> refresh({bool forceLocationRefresh = false}) async {
    retries++;
    state = state.copyWith(mapUnavailable: true);
  }

  @override
  void retryMap() {
    retries++;
    state = state.copyWith(mapUnavailable: false);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final family in stressFamilies) {
      final id = '$family-${platform.name}';
      testWidgets('D121 $id text2 stress and interaction', (t) async {
        debugDefaultTargetPlatformOverride = platform;
        t.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(() {
          debugDefaultTargetPlatformOverride = null;
          t.platformDispatcher.clearTextScaleFactorTestValue();
        });
        try {
          final size = family == 'ShelterChat'
              ? const Size(360, 800)
              : const Size(320, 568);
          switch (family) {
            case 'Onboarding':
            case 'PetEdit':
              final onboarding = family == 'Onboarding';
              await support.pumpFamily(t, onboarding ? 'P1-01' : 'DT-02', size);
              await capture121(t, '$id-top', size);
              final key = onboarding
                  ? 'onboarding-pet-name-field'
                  : 'pet-form-name-field';
              final action = onboarding
                  ? 'onboarding-continue-button'
                  : 'pet-form-save-button';
              final field = find.byKey(Key(key));
              await t.ensureVisible(field);
              await t.enterText(field, '');
              await visible121(t, find.byKey(Key(action)), size);
              await t.tap(find.byKey(Key(action)));
              await t.pump(const Duration(milliseconds: 400));
              expect(find.textContaining('Vui lòng nhập tên'), findsOneWidget);
              await t.ensureVisible(field);
              await t.enterText(field, 'Mochi thử nghiệm');
              t.view.viewInsets = const FakeViewPadding(bottom: 300);
              // Start and complete the IME-driven hero/field animation before
              // calculating ensureVisible against the final scroll extent.
              await t.pumpAndSettle();
              await visible121(t, find.byKey(Key(action)), size, keyboard: 300);
              expect(
                t
                    .widget<EditableText>(
                      find.descendant(
                        of: field,
                        matching: find.byType(EditableText),
                      ),
                    )
                    .controller
                    .text,
                'Mochi thử nghiệm',
              );
              await capture121(t, '$id-ime', size);
            case 'VetMap':
              await setTestViewport(t, size: size);
              final fixture = _VetFixture();
              await _app(t, const VetMapScreen(), [
                vetMapProvider.overrideWith(() => fixture),
              ]);
              await t.scrollUntilVisible(
                find.text('Chưa có quyền vị trí'),
                150,
                scrollable: find.byType(Scrollable).first,
              );
              panelCopy121(t);
              await capture121(t, '$id-denied', size);
              final denied = find.descendant(
                of: find.byKey(const ValueKey('permission-denied')),
                matching: find.text('Bật ngay'),
              );
              await visible121(t, denied, size);
              await t.tap(denied);
              await t.pumpAndSettle();
              expect(fixture.retries, 1);
              expect(find.text('Không hiển thị được bản đồ'), findsOneWidget);
              panelCopy121(t);
              final retry = find.text('Tải lại bản đồ');
              await visible121(t, retry, size);
              await capture121(t, '$id-offline', size);
              await t.tap(retry);
              await t.pumpAndSettle();
              expect(fixture.retries, 2);
              expect(find.text('Chưa có quyền vị trí'), findsOneWidget);
            case 'Notifications':
              await setTestViewport(t, size: size);
              final router = GoRouter(
                initialLocation: '/notifications',
                routes: [
                  GoRoute(
                    path: '/notifications',
                    builder: (_, _) => const NotificationCenterScreen(),
                  ),
                  GoRoute(
                    path: '/profile',
                    builder: (_, _) =>
                        const Scaffold(body: Text('QA profile destination')),
                  ),
                ],
              );
              addTearDown(router.dispose);
              await _app(t, null, [
                notificationListProvider.overrideWith(
                  (ref) async => const NotificationListResult(
                    items: [],
                    total: 0,
                    unreadCount: 0,
                    limit: 20,
                  ),
                ),
              ], router: router);
              await t.scrollUntilVisible(
                find.text('Chưa có thông báo mới'),
                150,
                scrollable: find.byType(Scrollable).first,
              );
              await capture121(t, '$id-top', size);
              final recovery = find.byKey(
                const ValueKey('notification-empty-profile-button'),
              );
              await visible121(t, recovery, size);
              await capture121(t, '$id-recovery', size);
              await t.tap(recovery);
              await t.pumpAndSettle();
              expect(
                router.routeInformationProvider.value.uri.path,
                '/profile',
              );
            case 'RescueExpanded':
            case 'RescueSelected':
              final h = await pumpDay119(t, 'DT-04', size, longContent: true);
              if (family == 'RescueExpanded') {
                final toggle = find.byKey(const Key('rescue-load-more'));
                await visible121(t, toggle, size);
                await t.tap(toggle);
                await t.pumpAndSettle();
                expect(find.text('Thu gọn'), findsOneWidget);
                await capture121(t, '$id-top', size);
                await t.scrollUntilVisible(
                  find.text('Mây'),
                  100,
                  scrollable: find.byType(Scrollable).last,
                );
                await visible121(t, find.text('Mây'), size);
                await capture121(t, '$id-last', size);
                await visible121(t, toggle, size);
                await t.tap(toggle);
                await t.pumpAndSettle();
                expect(find.text('Xem thêm'), findsOneWidget);
              } else {
                final marker = find.byKey(
                  ValueKey('rescue-marker-$day119FirstCaseId'),
                );
                await visible121(t, marker, size);
                await t.tap(marker);
                await t.pumpAndSettle();
                expect(
                  find.byKey(const Key('rescue-selected-case-card')),
                  findsOneWidget,
                );
                final details = find.byKey(
                  const Key('rescue-selected-details'),
                );
                await visible121(t, details, size);
                await capture121(t, '$id-selected', size);
                await t.tap(details);
                await t.pumpAndSettle();
                expect(
                  find.byKey(const Key('rescue-case-detail-screen')),
                  findsOneWidget,
                );
                h.router.pop();
                await t.pumpAndSettle();
                final close = find.byKey(const Key('rescue-selected-close'));
                await visible121(t, close, size);
                await t.tap(close);
                await t.pumpAndSettle();
                expect(
                  find.byKey(const Key('rescue-selected-case-card')),
                  findsNothing,
                );
              }
            case 'ShelterChat':
              await chat.pumpDay118Chat(t, size);
              final field = find.byKey(const Key('adoption-chat-composer'));
              await t.enterText(field, 'Liên hệ fixture 0900000000');
              t.view.viewInsets = const FakeViewPadding(bottom: 300);
              await t.pump(const Duration(milliseconds: 400));
              final send = find.byKey(const Key('adoption-chat-send'));
              await visible121(t, send, size, keyboard: 300);
              await capture121(t, '$id-ime', size);
              await t.tap(send);
              await t.pumpAndSettle();
              expect(
                find.byKey(const Key('adoption-chat-privacy-confirmation')),
                findsOneWidget,
              );
              await capture121(t, '$id-privacy', size);
              await t.tap(find.text('Xem lại'));
              await t.pumpAndSettle();
              expect(
                t.widget<TextField>(field).controller!.text,
                'Liên hệ fixture 0900000000',
              );
            case 'MyRequests':
              await pumpDay119(t, 'DT-03', size, longContent: true);
              await capture121(t, '$id-top', size);
              final last = find.byKey(
                const Key('my-adoption-request-chat-request-11'),
              );
              await t.scrollUntilVisible(
                last,
                300,
                scrollable: find.byType(Scrollable).first,
                maxScrolls: 80,
              );
              await visible121(t, last, size);
              await capture121(t, '$id-last', size);
              await t.pumpWidget(const SizedBox.shrink());
              await pumpDay119(
                t,
                'DT-03',
                size,
                requests: const AsyncValue.data([]),
              );
              final discover = find.text('Khám phá bé cần nhận nuôi');
              await visible121(t, discover, size);
              await capture121(t, '$id-empty', size);
              await t.pumpWidget(const SizedBox.shrink());
              await pumpDay119(
                t,
                'DT-03',
                size,
                requests: AsyncValue.error(
                  const AdoptionApiException(
                    'QA offline',
                    code: 'NETWORK_OFFLINE',
                  ),
                  StackTrace.current,
                ),
              );
              final retry = find.text('Thử lại');
              await visible121(t, retry, size);
              await capture121(t, '$id-error', size);
            // The injected provider is an immutable error fixture; retry dispatch
            // does not constitute API recovery. Recovery is covered by Day116.
          }
          expectNoFlutterOverflow(t);
          geometry121(t, size);
          await capture121(t, '$id-final', size);
          await t.pumpWidget(const SizedBox.shrink());
          await t.pumpAndSettle();
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }
}

Future<void> _app(
  WidgetTester t,
  Widget? home,
  List<Override> overrides, {
  GoRouter? router,
}) async {
  t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
  t.view.padding = const FakeViewPadding(top: 24, bottom: 34);
  addTearDown(t.view.resetViewPadding);
  addTearDown(t.view.resetPadding);
  await t.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: router == null
          ? MaterialApp(theme: AppTheme.light(), home: home)
          : MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await readyDay119(t);
}

Future<void> visible121(
  WidgetTester t,
  Finder target,
  Size size, {
  double keyboard = 0,
}) async {
  expect(target, findsOneWidget);
  final nested = find.descendant(
    of: target,
    matching: find.byType(PawMateButton),
  );
  if (nested.evaluate().length == 1) target = nested;
  await Scrollable.ensureVisible(t.element(target), alignment: .5);
  await t.pump(const Duration(milliseconds: 400));
  final button = find.ancestor(
    of: target,
    matching: find.byType(PawMateButton),
  );
  final rect = t.getRect(button.evaluate().isEmpty ? target : button.first);
  if (rect.top < 23.9 ||
      rect.bottom > size.height - (keyboard > 0 ? keyboard : 34) + .1) {
    await capture121(
      t,
      'diagnostic-${t.testDescription}-${keyboard.toInt()}',
      size,
    );
  }
  expect(rect.top, greaterThanOrEqualTo(24 - .1));
  expect(
    rect.bottom,
    lessThanOrEqualTo(size.height - (keyboard > 0 ? keyboard : 34) + .1),
  );
  expect(target.hitTestable(), findsOneWidget);
  for (final e
      in find.descendant(of: target, matching: find.byType(Text)).evaluate()) {
    final p = e.renderObject;
    if (p is RenderParagraph) {
      expect(
        p.didExceedMaxLines,
        isFalse,
        reason: 'Important action must not truncate',
      );
    }
  }
  expectNoFlutterOverflow(t);
}

void geometry121(WidgetTester t, Size size) {
  expect(
    MediaQuery.textScalerOf(t.element(find.byType(Scaffold).first)).scale(1),
    2,
  );
  for (final e in find.byType(Text).evaluate()) {
    if (ModalRoute.of(e)?.isCurrent == false) continue;
    final p = e.renderObject;
    if (p is! RenderParagraph || !p.hasSize) continue;
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

void panelCopy121(WidgetTester t) {
  for (final e
      in find
          .descendant(
            of: find.byKey(const Key('vet-map-bottom-panel')),
            matching: find.byType(Text),
          )
          .evaluate()) {
    final p = e.renderObject;
    if (p is RenderParagraph) {
      expect(
        p.didExceedMaxLines,
        isFalse,
        reason:
            'Location/offline recovery explanation must remain readable: ${(e.widget as Text).data}',
      );
    }
  }
}

Future<void> capture121(WidgetTester t, String id, Size size) async {
  expectNoFlutterOverflow(t);
  const primary = {
    'Onboarding': 'ime',
    'PetEdit': 'ime',
    'VetMap': 'offline',
    'Notifications': 'recovery',
    'RescueExpanded': 'last',
    'RescueSelected': 'selected',
    'ShelterChat': 'ime',
    'MyRequests': 'last',
  };
  for (final family in primary.keys) {
    for (final platform in ['android', 'iOS']) {
      if (id == '$family-$platform-${primary[family]}') {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/day121/$family-$platform.png'),
        );
      }
    }
  }
  final out = Platform.environment['D121_SCREENSHOTS'];
  if (out == null || out.isEmpty) return;
  final handle = t.ensureSemantics();
  await t.pump();
  final root = t.binding.rootPipelineOwner;
  final trees = <String>[];
  void collect(PipelineOwner owner) {
    final node = owner.semanticsOwner?.rootSemanticsNode;
    if (node != null) trees.add(node.toStringDeep());
    owner.visitChildren(collect);
  }

  collect(root);
  final metadata = {
    'id': id,
    'test': t.testDescription,
    'source_fingerprint':
        Platform.environment['D121_SOURCE_FINGERPRINT'] ??
        'UNPINNED_DIAGNOSTIC',
    'viewport': [size.width, size.height],
    'text_scale': 2,
    'platform': defaultTargetPlatform.name,
    'insets': {'top': 24, 'bottom': 34, 'ime': t.view.viewInsets.bottom},
    'proof': 'WIDGET_PLATFORM_SIMULATION_WITH_STATE_DOUBLES_NOT_NATIVE',
    'at': DateTime.now().toUtc().toIso8601String(),
  };
  await t.runAsync(() async {
    final image = await captureImage(t.element(find.byType(MaterialApp)));
    final bytes = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    image.dispose();
    Directory(out).createSync(recursive: true);
    for (final ext in ['png', 'json', 'semantics.txt']) {
      if (File('$out/$id.$ext').existsSync()) {
        throw StateError('Fresh capture ID required: $id');
      }
    }
    File('$out/$id.png').writeAsBytesSync(bytes);
    File('$out/$id.json').writeAsStringSync(jsonEncode(metadata));
    File('$out/$id.semantics.txt').writeAsStringSync(trees.join('\n'));
  });
  handle.dispose();
}
