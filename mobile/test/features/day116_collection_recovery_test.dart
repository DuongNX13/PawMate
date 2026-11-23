import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_runtime_providers.dart';
import 'package:pawmate_mobile/features/adoption/application/my_adoption_requests_provider.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_location_service.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_models.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_swipe_deck_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/my_adoption_requests_screen.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/data/pet_api.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/create_pet_screen.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';
import 'package:pawmate_mobile/features/reminders/application/reminder_providers.dart';
import 'package:pawmate_mobile/features/vets/application/vet_providers.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_detail_screen.dart';

import '../test_support/day116_capture.dart';
import '../test_support/ui_test_helpers.dart';
import 'adoption/adoption_ui_test_support.dart';

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final scale in [1.0, 1.3, 2.0]) {
    final suffix = scale.toString().replaceAll('.', '-');
    for (final state in ['ST-03', 'ST-04']) {
      testWidgets(
        'D116 R14 $state P1-07 text$scale home boundary and real create destination',
        (tester) async {
          final api = _HomePetSource();
          final router = GoRouter(
            initialLocation: '/pets',
            routes: [
              GoRoute(path: '/pets', builder: (_, _) => const PetHomeScreen()),
              GoRoute(
                path: '/pets/create',
                builder: (_, state) => CreatePetScreen(
                  returnTo: state.uri.queryParameters['returnTo'],
                ),
              ),
            ],
          );
          addTearDown(router.dispose);
          if (state == 'ST-04') api.pending.complete([]);
          await _pump(tester, scale, router, [
            petApiProvider.overrideWithValue(api),
            petAccessTokenProvider.overrideWith((ref) async => 'fixture-token'),
            authSessionSnapshotProvider.overrideWith((ref) async => null),
            upcomingRemindersProvider.overrideWith((ref) async => []),
          ], settle: state != 'ST-03');
          expect(api.calls, 1);
          final loading = find.byKey(const Key('pet-list-loading-state'));
          final empty = find.byKey(const Key('home-pets-empty-state'));
          if (state == 'ST-03') {
            expect(loading, findsOneWidget);
            expect(empty, findsNothing);
            await tester.pump(const Duration(milliseconds: 400));
            expect(loading, findsOneWidget);
            await captureDay116(tester, 'R14-P107-loading-text$suffix');
            api.pending.complete([
              PetProfile(
                id: 'r14-mochi',
                name: 'Mochi',
                species: 'dog',
                breed: 'Poodle',
                gender: 'unknown',
                dateOfBirth: null,
                weightKg: null,
                healthStatus: 'healthy',
                avatarPath: 'assets/images/pets/p1_05_mochi.png',
                color: 'Vàng kem',
              ),
            ]);
            await tester.pumpAndSettle();
            expect(loading, findsNothing);
            expect(empty, findsNothing);
            expect(
              find.byKey(const Key('home-pet-avatar-r14-mochi')),
              findsOneWidget,
            );
            expect(find.text('Mochi'), findsWidgets);
            expect(api.calls, 1);
            await captureDay116(tester, 'R14-P107-ready-text$suffix');
          } else {
            expect(empty, findsOneWidget);
            expect(loading, findsNothing);
            expect(
              find.byKey(const Key('home-pet-avatar-r14-mochi')),
              findsNothing,
            );
            final create = find.widgetWithText(PawMateButton, 'Thêm thú cưng');
            await _reach(tester, create);
            await _touch(tester, create);
            await captureDay116(tester, 'R14-P107-empty-text$suffix');
            await tester.tap(create);
            await tester.pumpAndSettle();
            expect(find.byType(CreatePetScreen), findsOneWidget);
            expect(router.canPop(), isTrue);
            expect(
              tester
                  .widget<CreatePetScreen>(find.byType(CreatePetScreen))
                  .returnTo,
              '/pets',
            );
            expect(
              find.byKey(const Key('pet-form-name-field')),
              findsOneWidget,
            );
            expect(api.calls, 1);
            await captureDay116(tester, 'R14-P107-create-text$suffix');
          }
          expectNoFlutterOverflow(tester);
        },
      );
    }
    testWidgets(
      'D116 R14 ST-03 P2-09 text$scale pending skeleton resolves once into discovery',
      (tester) async {
        final source = _PendingDiscoverySource();
        final location = FakeAdoptionLocationSource();
        final router = _adoptionRouter('/adoption');
        addTearDown(router.dispose);
        await _pump(tester, scale, router, [
          adoptionSourceProvider.overrideWithValue(source),
          adoptionAccessTokenProvider.overrideWith(
            (ref) async => 'fixture-token',
          ),
          adoptionLocationSourceProvider.overrideWithValue(location),
        ], settle: false);
        final loading = find.byKey(const Key('adoption-deck-loading'));
        expect(loading, findsOneWidget);
        expect(source.listQueries, hasLength(1));
        expect(
          find.byKey(const ValueKey('adoption-card-$adoptionListingId')),
          findsNothing,
        );
        expect(find.byKey(const Key('adoption-like-action')), findsNothing);
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          loading,
          findsOneWidget,
          reason: 'Loading persists until the real pending boundary completes.',
        );
        expect(source.listQueries, hasLength(1));
        await captureDay116(tester, 'R14-P209-loading-text$suffix');
        source.pending.complete(uiAdoptionPage());
        await tester.pumpAndSettle();
        expect(loading, findsNothing);
        expect(
          find.byKey(const ValueKey('adoption-card-$adoptionListingId')),
          findsOneWidget,
        );
        expect(source.listQueries, hasLength(1));
        expect(location.calls, 0);
        expectNoFlutterOverflow(tester);
        await captureDay116(tester, 'R14-P209-ready-text$suffix');
      },
    );
    testWidgets(
      'D116 R14 UX-27 DT-03 text$scale empty requests opens real discovery',
      (tester) async {
        final source = FakeAdoptionUiSource();
        final location = FakeAdoptionLocationSource();
        final router = _adoptionRouter('/adoption/requests');
        addTearDown(router.dispose);
        var requestReads = 0;
        await _pump(tester, scale, router, [
          myAdoptionRequestsProvider.overrideWith((ref) async {
            requestReads++;
            return [];
          }),
          adoptionSourceProvider.overrideWithValue(source),
          adoptionAccessTokenProvider.overrideWith(
            (ref) async => 'fixture-token',
          ),
          adoptionLocationSourceProvider.overrideWithValue(location),
        ]);
        expect(requestReads, 1);
        expect(
          find.byKey(const Key('my-adoption-requests-empty')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('my-adoption-requests-list')),
          findsNothing,
        );
        expect(find.textContaining('Tải thêm'), findsNothing);
        expect(source.listQueries, isEmpty);
        final cta = find.widgetWithText(
          PawMateButton,
          'Khám phá bé cần nhận nuôi',
        );
        await _reach(tester, cta);
        await _touch(tester, cta);
        await captureDay116(tester, 'R14-DT03-empty-text$suffix');
        await tester.tap(cta);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/adoption');
        expect(find.byType(AdoptionSwipeDeckScreen), findsOneWidget);
        expect(source.listQueries, hasLength(1));
        expect(
          find.byKey(const ValueKey('adoption-card-$adoptionListingId')),
          findsOneWidget,
        );
        expect(
          location.calls,
          0,
          reason: 'Discovery does not request GPS before opt-in.',
        );
        expectNoFlutterOverflow(tester);
        await captureDay116(tester, 'R14-DT03-discovery-text$suffix');
      },
    );

    testWidgets(
      'D116 R14 UX-28 DT-10 text$scale filter no results clears atomically',
      (tester) async {
        final source = FakeAdoptionUiSource();
        final location = FakeAdoptionLocationSource();
        final router = _adoptionRouter('/adoption');
        addTearDown(router.dispose);
        await _pump(tester, scale, router, [
          adoptionSourceProvider.overrideWithValue(source),
          adoptionAccessTokenProvider.overrideWith(
            (ref) async => 'fixture-token',
          ),
          adoptionLocationSourceProvider.overrideWithValue(location),
        ]);
        expect(source.listQueries, hasLength(1));
        final open = find.byKey(const Key('adoption-filter-button'));
        await tester.tap(open);
        await tester.pumpAndSettle();
        Future<void> select(String label) async {
          final target = find.text(label);
          await _reach(tester, target);
          await tester.tap(target);
          await tester.pumpAndSettle();
        }

        await select('Mèo');
        await select('1–3 tuổi');
        await select('10 km');
        expect(
          source.listQueries,
          hasLength(1),
          reason: 'Sheet edits are local until Apply.',
        );
        expect(location.calls, 0);
        source.page = uiAdoptionPage(items: const []);
        final apply = find.byKey(const Key('adoption-apply-filters'));
        await _reach(tester, apply);
        await _touch(tester, apply);
        await captureDay116(tester, 'R14-DT10-draft-text$suffix');
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(source.listQueries, hasLength(2));
        final query = source.listQueries.last;
        expect(query.species, AdoptionSpecies.cat);
        expect(query.ageGroup, AdoptionAgeGroup.oneToThree);
        expect(query.distanceKm, 10);
        expect(query.coordinates?.latitude, 10.7769);
        expect(query.coordinates?.longitude, 106.7009);
        expect(location.calls, 1);
        expect(find.byKey(const Key('adoption-filter-sheet')), findsNothing);
        expect(find.text('Chưa có hồ sơ phù hợp'), findsOneWidget);
        for (final action in [
          'adoption-like-action',
          'adoption-profile-action',
          'adoption-skip-action',
        ]) {
          expect(find.byKey(Key(action)), findsNothing);
        }
        expect(
          find.byKey(const ValueKey('adoption-card-$adoptionListingId')),
          findsNothing,
        );
        await captureDay116(tester, 'R14-DT10-empty-text$suffix');
        await tester.tap(open);
        await tester.pumpAndSettle();
        final clear = find.byKey(const Key('adoption-clear-filters'));
        await _reach(tester, clear);
        await _touch(tester, clear);
        source.page = uiAdoptionPage();
        await tester.tap(clear);
        await tester.pumpAndSettle();
        expect(source.listQueries, hasLength(3));
        final cleared = source.listQueries.last;
        expect(cleared.species, isNull);
        expect(cleared.ageGroup, isNull);
        expect(cleared.distanceKm, isNull);
        expect(cleared.coordinates, isNull);
        expect(cleared.cursor, isNull);
        expect(
          location.calls,
          1,
          reason: 'Clearing filters must not request location again.',
        );
        expect(find.byKey(const Key('adoption-filter-sheet')), findsNothing);
        expect(find.text('Chưa có hồ sơ phù hợp'), findsNothing);
        expect(
          find.byKey(const ValueKey('adoption-card-$adoptionListingId')),
          findsOneWidget,
        );
        expect(source.decisionCalls, isEmpty);
        expectNoFlutterOverflow(tester);
        await captureDay116(tester, 'R14-DT10-recovered-text$suffix');
      },
    );

    testWidgets(
      'D116 R14 UX-27 P1-10 text$scale empty reviews opens creation without load more',
      (tester) async {
        final api = _EmptyReviewSource();
        final router = GoRouter(
          initialLocation: '/vets/r14-vet',
          routes: [
            GoRoute(
              path: '/vets/:id',
              builder: (_, state) =>
                  VetDetailScreen(vetId: state.pathParameters['id']!),
            ),
          ],
        );
        addTearDown(router.dispose);
        await _pump(tester, scale, router, [
          vetApiProvider.overrideWithValue(api),
          vetReviewAccessTokenProvider.overrideWith(
            (ref) async => 'fixture-token',
          ),
        ]);
        final open = find.byKey(const Key('review-list-open-button'));
        await tester.scrollUntilVisible(
          open,
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(open.hitTestable(), findsOneWidget);
        expect(api.vetIds, ['r14-vet']);
        expect(find.textContaining('Chưa có đánh giá PawMate'), findsOneWidget);
        await tester.tap(open);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('review-list-empty')), findsOneWidget);
        await captureDay116(tester, 'R14-P110-empty-head-text$suffix');
        expect(find.byKey(const Key('review-load-more-button')), findsNothing);
        expect(find.byKey(const Key('review-helpful-button')), findsNothing);
        final create = find.widgetWithText(
          PawMateButton,
          'Viết đánh giá đầu tiên',
        );
        await _reach(tester, create);
        await _touch(tester, create);
        await captureDay116(tester, 'R14-P110-empty-text$suffix');
        await tester.tap(create);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('review-list-empty')), findsNothing);
        expect(
          find.byKey(const Key('write-review-body-field')),
          findsOneWidget,
        );
        final star = find.byKey(const Key('write-review-star-5'));
        await _reach(tester, star);
        await tester.tap(star);
        await tester.pumpAndSettle();
        final body = find.byKey(const Key('write-review-body-field'));
        await _reach(tester, body);
        await tester.enterText(body, 'Bác sĩ chăm sóc thú cưng chu đáo.');
        // Navigation to the real creation form and its enabled action are the
        // empty-state oracle; save persistence has its own R10 execution.
        final submit = find.byKey(const Key('write-review-submit'));
        expect(tester.widget<PawMateButton>(submit).onPressed, isNotNull);
        expect(api.vetIds, [
          'r14-vet',
        ], reason: 'Empty collection has no pagination request.');
        expectNoFlutterOverflow(tester);
        await captureDay116(tester, 'R14-P110-create-text$suffix');
      },
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  double scale,
  GoRouter router,
  List<Override> overrides, {
  bool settle = true,
}) async {
  await setTestViewport(tester, size: const Size(320, 568));
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: overrides,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

GoRouter _adoptionRouter(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(
      path: '/adoption/requests',
      builder: (_, _) => const MyAdoptionRequestsScreen(),
    ),
    GoRoute(
      path: '/adoption',
      builder: (_, _) => const AdoptionSwipeDeckScreen(),
    ),
  ],
);

Future<void> _reach(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    120,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
}

Future<void> _touch(WidgetTester tester, Finder target) async {
  final size = tester.getSize(target);
  expect(size.width, greaterThanOrEqualTo(48));
  expect(size.height, greaterThanOrEqualTo(48));
  final handle = tester.ensureSemantics();
  try {
    await tester.pump();
    final semantics = tester.getSemantics(target).getSemanticsData();
    expect(semantics.label.trim(), isNotEmpty);
    expect(semantics.hasAction(SemanticsAction.tap), isTrue);
  } finally {
    handle.dispose();
  }
}

class _PendingDiscoverySource extends FakeAdoptionUiSource {
  final pending = Completer<AdoptionListingPage>();
  @override
  Future<AdoptionListingPage> listListings(
    AdoptionListQuery query, {
    required String accessToken,
  }) {
    listQueries.add(query);
    expect(accessToken, 'fixture-token');
    return pending.future;
  }
}

class _HomePetSource extends PetApi {
  _HomePetSource() : super(Dio());
  final pending = Completer<List<PetProfile>>();
  var calls = 0;
  @override
  Future<List<PetProfile>> listPets({required String accessToken}) {
    expect(accessToken, 'fixture-token');
    calls++;
    return pending.future;
  }
}

/// Declared API boundary only. A cursor in an empty result must not expose
/// pagination; the real production sheet owns that decision.
class _EmptyReviewSource extends VetApi {
  _EmptyReviewSource() : super(Dio());
  final vetIds = <String>[];
  @override
  Future<VetDetail> getDetail(String vetId) async => VetDetail.fromJson({
    'id': 'r14-vet',
    'name': 'PetCare Elite',
    'city': 'TP Hồ Chí Minh',
    'district': 'Quận 1',
    'address': 'Địa chỉ fixture',
    'phone': '',
    'services': ['Khám tổng quát'],
    'photoUrls': [],
    'openHours': ['08:00–21:00'],
  });
  @override
  Future<VetReviewResult> listReviews(
    String vetId, {
    VetReviewListRequest request = const VetReviewListRequest(),
  }) async {
    vetIds.add(vetId);
    expect(request.cursor, isNull);
    return const VetReviewResult(
      items: [],
      nextCursor: 'must-not-use-empty-cursor',
      summary: VetReviewSummary(
        averageRating: null,
        reviewCount: 0,
        distribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      ),
      total: 0,
      limit: 20,
    );
  }
}
