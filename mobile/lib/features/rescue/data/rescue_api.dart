import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_dio.dart';
import '../domain/rescue_case_models.dart';

abstract interface class RescueCaseSource {
  Future<RescueCasePage> listCases(RescueCaseQuery query);
}

final rescueApiProvider = Provider<RescueCaseSource>((ref) {
  return RescueApi(ref.watch(dioProvider));
});

class RescueApiException implements Exception {
  const RescueApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class RescueApi implements RescueCaseSource {
  RescueApi(this._dio);

  final Dio _dio;

  @override
  Future<RescueCasePage> listCases(RescueCaseQuery query) async {
    try {
      final response = await _dio.get(
        '/rescue/cases',
        queryParameters: query.toQueryParameters(),
        options: Options(
          headers: const {'Cache-Control': 'no-store'},
          extra: const {'pawmate.cache': 'disabled'},
        ),
      );
      return RescueCasePage.fromJson(_readMap(response.data));
    } on DioException catch (error) {
      throw _toException(error);
    } on FormatException {
      throw const RescueApiException(
        'Máy chủ trả về dữ liệu cứu hộ không hợp lệ.',
        code: 'INVALID_RESPONSE',
      );
    }
  }

  RescueApiException _toException(DioException error) {
    final payload = error.response?.data;
    if (payload is Map) {
      final errorMap = payload['error'];
      if (errorMap is Map) {
        return RescueApiException(
          errorMap['message']?.toString() ?? _fallbackMessage(error),
          code: errorMap['code']?.toString(),
          statusCode: error.response?.statusCode,
        );
      }
    }
    return RescueApiException(
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
        return 'Không thể kết nối tới máy chủ cứu hộ.';
      default:
        return 'Không tải được các ca cứu hộ. Vui lòng thử lại.';
    }
  }
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('Invalid Rescue response envelope.');
}
