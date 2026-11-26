// Day 125 journey 3: Vet Map -> List -> Detail -> Write review -> Review list
// against the local backend and DB. Location and map tiles are fixed on the
// device side only (no GPS, no internet tiles); every API call is real.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/network/app_dio.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/data/authenticated_dio.dart';
import 'package:pawmate_mobile/features/vets/data/vet_api.dart';
import 'package:pawmate_mobile/features/vets/data/vet_location_service.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_map_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_detail_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_list_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_canvas.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_screen.dart';

const _apiBaseUrl = String.fromEnvironment(
  'PAWMATE_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);
const _email = 'mobile-e2e-owner@pawmate.test';
const _password = 'Pawmate123';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Day125 journey 3 vet list, detail and review on local backend', (
    tester,
  ) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: _apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: const {'Accept': 'application/json'},
      ),
    );
    final session = await AuthApi(
      dio,
    ).login(email: _email, password: _password);
    final location = _FixedLocation();
    final body =
        'Day125 E2E đánh giá ${DateTime.now().millisecondsSinceEpoch % 100000}: bác sĩ tận tình.';
    final router = GoRouter(
      initialLocation: '/vets/map',
      routes: [
        GoRoute(path: '/vets/map', builder: (_, _) => const VetMapScreen()),
        GoRoute(path: '/vets/list', builder: (_, _) => const VetListScreen()),
        GoRoute(
          path: '/vets/:vetId',
          builder: (_, s) => VetDetailScreen(
            vetId: s.pathParameters['vetId']!,
            returnPath: '/vets/list',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWith((ref) => dio),
          authenticatedDioProvider.overrideWith((ref) => dio),
          authAccessTokenProvider.overrideWith(
            (ref) async => session.accessToken,
          ),
          vetLocationServiceProvider.overrideWithValue(location),
          vetMapCanvasBuilderProvider.overrideWithValue(
            (center, items, style, onMarker, onError) =>
                const ColoredBox(color: Color(0xffF8F3EA)),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    // Map with location denied, then the manual list fallback.
    await _waitFor(tester, find.text('Xem dạng danh sách'));
    await _tap(tester, find.text('Xem dạng danh sách').first);
    // hn-001 is the clinic seeded into the local vets table for reviews.
    const vetId = 'hn-001';
    final card = find.byKey(const Key('vet-list-card-$vetId'));
    await _waitFor(tester, card);
    final before = await VetApi(dio).listReviews(vetId);

    await _tap(tester, card.first);
    await _waitFor(tester, find.byType(VetDetailScreen));
    final detailScroll = find
        .descendant(
          of: find.byType(VetDetailScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await _waitFor(
      tester,
      find.byKey(const Key('vet-detail-write-review-button')),
    );

    // Write review.
    await _tap(tester, find.byKey(const Key('vet-detail-write-review-button')));
    await _waitFor(tester, find.byKey(const Key('write-review-star-5')));
    await _tap(tester, find.byKey(const Key('write-review-star-5')));
    await tester.enterText(
      find.byKey(const Key('write-review-body-field')),
      body,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('write-review-submit')));
    await _waitFor(
      tester,
      find.byKey(const Key('vet-detail-write-review-button')),
      timeout: const Duration(seconds: 20),
    );
    expect(find.byKey(const Key('write-review-error')), findsNothing);

    // Review list shows the new review.
    final open = find.byKey(const Key('review-list-open-button'));
    await tester.scrollUntilVisible(open, 220, scrollable: detailScroll);
    await tester.pumpAndSettle();
    await _tap(tester, open);
    await _waitFor(tester, find.byKey(const Key('review-list-scroll')));
    await _waitFor(tester, find.textContaining('Day125 E2E đánh giá'));
    expect(tester.takeException(), isNull);

    final after = await VetApi(dio).listReviews(vetId);
    expect(after.items.any((r) => r.body == body), isTrue);
    expect(after.summary.reviewCount, before.summary.reviewCount + 1);
    expect(after.total, before.total + 1);

    // Granted location branch: the map asks the real /vets/nearby.
    Navigator.of(
      tester.element(find.byKey(const Key('review-list-scroll'))),
    ).pop();
    await tester.pumpAndSettle();
    router.go('/vets/map');
    await tester.pumpAndSettle();
    location.denied = false;
    await _tap(
      tester,
      find.byKey(const Key('vet-map-current-location-button')).first,
    );
    await _waitFor(tester, find.byKey(const Key('vet-map-bottom-panel')));
    expect(location.requests, greaterThanOrEqualTo(2));
    // ignore: avoid_print
    print('DAY125 VET PASS vetId=$vetId reviews ${before.summary.reviewCount}->${after.summary.reviewCount}');
  }, timeout: const Timeout(Duration(minutes: 5)));
}

class _FixedLocation implements VetLocationService {
  bool denied = true;
  int requests = 0;

  @override
  Future<VetMapLocation> resolveCurrentLocation() async {
    requests++;
    if (denied) {
      throw const VetLocationException(
        VetLocationFailureType.permissionDenied,
        'Day125: quyền vị trí bị từ chối',
      );
    }
    return const VetMapLocation(latitude: 10.7769, longitude: 106.7009);
  }
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(finder, findsAtLeastNWidgets(1));
}
