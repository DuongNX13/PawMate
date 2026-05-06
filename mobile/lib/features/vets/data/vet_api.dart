import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_dio.dart';
import '../domain/vet_models.dart';

final vetApiProvider = Provider<VetApi>((ref) {
  return VetApi(ref.watch(dioProvider));
});

class VetApiException implements Exception {
  const VetApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class VetApi {
  VetApi(this._dio);

  final Dio _dio;

  Future<VetSearchResult> search(VetSearchRequest request) async {
    return _perform(
      call: () => _dio.get(
        '/vets/search',
        queryParameters: {
          if (request.keyword.trim().isNotEmpty) 'q': request.keyword.trim(),
          if (request.city != null && request.city!.trim().isNotEmpty)
            'city': request.city!.trim(),
          if (request.district != null && request.district!.trim().isNotEmpty)
            'district': request.district!.trim(),
          if (request.only24h) 'is24h': 'true',
          if (request.openNow) 'isOpenNow': 'true',
          if (request.minRating != null) 'minRating': request.minRating,
          if (request.sort != VetSortOption.curated)
            'sort': request.sort.apiValue,
          'limit': request.limit,
          if (request.cursor != null) 'cursor': request.cursor,
        },
      ),
      parser: VetSearchResult.fromJson,
    );
  }

  Future<VetNearbyResult> nearby(VetNearbyRequest request) async {
    return _perform(
      call: () => _dio.get(
        '/vets/nearby',
        queryParameters: {
          'lat': request.latitude,
          'lng': request.longitude,
          'radius': request.radiusMeters,
          'limit': request.limit,
          if (request.cursor != null) 'cursor': request.cursor,
          if (request.only24h) 'is24h': 'true',
          if (request.openNow) 'isOpenNow': 'true',
          if (request.minRating != null) 'minRating': request.minRating,
        },
      ),
      parser: VetNearbyResult.fromJson,
    );
  }

  Future<VetDetail> getDetail(String vetId) async {
    return _perform(
      call: () => _dio.get('/vets/$vetId'),
      parser: (json) => VetDetail.fromJson(_readMap(json['data'])),
    );
  }

  Future<VetReviewResult> listReviews(
    String vetId, {
    VetReviewListRequest request = const VetReviewListRequest(),
  }) async {
    return _perform(
      call: () => _dio.get(
        '/vets/$vetId/reviews',
        queryParameters: {
          'limit': request.limit,
          if (request.cursor != null) 'cursor': request.cursor,
          if (request.sort != VetReviewSort.newest)
            'sort': request.sort.apiValue,
        },
      ),
      parser: VetReviewResult.fromJson,
    );
  }

  Future<VetReview> createReview(
    String vetId,
    CreateVetReviewInput input, {
    required String accessToken,
  }) async {
    return _perform(
      call: () => _dio.post(
        '/vets/$vetId/reviews',
        data: input.toJson(),
        options: _authOptions(accessToken),
      ),
      parser: (json) => VetReview.fromJson(_readMap(json['data'])),
    );
  }

  Future<UploadReviewPhotoResult> uploadReviewPhoto(
    String vetId,
    UploadReviewPhotoInput input, {
    required String accessToken,
  }) async {
    return _perform(
      call: () => _dio.post(
        '/vets/$vetId/reviews/photos',
        data: input.toJson(),
        options: _authOptions(accessToken),
      ),
      parser: (json) =>
          UploadReviewPhotoResult.fromJson(_readMap(json['data'])),
    );
  }

  Future<VetReviewHelpfulResult> toggleHelpful(
    String reviewId, {
    required String accessToken,
  }) async {
    return _perform(
      call: () => _dio.put(
        '/reviews/$reviewId/helpful',
        options: _authOptions(accessToken),
      ),
      parser: (json) => VetReviewHelpfulResult.fromJson(_readMap(json['data'])),
    );
  }

  Future<VetReviewReportResult> reportReview(
    String reviewId, {
    required String reason,
    String? description,
    required String accessToken,
  }) async {
    return _perform(
      call: () => _dio.post(
        '/reviews/$reviewId/report',
        data: {
          'reason': reason,
          if (description != null && description.trim().isNotEmpty)
            'description': description.trim(),
        },
        options: _authOptions(accessToken),
      ),
      parser: (json) => VetReviewReportResult.fromJson(_readMap(json['data'])),
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

  VetApiException _toException(DioException error) {
    final payload = error.response?.data;
    if (payload is Map<String, dynamic>) {
      final errorMap = payload['error'];
      if (errorMap is Map<String, dynamic>) {
        return VetApiException(
          errorMap['message']?.toString() ?? _fallbackMessage(error),
          code: errorMap['code']?.toString(),
          statusCode: error.response?.statusCode,
        );
      }
    }

    return VetApiException(
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
        return 'Không thể kết nối tới máy chủ vet của PawMate.';
      default:
        return 'Đã có lỗi xảy ra khi tải dữ liệu phòng khám.';
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
  throw const VetApiException('Máy chủ trả về dữ liệu vet không hợp lệ.');
}
