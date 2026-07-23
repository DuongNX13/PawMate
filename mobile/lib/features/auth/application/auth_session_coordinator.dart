import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/auth_api.dart';
import '../data/auth_session_store.dart';

final authSessionRevisionProvider = NotifierProvider<_AuthSessionRevision, int>(
  _AuthSessionRevision.new,
);

class _AuthSessionRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state += 1;
}

final Provider<AuthSessionCoordinator> authSessionCoordinatorProvider =
    Provider<AuthSessionCoordinator>((ref) {
      return AuthSessionCoordinator(
        ref.watch(authSessionStoreProvider),
        ref.watch(authApiProvider),
        markerStore: ref.watch(authSessionMarkerStoreProvider),
        onSessionChanged: () =>
            ref.read(authSessionRevisionProvider.notifier).bump(),
      );
    });

final authSessionMarkerStoreProvider = Provider<AuthSessionMarkerStore>((ref) {
  return SharedPreferencesAuthSessionMarkerStore();
});

final FutureProvider<AuthSession?> authSessionSnapshotProvider =
    FutureProvider.autoDispose<AuthSession?>((ref) async {
      ref.watch(authSessionRevisionProvider);
      final AuthSession? session;
      try {
        session = await ref
            .watch(authSessionCoordinatorProvider)
            .readValidSession();
      } on Object {
        // Auth state is a security boundary. Storage and validation failures
        // must resolve to signed-out UI instead of surfacing an unhandled
        // provider error or opening a protected route.
        return null;
      }
      final expiresAt = DateTime.tryParse(
        session?.accessTokenExpiresAt ?? '',
      )?.toUtc();
      if (expiresAt != null) {
        final refreshAt = expiresAt.subtract(
          AuthSessionCoordinator.accessTokenRefreshSkew,
        );
        final delay = refreshAt.difference(DateTime.now().toUtc());
        if (delay > Duration.zero) {
          final timer = Timer(delay, ref.invalidateSelf);
          ref.onDispose(timer.cancel);
        }
      }
      return session;
    });

final FutureProvider<String?> authAccessTokenProvider =
    FutureProvider.autoDispose<String?>((ref) async {
      final session = await ref.watch(authSessionSnapshotProvider.future);
      final token = session?.accessToken.trim();
      return token == null || token.isEmpty ? null : token;
    });

abstract interface class AuthSessionLifecycle {
  Future<AuthSession?> readValidSession();

  Future<AuthSession?> forceRefreshSession();
}

abstract interface class AuthSessionMarkerStore {
  Future<bool> isSignedOut();

  Future<void> write({required bool active, required bool signedOut});
}

class SharedPreferencesAuthSessionMarkerStore
    implements AuthSessionMarkerStore {
  static const activeSessionKey = 'hasActiveSession';
  static const signedOutTombstoneKey = 'authSessionSignedOut';

  @override
  Future<bool> isSignedOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(signedOutTombstoneKey) == true;
  }

  @override
  Future<void> write({required bool active, required bool signedOut}) async {
    final prefs = await SharedPreferences.getInstance();
    // Persist the security boundary first. A later hint-write failure must not
    // leave a stale secure session usable after restart.
    final tombstoneSaved = await prefs.setBool(
      signedOutTombstoneKey,
      signedOut,
    );
    if (!tombstoneSaved) {
      throw StateError('Unable to persist the signed-out marker.');
    }
    final activeSaved = await prefs.setBool(activeSessionKey, active);
    if (!activeSaved) {
      throw StateError('Unable to persist the active-session hint.');
    }
  }
}

class AuthSessionPersistenceException implements Exception {
  const AuthSessionPersistenceException({
    required this.secureStorageError,
    required this.markerStoreError,
  });

  final Object secureStorageError;
  final Object markerStoreError;

  @override
  String toString() => 'Unable to persist a fail-closed authentication state.';
}

class AuthSessionCoordinator implements AuthSessionLifecycle {
  AuthSessionCoordinator(
    this._store,
    this._api, {
    AuthSessionMarkerStore? markerStore,
    DateTime Function()? now,
    void Function()? onSessionChanged,
  }) : _markerStore = markerStore ?? SharedPreferencesAuthSessionMarkerStore(),
       _now = now ?? DateTime.now,
       _onSessionChanged = onSessionChanged;

  static const accessTokenRefreshSkew = Duration(seconds: 30);

  final AuthSessionStore _store;
  final AuthApi _api;
  final AuthSessionMarkerStore _markerStore;
  final DateTime Function() _now;
  final void Function()? _onSessionChanged;
  Future<void> _operationQueue = Future<void>.value();
  bool _signedOutInMemory = false;
  bool _sessionValidatedInProcess = false;

  @override
  Future<AuthSession?> readValidSession() {
    return _enqueue(_readValidSessionUnlocked);
  }

  @override
  Future<AuthSession?> forceRefreshSession() {
    return _enqueue(() => _readValidSessionUnlocked(forceRefresh: true));
  }

  Future<void> saveSession(AuthSession session) {
    return _enqueue(() async {
      if (!_hasUsableRefreshCredentials(session)) {
        throw StateError('Cannot persist an invalid authentication session.');
      }

      await _store.save(session);
      try {
        await _markerStore.write(active: true, signedOut: false);
        _signedOutInMemory = false;
        _sessionValidatedInProcess = true;
      } on Object catch (error, stackTrace) {
        try {
          await _clearLocalSession(signedOut: true);
        } on Object {
          // The original marker failure remains the actionable save error.
        }
        _notifySessionChanged();
        Error.throwWithStackTrace(error, stackTrace);
      }
      _notifySessionChanged();
    });
  }

  Future<void> logout() {
    return _enqueue(() async {
      final session = await _readStoredSession();
      if (!_hasUsableRefreshCredentials(session)) {
        await _clearLocalSessionAndNotify(signedOut: true);
        return;
      }

      try {
        await _api.logout(refreshToken: session!.refreshToken);
      } on AuthApiException catch (error) {
        if (error.statusCode != 401) {
          rethrow;
        }
        // A rejected refresh credential is already unusable server-side.
      }

      await _clearLocalSessionAndNotify(signedOut: true);
    });
  }

  Future<void> clearSession() {
    return _enqueue(() => _clearLocalSessionAndNotify(signedOut: true));
  }

  Future<AuthSession?> _readValidSessionUnlocked({
    bool forceRefresh = false,
  }) async {
    if (await _hasSignedOutTombstone()) {
      await _clearLocalSession(signedOut: true);
      return null;
    }

    AuthSession? session;
    try {
      session = await _store.read();
    } on Object {
      await _clearLocalSession(signedOut: true);
      return null;
    }

    if (!_hasUsableRefreshCredentials(session)) {
      await _clearLocalSession(signedOut: true);
      return null;
    }

    final currentSession = session!;
    if (forceRefresh ||
        !_sessionValidatedInProcess ||
        !_hasUsableAccessToken(currentSession)) {
      final AuthSession refreshed;
      try {
        refreshed = await _api.refresh(
          refreshToken: currentSession.refreshToken,
        );
      } on AuthApiException catch (error) {
        if (error.statusCode == 401) {
          await _clearLocalSession(signedOut: true);
          return null;
        }

        // Preserve the refresh credential for a later retry, but never expose
        // the expired access token to a protected route or API request.
        await _trySetSessionMarkers(active: true, signedOut: false);
        return null;
      }

      if (!_hasUsableRefreshCredentials(refreshed) ||
          !_hasUsableAccessToken(refreshed)) {
        await _clearLocalSession(signedOut: true);
        return null;
      }

      try {
        await _store.save(refreshed);
      } on Object {
        // The server rotated the token, so the stale local session must not be
        // reused when the new credential cannot be persisted.
        await _clearLocalSession(signedOut: true);
        return null;
      }
      session = refreshed;
      _sessionValidatedInProcess = true;
    } else {
      session = currentSession;
    }

    _signedOutInMemory = false;
    await _trySetSessionMarkers(active: true, signedOut: false);
    return session;
  }

  Future<AuthSession?> _readStoredSession() async {
    try {
      return await _store.read();
    } on Object {
      return null;
    }
  }

  bool _hasUsableRefreshCredentials(AuthSession? session) {
    if (session == null ||
        session.user.id.trim().isEmpty ||
        session.accessToken.trim().isEmpty ||
        session.refreshToken.trim().isEmpty) {
      return false;
    }

    final refreshExpiresAt = DateTime.tryParse(
      session.refreshTokenExpiresAt,
    )?.toUtc();
    if (refreshExpiresAt == null) {
      return false;
    }

    return refreshExpiresAt.isAfter(_now().toUtc());
  }

  bool _hasUsableAccessToken(AuthSession session) {
    final accessExpiresAt = DateTime.tryParse(
      session.accessTokenExpiresAt,
    )?.toUtc();
    return accessExpiresAt != null &&
        accessExpiresAt.isAfter(_now().toUtc().add(accessTokenRefreshSkew));
  }

  Future<void> _clearLocalSession({required bool signedOut}) async {
    _signedOutInMemory = signedOut;
    _sessionValidatedInProcess = false;
    Object? secureStorageError;
    try {
      await _store.clear();
    } on Object catch (error) {
      secureStorageError = error;
    }

    Object? markerStoreError;
    try {
      await _markerStore.write(active: false, signedOut: signedOut);
    } on Object catch (error) {
      markerStoreError = error;
    }

    if (secureStorageError != null && markerStoreError != null) {
      throw AuthSessionPersistenceException(
        secureStorageError: secureStorageError,
        markerStoreError: markerStoreError,
      );
    }
  }

  Future<void> _clearLocalSessionAndNotify({required bool signedOut}) async {
    try {
      await _clearLocalSession(signedOut: signedOut);
    } finally {
      _notifySessionChanged();
    }
  }

  void _notifySessionChanged() {
    _onSessionChanged?.call();
  }

  Future<bool> _hasSignedOutTombstone() async {
    if (_signedOutInMemory) {
      return true;
    }
    try {
      return await _markerStore.isSignedOut();
    } on Object {
      // If marker state cannot be read, do not trust a cached secure session.
      return true;
    }
  }

  Future<void> _trySetSessionMarkers({
    required bool active,
    required bool signedOut,
  }) async {
    try {
      await _markerStore.write(active: active, signedOut: signedOut);
    } on Object {
      // Secure storage remains authoritative for a valid session. Marker
      // writes are best-effort outside save/clear security transitions.
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _operationQueue = _operationQueue.then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
