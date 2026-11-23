import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_dio.dart';
import '../domain/rescue_comment_models.dart';

abstract interface class RescueCommentSource {
  Future<RescueCommentPage> listComments({
    required String accessToken,
    required String caseId,
    String? cursor,
    int limit = 50,
  });

  Future<RescueComment> sendComment({
    required String accessToken,
    required String caseId,
    required String body,
    required List<String> mediaIds,
    required String idempotencyKey,
    String? replyToCommentId,
  });

  Future<RescueCommentDraftMedia> uploadMedia({
    required String accessToken,
    required RescueCommentDraftMedia media,
    required ValueChanged<double> onProgress,
  });
}

final rescueCommentSourceProvider = Provider<RescueCommentSource>(
  (ref) => RescueCommentApi(ref.watch(dioProvider)),
);

class RescueCommentApiException implements Exception {
  const RescueCommentApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  bool get commentsClosed => code == 'RESCUE_010';
  bool get authRequired => code == 'AUTH_013' || statusCode == 401;

  @override
  String toString() => message;
}

class RescueCommentApi implements RescueCommentSource {
  RescueCommentApi(this._dio);

  final Dio _dio;

  @override
  Future<RescueCommentPage> listComments({
    required String accessToken,
    required String caseId,
    String? cursor,
    int limit = 50,
  }) async {
    final response = await _request(
      () => _dio.get(
        '/rescue/cases/$caseId/discussion',
        queryParameters: {
          'limit': limit,
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
        options: _authOptions(accessToken),
      ),
    );
    final envelope = _readMap(response.data);
    final rawItems = envelope['data'];
    final rawPageInfo = envelope['pageInfo'];
    if (rawItems is! List) {
      throw const RescueCommentApiException(
        'Máy chủ trả về danh sách bình luận không hợp lệ.',
        code: 'INVALID_RESPONSE',
      );
    }
    final items = <RescueComment>[];
    try {
      for (final item in rawItems) {
        if (item is Map) {
          items.add(RescueComment.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    } on FormatException {
      throw const RescueCommentApiException(
        'Máy chủ trả về bình luận không hợp lệ.',
        code: 'INVALID_RESPONSE',
      );
    }
    items.sort((left, right) {
      final byTime = left.createdAt.compareTo(right.createdAt);
      return byTime != 0 ? byTime : left.commentId.compareTo(right.commentId);
    });
    final pageInfo = rawPageInfo is Map
        ? Map<String, dynamic>.from(rawPageInfo)
        : const <String, dynamic>{};
    return RescueCommentPage(
      items: items,
      nextCursor: pageInfo['nextCursor']?.toString(),
    );
  }

  @override
  Future<RescueComment> sendComment({
    required String accessToken,
    required String caseId,
    required String body,
    required List<String> mediaIds,
    required String idempotencyKey,
    String? replyToCommentId,
  }) async {
    final response = await _request(
      () => _dio.post(
        '/rescue/cases/$caseId/comments',
        data: {
          'body': body.trim(),
          if (mediaIds.isNotEmpty) 'mediaIds': mediaIds,
          if (replyToCommentId != null && replyToCommentId.trim().isNotEmpty)
            'replyToCommentId': replyToCommentId.trim(),
        },
        options: _authOptions(accessToken, idempotencyKey: idempotencyKey),
      ),
    );
    try {
      return RescueComment.fromJson(_readDataMap(response.data));
    } on FormatException {
      throw const RescueCommentApiException(
        'Máy chủ trả về bình luận không hợp lệ.',
        code: 'INVALID_RESPONSE',
      );
    }
  }

  @override
  Future<RescueCommentDraftMedia> uploadMedia({
    required String accessToken,
    required RescueCommentDraftMedia media,
    required ValueChanged<double> onProgress,
  }) async {
    final file = File(media.path);
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } on FileSystemException {
      throw const RescueCommentApiException(
        'Không đọc được tệp đã chọn. Vui lòng chọn lại.',
        code: 'MEDIA_001',
      );
    }
    final digest = sha256.convert(bytes).toString();
    final ticketResponse = await _request(
      () => _dio.post(
        '/media/uploads',
        data: {
          'purpose': 'rescue_comment',
          'mimeType': media.mimeType,
          'sizeBytes': bytes.length,
          'sha256': digest,
          'fileName': _fileName(media.path),
        },
        options: _authOptions(
          accessToken,
          idempotencyKey: 'pawmate-day45-upload-${media.localId}',
        ),
      ),
    );
    final ticket = _readDataMap(ticketResponse.data);
    final uploadUrl = ticket['uploadUrl']?.toString();
    final mediaId = ticket['mediaId']?.toString();
    if (uploadUrl == null ||
        uploadUrl.isEmpty ||
        mediaId == null ||
        mediaId.isEmpty) {
      throw const RescueCommentApiException(
        'Máy chủ không trả về phiên tải tệp hợp lệ.',
        code: 'MEDIA_001',
      );
    }
    final uploadHeaders = <String, dynamic>{};
    final rawHeaders = ticket['uploadHeaders'];
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        uploadHeaders[entry.key.toString()] = entry.value;
      }
    }
    await _request(
      () => _dio.put(
        uploadUrl,
        data: Stream<Uint8List>.fromIterable([Uint8List.fromList(bytes)]),
        options: Options(
          headers: {'Content-Length': bytes.length, ...uploadHeaders},
          contentType: media.mimeType,
          responseType: ResponseType.json,
        ),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress((sent / total).clamp(0, 1));
        },
      ),
    );
    final completeResponse = await _request(
      () => _dio.post(
        '/media/uploads/$mediaId/complete',
        data: {'sha256': digest},
        options: _authOptions(
          accessToken,
          idempotencyKey: 'pawmate-day45-complete-${media.localId}',
        ),
      ),
    );
    final complete = _readDataMap(completeResponse.data);
    final completedMediaId = complete['mediaId']?.toString();
    if (completedMediaId == null || completedMediaId.isEmpty) {
      throw const RescueCommentApiException(
        'Tệp chưa được xác minh hoàn tất.',
        code: 'MEDIA_004',
      );
    }
    onProgress(1);
    return media.copyWith(
      mediaId: completedMediaId,
      status: RescueCommentUploadStatus.uploaded,
      progress: 1,
      clearError: true,
    );
  }

  Options _authOptions(String accessToken, {String? idempotencyKey}) {
    final headers = <String, dynamic>{
      'Authorization': 'Bearer $accessToken',
      'Cache-Control': 'no-store',
    };
    if (idempotencyKey != null) headers['Idempotency-Key'] = idempotencyKey;
    return Options(
      headers: headers,
      extra: const {'pawmate.cache': 'disabled'},
    );
  }

  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      final payload = error.response?.data;
      final rawError = payload is Map ? payload['error'] : null;
      final errorMap = rawError is Map
          ? Map<String, dynamic>.from(rawError)
          : const <String, dynamic>{};
      throw RescueCommentApiException(
        errorMap['message']?.toString() ?? _fallbackMessage(error),
        code: errorMap['code']?.toString(),
        statusCode: error.response?.statusCode,
      );
    } on FileSystemException {
      throw const RescueCommentApiException(
        'Không đọc được tệp đã chọn. Vui lòng chọn lại.',
        code: 'MEDIA_001',
      );
    }
  }

  String _fallbackMessage(DioException error) => switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout =>
      'Không thể kết nối. Nội dung chưa gửi vẫn được giữ.',
    _ => 'Không thể gửi bình luận. Vui lòng thử lại.',
  };

  static String _fileName(String path) => path.split(RegExp(r'[\\/]')).last;
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const RescueCommentApiException(
    'Máy chủ trả về dữ liệu không hợp lệ.',
    code: 'INVALID_RESPONSE',
  );
}

Map<String, dynamic> _readDataMap(dynamic value) {
  final envelope = _readMap(value);
  final data = envelope['data'];
  if (data is Map) return Map<String, dynamic>.from(data);
  throw const RescueCommentApiException(
    'Máy chủ trả về dữ liệu không hợp lệ.',
    code: 'INVALID_RESPONSE',
  );
}
