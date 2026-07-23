import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/authenticated_dio.dart';
import '../domain/pet_profile.dart';

final petApiProvider = Provider<PetApi>((ref) {
  return PetApi(ref.watch(authenticatedDioProvider));
});

class PetApiException implements Exception {
  const PetApiException(this.message, {this.code, this.statusCode, this.field});

  final String message;
  final String? code;
  final int? statusCode;
  final String? field;

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

  Future<PetProfile> getPet(String petId, {required String accessToken}) async {
    return _perform(
      call: () => _dio.get(
        '/pets/${Uri.encodeComponent(petId)}',
        options: _authOptions(accessToken),
      ),
      parser: (json) => PetProfile.fromJson(_readMap(json['data'])),
    );
  }

  Future<PetProfile> updatePet(
    String petId,
    UpdatePetProfileInput input, {
    required String accessToken,
  }) async {
    return _perform(
      call: () => _dio.put(
        '/pets/${Uri.encodeComponent(petId)}',
        data: input.toJson(),
        options: _authOptions(accessToken),
      ),
      parser: (json) => PetProfile.fromJson(_readMap(json['data'])),
    );
  }

  Future<void> deletePet(String petId, {required String accessToken}) async {
    try {
      await _dio.delete<void>(
        '/pets/${Uri.encodeComponent(petId)}',
        options: _authOptions(accessToken),
      );
    } on DioException catch (error) {
      throw _toException(error);
    }
  }

  Future<PetProfile> uploadPetPhoto(
    String petId,
    PetPhotoInput photo, {
    required String accessToken,
  }) async {
    return _perform(
      call: () => _dio.post(
        '/pets/${Uri.encodeComponent(petId)}/photo',
        data: {
          'fileName': photo.fileName,
          'contentType': photo.contentType,
          'base64Data': base64Encode(photo.bytes),
        },
        options: _authOptions(accessToken),
      ),
      parser: (json) {
        final data = _readMap(json['data']);
        return PetProfile.fromJson(_readMap(data['pet']));
      },
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
          field: errorMap['field']?.toString(),
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
