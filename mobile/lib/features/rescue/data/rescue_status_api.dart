import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_dio.dart';
import '../domain/rescue_case_models.dart';

abstract interface class RescueStatusSource {
  Future<RescueCaseDetail> markFound({
    required String accessToken,
    required String caseId,
    required int expectedVersion,
    required String idempotencyKey,
  });
}

final rescueStatusSourceProvider = Provider<RescueStatusSource>(
  (ref) => RescueStatusApi(ref.watch(dioProvider)),
);

class RescueStatusApiException implements Exception {
  const RescueStatusApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  bool get isForbidden => code == 'RESCUE_002' || statusCode == 403;
  bool get isConflict =>
      code == 'RESCUE_005' ||
      code == 'RESCUE_011' ||
      code == 'IDEMPOTENCY_001' ||
      statusCode == 409;
  bool get isAuthRequired => code == 'AUTH_013' || statusCode == 401;

  @override
  String toString() => message;
}

class RescueStatusApi implements RescueStatusSource {
  RescueStatusApi(this._dio);

  final Dio _dio;

  @override
  Future<RescueCaseDetail> markFound({
    required String accessToken,
    required String caseId,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    try {
      final response = await _dio.patch(
        '/rescue/cases/$caseId/status',
        data: {
          'newStatus': 'found',
          'expectedStatus': 'missing',
          'expectedVersion': expectedVersion,
          'confirmedSafe': true,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Idempotency-Key': idempotencyKey,
            'Cache-Control': 'no-store',
          },
          extra: const {'pawmate.cache': 'disabled'},
        ),
      );
      final envelope = _readMap(response.data);
      return RescueCaseDetail.fromJson(_readMap(envelope['data']));
    } on DioException catch (error) {
      final payload = error.response?.data;
      final rawError = payload is Map ? payload['error'] : null;
      final errorMap = rawError is Map
          ? Map<String, dynamic>.from(rawError)
          : const <String, dynamic>{};
      throw RescueStatusApiException(
        errorMap['message']?.toString() ?? _fallbackMessage(error),
        code: errorMap['code']?.toString(),
        statusCode: error.response?.statusCode,
      );
    } on FormatException {
      throw const RescueStatusApiException(
        'Máy chủ trả về trạng thái ca cứu hộ không hợp lệ.',
        code: 'INVALID_RESPONSE',
      );
    }
  }

  String _fallbackMessage(DioException error) => switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout =>
      'Không thể kết nối. Trạng thái chưa được thay đổi.',
    _ => 'Không thể cập nhật trạng thái. Vui lòng thử lại.',
  };
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('Invalid Rescue status response.');
}
