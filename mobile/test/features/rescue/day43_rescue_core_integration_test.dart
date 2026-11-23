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
import 'package:pawmate_mobile/features/rescue/presentation/rescue_create_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_info_form_screen.dart';

import '../../test_support/ui_test_helpers.dart';
import 'rescue_test_fixtures.dart';

void main() {
  testWidgets(
    'D43-SYNC-01 publish invalidates Home and syncs list/map preview',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final source = _Day43RescueSource();
      final container = ProviderContainer(
        overrides: [
          rescueApiProvider.overrideWithValue(source),
          rescueWriteSourceProvider.overrideWithValue(source),
          rescueClockProvider.overrideWithValue(fixedRescueClock()),
          authAccessTokenProvider.overrideWith((ref) async => 'test-token'),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(rescueCreateProvider.notifier);
      notifier.setPetName('Nắng');
      notifier.setBreedOrColor('Golden Retriever');
      notifier.setLostAt(DateTime.utc(2026, 7, 23, 10, 30));
      notifier.setLocation(
        const RescueDraftLocation(
          latitude: 10.7769,
          longitude: 106.7009,
          formattedAddress: 'Địa chỉ test riêng tư',
        ),
      );
      notifier.setIdentifyingFeatures('Vòng cổ xanh');

      final router = _router();
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
      expect(find.byKey(const Key('rescue-map-preview')), findsOneWidget);

      await tester.tap(find.byKey(const Key('rescue-create-entry')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rescue-create-continue-cta')));
      await tester.pumpAndSettle();
      notifier.setIdentifyingFeatures('Vòng cổ xanh');
      notifier.setMedia([
        const RescueDraftMedia(
          path: 'fixture.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 1024,
        ),
      ]);
      notifier.confirmMediaReview(true);
      await tester.tap(find.byKey(const Key('rescue-info-publish-cta')));
      await tester.pumpAndSettle();
      expect(source.published, isFalse);
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('rescue-review-confirm'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rescue-review-confirm')));
      await tester.pumpAndSettle();

      expect(source.published, isTrue);
      expect(find.byKey(const Key('rescue-case-day43-case')), findsOneWidget);
      expect(find.text('Nắng'), findsWidgets);
      expect(find.byKey(const Key('rescue-map-preview')), findsOneWidget);
      expect(source.listCallCount, greaterThanOrEqualTo(2));
      expect(container.read(rescueCreateProvider).draft.draftId, isNull);
      expect(container.read(rescueCreateProvider).published, isFalse);
      expectNoFlutterOverflow(tester);

      final restartedContainer = ProviderContainer(
        overrides: [
          rescueWriteSourceProvider.overrideWithValue(source),
          authAccessTokenProvider.overrideWith((ref) async => 'test-token'),
        ],
      );
      addTearDown(restartedContainer.dispose);
      expect(
        restartedContainer.read(rescueCreateProvider).draft.draftId,
        isNull,
      );
      expect(restartedContainer.read(rescueCreateProvider).published, isFalse);
    },
  );
}

GoRouter _router() => GoRouter(
  initialLocation: '/rescue',
  routes: [
    GoRoute(
      path: '/rescue',
      builder: (context, state) =>
          const RescueHomeScreen(browseEnabled: true, createEnabled: true),
    ),
    GoRoute(
      path: '/rescue/create',
      builder: (context, state) => const RescueCreateScreen(),
    ),
    GoRoute(
      path: '/rescue/create/details',
      builder: (context, state) => const RescueInfoFormScreen(),
    ),
    GoRoute(
      path: '/rescue/:caseId',
      builder: (context, state) =>
          RescueCaseDetailScreen(caseId: state.pathParameters['caseId']!),
    ),
    GoRoute(
      path: '/rescue/map',
      builder: (context, state) => const Scaffold(body: Text('Map')),
    ),
  ],
);

class _Day43RescueSource implements RescueCaseSource, RescueWriteSource {
  final RescueCaseSummary _publishedItem = rescueCase(
    caseId: 'day43-case',
    petName: 'Nắng',
    species: RescueSpecies.dog,
    status: RescueCaseStatus.missing,
    areaLabel: 'Q. Tân Bình',
    breedOrColor: 'Golden Retriever',
    distanceMeters: 900,
  );
  RescueDraft _draft = const RescueDraft();
  int _version = 1;
  bool published = false;
  int listCallCount = 0;

  @override
  Future<RescueCasePage> listCases(RescueCaseQuery query) async {
    listCallCount += 1;
    final items = [
      ...sampleCasesWithoutImages().take(1),
      if (published) _publishedItem,
    ];
    return samplePage(items: items, hasMore: false);
  }

  @override
  Future<RescueCaseDetail> getCase(String caseId) async =>
      sampleCaseDetail(caseId: caseId);

  @override
  Future<RescueDraft> createDraft({
    required String accessToken,
    String source = 'rescue_home',
  }) async {
    _draft = RescueDraft(draftId: 'day43-draft', version: _version);
    return _draft;
  }

  @override
  Future<RescueDraft> updateDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
    required Map<String, Object?> patch,
  }) async {
    _version += 1;
    _draft = _draft.copyWith(
      draftId: draftId,
      version: _version,
      petName: patch['petName'] as String?,
      breedOrColor: patch['breedOrColor'] as String?,
      identifyingFeatures: patch['identifyingFeatures'] as String?,
      behaviorHint: patch['behaviorHint'] as String?,
      lostAt: patch['lostAt'] is String
          ? DateTime.parse(patch['lostAt']! as String)
          : null,
      exactLocation: patch['exactLocation'] is Map
          ? RescueDraftLocation(
              latitude: (patch['exactLocation']! as Map)['latitude'] as double,
              longitude:
                  (patch['exactLocation']! as Map)['longitude'] as double,
            )
          : null,
      media: patch.containsKey('mediaIds')
          ? [
              const RescueDraftMedia(
                path: 'fixture.jpg',
                mimeType: 'image/jpeg',
                sizeBytes: 1024,
                mediaId: 'day43-media',
                uploaded: true,
              ),
            ]
          : _draft.media,
    );
    return _draft;
  }

  @override
  Future<RescueCaseDetail> publishDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
  }) async {
    published = true;
    return sampleCaseDetail(caseId: _publishedItem.caseId);
  }

  @override
  Future<RescueDraftMedia> uploadMedia({
    required String accessToken,
    required RescueDraftMedia media,
  }) async => media.copyWith(mediaId: 'day43-media', uploaded: true);
}
