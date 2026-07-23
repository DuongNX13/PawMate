import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/data/authenticated_dio.dart';

void main() {
  test(
    'protected request replaces a cached token with the current session',
    () async {
      final lifecycle = _FakeLifecycle(current: _session('fresh-access'));
      final adapter = _RecordingAdapter(statuses: [200]);
      final dio = _buildDio(lifecycle, adapter);

      final response = await dio.get<dynamic>(
        '/pets',
        options: Options(headers: {'Authorization': 'Bearer cached-access'}),
      );

      expect(response.statusCode, 200);
      expect(adapter.authorizationHeaders, ['Bearer fresh-access']);
      expect(lifecycle.readCalls, 1);
      expect(lifecycle.forceRefreshCalls, 0);
    },
  );

  test(
    'server 401 force refreshes once and retries with the rotated token',
    () async {
      final lifecycle = _FakeLifecycle(
        current: _session('initial-access'),
        refreshed: _session('rotated-access'),
      );
      final adapter = _RecordingAdapter(statuses: [401, 200]);
      final dio = _buildDio(lifecycle, adapter);

      final response = await dio.get<dynamic>(
        '/pets',
        options: Options(headers: {'Authorization': 'Bearer cached-access'}),
      );

      expect(response.statusCode, 200);
      expect(adapter.authorizationHeaders, [
        'Bearer initial-access',
        'Bearer rotated-access',
      ]);
      expect(lifecycle.forceRefreshCalls, 1);
    },
  );

  test(
    'missing valid session rejects protected request before transport',
    () async {
      final lifecycle = _FakeLifecycle();
      final adapter = _RecordingAdapter(statuses: [200]);
      final dio = _buildDio(lifecycle, adapter);

      await expectLater(
        dio.get<dynamic>(
          '/pets',
          options: Options(headers: {'Authorization': 'Bearer expired-access'}),
        ),
        throwsA(
          isA<DioException>().having(
            (error) => error.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
      expect(adapter.calls, 0);
    },
  );

  test('public request bypasses auth lifecycle', () async {
    final lifecycle = _FakeLifecycle();
    final adapter = _RecordingAdapter(statuses: [200]);
    final dio = _buildDio(lifecycle, adapter);

    final response = await dio.get<dynamic>('/vets/search');

    expect(response.statusCode, 200);
    expect(lifecycle.readCalls, 0);
    expect(adapter.calls, 1);
  });
}

Dio _buildDio(AuthSessionLifecycle lifecycle, HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://pawmate.test'));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(AuthSessionInterceptor(lifecycle: lifecycle, dio: dio));
  return dio;
}

class _FakeLifecycle implements AuthSessionLifecycle {
  _FakeLifecycle({this.current, this.refreshed});

  AuthSession? current;
  final AuthSession? refreshed;
  int readCalls = 0;
  int forceRefreshCalls = 0;

  @override
  Future<AuthSession?> readValidSession() async {
    readCalls += 1;
    return current;
  }

  @override
  Future<AuthSession?> forceRefreshSession() async {
    forceRefreshCalls += 1;
    current = refreshed;
    return current;
  }
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({required this.statuses});

  final List<int> statuses;
  final List<String?> authorizationHeaders = [];
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    authorizationHeaders.add(options.headers['Authorization']?.toString());
    final status = statuses[calls.clamp(0, statuses.length - 1)];
    calls += 1;
    final body = status == 200
        ? {
            'data': {'ok': true},
          }
        : {
            'error': {'code': 'AUTH_009', 'message': 'Unauthorized'},
          };
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AuthSession _session(String accessToken) {
  return AuthSession(
    user: const AuthUser(
      id: 'user-1',
      email: 'user@pawmate.test',
      authProvider: 'email',
      emailVerified: true,
    ),
    accessToken: accessToken,
    refreshToken: 'refresh-$accessToken',
    accessTokenExpiresAt: '2099-01-01T00:00:00Z',
    refreshTokenExpiresAt: '2099-02-01T00:00:00Z',
  );
}
