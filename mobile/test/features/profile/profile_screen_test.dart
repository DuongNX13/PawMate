import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/data/auth_session_store.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/profile/presentation/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('logout guards duplicate activation on ${platform.name}', (
      tester,
    ) async {
      await setTestViewport(tester, size: const Size(360, 800));
      SharedPreferences.setMockInitialValues({'hasActiveSession': true});
      final store = _FakeAuthSessionStore(_verifiedSession());
      final pending = Completer<void>();
      final api = _FakeAuthApi(logoutCompletion: pending);
      final router = _profileRouter();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authApiProvider.overrideWith((ref) => api),
            authSessionStoreProvider.overrideWith((ref) => store),
            petBackendListProvider.overrideWith((ref) async => const []),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light().copyWith(platform: platform),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final logout = find.text('Đăng xuất tài khoản');
      await tester.scrollUntilVisible(
        logout,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(logout);
      await tester.pumpAndSettle();
      expect(
        tester.getBottomRight(logout).dy,
        lessThan(tester.getTopLeft(find.byTooltip('Profile')).dy),
      );
      final logoutHandler = tester
          .widget<InkWell>(
            find.ancestor(of: logout, matching: find.byType(InkWell)).first,
          )
          .onTap!;
      await tester.tap(logout);
      // Exercise reentrancy directly: the modal correctly blocks another touch.
      logoutHandler();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('profile-logout-confirmation')),
        findsOneWidget,
      );
      expect(api.logoutCalls, 0);
      expect(store.cleared, isFalse);
      await tester.tap(find.byKey(const Key('profile-logout-confirm')));
      await tester.pumpAndSettle();
      expect(api.logoutCalls, 1);
      expect(store.cleared, isFalse);
      await tester.tap(logout);
      await tester.pumpAndSettle();
      expect(api.logoutCalls, 1);
      expect(
        find.byKey(const Key('profile-logout-confirmation')),
        findsNothing,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(store.cleared, isTrue);
      expect(find.text('Login target'), findsOneWidget);
      expectNoFlutterOverflow(tester);
    });
  }

  testWidgets('profile screen renders account, pet summary, and logout', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    SharedPreferences.setMockInitialValues({'hasActiveSession': true});
    final sessionStore = _FakeAuthSessionStore(_verifiedSession());
    final authApi = _FakeAuthApi();
    final router = _profileRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authApiProvider.overrideWith((ref) => authApi),
          authSessionStoreProvider.overrideWith((ref) => sessionStore),
          petBackendListProvider.overrideWith(
            (ref) async => [
              _samplePet(id: 'pet-1', name: 'Mochi'),
              _samplePet(id: 'pet-2', name: 'Kem'),
            ],
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PawMate'), findsOneWidget);
    expect(find.text('Owner QA'), findsOneWidget);
    expect(find.text('owner@pawmate.test'), findsOneWidget);
    expect(find.text('Verified Owner'), findsOneWidget);

    final avatar = find.byType(CircleAvatar).first;
    final ownerName = find.text('Owner QA');
    expect(
      tester.getTopLeft(ownerName).dx,
      greaterThan(tester.getTopRight(avatar).dx + 8),
      reason:
          'The approved Profile anchor uses a compact horizontal identity card.',
    );
    // Figma v0.34 P1-16 cards are taller; the last row may need a scroll at
    // 390x844 but must never sit under the fixed bottom navigation.
    await tester.scrollUntilVisible(
      find.text('Đăng xuất tài khoản'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      tester.getBottomRight(find.text('Đăng xuất tài khoản')).dy,
      lessThan(tester.getTopLeft(find.byTooltip('Profile')).dy),
      reason: 'Settings rows must remain reachable above the bottom navigation.',
    );

    await tester.scrollUntilVisible(
      find.text('Thú cưng của tôi'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Thú cưng của tôi'), findsOneWidget);
    expect(find.text('Mochi'), findsOneWidget);
    expect(find.text('Kem'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('CÀI ĐẶT HỆ THỐNG'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('CÀI ĐẶT HỆ THỐNG'), findsOneWidget);
    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Quyền riêng tư & Bảo mật'), findsOneWidget);
    expect(find.text('Lịch nhắc'), findsOneWidget);
    expect(find.byTooltip('Profile'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Đăng xuất tài khoản'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Đăng xuất tài khoản'));
    await tester.pumpAndSettle();

    expect(authApi.logoutCalls, 0);
    expect(sessionStore.cleared, isFalse);
    expect(
      find.byKey(const Key('profile-logout-confirmation')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('profile-logout-cancel')));
    await tester.pumpAndSettle();
    expect(authApi.logoutCalls, 0);
    expect(sessionStore.cleared, isFalse);
    expect(find.byType(ProfileScreen), findsOneWidget);

    await tester.tap(find.text('Đăng xuất tài khoản'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-logout-confirm')));
    await tester.pumpAndSettle();

    expect(sessionStore.cleared, isTrue);
    expect(authApi.logoutCalls, 1);
    expect(authApi.lastRefreshToken, 'refresh-token');
    expect(find.text('Login target'), findsOneWidget);
  });

  testWidgets(
    'renders profile shell without mobile overflow at text scale 2.0',
    (tester) async {
      await setTestViewport(tester, size: const Size(360, 800));
      SharedPreferences.setMockInitialValues({'hasActiveSession': true});
      final sessionStore = _FakeAuthSessionStore(_verifiedSession());
      final authApi = _FakeAuthApi();
      final router = _profileRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authApiProvider.overrideWith((ref) => authApi),
            authSessionStoreProvider.overrideWith((ref) => sessionStore),
            petBackendListProvider.overrideWith(
              (ref) async => [
                _samplePet(id: 'mochi', name: 'Mochi'),
                _samplePet(
                  id: 'ken',
                  name: 'Ken',
                  healthStatus: 'needs_vaccine',
                ),
              ],
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            builder: testTextScaleBuilder(2),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Owner QA'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Thú cưng của tôi'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Thú cưng của tôi'), findsOneWidget);
      expectNoFlutterOverflow(tester);

      await tester.scrollUntilVisible(
        find.text('CÀI ĐẶT HỆ THỐNG'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('CÀI ĐẶT HỆ THỐNG'), findsOneWidget);
      expect(find.byTooltip('Profile'), findsOneWidget);
      expectNoFlutterOverflow(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -420));
      await tester.pumpAndSettle();

      expect(find.text('Đăng xuất tài khoản'), findsOneWidget);
      expect(find.text('Kết thúc phiên trên tất cả thiết bị'), findsOneWidget);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('profile account email stays on one natural line at 360dp', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(360, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileSessionProvider.overrideWith(
            (ref) async => const AuthSession(
              user: AuthUser(
                id: 'owner-360',
                email: 'duong.ngo@example.com',
                authProvider: 'email',
                emailVerified: true,
                displayName: 'Dương Ngô',
              ),
              accessToken: 'access-token',
              refreshToken: 'refresh-token',
              accessTokenExpiresAt: '2099-05-14T10:00:00.000Z',
              refreshTokenExpiresAt: '2099-06-14T10:00:00.000Z',
            ),
          ),
          petBackendListProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final email = find.text('duong.ngo@example.com');
    expect(email, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(email);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(
      tester.getSize(email).height,
      lessThan(24),
      reason: 'The approved 360dp anchor keeps the complete email on one line.',
    );
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    'profile action labels stay fully readable at 320dp with large text',
    (tester) async {
      await setTestViewport(tester, size: const Size(320, 568));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileSessionProvider.overrideWith(
              (ref) async => _verifiedSession(),
            ),
            petBackendListProvider.overrideWith((ref) async => const []),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: testTextScaleBuilder(2),
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in const [
        'Thông báo',
        'Quyền riêng tư & Bảo mật',
        'Lịch nhắc',
        'Phòng khám gần bạn',
        'Đăng xuất tài khoản',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          260,
          scrollable: find.byType(Scrollable).first,
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: '$label must remain fully readable at accessibility scale.',
        );
      }
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('profile pet summary exposes an offline retry state', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(360, 800));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileSessionProvider.overrideWith(
            (ref) async => _verifiedSession(),
          ),
          petBackendListProvider.overrideWithValue(
            AsyncValue<List<PetProfile>>.error(
              Exception('offline'),
              StackTrace.empty,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-pets-error-state')), findsOneWidget);
    final retry = find.byKey(const Key('profile-pets-retry-action'));
    expect(retry, findsOneWidget);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
    expectNoFlutterOverflow(tester);
  });

  testWidgets('pet preview updates shared selected pet before opening detail', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final container = ProviderContainer(
      overrides: [
        profileSessionProvider.overrideWith((ref) async => _verifiedSession()),
        petBackendListProvider.overrideWith(
          (ref) async => [
            _samplePet(id: 'mochi', name: 'Mochi'),
            _samplePet(id: 'kem', name: 'Kem'),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(selectedPetIdProvider.notifier).select('mochi');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: _profileRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-pet-selected-mochi')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-pet-kem')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('profile-pet-kem')));
    await tester.pumpAndSettle();

    expect(container.read(selectedPetIdProvider), 'kem');
    expect(find.text('Pet detail target'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('settings and privacy actions use their contracted routes', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final router = _profileRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileSessionProvider.overrideWith(
            (ref) async => _verifiedSession(),
          ),
          petBackendListProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cài đặt'));
    await tester.pumpAndSettle();
    expect(find.text('Profile controls target'), findsOneWidget);

    router.go('/profile');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-privacy-action')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('profile-privacy-action')));
    await tester.pumpAndSettle();
    expect(find.text('Privacy target'), findsOneWidget);
  });

  testWidgets(
    'logout failure keeps the session and reports a retryable error',
    (tester) async {
      SharedPreferences.setMockInitialValues({'hasActiveSession': true});
      await setTestViewport(tester, size: const Size(390, 844));
      final sessionStore = _FakeAuthSessionStore(_verifiedSession());
      final authApi = _FakeAuthApi(
        logoutError: const AuthApiException(
          'Không thể kết nối tới máy chủ PawMate.',
        ),
      );
      final router = _profileRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authApiProvider.overrideWith((ref) => authApi),
            authSessionStoreProvider.overrideWith((ref) => sessionStore),
            petBackendListProvider.overrideWith((ref) async => const []),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Đăng xuất tài khoản'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -220));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đăng xuất tài khoản'));
      await tester.pumpAndSettle();

      expect(authApi.logoutCalls, 0);
      await tester.tap(find.byKey(const Key('profile-logout-confirm')));
      await tester.pumpAndSettle();

      expect(sessionStore.cleared, isFalse);
      expect(authApi.logoutCalls, 1);
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(
        find.textContaining('Chưa thể đăng xuất an toàn.'),
        findsOneWidget,
      );
    },
  );
}

AuthSession _verifiedSession() {
  return const AuthSession(
    user: AuthUser(
      id: 'user-1',
      email: 'owner@pawmate.test',
      authProvider: 'email',
      emailVerified: true,
      displayName: 'Owner QA',
    ),
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    accessTokenExpiresAt: '2099-05-14T10:00:00.000Z',
    refreshTokenExpiresAt: '2099-06-14T10:00:00.000Z',
  );
}

GoRouter _profileRouter() {
  return GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/controls',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Profile controls target')),
        ),
      ),
      GoRoute(
        path: '/profile/privacy',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Privacy target'))),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Login target'))),
      ),
      GoRoute(
        path: '/pets',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Pets target'))),
      ),
      GoRoute(
        path: '/pets/:id',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Pet detail target'))),
      ),
      GoRoute(
        path: '/vets/list',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Vets target'))),
      ),
      GoRoute(
        path: '/health',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Health target'))),
      ),
      GoRoute(
        path: '/health/reminders',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Reminder target'))),
      ),
      GoRoute(
        path: '/rescue',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Rescue target'))),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Notification target'))),
      ),
    ],
  );
}

class _FakeAuthSessionStore extends AuthSessionStore {
  _FakeAuthSessionStore(this.session) : super(const FlutterSecureStorage());

  AuthSession? session;
  bool cleared = false;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> save(AuthSession session) async {
    this.session = session;
  }

  @override
  Future<void> clear() async {
    cleared = true;
    session = null;
  }
}

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi({this.logoutError, this.logoutCompletion}) : super(Dio());

  final Object? logoutError;
  final Completer<void>? logoutCompletion;
  int logoutCalls = 0;
  int refreshCalls = 0;
  String? lastRefreshToken;

  @override
  Future<AuthSession> refresh({required String refreshToken}) async {
    refreshCalls += 1;
    lastRefreshToken = refreshToken;
    return _verifiedSession();
  }

  @override
  Future<void> logout({required String refreshToken}) async {
    logoutCalls += 1;
    lastRefreshToken = refreshToken;
    await logoutCompletion?.future;
    if (logoutError != null) {
      throw logoutError!;
    }
  }
}

PetProfile _samplePet({
  required String id,
  required String name,
  String healthStatus = 'healthy',
}) {
  return PetProfile(
    id: id,
    name: name,
    species: 'dog',
    breed: 'Poodle',
    gender: 'male',
    dateOfBirth: DateTime(2022, 4, 12),
    weightKg: 6.2,
    healthStatus: healthStatus,
  );
}
