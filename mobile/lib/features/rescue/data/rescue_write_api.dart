import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_dio.dart';
import '../domain/rescue_draft_models.dart';

abstract interface class RescueWriteSource {
  Future<RescueDraft> createDraft({
    required String accessToken,
    String source = 'rescue_home',
  });

  Future<RescueDraft> updateDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
    required Map<String, Object?> patch,
  });

  Future<void> publishDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
  });

  Future<RescueDraftMedia> uploadMedia({
    required String accessToken,
    required RescueDraftMedia media,
  });
}

final rescueWriteSourceProvider = Provider<RescueWriteSource>(
  (ref) => RescueWriteApi(ref.watch(dioProvider)),
);

class RescueWriteApiException implements Exception {
  const RescueWriteApiException(
    this.message, {
    this.code,
    this.statusCode,
    this.isConflict = false,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final bool isConflict;

  @override
  String toString() => message;
}

class RescueWriteApi implements RescueWriteSource {
  RescueWriteApi(this._dio);

  final Dio _dio;

  @override
  Future<RescueDraft> createDraft({
    required String accessToken,
    String source = 'rescue_home',
  }) async {
    final response = await _request(
      () => _dio.post(
        '/rescue/case-drafts',
        data: {'source': source},
        options: _authOptions(
          accessToken,
          idempotencyKey: _idempotencyKey('create'),
        ),
      ),
    );
    return RescueDraft.fromJson(_dataMap(response.data));
  }

  @override
  Future<RescueDraft> updateDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
    required Map<String, Object?> patch,
  }) async {
    final response = await _request(
      () => _dio.patch(
        '/rescue/case-drafts/$draftId',
        data: {'expectedVersion': expectedVersion, ...patch},
        options: _authOptions(accessToken),
      ),
    );
    return RescueDraft.fromJson(_dataMap(response.data));
  }

  @override
  Future<void> publishDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
  }) async {
    await _request(
      () => _dio.post(
        '/rescue/case-drafts/$draftId/publish',
        data: {'expectedVersion': expectedVersion},
        options: _authOptions(
          accessToken,
          idempotencyKey: _idempotencyKey('publish'),
        ),
      ),
    );
  }

  @override
  Future<RescueDraftMedia> uploadMedia({
    required String accessToken,
    required RescueDraftMedia media,
  }) async {
    final bytes = await File(media.path).readAsBytes();
    final digest = sha256.convert(bytes).toString();
    final ticketResponse = await _request(
      () => _dio.post(
        '/media/uploads',
        data: {
          'purpose': 'rescue_case',
          'mimeType': media.mimeType,
          'sizeBytes': bytes.length,
          'sha256': digest,
          'fileName': media.path.split(Platform.pathSeparator).last,
        },
        options: _authOptions(
          accessToken,
          idempotencyKey: _idempotencyKey('media'),
        ),
      ),
    );
    final ticket = _dataMap(ticketResponse.data);
    final uploadUrl = ticket['uploadUrl']?.toString();
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw const RescueWriteApiException(
        'Máy chủ không trả về đường dẫn tải ảnh.',
        code: 'MEDIA_001',
      );
    }
    final headers = <String, dynamic>{};
    final rawHeaders = ticket['uploadHeaders'];
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        headers[entry.key.toString()] = entry.value;
      }
    }
    await _request(
      () => _dio.put(
        uploadUrl,
        data: Stream<Uint8List>.fromIterable([Uint8List.fromList(bytes)]),
        options: Options(
          headers: {'Content-Length': bytes.length, ...headers},
          contentType: media.mimeType,
          responseType: ResponseType.json,
        ),
      ),
    );
    final complete = await _request(
      () => _dio.post(
        '/media/uploads/${ticket['mediaId']}/complete',
        data: {'sha256': digest},
        options: _authOptions(
          accessToken,
          idempotencyKey: _idempotencyKey('complete'),
        ),
      ),
    );
    final completeMap = _dataMap(complete.data);
    return media.copyWith(
      mediaId: completeMap['mediaId']?.toString(),
      uploaded: true,
    );
  }

  Options _authOptions(String accessToken, {String? idempotencyKey}) {
    final headers = <String, dynamic>{
      'Authorization': 'Bearer $accessToken',
      'Cache-Control': 'no-store',
    };
    if (idempotencyKey != null) headers['Idempotency-Key'] = idempotencyKey;
    return Options(headers: headers);
  }

  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      final payload = error.response?.data;
      final errorMap = payload is Map ? payload['error'] : null;
      final code = errorMap is Map ? errorMap['code']?.toString() : null;
      final message = errorMap is Map ? errorMap['message']?.toString() : null;
      throw RescueWriteApiException(
        message ?? _fallbackMessage(error),
        code: code,
        statusCode: error.response?.statusCode,
        isConflict: error.response?.statusCode == 409 || code == 'RESCUE_010',
      );
    }
  }

  String _fallbackMessage(DioException error) => switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout =>
      'Không thể kết nối. Bản nháp vẫn được giữ để bạn thử lại.',
    _ => 'Không thể lưu tin báo mất. Vui lòng thử lại.',
  };

  static String _idempotencyKey(String operation) =>
      'pawmate-day40-$operation-${DateTime.now().microsecondsSinceEpoch}';
}

Map<String, dynamic> _dataMap(dynamic value) {
  if (value is Map && value['data'] is Map) {
    return Map<String, dynamic>.from(value['data'] as Map);
  }
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const RescueWriteApiException(
    'Máy chủ trả về dữ liệu bản nháp không hợp lệ.',
    code: 'INVALID_RESPONSE',
  );
}
