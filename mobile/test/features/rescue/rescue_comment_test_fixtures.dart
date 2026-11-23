import 'package:pawmate_mobile/features/rescue/data/rescue_comment_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_comment_models.dart';

List<RescueComment> sampleComments() => [
  RescueComment(
    commentId: '11111111-1111-4111-8111-111111111111',
    caseId: sampleCommentCaseId,
    author: const RescueCommentAuthor(displayName: 'Lâm Hoàng'),
    body: 'Mình vừa thấy một bé rất giống ở gần công viên lúc 10 giờ sáng.',
    media: const [],
    createdAt: DateTime.utc(2026, 7, 27, 9, 50),
    updatedAt: DateTime.utc(2026, 7, 27, 9, 50),
    moderationState: RescueCommentModerationState.visible,
  ),
  RescueComment(
    commentId: '22222222-2222-4222-8222-222222222222',
    caseId: sampleCommentCaseId,
    author: const RescueCommentAuthor(displayName: 'Minh Anh'),
    body: 'Bé đang nằm dưới gầm xe, đuôi có khoang vàng đúng như mô tả.',
    media: [
      RescueCommentMedia(
        mediaId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        mimeType: 'image/jpeg',
        publicUrl: Uri.parse('https://example.test/comment-cat.jpg'),
        width: 800,
        height: 600,
      ),
    ],
    createdAt: DateTime.utc(2026, 7, 27, 10, 15),
    updatedAt: DateTime.utc(2026, 7, 27, 10, 15),
    moderationState: RescueCommentModerationState.visible,
  ),
];

const sampleCommentCaseId = '11111111-1111-4111-8111-111111111111';

class FakeRescueCommentSource implements RescueCommentSource {
  FakeRescueCommentSource({List<RescueComment>? comments})
    : comments = comments ?? sampleComments();

  List<RescueComment> comments;
  int failSends = 0;
  int failUploads = 0;
  bool closeOnSend = false;
  Duration sendDelay = Duration.zero;
  Object? listError;
  Object? sendError;
  Object? uploadError;
  final List<String> sentKeys = [];
  final List<String> sentBodies = [];
  final List<List<String>> sentMediaIds = [];
  final List<String?> sentReplyToCommentIds = [];
  final List<String> requestedCaseIds = [];
  int uploadAttempts = 0;

  @override
  Future<RescueCommentPage> listComments({
    required String accessToken,
    required String caseId,
    String? cursor,
    int limit = 50,
  }) async {
    requestedCaseIds.add(caseId);
    if (listError case final error?) throw error;
    return RescueCommentPage(items: comments);
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
    sentKeys.add(idempotencyKey);
    sentBodies.add(body);
    sentMediaIds.add([...mediaIds]);
    sentReplyToCommentIds.add(replyToCommentId);
    if (sendError case final error?) throw error;
    if (sendDelay > Duration.zero) {
      await Future<void>.delayed(sendDelay);
    }
    if (closeOnSend) {
      throw const RescueCommentApiException(
        'The Rescue case is closed for new comments.',
        code: 'RESCUE_010',
        statusCode: 409,
      );
    }
    if (failSends > 0) {
      failSends -= 1;
      throw const RescueCommentApiException(
        'Không thể kết nối. Nội dung chưa gửi vẫn được giữ.',
        code: 'SYS_001',
        statusCode: 503,
      );
    }
    final persisted = RescueComment(
      commentId: '33333333-3333-4333-8333-333333333333',
      caseId: caseId,
      author: const RescueCommentAuthor(displayName: 'Bạn'),
      body: body,
      media: const [],
      createdAt: DateTime.utc(2026, 7, 27, 10, 45),
      updatedAt: DateTime.utc(2026, 7, 27, 10, 45),
      moderationState: RescueCommentModerationState.visible,
      replyToCommentId: replyToCommentId,
    );
    comments = [...comments, persisted];
    return persisted;
  }

  @override
  Future<RescueCommentDraftMedia> uploadMedia({
    required String accessToken,
    required RescueCommentDraftMedia media,
    required void Function(double progress) onProgress,
  }) async {
    uploadAttempts += 1;
    onProgress(0.5);
    if (uploadError case final error?) throw error;
    if (failUploads > 0) {
      failUploads -= 1;
      throw const RescueCommentApiException(
        'Tải tệp thất bại. Chạm để thử lại.',
        code: 'MEDIA_005',
      );
    }
    onProgress(1);
    return media.copyWith(
      mediaId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      status: RescueCommentUploadStatus.uploaded,
      progress: 1,
      clearError: true,
    );
  }
}
