import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/data/auth_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime.utc(2026, 7, 15, 8);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'valid secure session is server-validated once per process',
    () async {
      final session = _validSession();
      final store = _FakeSessionStore(session: session);
      final api = _FakeAuthApi(refreshResult: session);
      final coordinator = AuthSessionCoordinator(
        store,
        api,
        now: () => now,
      );

      final result = await coordinator.readValidSession();

      expect(result, same(session));
      expect(api.refreshCalls, 1);
      expect(store.clearCalls, 0);
      expect(
        (await SharedPreferences.getInstance()).getBool('hasActiveSession'),
        isTrue,
      );
    },
  );

  test('missing secure session clears a stale active flag', () async {
    SharedPreferences.setMockInitialValues({'hasActiveSession': true});
    final store = _FakeSessionStore();
    final coordinator = AuthSessionCoordinator(
      store,
      _FakeAuthApi(),
      now: () => now,
    );

    expect(await coordinator.readValidSession(), isNull);
    expect(store.clearCalls, 1);
    expect(
      (await SharedPreferences.getInstance()).getBool('hasActiveSession'),
      isFalse,
    );
  });

  test('expired refresh credentials fail closed and are removed', () async {
    SharedPreferences.setMockInitialValues({'hasActiveSession': true});
    final store = _FakeSessionStore(session: _expiredSession());
    final coordinator = AuthSessionCoordinator(
      store,
      _FakeAuthApi(),
      now: () => now,
    );

    expect(await coordinator.readValidSession(), isNull);
    expect(store.clearCalls, 1);
    expect(
      (await SharedPreferences.getInstance()).getBool('hasActiveSession'),
      isFalse,
    );
  });

  test('malformed secure data fails closed even when cleanup fails', () async {
    SharedPreferences.setMockInitialValues({'hasActiveSession': true});
    final store = _FakeSessionStore(
      readError: const FormatException('malformed session'),
      clearError: StateError('storage unavailable'),
    );
    final coordinator = AuthSessionCoordinator(
      store,
      _FakeAuthApi(),
      now: () => now,
    );

    expect(await coordinator.readValidSession(), isNull);
    expect(store.clearCalls, 1);
    expect(
      (await SharedPreferences.getInstance()).getBool('hasActiveSession'),
      isFalse,
    );
  });

  test('clearSession removes secure data and active marker', () async {
    SharedPreferences.setMockInitialValues({'hasActiveSession': true});
    final store = _FakeSessionStore(session: _validSession());
    final coordinator = AuthSessionCoordinator(
      store,
      _FakeAuthApi(),
      now: () => now,
    );

    await coordinator.clearSession();

    expect(store.clearCalls, 1);
    expect(
      (await SharedPreferences.getInstance()).getBool('hasActiveSession'),
      isFalse,
    );
    expect(
      (await SharedPreferences.getInstance()).getBool('authSessionSignedOut'),
      isTrue,
    );
  });

  test(
    'expired access token is refreshed and the rotated session is saved',
    () async {
      final refreshed = _validSession();
      final store = _FakeSessionStore(session: _expiredAccessSession());
      final api = _FakeAuthApi(refreshResult: refreshed);
      final coordinator = AuthSessionCoordinator(store, api, now: () => now);

      final result = await coordinator.readValidSession();

      expect(result, same(refreshed));
      expect(api.refreshCalls, 1);
      expect(api.lastRefreshToken, 'refresh-still-valid');
      expect(store.session, same(refreshed));
      expect(store.saveCalls, 1);
    },
  );

  test('rejected refresh fails closed and removes the local session', () async {
    final store = _FakeSessionStore(session: _expiredAccessSession());
    final api = _FakeAuthApi(
      refreshError: const AuthApiException(
        'Refresh token revoked',
        code: 'AUTH_009',
        statusCode: 401,
      ),
    );
    final coordinator = AuthSessionCoordinator(store, api, now: () => now);

    expect(await coordinator.readValidSession(), isNull);
    expect(store.session, isNull);
    expect(
      (await SharedPreferences.getInstance()).getBool('authSessionSignedOut'),
      isTrue,
    );
  });

  test(
    'transient refresh failure preserves refresh credentials but never returns an expired access token',
    () async {
      final expired = _expiredAccessSession();
      final store = _FakeSessionStore(session: expired);
      final api = _FakeAuthApi(
        refreshError: const AuthApiException(
          'Service unavailable',
          code: 'NET_001',
          statusCode: 503,
        ),
      );
      final coordinator = AuthSessionCoordinator(store, api, now: () => now);

      expect(await coordinator.readValidSession(), isNull);
      expect(store.session, same(expired));
      expect(store.clearCalls, 0);
      expect(
        (await SharedPreferences.getInstance()).getBool('authSessionSignedOut'),
        isNot(true),
      );
    },
  );

  test('force refresh rotates a still-valid access token', () async {
    final refreshed = _validSession();
    final store = _FakeSessionStore(session: _validSession());
    final api = _FakeAuthApi(refreshResult: refreshed);
    final coordinator = AuthSessionCoordinator(store, api, now: () => now);

    expect(await coordinator.forceRefreshSession(), same(refreshed));
    expect(api.refreshCalls, 1);
    expect(store.saveCalls, 1);
  });

  test(
    'logout revokes the server session before clearing local state',
    () async {
      SharedPreferences.setMockInitialValues({'hasActiveSession': true});
      final store = _FakeSessionStore(session: _validSession());
      final api = _FakeAuthApi();
      final coordinator = AuthSessionCoordinator(store, api, now: () => now);

      await coordinator.logout();

      expect(api.logoutCalls, 1);
      expect(api.lastLogoutToken, 'valid-refresh-token');
      expect(store.session, isNull);
      expect(
        (await SharedPreferences.getInstance()).getBool('hasActiveSession'),
        isFalse,
      );
    },
  );

  test(
    'logout network failure preserves the session for a safe retry',
    () async {
      SharedPreferences.setMockInitialValues({'hasActiveSession': true});
      final session = _validSession();
      final store = _FakeSessionStore(session: session);
      final api = _FakeAuthApi(
        logoutError: const AuthApiException('Network unavailable'),
      );
      final coordinator = AuthSessionCoordinator(store, api, now: () => now);

      await expectLater(coordinator.logout(), throwsA(isA<AuthApiException>()));

      expect(store.session, same(session));
      expect(store.clearCalls, 0);
      expect(
        (await SharedPreferences.getInstance()).getBool('hasActiveSession'),
        isTrue,
      );
    },
  );

  test(
    'clear is serialized after an in-flight read and wins final state',
    () async {
      SharedPreferences.setMockInitialValues({'hasActiveSession': true});
      final store = _BlockingReadSessionStore(_validSession());
      final coordinator = AuthSessionCoordinator(
        store,
        _FakeAuthApi(),
        now: () => now,
      );

      final readFuture = coordinator.readValidSession();
      await store.readStarted.future;
      final clearFuture = coordinator.clearSession();
      store.releaseRead.complete();

      expect(await readFuture, isNotNull);
      await clearFuture;
      expect(store.session, isNull);
      expect(
        (await SharedPreferences.getInstance()).getBool('hasActiveSession'),
        isFalse,
      );
    },
  );

  test('cleanup failure leaves a persistent fail-closed tombstone', () async {
    final store = _FakeSessionStore(
      session: _validSession(),
      clearError: StateError('storage unavailable'),
    );
    final coordinator = AuthSessionCoordinator(
      store,
      _FakeAuthApi(),
      now: () => now,
    );

    await coordinator.clearSession();

    expect(store.session, isNotNull);
    expect(await coordinator.readValidSession(), isNull);
    expect(
      (await SharedPreferences.getInstance()).getBool('authSessionSignedOut'),
      isTrue,
    );
  });

  test(
    'secure clear plus marker failure is surfaced and remains fail closed in memory',
    () async {
      final store = _FakeSessionStore(
        session: _validSession(),
        clearError: StateError('secure storage unavailable'),
      );
      final markers = _FakeMarkerStore(
        writeError: StateError('marker storage unavailable'),
      );
      final coordinator = AuthSessionCoordinator(
        store,
        _FakeAuthApi(),
        markerStore: markers,
        now: () => now,
      );

      await expectLater(
        coordinator.clearSession(),
        throwsA(isA<AuthSessionPersistenceException>()),
      );
      await expectLater(
        coordinator.readValidSession(),
        throwsA(isA<AuthSessionPersistenceException>()),
      );
      expect(store.session, isNotNull);
    },
  );

  test(
    'fresh process cannot restore after server logout and dual persistence failure',
    () async {
      final store = _FakeSessionStore(
        session: _validSession(),
        clearError: StateError('secure storage unavailable'),
      );
      final markers = _FakeMarkerStore(
        writeError: StateError('marker storage unavailable'),
      );
      final api = _FakeAuthApi(
        refreshError: const AuthApiException(
          'Session revoked',
          code: 'AUTH_009',
          statusCode: 401,
        ),
      );
      final coordinator = AuthSessionCoordinator(
        store,
        api,
        markerStore: markers,
        now: () => now,
      );

      await expectLater(
        coordinator.logout(),
        throwsA(isA<AuthSessionPersistenceException>()),
      );
      expect(store.session, isNotNull);

      final restartedCoordinator = AuthSessionCoordinator(
        store,
        api,
        markerStore: markers,
        now: () => now,
      );
      await expectLater(
        restartedCoordinator.readValidSession(),
        throwsA(isA<AuthSessionPersistenceException>()),
      );
      expect(api.refreshCalls, 1);
    },
  );

  test(
    'marker read failure clears the secure session instead of trusting it',
    () async {
      final store = _FakeSessionStore(session: _validSession());
      final coordinator = AuthSessionCoordinator(
        store,
        _FakeAuthApi(),
        markerStore: _FakeMarkerStore(
          readError: StateError('marker storage unavailable'),
        ),
        now: () => now,
      );

      expect(await coordinator.readValidSession(), isNull);
      expect(store.session, isNull);
    },
  );
}

class _FakeMarkerStore implements AuthSessionMarkerStore {
  _FakeMarkerStore({this.readError, this.writeError});

  bool signedOut = false;
  final Object? readError;
  final Object? writeError;

  @override
  Future<bool> isSignedOut() async {
    if (readError != null) {
      throw readError!;
    }
    return signedOut;
  }

  @override
  Future<void> write({required bool active, required bool signedOut}) async {
    if (writeError != null) {
      throw writeError!;
    }
    this.signedOut = signedOut;
  }
}

class _FakeSessionStore extends AuthSessionStore {
  _FakeSessionStore({this.session, this.readError, this.clearError})
    : super(const FlutterSecureStorage());

  AuthSession? session;
  final Object? readError;
  final Object? clearError;
  int clearCalls = 0;
  int saveCalls = 0;

  @override
  Future<AuthSession?> read() async {
    if (readError != null) {
      throw readError!;
    }
    return session;
  }

  @override
  Future<void> clear() async {
    clearCalls += 1;
    if (clearError != null) {
      throw clearError!;
    }
    session = null;
  }

  @override
  Future<void> save(AuthSession session) async {
    saveCalls += 1;
    this.session = session;
  }
}

class _BlockingReadSessionStore extends _FakeSessionStore {
  _BlockingReadSessionStore(AuthSession session) : super(session: session);

  final readStarted = Completer<void>();
  final releaseRead = Completer<void>();

  @override
  Future<AuthSession?> read() async {
    if (!readStarted.isCompleted) {
      readStarted.complete();
      await releaseRead.future;
    }
    return session;
  }
}

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi({this.refreshResult, this.refreshError, this.logoutError})
    : super(Dio());

  final AuthSession? refreshResult;
  final Object? refreshError;
  final Object? logoutError;
  int refreshCalls = 0;
  int logoutCalls = 0;
  String? lastRefreshToken;
  String? lastLogoutToken;

  @override
  Future<AuthSession> refresh({required String refreshToken}) async {
    refreshCalls += 1;
    lastRefreshToken = refreshToken;
    if (refreshError != null) {
      throw refreshError!;
    }
    return refreshResult ?? _validSession();
  }

  @override
  Future<void> logout({required String refreshToken}) async {
    logoutCalls += 1;
    lastLogoutToken = refreshToken;
    if (logoutError != null) {
      throw logoutError!;
    }
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
    accessTokenExpiresAt: '2026-07-15T09:00:00Z',
    refreshTokenExpiresAt: '2026-08-15T08:00:00Z',
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
    accessTokenExpiresAt: '2026-07-14T08:00:00Z',
    refreshTokenExpiresAt: '2026-07-15T08:00:00Z',
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
    accessTokenExpiresAt: '2026-07-15T07:59:59Z',
    refreshTokenExpiresAt: '2026-08-15T08:00:00Z',
  );
}
