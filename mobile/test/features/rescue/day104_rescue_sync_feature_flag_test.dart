import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/router/app_feature_availability.dart';
import 'package:pawmate_mobile/app/router/feature_unavailable_screen.dart';
import 'package:pawmate_mobile/app/router/app_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_case_detail_provider.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_create_provider.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_map_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_location_service.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_write_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_draft_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_map_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_create_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_info_form_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../test_support/day115_capture.dart';
import 'rescue_test_fixtures.dart';

void main() {
  const offRoutes = [
    '/rescue',
    '/rescue/create',
    '/rescue/create/details',
    '/rescue/day115-missing',
    '/rescue/map',
    '/rescue/day115-missing/comment',
    '/rescue/day115-missing/status',
    '/rescue/day115-missing/discussion',
  ];
  for (var index = 0; index < offRoutes.length; index++) {
    final route = offRoutes[index];
    final id = 'FO-P2-0${index + 1}';
    testWidgets(
      'D115 $id direct link safe fallback and zero read write location',
      (tester) async {
        await setTestViewport(tester, size: const Size(390, 844));
        final source = _Day104RescueSource();
        final location = _CountingLocationService();
        final harness = await _pumpProductionRouter(
          tester,
          availability: const AppFeatureAvailability(
            rescueBrowse: false,
            rescueCreate: false,
          ),
          source: source,
          location: location,
        );
        addTearDown(harness.dispose);
        harness.router.go(route);
        await tester.pumpAndSettle();
        expect(harness.router.routeInformationProvider.value.uri.path, route);
        if (index == 0) {
          expect(find.byKey(const Key('rescue-staged-state')), findsOneWidget);
          expect(find.text('Đăng tin'), findsNothing);
        } else {
          expect(find.byType(FeatureUnavailableScreen), findsOneWidget);
        }
        expect(source.readCalls, 0);
        expect(source.writeCalls, 0);
        expect(location.calls, 0);
        await captureDay115(tester, id);
        if (index != 0) {
          await tester.ensureVisible(find.text('Quay lại').last);
          await tester.tap(find.text('Quay lại').last);
          await tester.pumpAndSettle();
          expect(
            harness.router.routeInformationProvider.value.uri.path,
            '/rescue',
          );
          expect(find.byKey(const Key('rescue-staged-state')), findsOneWidget);
        }
        expect(source.readCalls, 0);
        expect(source.writeCalls, 0);
        expect(location.calls, 0);
        expectNoFlutterOverflow(tester);
      },
    );
  }

  test('D104-FLAG-01 raw feature combinations fail closed', () {
    const matrix = <(bool, bool, bool, bool)>[
      (false, false, false, false),
      (false, true, false, false),
      (true, false, true, false),
      (true, true, true, true),
    ];
    for (final row in matrix) {
      final availability = AppFeatureAvailability(
        rescueBrowse: row.$1,
        rescueCreate: row.$2,
      );
      expect(availability.rescueBrowse, row.$3, reason: '$row browse');
      expect(availability.rescueCreate, row.$4, reason: '$row create');
    }
  });

  test('D104-FLAG-01E compile-time environment resolves expected mode', () {
    const expectedMode = String.fromEnvironment(
      'DAY104_EXPECTED_FLAG_MODE',
      defaultValue: 'off',
    );
    const availability = AppFeatureAvailability.fromEnvironment();
    final expected = switch (expectedMode) {
      'off' => (false, false),
      'browse' => (true, false),
      'full' => (true, true),
      _ => throw StateError('Unknown DAY104_EXPECTED_FLAG_MODE: $expectedMode'),
    };

    expect(availability.rescueBrowse, expected.$1);
    expect(availability.rescueCreate, expected.$2);
  });

  test('D104-API-01 publish parses the authoritative backend detail', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: {'data': _publishedDetailPayload()},
              ),
            );
          },
        ),
      );

    final detail = await RescueWriteApi(dio).publishDraft(
      accessToken: 'owner-token',
      draftId: 'day104-draft',
      expectedVersion: 3,
    );

    expect(request.method, 'POST');
    expect(request.uri.path, '/rescue/case-drafts/day104-draft/publish');
    expect(request.headers['Authorization'], 'Bearer owner-token');
    expect(request.headers['Cache-Control'], 'no-store');
    expect(request.data, {'expectedVersion': 3});
    expect(detail.caseId, _Day104RescueSource._caseId);
    expect(detail.petName, 'Nắng');
    expect(detail.viewerPermissions.canUpdateStatus, isTrue);
  });

  testWidgets('D104-FLAG-02 eight off surfaces make zero Rescue API calls', (
    tester,
  ) async {
    final source = _Day104RescueSource();
    final location = _CountingLocationService();
    final harness = await _pumpProductionRouter(
      tester,
      availability: const AppFeatureAvailability(
        rescueBrowse: false,
        rescueCreate: false,
      ),
      source: source,
      location: location,
    );
    addTearDown(harness.dispose);

    const routes = <String>[
      '/rescue',
      '/rescue/create',
      '/rescue/create/details',
      '/rescue/day104-case',
      '/rescue/map',
      '/rescue/day104-case/comment',
      '/rescue/day104-case/status',
      '/rescue/day104-case/discussion',
    ];
    for (final route in routes) {
      harness.router.go(route);
      await tester.pumpAndSettle();
      expect(
        harness.router.routeInformationProvider.value.uri.path,
        route,
        reason: route,
      );
      if (route == '/rescue') {
        expect(find.byKey(const Key('rescue-staged-state')), findsOne);
      } else {
        expect(
          find.byType(FeatureUnavailableScreen),
          findsOneWidget,
          reason: route,
        );
      }
      expect(tester.takeException(), isNull, reason: route);
    }
    expect(source.readCalls, 0);
    expect(source.writeCalls, 0);
    expect(location.calls, 0);
  });

  testWidgets('D104-FLAG-03 browse-only reads but keeps create unavailable', (
    tester,
  ) async {
    final source = _Day104RescueSource();
    final location = _CountingLocationService();
    final harness = await _pumpProductionRouter(
      tester,
      availability: const AppFeatureAvailability(
        rescueBrowse: true,
        rescueCreate: false,
      ),
      source: source,
      location: location,
    );
    addTearDown(harness.dispose);

    harness.router.go('/rescue');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rescue-live-list')), findsOne);
    expect(source.listCalls, greaterThan(0));

    harness.router.go('/rescue/create');
    await tester.pumpAndSettle();
    expect(find.byType(FeatureUnavailableScreen), findsOneWidget);
    expect(source.writeCalls, 0);
  });

  testWidgets('D104-FLAG-04 browse-create exposes the create form', (
    tester,
  ) async {
    final source = _Day104RescueSource();
    final harness = await _pumpProductionRouter(
      tester,
      availability: const AppFeatureAvailability(
        rescueBrowse: true,
        rescueCreate: true,
      ),
      source: source,
      location: _CountingLocationService(),
    );
    addTearDown(harness.dispose);

    harness.router.go('/rescue/create');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rescue-create-form')), findsOne);
    expect(source.writeCalls, 0, reason: 'opening a form must not write');
  });

  testWidgets('D104-SYNC-01 publish synchronizes Home Map and exposes Detail', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = _Day104RescueSource();
    final container = ProviderContainer(
      overrides: [
        rescueApiProvider.overrideWithValue(source),
        rescueWriteSourceProvider.overrideWithValue(source),
        rescueClockProvider.overrideWithValue(fixedRescueClock()),
        authAccessTokenProvider.overrideWith((ref) async => 'test-token'),
      ],
    );
    addTearDown(container.dispose);

    final mapSubscription = container.listen(
      rescueMapProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(mapSubscription.close);

    await container.read(rescueMapProvider.notifier).refresh();
    expect(
      container.read(rescueMapProvider).items,
      isNot(contains(predicate<RescueCaseSummary>(source.isPublishedCase))),
    );

    final notifier = container.read(rescueCreateProvider.notifier);
    notifier
      ..setPetName('Nắng')
      ..setBreedOrColor('Golden Retriever')
      ..setLostAt(DateTime.utc(2026, 7, 23, 10, 30))
      ..setLocation(
        const RescueDraftLocation(
          latitude: 10.7769,
          longitude: 106.7009,
          formattedAddress: 'Địa chỉ test riêng tư',
        ),
      )
      ..setIdentifyingFeatures('Vòng cổ xanh');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: _router(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rescue-create-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rescue-create-continue-cta')));
    await tester.pumpAndSettle();
    notifier
      ..setIdentifyingFeatures('Vòng cổ xanh')
      ..setMedia([
        const RescueDraftMedia(
          path: 'fixture.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 1024,
        ),
      ])
      ..confirmMediaReview(true);
    await tester.tap(find.byKey(const Key('rescue-info-publish-cta')));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('rescue-review-confirm'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rescue-review-confirm')));
    await tester.pumpAndSettle();

    expect(source.published, isTrue);
    expect(find.byKey(Key('rescue-case-${source.publishedCaseId}')), findsOne);
    expect(
      container.read(rescueMapProvider).items,
      contains(predicate<RescueCaseSummary>(source.isPublishedCase)),
    );
    final detail = await container.read(
      rescueCaseDetailProvider(source.publishedCaseId).future,
    );
    expect(detail.caseId, source.publishedCaseId);
    expect(detail.petName, 'Nắng');
    expectNoFlutterOverflow(tester);
  });
}

Future<_RouterHarness> _pumpProductionRouter(
  WidgetTester tester, {
  required AppFeatureAvailability availability,
  required _Day104RescueSource source,
  required _CountingLocationService location,
}) async {
  SharedPreferences.setMockInitialValues({
    'hasSeenOnboarding': true,
    'hasActiveSession': true,
  });
  final container = ProviderContainer(
    overrides: [
      authSessionSnapshotProvider.overrideWith((ref) async => _validSession()),
      appFeatureAvailabilityProvider.overrideWithValue(availability),
      rescueApiProvider.overrideWithValue(source),
      rescueWriteSourceProvider.overrideWithValue(source),
      rescueLocationServiceProvider.overrideWithValue(location),
      rescueClockProvider.overrideWithValue(fixedRescueClock()),
      authAccessTokenProvider.overrideWith((ref) async => 'owner-token'),
    ],
  );
  final router = container.read(appRouterProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pump();
  router.go('/rescue');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return _RouterHarness(container, router);
}

class _RouterHarness {
  const _RouterHarness(this.container, this.router);

  final ProviderContainer container;
  final GoRouter router;

  void dispose() {
    router.dispose();
    container.dispose();
  }
}

class _CountingLocationService implements RescueLocationService {
  int calls = 0;

  @override
  Future<RescueMapLocation> resolveCurrentLocation({
    RescueLocationRequest? request,
  }) async {
    calls += 1;
    return const RescueMapLocation(latitude: 10.7769, longitude: 106.7009);
  }
}

AuthSession _validSession() {
  return const AuthSession(
    user: AuthUser(
      id: 'day104-owner',
      email: 'owner@pawmate.test',
      authProvider: 'email',
      emailVerified: true,
    ),
    accessToken: 'owner-token',
    refreshToken: 'owner-refresh-token',
    accessTokenExpiresAt: '2099-01-01T00:00:00Z',
    refreshTokenExpiresAt: '2099-02-01T00:00:00Z',
  );
}

Map<String, Object?> _publishedDetailPayload() => {
  'caseId': _Day104RescueSource._caseId,
  'petName': 'Nắng',
  'species': 'dog',
  'status': 'missing',
  'version': 4,
  'lostAt': '2026-07-23T08:00:00.000Z',
  'publicLocation': {
    'areaLabel': 'Q. Tân Bình',
    'approximateLatitude': 10.8,
    'approximateLongitude': 106.7,
    'privacyRadiusMeters': 500,
  },
  'media': <Object?>[],
  'commentCount': 0,
  'createdAt': '2026-07-23T08:00:00.000Z',
  'updatedAt': '2026-07-23T08:01:00.000Z',
  'breedOrColor': 'Golden Retriever',
  'ageLabel': '2 tuổi',
  'identifyingFeatures': 'Vòng cổ xanh',
  'behaviorHint': 'Thân thiện',
  'viewerPermissions': {
    'canComment': true,
    'canUpdateStatus': true,
    'canViewPrivateContact': true,
  },
};

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
  ],
);

class _Day104RescueSource implements RescueCaseSource, RescueWriteSource {
  static const _caseId = 'd1040000-0000-4000-8000-000000000104';
  RescueDraft _draft = const RescueDraft();
  int _version = 1;
  bool published = false;
  int listCalls = 0;
  int detailCalls = 0;
  int createCalls = 0;
  int updateCalls = 0;
  int publishCalls = 0;
  int uploadCalls = 0;

  int get readCalls => listCalls + detailCalls;
  int get writeCalls => createCalls + updateCalls + publishCalls + uploadCalls;

  String get publishedCaseId => _caseId;

  bool isPublishedCase(RescueCaseSummary item) => item.caseId == _caseId;

  RescueCaseDetail get _publishedDetail {
    final template = sampleCaseDetail(
      caseId: _caseId,
      canComment: true,
      canUpdateStatus: true,
      canViewPrivateContact: true,
    );
    return RescueCaseDetail(
      caseId: template.caseId,
      petName: 'Nắng',
      species: template.species,
      status: template.status,
      version: template.version,
      lostAt: template.lostAt,
      publicLocation: template.publicLocation,
      media: template.media,
      commentCount: template.commentCount,
      createdAt: template.createdAt,
      updatedAt: template.updatedAt,
      identifyingFeatures: template.identifyingFeatures,
      viewerPermissions: template.viewerPermissions,
      breedOrColor: 'Golden Retriever',
      ageLabel: template.ageLabel,
      distanceMeters: template.distanceMeters,
      behaviorHint: template.behaviorHint,
    );
  }

  @override
  Future<RescueCasePage> listCases(RescueCaseQuery query) async {
    listCalls += 1;
    return samplePage(
      items: [
        ...sampleCasesWithoutImages().take(1),
        if (published) _publishedDetail,
      ],
      hasMore: false,
    );
  }

  @override
  Future<RescueCaseDetail> getCase(String caseId) async {
    detailCalls += 1;
    if (caseId == _caseId && published) return _publishedDetail;
    if (caseId == _caseId) {
      throw const RescueApiException(
        'Ca cứu hộ chưa tồn tại.',
        code: 'RESCUE_NOT_FOUND',
        statusCode: 404,
      );
    }
    return sampleCaseDetail(caseId: caseId);
  }

  @override
  Future<RescueDraft> createDraft({
    required String accessToken,
    String source = 'rescue_home',
  }) async {
    createCalls += 1;
    _draft = RescueDraft(draftId: 'day104-draft', version: _version);
    return _draft;
  }

  @override
  Future<RescueDraft> updateDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
    required Map<String, Object?> patch,
  }) async {
    updateCalls += 1;
    _version += 1;
    _draft = RescueDraft.fromJson({
      'draftId': draftId,
      'version': _version,
      ...patch,
    });
    return _draft;
  }

  @override
  Future<RescueCaseDetail> publishDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
  }) async {
    publishCalls += 1;
    published = true;
    return _publishedDetail;
  }

  @override
  Future<RescueDraftMedia> uploadMedia({
    required String accessToken,
    required RescueDraftMedia media,
  }) async {
    uploadCalls += 1;
    return media.copyWith(mediaId: 'day104-media', uploaded: true);
  }
}
