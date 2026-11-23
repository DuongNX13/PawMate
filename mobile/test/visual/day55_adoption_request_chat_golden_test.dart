import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_layout.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_draft_store.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_models.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_request_chat_models.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_request_form_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/my_adoption_requests_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/shelter_chat_screen.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';

import '../features/adoption/adoption_test_fixtures.dart';
import '../features/adoption/adoption_ui_test_support.dart';
import '../test_support/ui_test_helpers.dart';

const _goldenKey = Key('day55-adoption-golden-root');
const _viewport = Size(390, 844);

Future<void> pumpDay120AdoptionRequest(WidgetTester tester, Size size) => _pump(
  tester,
  const AdoptionRequestFormScreen(listingId: 'listing-1'),
  viewport: size,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets('P2-11 request form golden at 390x844', (tester) async {
    await _pump(
      tester,
      const AdoptionRequestFormScreen(listingId: 'listing-1'),
    );

    expect(
      find.byKey(const Key('adoption-request-living-condition-field')),
      findsOneWidget,
    );
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile(
        'goldens/day55/p2-11-adoption-request-form-390x844.png',
      ),
    );
  });

  testWidgets('P2-12 shelter chat golden at 390x844', (tester) async {
    await _pump(tester, const ShelterChatScreen(threadId: 'thread-1'));

    expect(find.byKey(const Key('adoption-chat-composer')), findsOneWidget);
    expect(
      find.text(
        'Chào bạn! Cảm ơn bạn đã quan tâm đến bé Mochi. Chúng mình đã nhận được yêu cầu nhận nuôi của bạn và đang xem xét hồ sơ.',
      ),
      findsOneWidget,
    );
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile('goldens/day55/p2-12-shelter-chat-390x844.png'),
    );
  });

  testWidgets('DT-03 expired request recovery golden at 390x844', (
    tester,
  ) async {
    await _pump(tester, const MyAdoptionRequestsScreen());

    expect(find.text('Tin nhận nuôi đã hết hiệu lực'), findsOneWidget);
    expect(find.text('Khám phá bé khác'), findsOneWidget);
    expect(find.text('Nhắn mái ấm'), findsOneWidget);
    expect(find.text('Xem hồ sơ'), findsNothing);
    expectNoFlutterOverflow(tester);
    await expectLater(
      find.byKey(_goldenKey),
      matchesGoldenFile(
        'goldens/day109/dt-03-expired-adoption-request-390x844.png',
      ),
    );
  });

  for (final viewport in const [
    Size(360, 800),
    Size(412, 915),
    Size(430, 932),
  ]) {
    final tag = '${viewport.width.toInt()}x${viewport.height.toInt()}';
    testWidgets('P2-12 shelter chat responsive golden at $tag', (tester) async {
      await _pump(
        tester,
        const ShelterChatScreen(threadId: 'thread-1'),
        viewport: viewport,
      );
      expect(find.byKey(const Key('adoption-chat-composer')), findsOneWidget);
      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/day55/p2-12-shelter-chat-$tag.png'),
      );
    });
  }
}

Future<void> pumpDay118Chat(WidgetTester tester, Size viewport) => _pump(
  tester,
  const ShelterChatScreen(threadId: 'thread-1'),
  viewport: viewport,
);

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Size viewport = _viewport,
}) async {
  await setTestViewport(tester, size: viewport);
  final detailJson = adoptionDetailJson();
  detailJson['heroMedia'] = adoptionMediaJson(publicUrl: null);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adoptionSourceProvider.overrideWithValue(
          FakeAdoptionUiSource(
            detail: AdoptionListingDetail.fromJson(detailJson),
          ),
        ),
        adoptionRequestChatSourceProvider.overrideWithValue(
          _GoldenRequestChatSource(),
        ),
        adoptionRequestChatDraftStoreProvider.overrideWithValue(
          _GoldenDraftStore(),
        ),
        adoptionRequestListSourceProvider.overrideWithValue(
          _GoldenRequestListSource(),
        ),
        authSessionSnapshotProvider.overrideWithValue(
          const AsyncValue.data(_session),
        ),
      ],
      child: RepaintBoundary(
        key: _goldenKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: screen,
        ),
      ),
    ),
  );
  if (screen is AdoptionRequestFormScreen || screen is ShelterChatScreen) {
    final context = tester.element(
      screen is AdoptionRequestFormScreen
          ? find.byType(AdoptionRequestFormScreen)
          : find.byType(ShelterChatScreen),
    );
    await tester.runAsync(() async {
      // Await both images: pumpAndSettle does not wait for asset decoding.
      // Otherwise an isolated Chat golden can omit the brand canvas while
      // the full suite has already warmed that same asset in the form test.
      await precacheImage(
        const AssetImage(PawMateBrandCanvas.textureAsset),
        context,
      );
      await precacheImage(
        const AssetImage('assets/images/pets/home_adoption_golden.png'),
        context,
      );
    });
  }
  await tester.pumpAndSettle();
}

class _GoldenRequestListSource implements AdoptionRequestListSource {
  @override
  Future<List<AdoptionRequestSummary>> listMyRequests({
    required String accessToken,
  }) async => [
    AdoptionRequestSummary.fromJson({
      'requestId': 'request-expired-1',
      'listingId': 'listing-expired-1',
      'petName': 'Mochi',
      'status': 'reviewing',
      'listingAvailability': 'expired',
      'threadId': 'thread-1',
      'createdAt': '2026-07-28T05:00:00.000Z',
      'updatedAt': '2026-09-18T05:00:00.000Z',
    }),
  ];
}

const _session = AuthSession(
  user: AuthUser(
    id: 'adopter-1',
    email: 'golden@example.com',
    authProvider: 'email',
    emailVerified: true,
  ),
  accessToken: 'golden-token',
  refreshToken: 'golden-refresh',
  accessTokenExpiresAt: '2030-01-01T00:00:00.000Z',
  refreshTokenExpiresAt: '2030-01-02T00:00:00.000Z',
);

class _GoldenRequestChatSource implements AdoptionRequestChatSource {
  @override
  Future<AdoptionRequestResult> createRequest({
    required String accessToken,
    required String listingId,
    required AdoptionRequestDraft draft,
    required String idempotencyKey,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdoptionChatPage> readChat({
    required String accessToken,
    required String threadId,
    String? cursor,
    int limit = 50,
  }) async {
    return AdoptionChatPage(
      messages: [
        AdoptionChatMessage(
          messageId: 'message-1',
          threadId: threadId,
          senderUserId: 'shelter-1',
          body:
              'Chào bạn! Cảm ơn bạn đã quan tâm đến bé Mochi. Chúng mình đã nhận được yêu cầu nhận nuôi của bạn và đang xem xét hồ sơ.',
          media: const [],
          createdAt: DateTime.utc(2026, 7, 28, 3, 10),
        ),
      ],
      thread: AdoptionChatThread(
        threadId: threadId,
        requestId: 'request-1',
        participantRole: AdoptionChatParticipantRole.adopter,
        lastReadAt: DateTime.utc(2026, 7, 28, 3, 10),
        unreadCount: 0,
      ),
      hasMore: false,
      limit: limit,
    );
  }

  @override
  Future<AdoptionChatReadState> markRead({
    required String accessToken,
    required String threadId,
    required String throughMessageId,
  }) async => AdoptionChatReadState(
    threadId: threadId,
    lastReadAt: DateTime.utc(2026, 7, 28, 3, 12),
    unreadCount: 0,
  );

  @override
  Future<AdoptionChatMessage> sendMessage({
    required String accessToken,
    required String threadId,
    required String body,
    required List<String> mediaIds,
    required String idempotencyKey,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdoptionChatDraftMedia> uploadChatMedia({
    required String accessToken,
    required String threadId,
    required AdoptionChatDraftMedia media,
    required ValueChanged<double> onProgress,
  }) {
    throw UnimplementedError();
  }
}

class _GoldenDraftStore implements AdoptionRequestChatDraftStore {
  @override
  Future<AdoptionRequestDraft> readRequestDraft({
    required String userId,
    required String listingId,
  }) async => const AdoptionRequestDraft();

  @override
  Future<AdoptionChatDraft> readChatDraft({
    required String userId,
    required String threadId,
  }) async => const AdoptionChatDraft();

  @override
  Future<AdoptionChatContext?> readChatContext({
    required String userId,
    required String threadId,
  }) async => const AdoptionChatContext(
    listingId: 'listing-1',
    petName: 'Mochi',
    shelterId: 'shelter-1',
  );

  @override
  Future<void> saveRequestDraft({
    required String userId,
    required String listingId,
    required AdoptionRequestDraft draft,
  }) async {}

  @override
  Future<void> clearRequestDraft({
    required String userId,
    required String listingId,
  }) async {}

  @override
  Future<void> saveChatDraft({
    required String userId,
    required String threadId,
    required AdoptionChatDraft draft,
  }) async {}

  @override
  Future<void> clearChatDraft({
    required String userId,
    required String threadId,
  }) async {}

  @override
  Future<void> saveChatContext({
    required String userId,
    required String threadId,
    required AdoptionChatContext context,
  }) async {}
}
