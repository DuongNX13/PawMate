import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dioProvider = Provider<Dio>((ref) {
  return createAppDio();
});

Dio createAppDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: _resolveBaseUrl(),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: const {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(BoundedRecoveryInterceptor(dio: dio));
  return dio;
}

typedef RecoveryDelay = Future<void> Function(Duration duration);

/// Performs a small, deterministic recovery attempt for transient responses.
///
/// Credential endpoints are deliberately excluded. Writes are retried only
/// when their caller supplied an idempotency key, and long Retry-After windows
/// are returned to the UI instead of keeping a form request alive in the
/// background.
class BoundedRecoveryInterceptor extends Interceptor {
  BoundedRecoveryInterceptor({
    required Dio dio,
    RecoveryDelay? delay,
    int Function()? jitterMilliseconds,
  }) : _dio = dio,
       _delay = delay ?? Future<void>.delayed,
       _jitterMilliseconds =
           jitterMilliseconds ?? (() => Random().nextInt(251));

  static const _retryCountKey = 'pawmate.boundedRecovery.retryCount';
  static const _maximumRetries = 2;
  static const _maximumAutomaticDelaySeconds = 5;

  final Dio _dio;
  final RecoveryDelay _delay;
  final int Function() _jitterMilliseconds;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final statusCode = err.response?.statusCode;
    final retryCount = request.extra[_retryCountKey] as int? ?? 0;
    final retryAfterSeconds = _retryAfterSeconds(err.response?.headers);

    if (!_isTransient(statusCode) ||
        !_isReplaySafe(request) ||
        retryCount >= _maximumRetries ||
        retryAfterSeconds == null ||
        retryAfterSeconds > _maximumAutomaticDelaySeconds) {
      handler.next(err);
      return;
    }

    final jitter = _jitterMilliseconds().clamp(0, 250);
    await _delay(Duration(seconds: retryAfterSeconds, milliseconds: jitter));
    request.extra[_retryCountKey] = retryCount + 1;

    try {
      final response = await _dio.fetch<dynamic>(request);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _isTransient(int? statusCode) => statusCode == 429 || statusCode == 503;

  bool _isReplaySafe(RequestOptions request) {
    final path = Uri.tryParse(request.path)?.path ?? request.path;
    if (path == '/auth' || path.startsWith('/auth/')) {
      return false;
    }
    if (request.data is Stream<Object?>) {
      return false;
    }

    final method = request.method.toUpperCase();
    if (method == 'GET' || method == 'HEAD' || method == 'OPTIONS') {
      return true;
    }

    return request.headers.entries.any(
      (entry) =>
          entry.key.toLowerCase() == 'idempotency-key' &&
          entry.value.toString().trim().isNotEmpty,
    );
  }

  int? _retryAfterSeconds(Headers? headers) {
    if (headers == null) {
      return null;
    }
    final value = headers.value('retry-after');
    final seconds = value == null ? null : int.tryParse(value.trim());
    return seconds != null && seconds >= 0 ? seconds : null;
  }
}

String _resolveBaseUrl() {
  const override = String.fromEnvironment('PAWMATE_API_BASE_URL');
  if (override.isNotEmpty) {
    return override;
  }

  if (kIsWeb) {
    return 'http://localhost:3000';
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:3000';
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return 'http://127.0.0.1:3000';
    case TargetPlatform.fuchsia:
      return 'http://localhost:3000';
  }
}
