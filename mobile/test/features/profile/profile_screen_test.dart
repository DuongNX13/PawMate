import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
  testWidgets('profile screen renders account, pet summary, and logout', (
    tester,
  ) async {
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
    expect(find.text('Profile'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Đăng xuất tài khoản'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Đăng xuất tài khoản'));
    await tester.pumpAndSettle();

    expect(sessionStore.cleared, isTrue);
    expect(authApi.logoutCalls, 1);
    expect(authApi.lastRefreshToken, 'refresh-token');
    expect(find.text('Login target'), findsOneWidget);
  });

  testWidgets('renders v0.27 profile shell without mobile overflow', (
    tester,
  ) async {
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
              _samplePet(id: 'ken', name: 'Ken', healthStatus: 'needs_vaccine'),
            ],
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(1.2),
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
    expect(find.text('Profile'), findsOneWidget);
    expectNoFlutterOverflow(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();

    expect(find.text('Đăng xuất tài khoản'), findsOneWidget);
    expect(find.text('Kết thúc phiên trên tất cả thiết bị'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

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
  _FakeAuthApi({this.logoutError}) : super(Dio());

  final Object? logoutError;
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
