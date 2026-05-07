import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_dio.dart';
import '../domain/pet_profile.dart';

final petApiProvider = Provider<PetApi>((ref) {
  return PetApi(ref.watch(dioProvider));
});

class PetApiException implements Exception {
  const PetApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class PetApi {
  PetApi(this._dio);

  final Dio _dio;

  Future<List<PetProfile>> listPets({required String accessToken}) async {
    return _perform(
      call: () => _dio.get('/pets', options: _authOptions(accessToken)),
      parser: (json) => _readPetList(json['data']),
    );
  }

  Future<PetProfile> createPet(
    CreatePetProfileInput input, {
    required String accessToken,
  }) async {
    return _perform(
      call: () => _dio.post(
        '/pets',
        data: input.toJson(),
        options: _authOptions(accessToken),
      ),
      parser: (json) => PetProfile.fromJson(_readMap(json['data'])),
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

  PetApiException _toException(DioException error) {
    final payload = error.response?.data;
    if (payload is Map<String, dynamic>) {
      final errorMap = payload['error'];
      if (errorMap is Map<String, dynamic>) {
        return PetApiException(
          errorMap['message']?.toString() ?? _fallbackMessage(error),
          code: errorMap['code']?.toString(),
          statusCode: error.response?.statusCode,
        );
      }
    }

    return PetApiException(
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
        return 'Không thể kết nối tới máy chủ hồ sơ thú cưng.';
      default:
        return 'Đã có lỗi xảy ra khi đồng bộ hồ sơ thú cưng.';
    }
  }
}

List<PetProfile> _readPetList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => PetProfile.fromJson(_readMap(item)))
        .toList();
  }
  return const [];
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  throw const PetApiException(
    'Máy chủ trả về dữ liệu hồ sơ thú cưng không hợp lệ.',
  );
}
