import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/authenticated_dio.dart';
import '../domain/reminder.dart';

final reminderApiProvider = Provider<ReminderApi>((ref) {
  return ReminderApi(ref.watch(authenticatedDioProvider));
});

class ReminderApiException implements Exception {
  const ReminderApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class ReminderApi {
  ReminderApi(this._dio);

  final Dio _dio;

  Future<ReminderListResult> listReminders(
    ReminderListQuery query, {
    required String accessToken,
  }) async {
    return _perform(
      call: () => _dio.get(
        '/pets/${query.petId}/reminders',
        queryParameters: query.toQueryParameters(),
        options: _authOptions(accessToken),
      ),
      parser: (json) => ReminderListResult.fromJson(_readMap(json['data'])),
    );
  }

  Future<Reminder> createReminder(
    String petId,
    CreateReminderInput input, {
    required String accessToken,
  }) async {
    return _perform(
      call: () => _dio.post(
        '/pets/$petId/reminders',
        data: input.toJson(),
        options: _authOptions(accessToken),
      ),
      parser: (json) => Reminder.fromJson(_readMap(json['data'])),
    );
  }

  Future<Reminder> markDone(
    String petId,
    String reminderId, {
    required String accessToken,
  }) async {
    return _perform(
      call: () => _dio.post(
        '/pets/$petId/reminders/$reminderId/mark-done',
        options: _authOptions(accessToken),
      ),
      parser: (json) => Reminder.fromJson(_readMap(json['data'])),
    );
  }

  Future<Reminder> snoozeReminder(
    String petId,
    String reminderId,
    DateTime snoozedUntil, {
    required String accessToken,
  }) async {
    return _perform(
      call: () => _dio.post(
        '/pets/$petId/reminders/$reminderId/snooze',
        data: {'snoozedUntil': snoozedUntil.toUtc().toIso8601String()},
        options: _authOptions(accessToken),
      ),
      parser: (json) => Reminder.fromJson(_readMap(json['data'])),
    );
  }

  Future<void> deleteReminder(
    String petId,
    String reminderId, {
    required String accessToken,
  }) async {
    try {
      await _dio.delete(
        '/pets/$petId/reminders/$reminderId',
        options: _authOptions(accessToken),
      );
    } on DioException catch (error) {
      throw _toException(error);
    }
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

  ReminderApiException _toException(DioException error) {
    final payload = error.response?.data;
    if (payload is Map<String, dynamic>) {
      final errorMap = payload['error'];
      if (errorMap is Map<String, dynamic>) {
        return ReminderApiException(
          errorMap['message']?.toString() ?? _fallbackMessage(error),
          code: errorMap['code']?.toString(),
          statusCode: error.response?.statusCode,
        );
      }
    }

    return ReminderApiException(
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
        return 'Không thể kết nối tới máy chủ lịch nhắc.';
      default:
        return 'Đã có lỗi xảy ra khi tải lịch nhắc.';
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
  throw const ReminderApiException(
    'Máy chủ trả về dữ liệu lịch nhắc không hợp lệ.',
  );
}
