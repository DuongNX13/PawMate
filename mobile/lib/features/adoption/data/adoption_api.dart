import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/authenticated_dio.dart';
import '../domain/adoption_models.dart';

abstract interface class AdoptionSource {
  Future<AdoptionListingPage> listListings(
    AdoptionListQuery query, {
    required String accessToken,
  });

  Future<AdoptionListingDetail> getListing(
    String listingId, {
    required String accessToken,
  });

  Future<AdoptionDecisionResult> recordDecision(
    String listingId,
    AdoptionDecision decision, {
    required String accessToken,
    required String idempotencyKey,
  });
}

final adoptionSourceProvider = Provider<AdoptionSource>((ref) {
  return AdoptionApi(ref.watch(authenticatedDioProvider));
});

class AdoptionApiException implements Exception {
  const AdoptionApiException(
    this.message, {
    this.code,
    this.statusCode,
    this.field,
    this.requestId,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final String? field;
  final String? requestId;

  bool get isAuthRequired =>
      statusCode == 401 || code == 'AUTH_001' || code == 'AUTH_013';

  bool get isUnavailable =>
      statusCode == 404 ||
      code == 'ADOPTION_003' ||
      code == 'ADOPTION_LISTING_NOT_FOUND';

  bool get isConflict => statusCode == 409 || code == 'IDEMPOTENCY_001';

  bool get isOffline => code == 'NETWORK_OFFLINE';

  @override
  String toString() => message;
}

class AdoptionApi implements AdoptionSource {
  AdoptionApi(this._dio);

  final Dio _dio;

  @override
  Future<AdoptionListingPage> listListings(
    AdoptionListQuery query, {
    required String accessToken,
  }) {
    return _perform(
      call: () => _dio.get(
        '/adoption/listings',
        queryParameters: query.toQueryParameters(),
        options: _options(accessToken),
      ),
      parser: AdoptionListingPage.fromJson,
      invalidResponseMessage:
          'Máy chủ trả về danh sách nhận nuôi không hợp lệ.',
    );
  }

  @override
  Future<AdoptionListingDetail> getListing(
    String listingId, {
    required String accessToken,
  }) {
    return _perform(
      call: () => _dio.get(
        '/adoption/listings/${Uri.encodeComponent(listingId)}',
        options: _options(accessToken),
      ),
      parser: (json) => AdoptionListingDetail.fromJson(_readMap(json['data'])),
      invalidResponseMessage: 'Máy chủ trả về hồ sơ nhận nuôi không hợp lệ.',
    );
  }

  @override
  Future<AdoptionDecisionResult> recordDecision(
    String listingId,
    AdoptionDecision decision, {
    required String accessToken,
    required String idempotencyKey,
  }) {
    return _perform(
      call: () => _dio.post(
        '/adoption/listings/${Uri.encodeComponent(listingId)}/decisions',
        data: {'decision': decision.wireValue},
        options: _options(accessToken, idempotencyKey: idempotencyKey),
      ),
      parser: (json) => AdoptionDecisionResult.fromJson(_readMap(json['data'])),
      invalidResponseMessage:
          'Máy chủ trả về quyết định nhận nuôi không hợp lệ.',
    );
  }

  Options _options(String accessToken, {String? idempotencyKey}) {
    final normalizedToken = accessToken.trim();
    if (normalizedToken.isEmpty) {
      throw const AdoptionApiException(
        'Bạn cần đăng nhập để sử dụng tính năng nhận nuôi.',
        code: 'AUTH_REQUIRED',
        statusCode: 401,
      );
    }
    final headers = <String, dynamic>{
      'Authorization': 'Bearer $normalizedToken',
      'Cache-Control': 'no-store',
    };
    if (idempotencyKey != null) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    return Options(
      headers: headers,
      extra: const {'pawmate.cache': 'disabled'},
    );
  }

  Future<T> _perform<T>({
    required Future<Response<dynamic>> Function() call,
    required T Function(Map<String, dynamic> json) parser,
    required String invalidResponseMessage,
  }) async {
    try {
      final response = await call();
      return parser(_readMap(response.data));
    } on AdoptionApiException {
      rethrow;
    } on DioException catch (error) {
      throw _toException(error);
    } on FormatException {
      throw AdoptionApiException(
        invalidResponseMessage,
        code: 'INVALID_RESPONSE',
      );
    }
  }

  AdoptionApiException _toException(DioException error) {
    final payload = error.response?.data;
    if (payload is Map) {
      final errorMap = payload['error'];
      if (errorMap is Map) {
        return AdoptionApiException(
          errorMap['message']?.toString() ?? _fallbackMessage(error),
          code: errorMap['code']?.toString(),
          statusCode: error.response?.statusCode,
          field: errorMap['field']?.toString(),
          requestId: payload['requestId']?.toString(),
        );
      }
    }
    return AdoptionApiException(
      _fallbackMessage(error),
      code: _isNetworkFailure(error) ? 'NETWORK_OFFLINE' : null,
      statusCode: error.response?.statusCode,
    );
  }

  bool _isNetworkFailure(DioException error) => switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout => true,
    _ => false,
  };

  String _fallbackMessage(DioException error) {
    if (_isNetworkFailure(error)) {
      return 'Không thể kết nối tới máy chủ nhận nuôi.';
    }
    return 'Không tải được dữ liệu nhận nuôi. Vui lòng thử lại.';
  }
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('Invalid Adoption response envelope.');
}
