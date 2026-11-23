import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/network/app_dio.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_runtime_providers.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_draft_store.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_models.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_request_chat_models.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_profile_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_request_form_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_swipe_deck_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/my_adoption_requests_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/shelter_chat_screen.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/data/authenticated_dio.dart';

const _apiBaseUrl = String.fromEnvironment(
  'PAWMATE_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);
const _email = 'mobile-e2e-owner@pawmate.test';
const _password = 'Pawmate123';
const _listingId = '83000000-0000-4000-8000-000000000003';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'SRS P2-09..P2-12 deck to profile, request, requests list and chat',
    (tester) async {
      final dio = Dio(
        BaseOptions(
          baseUrl: _apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: const {'Accept': 'application/json'},
        ),
      );
      final session = await AuthApi(
        dio,
      ).login(email: _email, password: _password);
      final listingPage = await AdoptionApi(dio).listListings(
        const AdoptionListQuery(limit: 20),
        accessToken: session.accessToken,
      );
      expect(
        listingPage.items.any((item) => item.listingId == _listingId),
        isTrue,
      );

      final store = _MemoryDraftStore();
      final router = GoRouter(
        initialLocation: '/adoption',
        routes: [
          GoRoute(
            path: '/adoption',
            builder: (context, state) => const AdoptionSwipeDeckScreen(),
          ),
          GoRoute(
            path: '/adoption/requests',
            builder: (context, state) => const MyAdoptionRequestsScreen(),
          ),
          GoRoute(
            path: '/adoption/:listingId/request',
            builder: (context, state) => AdoptionRequestFormScreen(
              listingId: state.pathParameters['listingId']!,
            ),
          ),
          GoRoute(
            path: '/adoption/chat/:threadId',
            builder: (context, state) =>
                ShelterChatScreen(threadId: state.pathParameters['threadId']!),
          ),
          GoRoute(
            path: '/adoption/:listingId',
            builder: (context, state) => AdoptionProfileScreen(
              listingId: state.pathParameters['listingId']!,
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWith((ref) => dio),
            authenticatedDioProvider.overrideWith((ref) => dio),
            authSessionSnapshotProvider.overrideWith((ref) async => session),
            adoptionAccessTokenProvider.overrideWith(
              (ref) async => session.accessToken,
            ),
            adoptionRequestChatDraftStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );

      await _waitFor(
        tester,
        find.byKey(const ValueKey('adoption-card-$_listingId')),
      );
      expect(find.textContaining('Mint SRS E2E'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('adoption-profile-action')));
      await _waitFor(tester, find.byKey(const Key('adoption-profile-screen')));
      await _waitFor(tester, find.text('Gửi yêu cầu nhận nuôi'));

      await tester.tap(find.text('Gửi yêu cầu nhận nuôi'));
      await _waitFor(tester, find.byKey(const Key('adoption-request-form')));

      await tester.tap(find.byKey(const Key('adoption-request-submit-cta')));
      await tester.pump();
      expect(find.text('Vui lòng mô tả môi trường sống.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('adoption-request-living-condition-field')),
        'Căn hộ có lưới an toàn, dữ liệu synthetic.',
      );
      await tester.enterText(
        find.byKey(const Key('adoption-request-pet-experience-field')),
        'Đã chăm sóc chó trưởng thành trong fixture kiểm thử.',
      );
      await tester.enterText(
        find.byKey(const Key('adoption-request-care-plan-field')),
        'Khám định kỳ và chăm sóc theo hướng dẫn bác sĩ thú y.',
      );
      await tester.dragUntilVisible(
        find.byKey(const Key('adoption-request-consent')),
        find.byKey(const Key('adoption-request-form')),
        const Offset(0, -400),
      );
      await tester.tap(find.byKey(const Key('adoption-request-consent')));
      await tester.tap(find.byKey(const Key('adoption-request-submit-cta')));
      await _waitFor(
        tester,
        find.byKey(const Key('adoption-request-submitted')),
        timeout: const Duration(seconds: 20),
      );

      final requests = await AdoptionRequestChatApi(
        dio,
      ).listMyRequests(accessToken: session.accessToken);
      final request = requests.singleWhere(
        (item) => item.listingId == _listingId,
      );
      expect(request.threadId, isNotNull);

      await tester.tap(find.text('Mở cuộc trò chuyện'));
      await _waitFor(tester, find.byKey(const Key('adoption-chat-screen')));
      await _waitFor(tester, find.byKey(const Key('adoption-chat-composer')));
      final message =
          'Tin nhắn synthetic SRS E2E ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(
        find.byKey(const Key('adoption-chat-composer')),
        message,
      );
      final composer = tester.widget<TextField>(
        find.byKey(const Key('adoption-chat-composer')),
      );
      composer.onChanged?.call(message);
      await tester.pump();
      final sendAction = find.byKey(const Key('adoption-chat-send'));
      expect(tester.widget<IconButton>(sendAction).onPressed, isNotNull);
      await tester.tap(sendAction);
      final chatApi = AdoptionRequestChatApi(dio);
      late AdoptionChatPage chat;
      for (var attempt = 0; attempt < 50; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        chat = await chatApi.readChat(
          accessToken: session.accessToken,
          threadId: request.threadId!,
        );
        if (chat.messages.any((item) => item.body == message)) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(chat.messages.any((item) => item.body == message), isTrue);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('adoption-chat-composer')))
            .controller
            ?.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);

      router.go('/adoption/requests');
      await _waitFor(
        tester,
        find.byKey(const Key('my-adoption-requests-list')),
      );
      expect(find.text('Mint SRS E2E'), findsOneWidget);
      expect(
        find.byKey(Key('my-adoption-request-${request.requestId}')),
        findsOneWidget,
      );
    },
  );
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(finder, findsAtLeastNWidgets(1));
}

class _MemoryDraftStore implements AdoptionRequestChatDraftStore {
  final Map<String, AdoptionRequestDraft> _requestDrafts = {};
  final Map<String, AdoptionChatDraft> _chatDrafts = {};
  final Map<String, AdoptionChatContext> _chatContexts = {};

  String _key(String userId, String resourceId) => '$userId::$resourceId';

  @override
  Future<void> clearChatDraft({
    required String userId,
    required String threadId,
  }) async => _chatDrafts.remove(_key(userId, threadId));

  @override
  Future<void> clearRequestDraft({
    required String userId,
    required String listingId,
  }) async => _requestDrafts.remove(_key(userId, listingId));

  @override
  Future<AdoptionChatContext?> readChatContext({
    required String userId,
    required String threadId,
  }) async => _chatContexts[_key(userId, threadId)];

  @override
  Future<AdoptionChatDraft> readChatDraft({
    required String userId,
    required String threadId,
  }) async => _chatDrafts[_key(userId, threadId)] ?? const AdoptionChatDraft();

  @override
  Future<AdoptionRequestDraft> readRequestDraft({
    required String userId,
    required String listingId,
  }) async =>
      _requestDrafts[_key(userId, listingId)] ?? const AdoptionRequestDraft();

  @override
  Future<void> saveChatContext({
    required String userId,
    required String threadId,
    required AdoptionChatContext context,
  }) async => _chatContexts[_key(userId, threadId)] = context;

  @override
  Future<void> saveChatDraft({
    required String userId,
    required String threadId,
    required AdoptionChatDraft draft,
  }) async => _chatDrafts[_key(userId, threadId)] = draft;

  @override
  Future<void> saveRequestDraft({
    required String userId,
    required String listingId,
    required AdoptionRequestDraft draft,
  }) async => _requestDrafts[_key(userId, listingId)] = draft;
}
