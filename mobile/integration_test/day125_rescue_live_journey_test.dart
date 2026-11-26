// Day 125 journey 5: Rescue Home -> marker -> selected card -> case detail
// against the local backend and DB. The case is published through the real
// draft API before the UI starts; its photo is a verified media row seeded in
// the local DB (output-evidence/day-125/lost-alert/*_media_seed.sql), because a
// Supabase Storage upload would write outside this machine.
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
import 'package:pawmate_mobile/features/rescue/data/rescue_write_api.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';

const _apiBaseUrl = String.fromEnvironment(
  'PAWMATE_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);
const _email = 'mobile-e2e-owner@pawmate.test';
const _password = 'Pawmate123';
const _seededMediaId = '83000000-0000-4000-8000-000000000611';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Day125 journey 5 rescue marker to detail on local backend', (
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
    final petName = 'Bông D125 ${DateTime.now().millisecondsSinceEpoch % 100000}';
    final caseId = await _publishCase(dio, session.accessToken, petName);

    final router = GoRouter(
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
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    final marker = find.byKey(ValueKey('rescue-marker-$caseId'));
    final card = find.byKey(const Key('rescue-selected-case-card'));
    await _waitFor(tester, marker);
    expect(card, findsNothing);
    expect(find.byKey(Key('rescue-case-$caseId')), findsWidgets);

    await _tap(tester, marker);
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.text(petName)), findsWidgets);

    await _tap(tester, find.byKey(const Key('rescue-selected-details')));
    await _waitFor(tester, find.byKey(const Key('rescue-case-detail-screen')));
    await _waitFor(tester, find.text(petName));
    expect(
      GoRouterState.of(
        tester.element(find.byKey(const Key('rescue-case-detail-screen'))),
      ).uri.path,
      '/rescue/$caseId',
    );
    expect(tester.takeException(), isNull);

    router.pop();
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);
    // ignore: avoid_print
    print('DAY125 RESCUE PASS caseId=$caseId pet=$petName');
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<String> _publishCase(Dio dio, String token, String petName) async {
  final api = RescueWriteApi(dio);
  final draft = await api.createDraft(accessToken: token);
  final updated = await api.updateDraft(
    accessToken: token,
    draftId: draft.draftId!,
    expectedVersion: draft.version!,
    patch: {
      'petName': petName,
      'species': 'cat',
      'breedOrColor': 'Mèo trắng, mắt xanh',
      'lostAt': DateTime.now()
          .subtract(const Duration(hours: 3))
          .toUtc()
          .toIso8601String(),
      'exactLocation': {'latitude': 10.7769, 'longitude': 106.7009},
      'identifyingFeatures': 'Vòng cổ đỏ có chuông',
      'behaviorHint': '',
      'contactPreference': 'in_app',
      'mediaIds': [_seededMediaId],
    },
  );
  final published = await api.publishDraft(
    accessToken: token,
    draftId: updated.draftId!,
    expectedVersion: updated.version!,
  );
  return published.caseId;
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
