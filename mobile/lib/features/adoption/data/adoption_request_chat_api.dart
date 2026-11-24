import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/authenticated_dio.dart';
import '../domain/adoption_request_chat_models.dart';
import 'adoption_api.dart';

final adoptionRequestChatSourceProvider = Provider<AdoptionRequestChatSource>((
  ref,
) {
  return AdoptionRequestChatApi(ref.watch(authenticatedDioProvider));
});

final adoptionRequestListSourceProvider = Provider<AdoptionRequestListSource>((
  ref,
) {
  return AdoptionRequestChatApi(ref.watch(authenticatedDioProvider));
});

final adoptionChatMediaSourceProvider = Provider<AdoptionChatMediaSource>((
  ref,
) {
  return AdoptionRequestChatApi(ref.watch(authenticatedDioProvider));
});

abstract interface class AdoptionChatMediaSource {
  Future<Uint8List> downloadChatMedia({
    required String accessToken,
    required String threadId,
    required AdoptionChatMedia media,
  });
}

abstract interface class AdoptionRequestListSource {
  Future<List<AdoptionRequestSummary>> listMyRequests({
    required String accessToken,
  });
}

abstract interface class AdoptionRequestChatSource {
  Future<AdoptionRequestResult> createRequest({
    required String accessToken,
    required String listingId,
    required AdoptionRequestDraft draft,
    required String idempotencyKey,
  });

  Future<AdoptionChatPage> readChat({
    required String accessToken,
    required String threadId,
    String? cursor,
    int limit = 50,
  });

  Future<AdoptionChatMessage> sendMessage({
    required String accessToken,
    required String threadId,
    required String body,
    required List<String> mediaIds,
    required String idempotencyKey,
  });

  Future<AdoptionChatReadState> markRead({
    required String accessToken,
    required String threadId,
    required String throughMessageId,
  });

  Future<AdoptionChatDraftMedia> uploadChatMedia({
    required String accessToken,
    required String threadId,
    required AdoptionChatDraftMedia media,
    required ValueChanged<double> onProgress,
  });
}

class AdoptionRequestChatApi
    implements
        AdoptionRequestChatSource,
        AdoptionRequestListSource,
        AdoptionChatMediaSource {
  AdoptionRequestChatApi(this._dio);

  final Dio _dio;

  @override
  Future<Uint8List> downloadChatMedia({
    required String accessToken,
    required String threadId,
    required AdoptionChatMedia media,
  }) async {
    final path = media.downloadPath;
    final expectedPath =
        '/adoption/chat/${Uri.encodeComponent(threadId)}/media/'
        '${Uri.encodeComponent(media.mediaId)}';
    if (path != expectedPath) {
      throw const AdoptionApiException(
        'Ảnh đính kèm hiện chưa có đường tải riêng tư.',
        code: 'MEDIA_PRIVATE_UNAVAILABLE',
      );
    }
    final maxBytes = AdoptionChatMediaPolicy.maxBytesFor(media.mimeType);
    if (maxBytes <= 0 || media.sizeBytes < 1 || media.sizeBytes > maxBytes) {
      throw const AdoptionApiException(
        'Tệp đính kèm không hợp lệ.',
        code: 'INVALID_RESPONSE',
      );
    }
    try {
      final response = await _dio.get<List<int>>(
        expectedPath,
        options: _options(
          accessToken,
        ).copyWith(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      final contentType = response.headers
          .value(Headers.contentTypeHeader)
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (bytes == null ||
          bytes.isEmpty ||
          bytes.length > maxBytes ||
          contentType != media.mimeType) {
        throw const AdoptionApiException(
          'Máy chủ trả về tệp đính kèm không hợp lệ.',
          code: 'INVALID_RESPONSE',
        );
      }
      return Uint8List.fromList(bytes);
    } on DioException catch (error) {
      throw _toException(error);
    }
  }

  @override
  Future<List<AdoptionRequestSummary>> listMyRequests({
    required String accessToken,
  }) {
    return _perform(
      call: () =>
          _dio.get('/adoption/requests', options: _options(accessToken)),
      parser: (json) {
        final rawItems = json['data'];
        if (rawItems is! List) {
          throw const FormatException('Invalid Adoption request list.');
        }
        return List.unmodifiable(
          rawItems.map(
            (item) => AdoptionRequestSummary.fromJson(_readMap(item)),
          ),
        );
      },
      invalidResponseMessage:
          'Máy chủ trả về danh sách yêu cầu nhận nuôi không hợp lệ.',
    );
  }

  @override
  Future<AdoptionRequestResult> createRequest({
    required String accessToken,
    required String listingId,
    required AdoptionRequestDraft draft,
    required String idempotencyKey,
  }) {
    return _perform(
      call: () => _dio.post(
        '/adoption/listings/${Uri.encodeComponent(listingId)}/requests',
        data: draft.toRequestJson(),
        options: _options(accessToken, idempotencyKey: idempotencyKey),
      ),
      parser: (json) => AdoptionRequestResult.fromJson(_readMap(json['data'])),
      invalidResponseMessage: 'Máy chủ trả về yêu cầu nhận nuôi không hợp lệ.',
    );
  }

  @override
  Future<AdoptionChatPage> readChat({
    required String accessToken,
    required String threadId,
    String? cursor,
    int limit = 50,
  }) {
    return _perform(
      call: () => _dio.get(
        '/adoption/chat/${Uri.encodeComponent(threadId)}',
        queryParameters: {
          if (cursor != null && cursor.trim().isNotEmpty)
            'cursor': cursor.trim(),
          'limit': limit,
        },
        options: _options(accessToken),
      ),
      parser: AdoptionChatPage.fromJson,
      invalidResponseMessage: 'Máy chủ trả về cuộc trò chuyện không hợp lệ.',
    );
  }

  @override
  Future<AdoptionChatMessage> sendMessage({
    required String accessToken,
    required String threadId,
    required String body,
    required List<String> mediaIds,
    required String idempotencyKey,
  }) {
    return _perform(
      call: () => _dio.post(
        '/adoption/chat/${Uri.encodeComponent(threadId)}/messages',
        data: {'body': body.trim(), 'mediaIds': mediaIds},
        options: _options(accessToken, idempotencyKey: idempotencyKey),
      ),
      parser: (json) => AdoptionChatMessage.fromJson(_readMap(json['data'])),
      invalidResponseMessage: 'Máy chủ trả về tin nhắn không hợp lệ.',
    );
  }

  @override
  Future<AdoptionChatReadState> markRead({
    required String accessToken,
    required String threadId,
    required String throughMessageId,
  }) {
    return _perform(
      call: () => _dio.put(
        '/adoption/chat/${Uri.encodeComponent(threadId)}/read',
        data: {'throughMessageId': throughMessageId},
        options: _options(accessToken),
      ),
      parser: (json) => AdoptionChatReadState.fromJson(_readMap(json['data'])),
      invalidResponseMessage: 'Máy chủ trả về trạng thái đã đọc không hợp lệ.',
    );
  }

  @override
  Future<AdoptionChatDraftMedia> uploadChatMedia({
    required String accessToken,
    required String threadId,
    required AdoptionChatDraftMedia media,
    required ValueChanged<double> onProgress,
  }) async {
    final Uint8List bytes;
    try {
      bytes = await File(media.path).readAsBytes();
    } on FileSystemException {
      throw const AdoptionApiException(
        'Không đọc được tệp đã chọn. Vui lòng chọn lại.',
        code: 'MEDIA_001',
      );
    }
    final digest = sha256.convert(bytes).toString();
    final ticket = await _perform(
      call: () => _dio.post(
        '/media/uploads',
        data: {
          'purpose': 'adoption_chat',
          'threadId': threadId,
          'mimeType': media.mimeType,
          'sizeBytes': bytes.length,
          'sha256': digest,
          'fileName': _fileName(media.path),
        },
        options: _options(
          accessToken,
          idempotencyKey: 'pawmate-day55-upload-${media.localId}',
        ),
      ),
      parser: (json) => _readMap(json['data']),
      invalidResponseMessage: 'Máy chủ không trả về phiên tải tệp hợp lệ.',
    );
    final mediaId = ticket['mediaId']?.toString().trim();
    final uploadUrl = ticket['uploadUrl']?.toString().trim();
    if (mediaId == null ||
        mediaId.isEmpty ||
        uploadUrl == null ||
        uploadUrl.isEmpty) {
      throw const AdoptionApiException(
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
    try {
      await _dio.put(
        uploadUrl,
        data: Stream<Uint8List>.fromIterable([bytes]),
        options: Options(
          headers: {'Content-Length': bytes.length, ...uploadHeaders},
          contentType: media.mimeType,
          responseType: ResponseType.json,
        ),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress((sent / total).clamp(0, 1));
        },
      );
    } on DioException catch (error) {
      throw _toException(error);
    }
    final completed = await _perform(
      call: () => _dio.post(
        '/media/uploads/${Uri.encodeComponent(mediaId)}/complete',
        data: {'sha256': digest},
        options: _options(
          accessToken,
          idempotencyKey: 'pawmate-day55-complete-${media.localId}',
        ),
      ),
      parser: (json) => _readMap(json['data']),
      invalidResponseMessage: 'Tệp chưa được xác minh hoàn tất.',
    );
    final completedMediaId = completed['mediaId']?.toString().trim();
    if (completedMediaId == null || completedMediaId.isEmpty) {
      throw const AdoptionApiException(
        'Tệp chưa được xác minh hoàn tất.',
        code: 'MEDIA_004',
      );
    }
    onProgress(1);
    return media.copyWith(
      mediaId: completedMediaId,
      status: AdoptionChatUploadStatus.uploaded,
      progress: 1,
      clearError: true,
    );
  }

  Options _options(String accessToken, {String? idempotencyKey}) {
    final token = accessToken.trim();
    if (token.isEmpty) {
      throw const AdoptionApiException(
        'Bạn cần đăng nhập để sử dụng tính năng nhận nuôi.',
        code: 'AUTH_REQUIRED',
        statusCode: 401,
      );
    }
    return Options(
      headers: {
        'Authorization': 'Bearer $token',
        'Cache-Control': 'no-store',
        'Idempotency-Key': ?idempotencyKey,
      },
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
      final rawError = payload['error'];
      if (rawError is Map) {
        return AdoptionApiException(
          rawError['message']?.toString() ?? _fallbackMessage(error),
          code: rawError['code']?.toString(),
          statusCode: error.response?.statusCode,
          field: rawError['field']?.toString(),
          requestId: payload['requestId']?.toString(),
        );
      }
    }
    return AdoptionApiException(
      _fallbackMessage(error),
      code: _isNetwork(error) ? 'NETWORK_OFFLINE' : null,
      statusCode: error.response?.statusCode,
    );
  }

  static bool _isNetwork(DioException error) =>
      error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout;

  static String _fallbackMessage(DioException error) => _isNetwork(error)
      ? 'Không thể kết nối. Nội dung chưa gửi vẫn được giữ.'
      : 'Không thể hoàn tất thao tác. Vui lòng thử lại.';

  static String _fileName(String path) => path.split(RegExp(r'[\\/]')).last;
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('Invalid Adoption request/chat response.');
}
