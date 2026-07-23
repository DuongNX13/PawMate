import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_dio.dart';
import '../application/auth_session_coordinator.dart';

final authenticatedDioProvider = Provider<Dio>((ref) {
  final dio = createAppDio();
  dio.interceptors.add(
    AuthSessionInterceptor(
      lifecycle: ref.watch(authSessionCoordinatorProvider),
      dio: dio,
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

class AuthSessionInterceptor extends Interceptor {
  AuthSessionInterceptor({
    required AuthSessionLifecycle lifecycle,
    required Dio dio,
  }) : _lifecycle = lifecycle,
       _dio = dio;

  static const _retryKey = 'pawmate.auth.retry';
  static const _resolutionFailedKey = 'pawmate.auth.resolutionFailed';

  final AuthSessionLifecycle _lifecycle;
  final Dio _dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_requiresAuthentication(options)) {
      handler.next(options);
      return;
    }

    try {
      final session = await _lifecycle.readValidSession();
      if (session == null) {
        options.extra[_resolutionFailedKey] = true;
        handler.reject(_authRequiredError(options));
        return;
      }
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
      handler.next(options);
    } on Object catch (error) {
      options.extra[_resolutionFailedKey] = true;
      handler.reject(_authRequiredError(options, cause: error));
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        !_requiresAuthentication(request) ||
        request.extra[_retryKey] == true ||
        request.extra[_resolutionFailedKey] == true) {
      handler.next(err);
      return;
    }

    try {
      final requestToken = _readBearerToken(request);
      var session = await _lifecycle.readValidSession();
      if (session == null || session.accessToken == requestToken) {
        session = await _lifecycle.forceRefreshSession();
      }
      if (session == null) {
        handler.next(err);
        return;
      }

      request.extra[_retryKey] = true;
      request.headers['Authorization'] = 'Bearer ${session.accessToken}';
      final response = await _dio.fetch<dynamic>(request);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    } on Object {
      handler.next(err);
    }
  }

  bool _requiresAuthentication(RequestOptions options) {
    return _readBearerToken(options) != null;
  }

  String? _readBearerToken(RequestOptions options) {
    final value = options.headers.entries
        .where((entry) => entry.key.toLowerCase() == 'authorization')
        .map((entry) => entry.value?.toString())
        .whereType<String>()
        .firstOrNull;
    if (value == null || !value.startsWith('Bearer ')) {
      return null;
    }
    final token = value.substring('Bearer '.length).trim();
    return token.isEmpty ? null : token;
  }

  DioException _authRequiredError(RequestOptions request, {Object? cause}) {
    return DioException(
      requestOptions: request,
      response: Response<dynamic>(
        requestOptions: request,
        statusCode: 401,
        data: const {
          'error': {
            'code': 'AUTH_001',
            'message': 'Phiên đăng nhập không còn hợp lệ.',
          },
        },
      ),
      error: cause,
      type: DioExceptionType.badResponse,
    );
  }
}
