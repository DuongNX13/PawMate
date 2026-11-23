import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/features/adoption/application/my_adoption_requests_provider.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_request_chat_models.dart';
import 'package:pawmate_mobile/features/adoption/presentation/my_adoption_requests_screen.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../test_support/day115_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadPawMateTestFonts);

  testWidgets('ST-20 renders exact discovery CTA and returns to Adoption', (
    tester,
  ) async {
    final harness = await _pump(
      tester,
      requests: const [],
      textScale: 2,
      viewport: const Size(320, 568),
    );
    addTearDown(harness.dispose);

    expect(find.bySemanticsLabel('Đơn nhận nuôi của tôi'), findsOneWidget);
    final title = find.text('Đơn của tôi');
    expect(title, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
      isFalse,
      reason: 'Visible P2-13 title must not ellipsize at text scale 2.0',
    );
    expect(find.byKey(const Key('my-adoption-requests-empty')), findsOneWidget);
    expect(find.text('Bạn chưa có đơn nhận nuôi'), findsOneWidget);
    expect(find.text('Khám phá bé cần nhận nuôi'), findsOneWidget);
    expectNoFlutterOverflow(tester);

    final discoveryCta = find.text('Khám phá bé cần nhận nuôi');
    await tester.ensureVisible(discoveryCta);
    await tester.pumpAndSettle();
    await captureDay115(tester, 'ST-20');
    await tester.tap(discoveryCta);
    await tester.pumpAndSettle();

    expect(harness.router.routeInformationProvider.value.uri.path, '/adoption');
    expect(find.byKey(const Key('adoption-target')), findsOneWidget);
  });

  testWidgets('non-empty requests expose status, profile and private chat', (
    tester,
  ) async {
    final request = AdoptionRequestSummary.fromJson({
      'requestId': 'request-1',
      'listingId': '11111111-1111-4111-8111-111111111111',
      'petName': 'Golden đang chờ một mái ấm thật phù hợp',
      'status': 'reviewing',
      'listingAvailability': 'available',
      'threadId': '33333333-3333-4333-8333-333333333333',
      'createdAt': '2026-07-28T05:00:00.000Z',
      'updatedAt': '2026-07-29T05:00:00.000Z',
    });
    final harness = await _pump(
      tester,
      requests: [request],
      textScale: 2,
      viewport: const Size(320, 568),
    );
    addTearDown(harness.dispose);

    expect(find.byKey(const Key('my-adoption-requests-list')), findsOneWidget);
    expect(find.text('Đang xem xét'), findsOneWidget);
    expect(find.text('Xem hồ sơ'), findsOneWidget);
    expect(find.text('Nhắn mái ấm'), findsOneWidget);
    expectNoFlutterOverflow(tester);

    final chatButton = find.byKey(
      const Key('my-adoption-request-chat-request-1'),
    );
    await tester.ensureVisible(chatButton);
    await tester.pumpAndSettle();
    final button = tester.widget<PawMateButton>(chatButton);
    expect(button.onPressed, isNotNull);
    button.onPressed!();
    await tester.pumpAndSettle();
    expectNoFlutterOverflow(tester);

    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/adoption/chat/33333333-3333-4333-8333-333333333333',
    );
    expect(find.byKey(const Key('chat-target')), findsOneWidget);
  });

  testWidgets('P2-13 offline recovery actions remain reachable at large text', (
    tester,
  ) async {
    final harness = await _pump(
      tester,
      requests: const [],
      error: const AdoptionApiException(
        'Không thể kết nối.',
        code: 'NETWORK_OFFLINE',
      ),
      textScale: 2,
      viewport: const Size(320, 568),
    );
    addTearDown(harness.dispose);

    expect(find.byKey(const Key('my-adoption-requests-error')), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Khám phá các bé'), findsOneWidget);
    expectNoFlutterOverflow(tester);

    final retry = find.text('Thử lại');
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my-adoption-requests-error')), findsOneWidget);

    final discovery = find.text('Khám phá các bé');
    await tester.ensureVisible(discovery);
    await tester.pumpAndSettle();
    await tester.tap(discovery);
    await tester.pumpAndSettle();

    expect(harness.router.routeInformationProvider.value.uri.path, '/adoption');
    expect(find.byKey(const Key('adoption-target')), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    'DT-03 deleted listing hides stale profile action and keeps safe recovery',
    (tester) async {
      final request = AdoptionRequestSummary.fromJson({
        'requestId': 'request-deleted',
        'listingId': '11111111-1111-4111-8111-111111111111',
        'petName': 'Mochi',
        'status': 'approved',
        'listingAvailability': 'deleted',
        'threadId': '33333333-3333-4333-8333-333333333333',
        'createdAt': '2026-07-28T05:00:00.000Z',
        'updatedAt': '2026-07-29T05:00:00.000Z',
      });
      final harness = await _pump(
        tester,
        requests: [request],
        textScale: 2,
        viewport: const Size(320, 568),
      );
      addTearDown(harness.dispose);

      expect(find.text('Hồ sơ đã bị xóa'), findsOneWidget);
      expect(find.text('Xem hồ sơ'), findsNothing);
      expect(find.text('Khám phá bé khác'), findsOneWidget);
      expect(find.text('Nhắn mái ấm'), findsOneWidget);
      expectNoFlutterOverflow(tester);
    },
  );
}

Future<_Harness> _pump(
  WidgetTester tester, {
  required List<AdoptionRequestSummary> requests,
  required double textScale,
  Size viewport = const Size(390, 844),
  Object? error,
}) async {
  await setTestViewport(tester, size: viewport);
  final router = GoRouter(
    initialLocation: '/adoption/requests',
    routes: [
      GoRoute(
        path: '/adoption/requests',
        builder: (_, _) => const MyAdoptionRequestsScreen(),
      ),
      GoRoute(
        path: '/adoption',
        builder: (_, _) =>
            const Scaffold(body: SizedBox(key: Key('adoption-target'))),
      ),
      GoRoute(
        path: '/adoption/chat/:threadId',
        builder: (_, _) =>
            const Scaffold(body: SizedBox(key: Key('chat-target'))),
      ),
      GoRoute(
        path: '/adoption/:listingId',
        builder: (_, _) =>
            const Scaffold(body: SizedBox(key: Key('profile-target'))),
      ),
    ],
  );
  final container = ProviderContainer(
    overrides: [
      myAdoptionRequestsProvider.overrideWith((ref) async {
        if (error != null) {
          throw error;
        }
        return requests;
      }),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: testTextScaleBuilder(textScale),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(container, router);
}

class _Harness {
  const _Harness(this.container, this.router);

  final ProviderContainer container;
  final GoRouter router;

  void dispose() {
    router.dispose();
    container.dispose();
  }
}
