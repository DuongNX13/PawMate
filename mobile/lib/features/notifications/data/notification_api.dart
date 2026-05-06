import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_dio.dart';
import '../domain/pawmate_notification.dart';

final notificationApiProvider = Provider<NotificationApi>((ref) {
  return NotificationApi(ref.watch(dioProvider));
});

class NotificationApiException implements Exception {
  const NotificationApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class NotificationApi {
  NotificationApi(this._dio);

  final Dio _dio;

  Future<NotificationListResult> listNotifications({
    required String accessToken,
    int limit = 20,
    String? cursor,
    bool unreadOnly = false,
  }) async {
    return _perform(
      call: () => _dio.get(
        '/notifications',
        queryParameters: {
          'limit': limit,
          if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor,
          if (unreadOnly) 'unreadOnly': true,
        },
        options: _authOptions(accessToken),
      ),
      parser: (json) => NotificationListResult.fromJson(_readMap(json['data'])),
    );
  }

  Future<int> processDueReminders({required String accessToken}) async {
    return _perform(
      call: () => _dio.post(
        '/notifications/process-due-reminders',
        options: _authOptions(accessToken),
      ),
      parser: (json) {
        final data = _readMap(json['data']);
        return int.tryParse(data['processedCount']?.toString() ?? '') ?? 0;
      },
    );
  }

  Future<PawMateNotification> markRead(
    String notificationId, {
    required String accessToken,
  }) async {
    return _perform(
      call: () => _dio.patch(
        '/notifications/$notificationId/read',
        options: _authOptions(accessToken),
      ),
      parser: (json) => PawMateNotification.fromJson(_readMap(json['data'])),
    );
  }

  Future<int> markAllRead({required String accessToken}) async {
    return _perform(
      call: () => _dio.post(
        '/notifications/read-all',
        options: _authOptions(accessToken),
      ),
      parser: (json) {
        final data = _readMap(json['data']);
        return int.tryParse(data['updatedCount']?.toString() ?? '') ?? 0;
      },
    );
  }

  Future<PawMateNotification> dismiss(
    String notificationId, {
    required String accessToken,
  }) async {
    return _perform(
      call: () => _dio.patch(
        '/notifications/$notificationId/dismiss',
        options: _authOptions(accessToken),
      ),
      parser: (json) => PawMateNotification.fromJson(_readMap(json['data'])),
    );
  }

  Options _authOptions(String accessToken) {
    return Options(headers: {'Authorization': 'Bearer $accessToken'});
  }

  Future<T> _perform<T>({
    required Future<Response<dynamic>> Function() call,
    required T Function(Map<String, dynamic> json) parser,
  }) async {
    try {
      final response = await call();
      return parser(_readMap(response.data));
    } on DioException catch (error) {
      throw _toException(error);
    }
  }

  NotificationApiException _toException(DioException error) {
    final payload = error.response?.data;
    if (payload is Map<String, dynamic>) {
      final errorMap = payload['error'];
      if (errorMap is Map<String, dynamic>) {
        return NotificationApiException(
          errorMap['message']?.toString() ?? _fallbackMessage(error),
          code: errorMap['code']?.toString(),
          statusCode: error.response?.statusCode,
        );
      }
    }

    return NotificationApiException(
      _fallbackMessage(error),
      statusCode: error.response?.statusCode,
    );
  }

  String _fallbackMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Khong the ket noi toi may chu thong bao.';
      default:
        return 'Da co loi xay ra khi tai thong bao.';
    }
  }
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  throw const NotificationApiException(
    'May chu tra ve du lieu thong bao khong hop le.',
  );
}
