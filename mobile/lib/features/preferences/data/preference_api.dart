import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/authenticated_dio.dart';
import '../domain/preference_models.dart';

abstract interface class PreferenceSource {
  Future<NotificationPreferences> getNotificationPreferences({
    required String accessToken,
  });

  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences, {
    required String accessToken,
  });

  Future<PrivacyDefaults> getPrivacyDefaults({required String accessToken});

  Future<PrivacyDefaults> updatePrivacyDefaults(
    PrivacyDefaults defaults, {
    required String accessToken,
  });
}

final preferenceSourceProvider = Provider<PreferenceSource>((ref) {
  return PreferenceApi(ref.watch(authenticatedDioProvider));
});

class PreferenceApiException implements Exception {
  const PreferenceApiException(
    this.message, {
    this.code,
    this.statusCode,
    this.field,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final String? field;

  bool get isVersionConflict => statusCode == 409 || code == 'PREFERENCE_004';

  @override
  String toString() => message;
}

class PreferenceApi implements PreferenceSource {
  PreferenceApi(this._dio);

  final Dio _dio;

  @override
  Future<NotificationPreferences> getNotificationPreferences({
    required String accessToken,
  }) {
    return _perform(
      call: () => _dio.get(
        '/me/notification-preferences',
        options: _options(accessToken),
      ),
      parser: NotificationPreferences.fromJson,
    );
  }

  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences, {
    required String accessToken,
  }) {
    return _perform(
      call: () => _dio.put(
        '/me/notification-preferences',
        data: preferences.toUpdateJson(),
        options: _options(accessToken),
      ),
      parser: NotificationPreferences.fromJson,
    );
  }

  @override
  Future<PrivacyDefaults> getPrivacyDefaults({required String accessToken}) {
    return _perform(
      call: () =>
          _dio.get('/me/privacy-defaults', options: _options(accessToken)),
      parser: PrivacyDefaults.fromJson,
    );
  }

  @override
  Future<PrivacyDefaults> updatePrivacyDefaults(
    PrivacyDefaults defaults, {
    required String accessToken,
  }) {
    return _perform(
      call: () => _dio.put(
        '/me/privacy-defaults',
        data: defaults.toUpdateJson(),
        options: _options(accessToken),
      ),
      parser: PrivacyDefaults.fromJson,
    );
  }

  Options _options(String accessToken) {
    final token = accessToken.trim();
    if (token.isEmpty) {
      throw const PreferenceApiException(
        'Bạn cần đăng nhập để quản lý cài đặt.',
        code: 'AUTH_REQUIRED',
        statusCode: 401,
      );
    }
    return Options(
      headers: {'Authorization': 'Bearer $token', 'Cache-Control': 'no-store'},
      extra: const {'pawmate.cache': 'disabled'},
    );
  }

  Future<T> _perform<T>({
    required Future<Response<dynamic>> Function() call,
    required T Function(Map<String, dynamic> json) parser,
  }) async {
    try {
      final response = await call();
      return parser(_readMap(_readMap(response.data)['data']));
    } on PreferenceApiException {
      rethrow;
    } on DioException catch (error) {
      final payload = error.response?.data;
      if (payload is Map) {
        final errorMap = payload['error'];
        if (errorMap is Map) {
          throw PreferenceApiException(
            errorMap['message']?.toString() ??
                'Không thể lưu cài đặt. Vui lòng thử lại.',
            code: errorMap['code']?.toString(),
            statusCode: error.response?.statusCode,
            field: errorMap['field']?.toString(),
          );
        }
      }
      throw PreferenceApiException(
        _isOffline(error)
            ? 'Không thể kết nối tới máy chủ cài đặt.'
            : 'Không thể lưu cài đặt. Vui lòng thử lại.',
        code: _isOffline(error) ? 'NETWORK_OFFLINE' : null,
        statusCode: error.response?.statusCode,
      );
    } on FormatException {
      throw const PreferenceApiException(
        'Máy chủ trả về dữ liệu cài đặt không hợp lệ.',
        code: 'INVALID_RESPONSE',
      );
    }
  }

  bool _isOffline(DioException error) => switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout => true,
    _ => false,
  };
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('Invalid preference response envelope.');
}
