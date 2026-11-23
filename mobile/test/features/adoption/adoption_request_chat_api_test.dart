import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_api.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_request_chat_models.dart';

void main() {
  test('private chat image uses bearer API bytes and never a public URL', () async {
    late RequestOptions request;
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            request = options;
            handler.resolve(
              Response<List<int>>(
                requestOptions: options,
                statusCode: 200,
                data: const [0xff, 0xd8, 0xff, 0xd9],
                headers: Headers.fromMap({
                  'content-type': ['image/jpeg'],
                }),
              ),
            );
          },
        ),
      );
    final media = _privateChatMedia();

    final bytes = await AdoptionRequestChatApi(dio).downloadChatMedia(
      accessToken: ' participant-token ',
      threadId: 'thread-1',
      media: media,
    );

    expect(bytes, [0xff, 0xd8, 0xff, 0xd9]);
    expect(request.uri.path, '/adoption/chat/thread-1/media/media-1');
    expect(request.uri.host, 'api.example.test');
    expect(request.headers['Authorization'], 'Bearer participant-token');
    expect(request.headers['Cache-Control'], 'no-store');
    expect(request.responseType, ResponseType.bytes);
  });

  test('legacy public chat URL is never used as a download fallback', () async {
    var requests = 0;
    final dio = _dio((_) {
      requests++;
      return {};
    });
    final media = _privateChatMedia(downloadPath: null);

    await expectLater(
      AdoptionRequestChatApi(dio).downloadChatMedia(
        accessToken: 'participant-token',
        threadId: 'thread-1',
        media: media,
      ),
      throwsA(
        isA<AdoptionApiException>().having(
          (error) => error.code,
          'code',
          'MEDIA_PRIVATE_UNAVAILABLE',
        ),
      ),
    );
    expect(requests, 0);
  });

  test('chat image path cannot be redirected to another thread', () async {
    var requests = 0;
    final dio = _dio((_) {
      requests++;
      return {};
    });

    await expectLater(
      AdoptionRequestChatApi(dio).downloadChatMedia(
        accessToken: 'participant-token',
        threadId: 'other-thread',
        media: _privateChatMedia(),
      ),
      throwsA(isA<AdoptionApiException>()),
    );
    expect(requests, 0);
  });

  test(
    'my requests uses authenticated no-store route and safe summaries',
    () async {
      late RequestOptions request;
      final result = await AdoptionRequestChatApi(
        _dio((options) {
          request = options;
          return {
            'data': [
              {
                'requestId': 'request-1',
                'listingId': 'listing-1',
                'petName': 'Golden',
                'status': 'reviewing',
                'listingAvailability': 'expired',
                'threadId': 'thread-1',
                'createdAt': '2026-07-28T05:00:00.000Z',
                'updatedAt': '2026-07-29T05:00:00.000Z',
              },
            ],
          };
        }),
      ).listMyRequests(accessToken: ' token ');

      expect(request.method, 'GET');
      expect(request.uri.path, '/adoption/requests');
      expect(request.headers['Authorization'], 'Bearer token');
      expect(request.headers['Cache-Control'], 'no-store');
      expect(result, hasLength(1));
      expect(result.single.petName, 'Golden');
      expect(result.single.status, AdoptionRequestStatus.reviewing);
      expect(
        result.single.listingAvailability,
        AdoptionRequestListingAvailability.expired,
      );
    },
  );

  test('request sends exact payload and idempotency header', () async {
    late RequestOptions request;
    final dio = _dio((options) {
      request = options;
      return {
        'data': {
          'requestId': 'request-1',
          'listingId': 'listing-1',
          'adopterUserId': 'adopter-1',
          'shelterId': 'shelter-1',
          'livingCondition': 'Căn hộ an toàn',
          'petExperience': 'Đã nuôi chó',
          'carePlan': 'Khám định kỳ',
          'commitmentAccepted': true,
          'status': 'submitted',
          'threadId': 'thread-1',
          'createdAt': '2026-07-28T05:00:00.000Z',
        },
      };
    });

    final result = await AdoptionRequestChatApi(dio).createRequest(
      accessToken: ' token ',
      listingId: 'listing/unsafe',
      draft: const AdoptionRequestDraft(
        livingCondition: ' Căn hộ an toàn ',
        petExperience: ' Đã nuôi chó ',
        carePlan: ' Khám định kỳ ',
        commitmentAccepted: true,
      ),
      idempotencyKey: 'day55-request-1',
    );

    expect(request.uri.path, '/adoption/listings/listing%2Funsafe/requests');
    expect(request.data, {
      'livingCondition': 'Căn hộ an toàn',
      'petExperience': 'Đã nuôi chó',
      'carePlan': 'Khám định kỳ',
      'commitmentAccepted': true,
    });
    expect(request.headers['Authorization'], 'Bearer token');
    expect(request.headers['Idempotency-Key'], 'day55-request-1');
    expect(result.threadId, 'thread-1');
  });

  test('chat read, send and read-receipt use frozen routes', () async {
    final requests = <RequestOptions>[];
    final dio = _dio((options) {
      requests.add(options);
      if (options.method == 'GET') {
        return {
          'data': [
            {
              'messageId': 'message-1',
              'threadId': 'thread-1',
              'senderUserId': 'shelter-1',
              'body': 'Chào bạn',
              'media': <Object>[],
              'createdAt': '2026-07-28T05:00:00.000Z',
            },
          ],
          'thread': {
            'threadId': 'thread-1',
            'requestId': 'request-1',
            'participantRole': 'adopter',
            'lastReadAt': '2026-07-28T04:59:00.000Z',
            'unreadCount': 1,
          },
          'pageInfo': {'nextCursor': null, 'hasMore': false, 'limit': 50},
        };
      }
      if (options.method == 'POST') {
        return {
          'data': {
            'messageId': 'message-2',
            'threadId': 'thread-1',
            'senderUserId': 'adopter-1',
            'body': 'Mình cảm ơn',
            'media': <Object>[],
            'createdAt': '2026-07-28T05:01:00.000Z',
          },
        };
      }
      return {
        'data': {
          'threadId': 'thread-1',
          'lastReadAt': '2026-07-28T05:01:00.000Z',
          'unreadCount': 0,
        },
      };
    });
    final api = AdoptionRequestChatApi(dio);

    final page = await api.readChat(
      accessToken: 'token',
      threadId: 'thread-1',
      cursor: 'older',
    );
    final sent = await api.sendMessage(
      accessToken: 'token',
      threadId: 'thread-1',
      body: ' Mình cảm ơn ',
      mediaIds: const ['media-1'],
      idempotencyKey: 'day55-message-1',
    );
    final read = await api.markRead(
      accessToken: 'token',
      threadId: 'thread-1',
      throughMessageId: sent.messageId,
    );

    expect(requests[0].uri.path, '/adoption/chat/thread-1');
    expect(requests[0].queryParameters, {'cursor': 'older', 'limit': 50});
    expect(requests[1].uri.path, '/adoption/chat/thread-1/messages');
    expect(requests[1].data, {
      'body': 'Mình cảm ơn',
      'mediaIds': ['media-1'],
    });
    expect(requests[1].headers['Idempotency-Key'], 'day55-message-1');
    expect(requests[2].uri.path, '/adoption/chat/thread-1/read');
    expect(requests[2].data, {'throughMessageId': 'message-2'});
    expect(page.thread.unreadCount, 1);
    expect(read.unreadCount, 0);
  });

  test(
    'media upload uses ticket, exact digest and complete contract',
    () async {
      final directory = await Directory.systemTemp.createTemp('pawmate-day55-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}chat.webp');
      await file.writeAsBytes([1, 2, 3, 4]);
      final requests = <RequestOptions>[];
      final progress = <double>[];
      final dio = _dio((options) {
        requests.add(options);
        if (options.path == '/media/uploads') {
          return {
            'data': {
              'mediaId': 'media-1',
              'uploadUrl': 'https://uploads.example.test/media-1',
              'uploadHeaders': {'x-upload-token': 'test-only'},
            },
          };
        }
        if (options.path == '/media/uploads/media-1/complete') {
          return {
            'data': {'mediaId': 'media-1'},
          };
        }
        return <String, dynamic>{};
      });

      final uploaded = await AdoptionRequestChatApi(dio).uploadChatMedia(
        accessToken: 'token',
        threadId: 'thread-1',
        media: AdoptionChatDraftMedia(
          localId: 'local-1',
          path: file.path,
          mimeType: 'image/webp',
          sizeBytes: 4,
        ),
        onProgress: progress.add,
      );

      expect(requests, hasLength(3));
      expect(requests[0].data['purpose'], 'adoption_chat');
      expect(requests[0].data['threadId'], 'thread-1');
      expect(requests[0].data['fileName'], 'chat.webp');
      expect(requests[0].data['sha256'], hasLength(64));
      expect(
        requests[0].headers['Idempotency-Key'],
        'pawmate-day55-upload-local-1',
      );
      expect(requests[1].uri.host, 'uploads.example.test');
      expect(requests[1].headers['x-upload-token'], 'test-only');
      expect(requests[2].data['sha256'], requests[0].data['sha256']);
      expect(
        requests[2].headers['Idempotency-Key'],
        'pawmate-day55-complete-local-1',
      );
      expect(uploaded.status, AdoptionChatUploadStatus.uploaded);
      expect(uploaded.mediaId, 'media-1');
      expect(progress.last, 1);
    },
  );

  test(
    'media upload fails safely for missing file and invalid tickets',
    () async {
      final missingApi = AdoptionRequestChatApi(_dio((_) => {}));
      await expectLater(
        missingApi.uploadChatMedia(
          accessToken: 'token',
          threadId: 'thread-1',
          media: const AdoptionChatDraftMedia(
            localId: 'missing',
            path: 'Z:/definitely-missing/day55.webp',
            mimeType: 'image/webp',
            sizeBytes: 1,
          ),
          onProgress: (_) {},
        ),
        throwsA(
          isA<AdoptionApiException>().having(
            (error) => error.code,
            'code',
            'MEDIA_001',
          ),
        ),
      );

      final directory = await Directory.systemTemp.createTemp('pawmate-day55-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}chat.png');
      await file.writeAsBytes([1]);
      final invalidTicketApi = AdoptionRequestChatApi(
        _dio(
          (_) => {
            'data': {'mediaId': 'media-1'},
          },
        ),
      );
      await expectLater(
        invalidTicketApi.uploadChatMedia(
          accessToken: 'token',
          threadId: 'thread-1',
          media: AdoptionChatDraftMedia(
            localId: 'invalid-ticket',
            path: file.path,
            mimeType: 'image/png',
            sizeBytes: 1,
          ),
          onProgress: (_) {},
        ),
        throwsA(
          isA<AdoptionApiException>().having(
            (error) => error.code,
            'code',
            'MEDIA_001',
          ),
        ),
      );
    },
  );

  test('API maps auth, malformed and backend/network errors safely', () async {
    final validDraft = const AdoptionRequestDraft(
      livingCondition: 'Căn hộ',
      petExperience: 'Đã nuôi chó',
      carePlan: 'Khám định kỳ',
      commitmentAccepted: true,
    );
    await expectLater(
      AdoptionRequestChatApi(_dio((_) => {})).createRequest(
        accessToken: ' ',
        listingId: 'listing-1',
        draft: validDraft,
        idempotencyKey: 'request-1',
      ),
      throwsA(
        isA<AdoptionApiException>().having(
          (error) => error.code,
          'code',
          'AUTH_REQUIRED',
        ),
      ),
    );
    await expectLater(
      AdoptionRequestChatApi(_dio((_) => {'unexpected': true})).createRequest(
        accessToken: 'token',
        listingId: 'listing-1',
        draft: validDraft,
        idempotencyKey: 'request-1',
      ),
      throwsA(
        isA<AdoptionApiException>().having(
          (error) => error.code,
          'code',
          'INVALID_RESPONSE',
        ),
      ),
    );

    final backendDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 409,
                  data: {
                    'requestId': 'trace-1',
                    'error': {
                      'code': 'ADOPTION_006',
                      'message': 'Duplicate request',
                      'field': 'listingId',
                    },
                  },
                ),
              ),
            );
          },
        ),
      );
    await expectLater(
      AdoptionRequestChatApi(backendDio).createRequest(
        accessToken: 'token',
        listingId: 'listing-1',
        draft: validDraft,
        idempotencyKey: 'request-1',
      ),
      throwsA(
        isA<AdoptionApiException>()
            .having((error) => error.code, 'code', 'ADOPTION_006')
            .having((error) => error.requestId, 'requestId', 'trace-1'),
      ),
    );

    final offlineDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
          },
        ),
      );
    await expectLater(
      AdoptionRequestChatApi(
        offlineDio,
      ).readChat(accessToken: 'token', threadId: 'thread-1'),
      throwsA(
        isA<AdoptionApiException>().having(
          (error) => error.code,
          'code',
          'NETWORK_OFFLINE',
        ),
      ),
    );
  });
}

AdoptionChatMedia _privateChatMedia({
  String? downloadPath = '/adoption/chat/thread-1/media/media-1',
}) => AdoptionChatMedia(
  mediaId: 'media-1',
  ownerUserId: 'participant-1',
  mimeType: 'image/jpeg',
  sizeBytes: 4,
  sha256: 'a' * 64,
  status: 'attached',
  createdAt: DateTime.utc(2026, 9, 23),
  downloadPath: downloadPath,
  publicUrl: Uri.parse('https://cdn.example.test/legacy-chat.jpg'),
);

Dio _dio(Map<String, dynamic> Function(RequestOptions options) respond) {
  return Dio(BaseOptions(baseUrl: 'https://api.example.test'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: respond(options),
            ),
          );
        },
      ),
    );
}
