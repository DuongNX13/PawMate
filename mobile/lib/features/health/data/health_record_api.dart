import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_dio.dart';
import '../domain/health_record.dart';

final healthRecordApiProvider = Provider<HealthRecordApi>((ref) {
  return HealthRecordApi(ref.watch(dioProvider));
});

class HealthRecordApiException implements Exception {
  const HealthRecordApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class HealthRecordApi {
  HealthRecordApi(this._dio);

  final Dio _dio;

  Future<HealthRecordListResult> listRecords(
    HealthRecordListQuery query, {
    required String accessToken,
  }) async {
    return _perform(
      call: () => _dio.get(
        '/pets/${query.petId}/health-records',
        queryParameters: query.toQueryParameters(),
        options: _authOptions(accessToken),
      ),
      parser: (json) => HealthRecordListResult.fromJson(_readMap(json['data'])),
    );
  }

  Future<HealthRecord> createRecord(
    String petId,
    CreateHealthRecordInput input, {
    required String accessToken,
  }) async {
    return _perform(
      call: () => _dio.post(
        '/pets/$petId/health-records',
        data: input.toJson(),
        options: _authOptions(accessToken),
      ),
      parser: (json) => HealthRecord.fromJson(_readMap(json['data'])),
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

  HealthRecordApiException _toException(DioException error) {
    final payload = error.response?.data;
    if (payload is Map<String, dynamic>) {
      final errorMap = payload['error'];
      if (errorMap is Map<String, dynamic>) {
        return HealthRecordApiException(
          errorMap['message']?.toString() ?? _fallbackMessage(error),
          code: errorMap['code']?.toString(),
          statusCode: error.response?.statusCode,
        );
      }
    }

    return HealthRecordApiException(
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
        return 'Không thể kết nối tới máy chủ hồ sơ sức khỏe.';
      default:
        return 'Đã có lỗi xảy ra khi tải hồ sơ sức khỏe.';
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
  throw const HealthRecordApiException(
    'Máy chủ trả về dữ liệu hồ sơ sức khỏe không hợp lệ.',
  );
}
