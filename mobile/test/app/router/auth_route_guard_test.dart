import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/router/app_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/data/auth_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('stale active flag without secure session opens login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'hasSeenOnboarding': true,
      'hasActiveSession': true,
    });
    final harness = await _pumpProductionRouter(tester, session: null);

    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/auth/login',
      reason: 'A SharedPreferences flag is not sufficient authentication.',
    );
    expect(harness.store.clearCalls, greaterThan(0));
    expect(
      (await SharedPreferences.getInstance()).getBool('hasActiveSession'),
      isFalse,
    );
    harness.dispose();
  });

  testWidgets('expired secure session opens login', (tester) async {
    SharedPreferences.setMockInitialValues({
      'hasSeenOnboarding': true,
      'hasActiveSession': true,
    });
    final harness = await _pumpProductionRouter(
      tester,
      session: _expiredSession(),
    );

    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/auth/login',
      reason: 'Expired refresh credentials must not restore a protected route.',
    );
    expect(harness.store.clearCalls, greaterThan(0));
    expect(
      (await SharedPreferences.getInstance()).getBool('hasActiveSession'),
      isFalse,
    );
    harness.dispose();
  });

  testWidgets('guest deep link to protected pets route is guarded', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'hasSeenOnboarding': true,
      'hasActiveSession': false,
    });
    final harness = await _pumpProductionRouter(tester, session: null);
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/auth/login',
    );

    harness.router.go('/pets');
    await tester.pumpAndSettle();

    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/auth/login',
      reason: 'Protected routes require a production router redirect guard.',
    );
    harness.dispose();
  });

  testWidgets('auth lifecycle failure fails closed on protected navigation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'hasSeenOnboarding': true,
      'hasActiveSession': true,
    });
    final store = _FailClosedSessionStore();
    final container = ProviderContainer(
      overrides: [
        authSessionStoreProvider.overrideWith((ref) => store),
        authSessionMarkerStoreProvider.overrideWith(
          (ref) => _FailClosedMarkerStore(),
        ),
      ],
    );
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/profile');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/auth/login');
    expect(store.clearCalls, greaterThan(0));
    router.dispose();
    container.dispose();
  });

  testWidgets('valid secure session restores pets and repairs active flag', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'hasSeenOnboarding': true,
      'hasActiveSession': false,
    });
    final harness = await _pumpProductionRouter(
      tester,
      session: _validSession(),
    );

    expect(harness.router.routeInformationProvider.value.uri.path, '/pets');
    expect(harness.store.clearCalls, 0);
    expect(
      (await SharedPreferences.getInstance()).getBool('hasActiveSession'),
      isTrue,
    );
    harness.dispose();
  });

  testWidgets('guest is blocked from every protected route family', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'hasSeenOnboarding': true,
      'hasActiveSession': false,
    });
    final harness = await _pumpProductionRouter(tester, session: null);
    const protectedLocations = <String>[
      '/pets',
      '/pets/list',
      '/pets/create',
      '/pets/pet-1',
      '/vets/map',
      '/vets/list',
      '/vets/vet-1',
      '/health',
      '/health/events/new',
      '/health/reminders',
      '/notifications',
      '/community',
      '/adoption',
      '/profile/controls',
      '/profile/privacy',
      '/profile',
      '/rescue',
      '/rescue/create',
      '/rescue/create/details',
      '/rescue/case-1',
      '/rescue/case-1/comment',
      '/rescue/case-1/status',
      '/rescue/case-1/discussion',
    ];

    for (final location in protectedLocations) {
      harness.router.go(location);
      await tester.pumpAndSettle();
      expect(
        harness.router.routeInformationProvider.value.uri.path,
        '/auth/login',
        reason: '$location must require a valid secure session.',
      );
    }
    harness.dispose();
  });

  testWidgets('guest can access every public route without a redirect loop', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'hasSeenOnboarding': true,
      'hasActiveSession': false,
    });
    final harness = await _pumpProductionRouter(tester, session: null);
    const publicLocations = <String>[
      '/onboarding',
      '/auth/login?email=guest%40pawmate.test',
      '/auth/register?email=guest%40pawmate.test',
      '/auth/otp?email=guest%40pawmate.test',
    ];

    for (final location in publicLocations) {
      harness.router.go(location);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        harness.router.routeInformationProvider.value.uri.path,
        Uri.parse(location).path,
        reason: '$location is public and must not redirect back to Login.',
      );
    }

    // Leave the OTP route so its countdown timer is disposed before teardown.
    harness.router.go('/auth/login');
    await tester.pumpAndSettle();
    harness.dispose();
  });

  testWidgets('logout clears session and blocks protected navigation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'hasSeenOnboarding': true,
      'hasActiveSession': true,
    });
    final harness = await _pumpProductionRouter(
      tester,
      session: _validSession(),
    );
    expect(harness.router.routeInformationProvider.value.uri.path, '/pets');

    await harness.container.read(authSessionCoordinatorProvider).clearSession();
    harness.router.go('/auth/login');
    await tester.pumpAndSettle();
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/auth/login',
    );
    expect(harness.store.session, isNull);
    expect(
      (await SharedPreferences.getInstance()).getBool('hasActiveSession'),
      isFalse,
    );

    harness.router.go('/pets');
    await tester.pumpAndSettle();
    expect(
      harness.router.routeInformationProvider.value.uri.path,
      '/auth/login',
      reason: 'A logged-out user must not reopen a protected route.',
    );
    harness.dispose();
  });

  testWidgets('guest redirect preserves protected path and query as returnTo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'hasSeenOnboarding': true,
      'hasActiveSession': false,
    });
    final harness = await _pumpProductionRouter(tester, session: null);

    harness.router.go('/vets/list?availability=24h');
    await tester.pumpAndSettle();

    final uri = harness.router.routeInformationProvider.value.uri;
    expect(uri.path, '/auth/login');
    expect(uri.queryParameters['returnTo'], '/vets/list?availability=24h');
    harness.dispose();
  });

  testWidgets('expired access token is refreshed before protected restore', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'hasSeenOnboarding': true,
      'hasActiveSession': true,
    });
    final api = _RouterAuthApi(_validSession());
    final harness = await _pumpProductionRouter(
      tester,
      session: _expiredAccessSession(),
      authApi: api,
    );

    expect(harness.router.routeInformationProvider.value.uri.path, '/pets');
    expect(api.refreshCalls, 1);
    expect(api.lastRefreshToken, 'refresh-still-valid');
    expect(harness.store.session?.accessToken, 'valid-access-token');
    harness.dispose();
  });

  testWidgets(
    'active protected route reacts when the session becomes invalid',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'hasSeenOnboarding': true,
        'hasActiveSession': true,
      });
      final harness = await _pumpProductionRouter(
        tester,
        session: _validSession(),
      );
      expect(harness.router.routeInformationProvider.value.uri.path, '/pets');

      harness.store.session = _expiredSession();
      harness.container.invalidate(authSessionSnapshotProvider);
      await tester.pumpAndSettle();

      expect(
        harness.router.routeInformationProvider.value.uri.path,
        '/auth/login',
      );
      expect(harness.store.clearCalls, greaterThan(0));
      harness.dispose();
    },
  );

  testWidgets('authenticated unknown route renders a safe in-app fallback', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'hasSeenOnboarding': true,
      'hasActiveSession': true,
    });
    final harness = await _pumpProductionRouter(
      tester,
      session: _validSession(),
    );

    harness.router.go('/not-a-pawmate-route');
    await tester.pumpAndSettle();

    expect(find.text('Không tìm thấy trang'), findsWidgets);
    expect(find.textContaining('quay lại trang chủ an toàn'), findsOneWidget);
    expect(tester.takeException(), isNull);
    harness.dispose();
  });

  testWidgets('disabled Rescue routes fail closed without showing case data', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'hasSeenOnboarding': true,
      'hasActiveSession': true,
    });
    final harness = await _pumpProductionRouter(
      tester,
      session: _validSession(),
    );

    harness.router.go('/rescue');
    await tester.pumpAndSettle();
    expect(find.text('Cứu hộ thú cưng'), findsWidgets);
    expect(
      find.textContaining('không tải ca cứu hộ, bản đồ hoặc vị trí thật'),
      findsOneWidget,
    );
    expect(find.text('Đăng tin'), findsNothing);
    expect(find.text('Mochi đi lạc'), findsNothing);

    harness.router.go('/rescue/case-1');
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết ca cứu hộ'), findsWidgets);
    expect(find.textContaining('không gọi API'), findsOneWidget);
    expect(tester.takeException(), isNull);
    harness.dispose();
  });

  testWidgets('authenticated production router builds every UI-owned route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'hasSeenOnboarding': true,
      'hasActiveSession': true,
    });
    final harness = await _pumpProductionRouter(
      tester,
      session: _validSession(),
    );
    const locations = <String>[
      '/pets/list',
      '/adoption',
      '/vets/map',
      '/vets/list',
      '/health',
      '/health/reminders',
      '/profile',
      '/profile/controls',
      '/profile/privacy',
      '/notifications?returnTo=%2Fprofile',
      '/pets/create?returnTo=%2Fpets',
      '/pets/pet-1/edit?returnTo=%2Fpets',
      '/pets/pet-1',
      '/vets/vet-1?returnTo=%2Fvets%2Flist',
      '/health/events/new?petId=pet-1',
      '/community',
      '/rescue/map',
      '/rescue/create/details',
      '/rescue/create',
      '/rescue/case-1/comment',
      '/rescue/case-1/status',
      '/rescue/case-1/discussion',
      '/rescue/case-1',
    ];

    for (final location in locations) {
      harness.router.go(location);
      // Route transitions may temporarily keep the outgoing page alive. Wait
      // for that transition to finish before exercising the next deep link so
      // the sweep reflects a user-reachable settled route state.
      await tester.pumpAndSettle();
      expect(
        harness.router.routeInformationProvider.value.uri.path,
        Uri.parse(location).path,
        reason: '$location must build through the production route handler.',
      );
      expect(tester.takeException(), isNull, reason: location);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    harness.dispose();
  });
}

Future<_RouterHarness> _pumpProductionRouter(
  WidgetTester tester, {
  required AuthSession? session,
  AuthApi? authApi,
}) async {
  final store = _ProbeSessionStore(session);
  final container = ProviderContainer(
    overrides: [
      authSessionStoreProvider.overrideWith((ref) => store),
      authApiProvider.overrideWith(
        (ref) => authApi ?? _RouterAuthApi(_validSession()),
      ),
    ],
  );
  final router = container.read(appRouterProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return _RouterHarness(container, router, store);
}

class _RouterHarness {
  _RouterHarness(this.container, this.router, this.store);

  final ProviderContainer container;
  final GoRouter router;
  final _ProbeSessionStore store;

  void dispose() {
    router.dispose();
    container.dispose();
  }
}

class _ProbeSessionStore extends AuthSessionStore {
  _ProbeSessionStore(this.session) : super(const FlutterSecureStorage());

  AuthSession? session;
  int clearCalls = 0;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> save(AuthSession session) async {
    this.session = session;
  }

  @override
  Future<void> clear() async {
    clearCalls += 1;
    session = null;
  }
}

class _FailClosedSessionStore extends AuthSessionStore {
  _FailClosedSessionStore() : super(const FlutterSecureStorage());

  int clearCalls = 0;

  @override
  Future<AuthSession?> read() async {
    throw StateError('secure session unreadable');
  }

  @override
  Future<void> save(AuthSession session) async {
    throw StateError('secure session unwritable');
  }

  @override
  Future<void> clear() async {
    clearCalls += 1;
    throw StateError('secure session cannot be cleared');
  }
}

class _FailClosedMarkerStore implements AuthSessionMarkerStore {
  @override
  Future<bool> isSignedOut() async => false;

  @override
  Future<void> write({required bool active, required bool signedOut}) async {
    throw StateError('session marker unavailable');
  }
}

class _RouterAuthApi extends AuthApi {
  _RouterAuthApi(this.refreshedSession) : super(Dio());

  final AuthSession refreshedSession;
  int refreshCalls = 0;
  String? lastRefreshToken;

  @override
  Future<AuthSession> refresh({required String refreshToken}) async {
    refreshCalls += 1;
    lastRefreshToken = refreshToken;
    return refreshedSession;
  }
}

AuthSession _validSession() {
  return const AuthSession(
    user: AuthUser(
      id: 'valid-user',
      email: 'valid@pawmate.test',
      authProvider: 'email',
      emailVerified: true,
    ),
    accessToken: 'valid-access-token',
    refreshToken: 'valid-refresh-token',
    accessTokenExpiresAt: '2099-01-01T00:00:00Z',
    refreshTokenExpiresAt: '2099-02-01T00:00:00Z',
  );
}

AuthSession _expiredSession() {
  return const AuthSession(
    user: AuthUser(
      id: 'expired-user',
      email: 'expired@pawmate.test',
      authProvider: 'email',
      emailVerified: true,
    ),
    accessToken: 'expired-access-token',
    refreshToken: 'expired-refresh-token',
    accessTokenExpiresAt: '2026-07-13T00:00:00Z',
    refreshTokenExpiresAt: '2026-07-13T01:00:00Z',
  );
}

AuthSession _expiredAccessSession() {
  return const AuthSession(
    user: AuthUser(
      id: 'refresh-user',
      email: 'refresh@pawmate.test',
      authProvider: 'email',
      emailVerified: true,
    ),
    accessToken: 'expired-access-token',
    refreshToken: 'refresh-still-valid',
    accessTokenExpiresAt: '2026-07-13T00:00:00Z',
    refreshTokenExpiresAt: '2099-02-01T00:00:00Z',
  );
}
