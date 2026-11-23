import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_case_share_service.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';

import '../../test_support/ui_test_helpers.dart';
import 'rescue_test_fixtures.dart';

void main() {
  testWidgets(
    'owner sees status and comment actions without private contact leakage',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final source = FakeRescueSource(
        detail: sampleCaseDetail(canUpdateStatus: true),
      );
      final router = _router();
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router, source));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết tin báo'), findsOneWidget);
      expect(find.text('LuLu'), findsOneWidget);
      expect(find.text('Đặc điểm nhận dạng'), findsOneWidget);
      expect(
        find.byKey(const Key('rescue-detail-comment-bar')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('rescue-detail-owner-actions')),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const Key('rescue-detail-owner-actions')),
        findsOneWidget,
      );
      expect(find.text('Cập nhật trạng thái'), findsOneWidget);
      expect(find.textContaining('0900000000'), findsNothing);
      expect(find.textContaining('10.812345'), findsNothing);
      expect(find.textContaining('private-address'), findsNothing);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('viewer cannot see owner-only or disallowed comment actions', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = FakeRescueSource(
      detail: sampleCaseDetail(
        canComment: false,
        canUpdateStatus: false,
        behaviorHint: null,
      ),
    );
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router, source));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rescue-detail-comment-bar')), findsNothing);
    expect(find.byKey(const Key('rescue-detail-owner-actions')), findsNothing);
    expect(find.text('Tính cách và lưu ý'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('rescue-detail-report')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('rescue-detail-report')), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P2-04 opens one native share action for its public case', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = FakeRescueSource(detail: sampleCaseDetail());
    final shareSource = _PendingRescueCaseShareSource();
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _app(router, source, rescueCaseShareSource: shareSource),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rescue-detail-share')));
    await tester.pump();

    expect(shareSource.calls, 1);
    expect(
      shareSource.lastDetail?.caseId,
      '11111111-1111-4111-8111-111111111111',
    );
    expect(shareSource.lastOrigin, isNotNull);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('rescue-detail-share')))
          .onPressed,
      isNull,
    );
    expect(find.text('Đã sao chép liên kết tin báo.'), findsNothing);

    shareSource.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('P2-04 recovers when the native share action fails', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = FakeRescueSource(detail: sampleCaseDetail());
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _app(
        router,
        source,
        rescueCaseShareSource: _FailingRescueCaseShareSource(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rescue-detail-share')));
    await tester.pumpAndSettle();

    expect(
      find.text('Chưa thể mở bảng chia sẻ. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('rescue-detail-share')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('deleted case renders recoverable unavailable state', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = FakeRescueSource(
      detailError: const RescueApiException(
        'Không tìm thấy tin báo.',
        code: 'RESCUE_CASE_NOT_FOUND',
        statusCode: 404,
      ),
    );
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router, source));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rescue-detail-unavailable')), findsOneWidget);
    expect(find.text('Tin báo không còn khả dụng'), findsOneWidget);
    expect(find.text('Thử lại'), findsNothing);
    expect(find.text('Quay lại'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('detail stays readable at 360 width and text scale 2.0', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(360, 800));
    final source = FakeRescueSource(
      detail: sampleCaseDetail(
        canUpdateStatus: true,
        behaviorHint:
            'Bé nhút nhát khi gặp người lạ, hãy ngồi thấp và gọi tên thật nhẹ nhàng.',
      ),
    );
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _app(router, source),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tin báo'), findsOneWidget);
    expect(find.bySemanticsLabel('Chi tiết tin báo'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Cập nhật trạng thái'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cập nhật trạng thái'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P2-04 keeps its top-bar title readable at text scale 2.0', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(320, 568));
    final source = FakeRescueSource(detail: sampleCaseDetail());
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _app(router, source),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Chi tiết tin báo'), findsOneWidget);
    final title = find.text('Tin báo');
    expect(title, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
      isFalse,
      reason: 'Visible P2-04 title must not ellipsize at text scale 2.0',
    );
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P2-04 keeps its real comment CTA usable at narrow large text', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(320, 568));
    final source = FakeRescueSource(
      detail: sampleCaseDetail(canComment: true, canUpdateStatus: false),
    );
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _app(router, source),
      ),
    );
    await tester.pumpAndSettle();

    final action = find.bySemanticsLabel('Bình luận về tin báo này');
    expect(action, findsOneWidget);
    final actionRect = tester.getRect(action);
    expect(actionRect.bottom, lessThanOrEqualTo(568));
    expect(actionRect.height, greaterThanOrEqualTo(48));
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('Comment target'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });
}

Widget _app(
  GoRouter router,
  RescueCaseSource source, {
  RescueCaseShareSource? rescueCaseShareSource,
}) {
  return ProviderScope(
    overrides: [
      rescueApiProvider.overrideWithValue(source),
      if (rescueCaseShareSource != null)
        rescueCaseShareSourceProvider.overrideWithValue(rescueCaseShareSource),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    ),
  );
}

class _PendingRescueCaseShareSource implements RescueCaseShareSource {
  final _completer = Completer<void>();
  int calls = 0;
  RescueCaseDetail? lastDetail;
  Rect? lastOrigin;

  @override
  Future<void> shareCase(
    RescueCaseDetail detail, {
    required Rect sharePositionOrigin,
  }) {
    calls += 1;
    lastDetail = detail;
    lastOrigin = sharePositionOrigin;
    return _completer.future;
  }

  void complete() => _completer.complete();
}

class _FailingRescueCaseShareSource implements RescueCaseShareSource {
  @override
  Future<void> shareCase(
    RescueCaseDetail detail, {
    required Rect sharePositionOrigin,
  }) => Future<void>.error(StateError('Native sheet unavailable'));
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/rescue/11111111-1111-4111-8111-111111111111',
    routes: [
      GoRoute(
        path: '/rescue',
        builder: (_, _) => const Scaffold(body: Text('Rescue Home')),
      ),
      GoRoute(
        path: '/rescue/map',
        builder: (_, _) => const Scaffold(body: Text('Rescue Map')),
      ),
      GoRoute(
        path: '/rescue/:caseId',
        builder: (_, state) =>
            RescueCaseDetailScreen(caseId: state.pathParameters['caseId']!),
      ),
      GoRoute(
        path: '/rescue/:caseId/comment',
        builder: (_, _) => const Scaffold(body: Text('Comment target')),
      ),
      GoRoute(
        path: '/rescue/:caseId/status',
        builder: (_, _) => const Scaffold(body: Text('Status target')),
      ),
    ],
  );
}
