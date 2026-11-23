import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_create_provider.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_write_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_draft_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_info_form_screen.dart';

import '../../test_support/ui_test_helpers.dart';
import 'rescue_test_fixtures.dart';

void main() {
  testWidgets('D42-NAV-01 opens the live case detail from the live list', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = FakeRescueSource(
      pages: [samplePage(items: sampleCasesWithoutImages())],
      detail: sampleCaseDetail(),
    );
    final router = _rescueRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rescueApiProvider.overrideWithValue(source),
          rescueClockProvider.overrideWithValue(fixedRescueClock()),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('rescue-case-11111111-1111-4111-8111-111111111111')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rescue-case-detail-screen')), findsOneWidget);
    expect(find.text('LuLu'), findsWidgets);
    expect(source.detailCaseIds, ['11111111-1111-4111-8111-111111111111']);
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    'D42-DRAFT-01 a new create flow must not reuse a published draft',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final writeSource = _Day42WriteSource();
      final container = ProviderContainer(
        overrides: [
          rescueWriteSourceProvider.overrideWithValue(writeSource),
          authAccessTokenProvider.overrideWith((ref) async => 'test-token'),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(rescueCreateProvider.notifier);
      notifier.setPetName('Mochi');
      notifier.setBreedOrColor('Poodle trắng kem');
      notifier.setLostAt(DateTime.utc(2026, 7, 23, 10, 30));
      notifier.setLocation(
        const RescueDraftLocation(
          latitude: 10.7769,
          longitude: 106.7009,
          formattedAddress: 'Địa chỉ test riêng tư',
        ),
      );
      expect(await notifier.continueToDetails(), isTrue);
      notifier.setIdentifyingFeatures('Vòng cổ đỏ');
      notifier.setMedia([
        const RescueDraftMedia(
          path: 'fixture.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 1024,
        ),
      ]);
      notifier.confirmMediaReview(true);
      final router = GoRouter(
        initialLocation: '/rescue/create/details',
        routes: [
          GoRoute(
            path: '/rescue',
            builder: (context, state) =>
                const Scaffold(body: Text('Rescue Home refreshed')),
          ),
          GoRoute(
            path: '/rescue/create/details',
            builder: (context, state) => const RescueInfoFormScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đăng tin tìm'));
      await tester.pumpAndSettle();
      expect(writeSource.published, isFalse);
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('rescue-review-confirm'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rescue-review-confirm')));
      await tester.pumpAndSettle();

      expect(writeSource.published, isTrue);
      expect(find.text('Rescue Home refreshed'), findsOneWidget);
      expect(container.read(rescueCreateProvider).draft.draftId, isNull);
      expect(container.read(rescueCreateProvider).published, isFalse);
    },
  );
}

GoRouter _rescueRouter() => GoRouter(
  initialLocation: '/rescue',
  routes: [
    GoRoute(
      path: '/rescue',
      builder: (context, state) =>
          const RescueHomeScreen(browseEnabled: true, createEnabled: true),
    ),
    GoRoute(
      path: '/rescue/:caseId',
      builder: (context, state) =>
          RescueCaseDetailScreen(caseId: state.pathParameters['caseId']!),
    ),
    for (final path in const [
      '/pets',
      '/vets/map',
      '/health',
      '/profile',
      '/profile/controls',
      '/notifications',
      '/rescue/map',
      '/rescue/create',
    ])
      GoRoute(
        path: path,
        builder: (context, state) =>
            Scaffold(body: Center(child: Text('Target $path'))),
      ),
    GoRoute(
      path: '/rescue/:caseId/comment',
      builder: (context, state) => const Scaffold(body: Text('Comment')),
    ),
    GoRoute(
      path: '/rescue/:caseId/status',
      builder: (context, state) => const Scaffold(body: Text('Status')),
    ),
  ],
);

class _Day42WriteSource implements RescueWriteSource {
  int version = 1;
  bool published = false;

  @override
  Future<RescueDraft> createDraft({
    required String accessToken,
    String source = 'rescue_home',
  }) async => RescueDraft(draftId: 'draft-day42', version: version);

  @override
  Future<RescueDraft> updateDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
    required Map<String, Object?> patch,
  }) async {
    version += 1;
    return RescueDraft.fromJson({
      'draftId': draftId,
      'version': version,
      ...patch,
    });
  }

  @override
  Future<RescueCaseDetail> publishDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
  }) async {
    published = true;
    return sampleCaseDetail(caseId: 'day42-published');
  }

  @override
  Future<RescueDraftMedia> uploadMedia({
    required String accessToken,
    required RescueDraftMedia media,
  }) async => media.copyWith(mediaId: 'media-day42', uploaded: true);
}
