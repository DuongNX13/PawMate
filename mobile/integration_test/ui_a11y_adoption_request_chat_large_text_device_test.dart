import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_draft_store.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_models.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_request_chat_models.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_request_form_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/shelter_chat_screen.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';

import '../test/features/adoption/adoption_ui_test_support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Adoption Request keeps its title readable on Android at text scale 2',
    (tester) async {
      await binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _app(const AdoptionRequestFormScreen(listingId: 'listing-1')),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Yêu cầu nhận nuôi'), findsOneWidget);
      final title = find.text('Nhận nuôi');
      expect(title, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
        isFalse,
        reason: 'Visible P2-11 title must not ellipsize at text scale 2.0',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Shelter Chat keeps its title readable on Android at text scale 2',
    (tester) async {
      await binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _app(const ShelterChatScreen(threadId: 'thread-1')),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Hồ sơ thú cưng'), findsOneWidget);
      final title = find.text('Hồ sơ');
      expect(title, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
        isFalse,
        reason: 'Visible P2-12 title must not ellipsize at text scale 2.0',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app(Widget home) {
  final source = _DeviceSource();
  return ProviderScope(
    overrides: [
      adoptionSourceProvider.overrideWithValue(source),
      adoptionRequestChatSourceProvider.overrideWithValue(source),
      adoptionRequestChatDraftStoreProvider.overrideWithValue(_DeviceStore()),
      authSessionSnapshotProvider.overrideWithValue(
        const AsyncValue.data(_session),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: home,
    ),
  );
}

const _session = AuthSession(
  user: AuthUser(
    id: 'adopter-device',
    email: 'device@example.test',
    authProvider: 'email',
    emailVerified: true,
  ),
  accessToken: 'device-token',
  refreshToken: 'device-refresh-token',
  accessTokenExpiresAt: '2030-01-01T00:00:00.000Z',
  refreshTokenExpiresAt: '2030-01-02T00:00:00.000Z',
);

class _DeviceSource implements AdoptionSource, AdoptionRequestChatSource {
  @override
  Future<AdoptionListingPage> listListings(
    AdoptionListQuery query, {
    required String accessToken,
  }) async => uiAdoptionPage();

  @override
  Future<AdoptionListingDetail> getListing(
    String listingId, {
    required String accessToken,
  }) async => uiAdoptionDetail(listingId: listingId);

  @override
  Future<AdoptionDecisionResult> recordDecision(
    String listingId,
    AdoptionDecision decision, {
    required String accessToken,
    required String idempotencyKey,
  }) => Future.error(UnimplementedError('Not used by title proof.'));

  @override
  Future<AdoptionRequestResult> createRequest({
    required String accessToken,
    required String listingId,
    required AdoptionRequestDraft draft,
    required String idempotencyKey,
  }) => Future.error(UnimplementedError('Not used by title proof.'));

  @override
  Future<AdoptionChatPage> readChat({
    required String accessToken,
    required String threadId,
    String? cursor,
    int limit = 50,
  }) async => AdoptionChatPage(
    messages: const [],
    thread: AdoptionChatThread(
      threadId: threadId,
      requestId: 'request-device',
      participantRole: AdoptionChatParticipantRole.adopter,
      lastReadAt: DateTime.utc(2026, 7, 28, 4),
      unreadCount: 0,
    ),
    hasMore: false,
    limit: limit,
  );

  @override
  Future<AdoptionChatMessage> sendMessage({
    required String accessToken,
    required String threadId,
    required String body,
    required List<String> mediaIds,
    required String idempotencyKey,
  }) => Future.error(UnimplementedError('Not used by title proof.'));

  @override
  Future<AdoptionChatReadState> markRead({
    required String accessToken,
    required String threadId,
    required String throughMessageId,
  }) => Future.error(UnimplementedError('Not used by title proof.'));

  @override
  Future<AdoptionChatDraftMedia> uploadChatMedia({
    required String accessToken,
    required String threadId,
    required AdoptionChatDraftMedia media,
    required ValueChanged<double> onProgress,
  }) => Future.error(UnimplementedError('Not used by title proof.'));
}

class _DeviceStore implements AdoptionRequestChatDraftStore {
  @override
  Future<void> clearChatDraft({
    required String userId,
    required String threadId,
  }) async {}

  @override
  Future<void> clearRequestDraft({
    required String userId,
    required String listingId,
  }) async {}

  @override
  Future<AdoptionChatContext?> readChatContext({
    required String userId,
    required String threadId,
  }) async => null;

  @override
  Future<AdoptionChatDraft> readChatDraft({
    required String userId,
    required String threadId,
  }) async => const AdoptionChatDraft();

  @override
  Future<AdoptionRequestDraft> readRequestDraft({
    required String userId,
    required String listingId,
  }) async => const AdoptionRequestDraft();

  @override
  Future<void> saveChatContext({
    required String userId,
    required String threadId,
    required AdoptionChatContext context,
  }) async {}

  @override
  Future<void> saveChatDraft({
    required String userId,
    required String threadId,
    required AdoptionChatDraft draft,
  }) async {}

  @override
  Future<void> saveRequestDraft({
    required String userId,
    required String listingId,
    required AdoptionRequestDraft draft,
  }) async {}
}
