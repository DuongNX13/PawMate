import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/core/network/app_dio.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';

void main() {
  test('retries a safe read at most twice and honors Retry-After', () async {
    final delays = <Duration>[];
    final adapter = _SequenceAdapter([503, 503, 200]);
    final dio = _dio(adapter, delay: (duration) async => delays.add(duration));

    final response = await dio.get<dynamic>('/vets/search');

    expect(response.statusCode, 200);
    expect(adapter.calls, 3);
    expect(delays, [const Duration(seconds: 1), const Duration(seconds: 1)]);
  });

  test('stops after two retries and preserves the final 503', () async {
    final adapter = _SequenceAdapter([503, 503, 503, 200]);
    final dio = _dio(adapter, delay: (_) async {});

    await expectLater(
      dio.get<dynamic>('/vets/search'),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'statusCode',
          503,
        ),
      ),
    );
    expect(adapter.calls, 3);
  });

  test('never retries credential endpoints or unsafe writes', () async {
    final authAdapter = _SequenceAdapter([503, 200]);
    final authDio = _dio(authAdapter, delay: (_) async {});
    await expectLater(
      authDio.post<dynamic>(
        '/auth/login',
        data: {'email': 'owner@example.test', 'password': 'not-logged'},
        options: Options(headers: {'Idempotency-Key': 'auth-key'}),
      ),
      throwsA(isA<DioException>()),
    );
    expect(authAdapter.calls, 1);

    final unsafeAdapter = _SequenceAdapter([503, 200]);
    final unsafeDio = _dio(unsafeAdapter, delay: (_) async {});
    await expectLater(
      unsafeDio.post<dynamic>('/reviews', data: {'rating': 5}),
      throwsA(isA<DioException>()),
    );
    expect(unsafeAdapter.calls, 1);
  });

  test(
    'retries an idempotent write but does not auto-wait a long window',
    () async {
      final writeAdapter = _SequenceAdapter([503, 200]);
      final writeDio = _dio(writeAdapter, delay: (_) async {});
      final response = await writeDio.post<dynamic>(
        '/adoption/listings/listing-1/requests',
        data: {'message': 'hello'},
        options: Options(headers: {'Idempotency-Key': 'request-key'}),
      );
      expect(response.statusCode, 200);
      expect(writeAdapter.calls, 2);

      final longAdapter = _SequenceAdapter([429, 200], retryAfterSeconds: 30);
      final longDio = _dio(longAdapter, delay: (_) async {});
      await expectLater(
        longDio.get<dynamic>('/vets/search'),
        throwsA(isA<DioException>()),
      );
      expect(longAdapter.calls, 1);
    },
  );

  test(
    'auth exposes the deterministic Retry-After without retrying credentials',
    () async {
      final adapter = _SequenceAdapter([503], retryAfterSeconds: 5);
      final api = AuthApi(_dio(adapter, delay: (_) async {}));

      await expectLater(
        api.login(email: 'owner@example.test', password: 'not-logged'),
        throwsA(
          isA<AuthApiException>()
              .having((error) => error.code, 'code', 'SEC_002')
              .having(
                (error) => error.retryAfterSeconds,
                'retryAfterSeconds',
                5,
              )
              .having(
                (error) => error.message,
                'message',
                contains('Thử lại sau 5 giây.'),
              ),
        ),
      );
      expect(adapter.calls, 1);
    },
  );
}

Dio _dio(
  HttpClientAdapter adapter, {
  required Future<void> Function(Duration) delay,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://pawmate.test'));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(
    BoundedRecoveryInterceptor(
      dio: dio,
      delay: delay,
      jitterMilliseconds: () => 0,
    ),
  );
  return dio;
}

class _SequenceAdapter implements HttpClientAdapter {
  _SequenceAdapter(this.statuses, {this.retryAfterSeconds = 1});

  final List<int> statuses;
  final int retryAfterSeconds;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final status = statuses[calls.clamp(0, statuses.length - 1)];
    calls += 1;
    return ResponseBody.fromString(
      jsonEncode(
        status >= 400
            ? {
                'error': {'code': 'SEC_002', 'message': 'Thử lại sau.'},
              }
            : {
                'data': {'ok': true},
              },
      ),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        'retry-after': ['$retryAfterSeconds'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
