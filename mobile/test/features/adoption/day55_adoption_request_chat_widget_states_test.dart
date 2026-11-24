import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_text_field.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_request_provider.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_request_chat_draft_store.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_models.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_request_chat_models.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_request_form_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/shelter_chat_screen.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../test_support/day114_capture.dart';
import '../../test_support/day115_capture.dart';
import 'adoption_test_fixtures.dart';
import 'adoption_ui_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'D115 ST-19 failed adoption request retains draft and retries same key',
    (tester) async {
      final source = _WidgetSource()..failRequests = 1;
      final store = _WidgetStore()
        ..requestDraft = const AdoptionRequestDraft(
          livingCondition: 'Căn hộ',
          petExperience: 'Đã có kinh nghiệm',
          carePlan: 'Khám định kỳ',
          commitmentAccepted: true,
        );
      await _pump(
        tester,
        const AdoptionRequestFormScreen(listingId: 'listing-1'),
        source: source,
        store: store,
      );
      await tester.tap(find.byKey(const Key('adoption-request-submit-cta')));
      await _pumpFrames(tester);
      final care = tester.widget<PawMateTextField>(
        find.byKey(const Key('adoption-request-care-plan-field')),
      );
      expect(care.controller?.text, 'Khám định kỳ');
      expect(find.text('Gửi lại yêu cầu'), findsOneWidget);
      await captureDay115(tester, 'ST-19');
      await tester.tap(find.text('Gửi lại yêu cầu'));
      await _pumpFrames(tester);
      expect(
        find.byKey(const Key('adoption-request-submitted')),
        findsOneWidget,
      );
      expect(source.requestKeys, hasLength(2));
      expect(source.requestKeys[1], source.requestKeys[0]);
      expectNoFlutterOverflow(tester);
    },
  );

  // D122-TB-P2-002: at 2x text the just-sent bubble must scroll above the
  // composer instead of staying hidden under it.
  testWidgets('D124 sent message scrolls above composer at 2x text', (
    tester,
  ) async {
    await tester.runAsync(loadPawMateTestFonts);
    final source = _WidgetSource(
      chatPage: _chatPage(
        messages: [
          for (var i = 0; i < 12; i++)
            _chatMessage('m$i', sender: i.isEven ? 'shelter-1' : 'adopter-1'),
        ],
      ),
    );
    await _pump(
      tester,
      const ShelterChatScreen(threadId: 'thread-1'),
      source: source,
      store: _WidgetStore(),
      size: const Size(360, 800),
      textScale: 2,
    );
    const body = 'Tin D124';
    await tester.enterText(
      find.byKey(const Key('adoption-chat-composer')),
      body,
    );
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const Key('adoption-chat-send')));
    await _pumpFrames(tester);
    await tester.pump(const Duration(milliseconds: 600));
    final bubble = find.descendant(
      of: find.byKey(const Key('adoption-chat-message-list')),
      matching: find.text(body),
    );
    expect(bubble, findsOneWidget);
    final composerTop = tester
        .getRect(find.byKey(const Key('adoption-chat-composer')))
        .top;
    expect(tester.getRect(bubble).bottom, lessThanOrEqualTo(composerTop));
  });

  testWidgets('D115 ST-21 failed chat retains message and retries same key', (
    tester,
  ) async {
    await tester.runAsync(loadPawMateTestFonts);
    final source = _WidgetSource()..failMessages = 1;
    await _pump(
      tester,
      const ShelterChatScreen(threadId: 'thread-1'),
      source: source,
      store: _WidgetStore(),
    );
    final field = find.byKey(const Key('adoption-chat-composer'));
    await tester.enterText(field, 'Mình muốn tìm hiểu về bé.');
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const Key('adoption-chat-send')));
    await _pumpFrames(tester);
    expect(
      tester.widget<TextField>(field).controller?.text,
      'Mình muốn tìm hiểu về bé.',
    );
    expect(find.byTooltip('Gửi lại tin nhắn'), findsOneWidget);
    final sendIcon = find.descendant(
      of: find.byKey(const Key('adoption-chat-send')),
      matching: find.byIcon(Icons.send_rounded),
    );
    expect(
      IconTheme.of(tester.element(sendIcon)).color,
      AppColors.white,
      reason: 'Enabled retry arrow must contrast with the teal filled action',
    );
    await captureDay115(tester, 'ST-21');
    await tester.tap(find.byTooltip('Gửi lại tin nhắn'));
    await _pumpFrames(tester);
    expect(tester.widget<TextField>(field).controller?.text, isEmpty);
    expect(source.messageKeys, hasLength(2));
    expect(source.messageKeys[1], source.messageKeys[0]);
    expectNoFlutterOverflow(tester);
  });

  for (final action in ['Mở cuộc trò chuyện', 'Xem đơn của tôi']) {
    testWidgets(
      'D114 ST-14 confirmation routes $action to its contract destination',
      (tester) async {
        await setTestViewport(tester, size: const Size(390, 844));
        final source = _WidgetSource();
        final router = GoRouter(
          initialLocation: '/adoption/request',
          routes: [
            GoRoute(
              path: '/adoption/request',
              builder: (_, _) =>
                  AdoptionRequestFormScreen(listingId: 'listing-1'),
            ),
            GoRoute(
              path: '/adoption/chat/:threadId',
              builder: (_, state) => Scaffold(
                body: Text('Chat target ${state.pathParameters['threadId']}'),
              ),
            ),
            GoRoute(
              path: '/adoption/requests',
              builder: (_, _) => const Scaffold(body: Text('Requests target')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              adoptionSourceProvider.overrideWithValue(source),
              adoptionRequestChatSourceProvider.overrideWithValue(source),
              adoptionRequestChatDraftStoreProvider.overrideWithValue(
                _WidgetStore(),
              ),
              authSessionSnapshotProvider.overrideWithValue(
                const AsyncValue.data(_session),
              ),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light(),
              routerConfig: router,
            ),
          ),
        );
        await _pumpFrames(tester);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(AdoptionRequestFormScreen)),
        );
        container.read(adoptionRequestProvider('listing-1').notifier)
          ..setLivingCondition('Căn hộ')
          ..setPetExperience('Đã có kinh nghiệm')
          ..setCarePlan('Khám định kỳ và chuẩn bị không gian riêng an toàn.')
          ..setCommitmentAccepted(true);
        await tester.pump();
        final submit = find.byKey(const Key('adoption-request-submit-cta'));
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await _pumpFrames(tester);
        expect(
          find.byKey(const Key('adoption-request-submitted')),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text(action));
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        final expectedPath = action == 'Mở cuộc trò chuyện'
            ? '/adoption/chat/thread-1'
            : '/adoption/requests';
        final destination = find.text(
          action == 'Mở cuộc trò chuyện'
              ? 'Chat target thread-1'
              : 'Requests target',
        );
        expect(destination, findsOneWidget);
        expect(
          GoRouterState.of(tester.element(destination)).uri.path,
          expectedPath,
        );
        expectNoFlutterOverflow(tester);
      },
    );
  }

  testWidgets(
    'request form exposes validation, unavailable and submitted states',
    (tester) async {
      final source = _WidgetSource();
      final store = _WidgetStore();
      await _pump(
        tester,
        AdoptionRequestFormScreen(listingId: 'listing-1'),
        source: source,
        store: store,
      );

      expect(find.byKey(const Key('adoption-request-form')), findsOneWidget);
      await tester.tap(find.byKey(const Key('adoption-request-submit-cta')));
      await tester.pump();
      expect(find.text('Vui lòng mô tả môi trường sống.'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('adoption-request-living-condition-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Căn hộ').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đã có kinh nghiệm'));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('adoption-request-care-plan-field')),
      );
      await tester.enterText(
        find.byKey(const Key('adoption-request-care-plan-field')),
        'Khám định kỳ',
      );
      await tester.ensureVisible(
        find.byKey(const Key('adoption-request-consent')),
      );
      await tester.pump();
      expect(
        find.text('Bạn cần xác nhận cam kết trước khi gửi.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('adoption-request-consent')));
      await tester.tap(find.byKey(const Key('adoption-request-submit-cta')));
      await _pumpFrames(tester);
      expect(
        find.byKey(const Key('adoption-request-submitted')),
        findsOneWidget,
      );
      await captureDay114(tester, 'ST-14');

      source.detail = uiAdoptionDetail(
        status: AdoptionListingStatus.closed,
        canRequest: false,
      );
      await tester.pumpWidget(
        _scope(
          AdoptionRequestFormScreen(listingId: 'listing-2'),
          source: source,
          store: store,
        ),
      );
      await _pumpFrames(tester);
      expect(
        find.text('Tin này hiện không nhận thêm yêu cầu.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('adoption-request-submit-cta')),
        findsOneWidget,
      );
      final unavailableButton = tester.widget<PawMateButton>(
        find.descendant(
          of: find.byKey(const Key('adoption-request-submit-cta')),
          matching: find.byType(PawMateButton),
        ),
      );
      expect(unavailableButton.onPressed, isNull);
    },
  );

  testWidgets(
    'ST-14 submitted adoption request keeps its confirmation actions reachable at text scale 2.0',
    (tester) async {
      final source = _WidgetSource();
      final store = _WidgetStore();
      await _pump(
        tester,
        AdoptionRequestFormScreen(listingId: 'listing-1'),
        source: source,
        store: store,
        size: const Size(320, 568),
        textScale: 2,
      );

      final providerContainer = ProviderScope.containerOf(
        tester.element(find.byType(AdoptionRequestFormScreen)),
      );
      final notifier = providerContainer.read(
        adoptionRequestProvider('listing-1').notifier,
      );
      notifier
        ..setLivingCondition('Căn hộ')
        ..setPetExperience('Đã có kinh nghiệm')
        ..setCarePlan('Khám định kỳ và chuẩn bị không gian riêng an toàn.')
        ..setCommitmentAccepted(true);
      await tester.pump();
      await tester.tap(find.byKey(const Key('adoption-request-submit-cta')));
      await _pumpFrames(tester);

      expect(
        find.byKey(const Key('adoption-request-submitted')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Mở cuộc trò chuyện'));
      expect(find.text('Đã gửi yêu cầu'), findsOneWidget);
      expect(find.text('Xem đơn của tôi'), findsOneWidget);
      expect(
        tester
            .getSize(find.widgetWithText(PawMateButton, 'Mở cuộc trò chuyện'))
            .height,
        greaterThanOrEqualTo(48),
      );
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('request form error state retries into the form', (tester) async {
    final source = _WidgetSource(
      detailError: const AdoptionApiException(
        'offline',
        code: 'NETWORK_OFFLINE',
      ),
    );
    final store = _WidgetStore();
    await _pump(
      tester,
      AdoptionRequestFormScreen(listingId: 'listing-1'),
      source: source,
      store: store,
      size: const Size(320, 568),
      textScale: 2,
    );
    expect(find.byKey(const Key('adoption-request-error')), findsOneWidget);
    await tester.ensureVisible(find.text('Thử lại'));
    expectNoFlutterOverflow(tester);
    source.detailError = null;
    await tester.tap(find.text('Thử lại'));
    await _pumpFrames(tester);
    expect(find.byKey(const Key('adoption-request-form')), findsOneWidget);
  });

  testWidgets(
    'request form keeps its fixed CTA usable at text scale 2.0 with keyboard',
    (tester) async {
      final source = _WidgetSource();
      final store = _WidgetStore();
      await _pump(
        tester,
        AdoptionRequestFormScreen(listingId: 'listing-1'),
        source: source,
        store: store,
        size: const Size(320, 568),
        textScale: 2,
      );

      expect(find.bySemanticsLabel('Yêu cầu nhận nuôi'), findsOneWidget);
      final title = find.text('Nhận nuôi');
      expect(title, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
        isFalse,
        reason: 'Visible P2-11 title must not ellipsize at text scale 2.0',
      );

      final housingPicker = find.descendant(
        of: find.byKey(const Key('adoption-request-living-condition-field')),
        matching: find.byType(DropdownButton<String>),
      );
      expect(housingPicker, findsOneWidget);
      await tester.ensureVisible(housingPicker);
      await tester.tap(housingPicker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Căn hộ').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('adoption-request-care-plan-field')),
        160,
        scrollable: find.descendant(
          of: find.byKey(const Key('adoption-request-form')),
          // Real-font layout also creates horizontal EditText scrollables.
          // Only the vertical form can expose the offscreen care-plan field.
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                (widget.axisDirection == AxisDirection.down ||
                    widget.axisDirection == AxisDirection.up),
          ),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const Key('adoption-request-care-plan-field')),
      );
      final careInput = find.descendant(
        of: find.byKey(const Key('adoption-request-care-plan-field')),
        matching: find.byType(TextFormField),
      );
      await Scrollable.ensureVisible(tester.element(careInput), alignment: 0.5);
      await tester.pumpAndSettle();
      expect(
        tester
            .getRect(find.byKey(const Key('adoption-request-care-plan-field')))
            .bottom,
        lessThanOrEqualTo(
          tester
              .getRect(find.byKey(const Key('adoption-request-submit-cta')))
              .top,
        ),
      );
      expect(careInput.hitTestable(), findsOneWidget);
      await tester.tap(careInput);
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: careInput,
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      await setKeyboardInset(tester, bottom: 300);
      await tester.enterText(
        find.byKey(const Key('adoption-request-care-plan-field')),
        'Kế hoạch chăm sóc vẫn thao tác được khi bàn phím mở.',
      );

      final submitCta = find.byKey(const Key('adoption-request-submit-cta'));
      final submitButton = find.descendant(
        of: submitCta,
        matching: find.byType(PawMateButton),
      );
      expect(submitCta, findsOneWidget);
      expect(submitButton, findsOneWidget);
      // The fixed bar must lift its actual touch target above the 300dp IME,
      // not merely remain mounted below it.
      final keyboardTop = 568 - 300.0;
      final submitRect = tester.getRect(submitButton);
      expect(submitRect.top, greaterThanOrEqualTo(0));
      expect(submitRect.bottom, lessThanOrEqualTo(keyboardTop));
      expect(tester.getSize(submitButton).height, greaterThanOrEqualTo(48));
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets(
    'chat renders context, notices, pagination, composer and media sheet',
    (tester) async {
      final source = _WidgetSource(
        chatPage: _chatPage(
          messages: [
            _chatMessage('message-1', sender: 'shelter-1'),
            _chatMessage('message-2', sender: 'adopter-1', body: 'Đã rõ'),
          ],
          hasMore: true,
          nextCursor: 'older',
          unreadCount: 1,
        ),
      );
      final store = _WidgetStore()
        ..context = const AdoptionChatContext(
          listingId: 'listing-1',
          petName: 'Mochi',
          shelterId: 'shelter-1',
        );
      await _pump(
        tester,
        const ShelterChatScreen(threadId: 'thread-1'),
        source: source,
        store: store,
      );

      expect(find.byKey(const Key('adoption-chat-screen')), findsOneWidget);
      expect(find.text('Mochi & PawMate'), findsOneWidget);
      expect(
        find.byKey(const Key('adoption-chat-message-list')),
        findsOneWidget,
      );
      final loadOlder = find.byKey(const Key('adoption-chat-load-older'));
      expect(loadOlder, findsOneWidget);
      await tester.ensureVisible(loadOlder);
      await tester.pumpAndSettle();
      await tester.tap(loadOlder);
      await _pumpFrames(tester);
      expect(source.readCursors, contains('older'));

      const quickReplies = <String>[
        'Đặt lịch hẹn',
        'Hỏi về tính cách',
        'Thủ tục nhận nuôi',
      ];
      final firstQuickReply = find.byKey(
        const Key('adoption-chat-quick-reply-0'),
      );
      final quickReplyList = find.ancestor(
        of: firstQuickReply,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is ListView && widget.scrollDirection == Axis.horizontal,
          description: 'horizontal quick-reply list',
        ),
      );
      expect(quickReplyList, findsOneWidget);
      expect(
        tester
            .widget<ListView>(quickReplyList)
            .childrenDelegate
            .estimatedChildCount,
        quickReplies.length * 2 - 1,
        reason:
            'ListView.separated exposes item and separator children; five '
            'delegates prove exactly three quick replies.',
      );
      expect(find.text(quickReplies.first), findsOneWidget);
      expect(find.text(quickReplies[1]), findsOneWidget);
      await tester.ensureVisible(firstQuickReply);
      await tester.tap(firstQuickReply);
      await _pumpFrames(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('adoption-chat-composer')))
            .controller
            ?.text,
        quickReplies.first,
      );
      await tester.drag(quickReplyList, const Offset(-320, 0));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('adoption-chat-quick-reply-2')),
        findsOneWidget,
      );
      expect(find.text(quickReplies.last), findsOneWidget);

      await tester.tap(find.byKey(const Key('adoption-chat-attach')));
      await _pumpFrames(tester);
      expect(find.byKey(const Key('adoption-chat-pick-image')), findsOneWidget);
      expect(find.byKey(const Key('adoption-chat-pick-video')), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await _pumpFrames(tester);

      await tester.enterText(
        find.byKey(const Key('adoption-chat-composer')),
        'Xin chào',
      );
      await tester.tap(find.byKey(const Key('adoption-chat-send')));
      await _pumpFrames(tester);
      expect(find.text('Xin chào'), findsWidgets);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('chat remains scrollable without overflow at large text scale', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final source = _WidgetSource(
      chatPage: _chatPage(
        messages: [
          _chatMessage(
            'large-text-message',
            sender: 'shelter-1',
            body:
                'Mình đã xem hồ sơ của Mochi. Bạn cho trung tâm biết thêm thời gian phù hợp để gặp bé nhé.',
          ),
        ],
      ),
    );
    final store = _WidgetStore()
      ..context = const AdoptionChatContext(
        listingId: 'listing-1',
        petName: 'Mochi',
        shelterId: 'shelter-1',
      );

    await tester.pumpWidget(
      _scope(
        const ShelterChatScreen(threadId: 'thread-1'),
        source: source,
        store: store,
        textScale: 2,
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(const Key('adoption-chat-composer')), findsOneWidget);
    expectNoFlutterOverflow(tester);
    await tester.scrollUntilVisible(
      find.textContaining('Mình đã xem hồ sơ'),
      160,
      scrollable: find.descendant(
        of: find.byKey(const Key('adoption-chat-message-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.textContaining('Mình đã xem hồ sơ'), findsOneWidget);
    expectNoFlutterOverflow(tester);

    await tester.tap(find.byKey(const Key('adoption-chat-composer')));
    await setKeyboardInset(tester, bottom: 300);
    await tester.enterText(
      find.byKey(const Key('adoption-chat-composer')),
      'Tin nhắn ở cỡ chữ lớn vẫn nằm trên bàn phím.',
    );
    expect(find.byKey(const Key('adoption-chat-send')), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    'P2-12 keeps composer and send target above the keyboard at 360x800 and text scale 2',
    (tester) async {
      final source = _WidgetSource(
        chatPage: _chatPage(
          messages: [_chatMessage('message-1', sender: 'shelter-1')],
        ),
      );
      final store = _WidgetStore()
        ..context = const AdoptionChatContext(
          listingId: 'listing-1',
          petName: 'Mochi',
          shelterId: 'shelter-1',
        );
      await _pump(
        tester,
        const ShelterChatScreen(threadId: 'thread-1'),
        source: source,
        store: store,
        size: const Size(360, 800),
        textScale: 2,
      );

      expect(find.bySemanticsLabel('Hồ sơ thú cưng'), findsOneWidget);
      final title = find.text('Hồ sơ');
      expect(title, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
        isFalse,
        reason: 'Visible P2-12 title must not ellipsize at text scale 2.0',
      );

      final composer = find.byKey(const Key('adoption-chat-composer'));
      final send = find.byKey(const Key('adoption-chat-send'));
      await tester.tap(composer);
      await setKeyboardInset(tester, bottom: 300);
      await tester.enterText(composer, 'Tin nhắn vẫn thao tác được.');

      final keyboardTop = 800 - 300.0;
      for (final target in [composer, send]) {
        final rect = tester.getRect(target);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(keyboardTop));
      }
      expect(tester.getSize(send).height, greaterThanOrEqualTo(48));
      expect(
        find.byKey(const Key('adoption-chat-quick-reply-0')),
        findsNothing,
      );
      expectNoFlutterOverflow(tester);

      await setKeyboardInset(tester, bottom: 0);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('adoption-chat-quick-reply-0')),
        findsOneWidget,
      );
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('chat error and closed states remain recoverable', (
    tester,
  ) async {
    final source = _WidgetSource(
      readError: const AdoptionApiException('offline', code: 'NETWORK_OFFLINE'),
    );
    final store = _WidgetStore();
    await _pump(
      tester,
      const ShelterChatScreen(threadId: 'thread-1'),
      source: source,
      store: store,
      size: const Size(320, 568),
      textScale: 2,
    );
    expect(find.byKey(const Key('adoption-chat-error')), findsOneWidget);
    await tester.ensureVisible(find.text('Thử lại'));
    expectNoFlutterOverflow(tester);
    source.readError = null;
    await tester.tap(find.text('Thử lại'));
    await _pumpFrames(tester);
    expect(find.byKey(const Key('adoption-chat-composer')), findsOneWidget);

    source.chatPage = _chatPage(closed: true);
    final refreshFuture = tester
        .state<RefreshIndicatorState>(
          find.byKey(const Key('adoption-chat-refresh')),
        )
        .show();
    await _pumpFrames(tester);
    await refreshFuture;
    await tester.pump();
    expect(find.text('Đã kết thúc trao đổi'), findsOneWidget);
    expect(find.byKey(const Key('adoption-chat-composer')), findsOneWidget);
  });

  testWidgets('chat media fallbacks and read warning are actionable', (
    tester,
  ) async {
    final source = _WidgetSource(
      chatPage: _chatPage(
        messages: [
          _chatMessage(
            'message-media',
            sender: 'shelter-1',
            media: [
              _chatMedia('media-no-url'),
              _chatMedia(
                'media-video',
                mimeType: 'video/mp4',
                publicUrl: Uri.parse('https://cdn.example.test/chat.mp4'),
              ),
            ],
          ),
        ],
      ),
    )..markReadError = StateError('synthetic read failure');
    final store = _WidgetStore()
      ..chatDraft = const AdoptionChatDraft(
        body: 'Bản nháp',
        media: [
          AdoptionChatDraftMedia(
            localId: 'failed-video',
            path: 'Z:/definitely-missing/day55.mp4',
            mimeType: 'video/mp4',
            sizeBytes: 3,
            status: AdoptionChatUploadStatus.failed,
            errorMessage: 'offline',
          ),
        ],
      );
    await _pump(
      tester,
      const ShelterChatScreen(threadId: 'thread-1'),
      source: source,
      store: store,
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await _pumpFrames(tester);

    await tester.tap(find.byIcon(Icons.refresh).last);
    await _pumpFrames(tester);
    await tester.tap(find.byTooltip('Xóa tệp'));
    await _pumpFrames(tester);
    expect(find.byTooltip('Xóa tệp'), findsNothing);
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    'private chat image uses authenticated bytes and retries errors',
    (tester) async {
      final fixtureBytes = await tester.runAsync(
        () => File(
          'test/fixtures/images/golden_retriever_hero_v1.png',
        ).readAsBytes(),
      );
      final mediaSource = _WidgetMediaSource(fixtureBytes!)..failNext = true;
      final source = _WidgetSource(
        chatPage: _chatPage(
          messages: [
            _chatMessage(
              'message-private',
              sender: 'shelter-1',
              media: [
                _chatMedia(
                  'media-private',
                  downloadPath: '/adoption/chat/thread-1/media/media-private',
                  publicUrl: Uri.parse(
                    'https://cdn.example.test/legacy-chat.webp',
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      await _pump(
        tester,
        const ShelterChatScreen(threadId: 'thread-1'),
        source: source,
        store: _WidgetStore(),
        mediaSource: mediaSource,
      );

      expect(mediaSource.requests, ['thread-1/media-private']);
      expect(
        find.byKey(const Key('adoption-chat-media-retry-media-private')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('adoption-chat-media-retry-media-private')),
      );
      await _pumpFrames(tester);
      final image = tester.widget<Image>(
        find.byKey(const Key('adoption-chat-private-media-media-private')),
      );
      expect(image.image, isA<MemoryImage>());
      expect(mediaSource.requests, [
        'thread-1/media-private',
        'thread-1/media-private',
      ]);
      expect(mediaSource.tokens, ['access-token', 'access-token']);
    },
  );

  testWidgets('private chat image asks for login after an expired session', (
    tester,
  ) async {
    final mediaSource = _WidgetMediaSource(Uint8List(0))
      ..nextError = const AdoptionApiException(
        'Phiên đăng nhập đã hết hạn.',
        statusCode: 401,
      );
    await _pump(
      tester,
      const ShelterChatScreen(threadId: 'thread-1'),
      source: _WidgetSource(
        chatPage: _chatPage(
          messages: [
            _chatMessage(
              'message-private',
              sender: 'shelter-1',
              media: [
                _chatMedia(
                  'media-private',
                  downloadPath: '/adoption/chat/thread-1/media/media-private',
                ),
              ],
            ),
          ],
        ),
      ),
      store: _WidgetStore(),
      mediaSource: mediaSource,
    );

    expect(
      find.byKey(const Key('adoption-chat-media-login-media-private')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('adoption-chat-media-retry-media-private')),
      findsNothing,
    );
    expect(mediaSource.requests, ['thread-1/media-private']);
  });

  testWidgets('expired media session returns to the same chat after login', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final mediaSource = _WidgetMediaSource(Uint8List(0))
      ..nextError = const AdoptionApiException(
        'Phiên đăng nhập đã hết hạn.',
        statusCode: 401,
      );
    final source = _WidgetSource(
      chatPage: _chatPage(
        messages: [
          _chatMessage(
            'message-private',
            sender: 'shelter-1',
            media: [
              _chatMedia(
                'media-private',
                downloadPath: '/adoption/chat/thread-1/media/media-private',
              ),
            ],
          ),
        ],
      ),
    );
    final router = GoRouter(
      initialLocation: '/adoption/chat/thread-1',
      routes: [
        GoRoute(
          path: '/adoption/chat/:threadId',
          builder: (_, state) =>
              ShelterChatScreen(threadId: state.pathParameters['threadId']!),
        ),
        GoRoute(
          path: '/auth/login',
          builder: (_, state) => Scaffold(
            body: Text(state.uri.queryParameters['returnTo'] ?? 'missing'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adoptionSourceProvider.overrideWithValue(source),
          adoptionRequestChatSourceProvider.overrideWithValue(source),
          adoptionChatMediaSourceProvider.overrideWithValue(mediaSource),
          adoptionRequestChatDraftStoreProvider.overrideWithValue(
            _WidgetStore(),
          ),
          authSessionSnapshotProvider.overrideWithValue(
            const AsyncValue.data(_session),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await _pumpFrames(tester);

    await tester.tap(
      find.byKey(const Key('adoption-chat-media-login-media-private')),
    );
    await tester.pumpAndSettle();
    expect(find.text('/adoption/chat/thread-1'), findsOneWidget);
  });

  testWidgets('revoked chat media does not offer a repeated download', (
    tester,
  ) async {
    final mediaSource = _WidgetMediaSource(Uint8List(0))
      ..nextError = const AdoptionApiException(
        'Không có quyền xem ảnh.',
        statusCode: 403,
      );
    await _pump(
      tester,
      const ShelterChatScreen(threadId: 'thread-1'),
      source: _WidgetSource(
        chatPage: _chatPage(
          messages: [
            _chatMessage(
              'message-private',
              sender: 'shelter-1',
              media: [
                _chatMedia(
                  'media-private',
                  downloadPath: '/adoption/chat/thread-1/media/media-private',
                ),
              ],
            ),
          ],
        ),
      ),
      store: _WidgetStore(),
      mediaSource: mediaSource,
    );

    expect(
      find.byKey(const Key('adoption-chat-media-forbidden-media-private')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('adoption-chat-media-retry-media-private')),
      findsNothing,
    );
    expect(mediaSource.requests, ['thread-1/media-private']);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  required _WidgetSource source,
  required _WidgetStore store,
  _WidgetMediaSource? mediaSource,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  await setTestViewport(tester, size: size);
  await tester.pumpWidget(
    _scope(
      home,
      source: source,
      store: store,
      textScale: textScale,
      mediaSource: mediaSource,
    ),
  );
  await _pumpFrames(tester);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 8; frame += 1) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Widget _scope(
  Widget home, {
  required _WidgetSource source,
  required _WidgetStore store,
  _WidgetMediaSource? mediaSource,
  double textScale = 1,
}) {
  return ProviderScope(
    overrides: [
      adoptionSourceProvider.overrideWithValue(source),
      adoptionRequestChatSourceProvider.overrideWithValue(source),
      if (mediaSource != null)
        adoptionChatMediaSourceProvider.overrideWithValue(mediaSource),
      adoptionRequestChatDraftStoreProvider.overrideWithValue(store),
      authSessionSnapshotProvider.overrideWithValue(
        const AsyncValue.data(_session),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      builder: testTextScaleBuilder(textScale),
      home: home,
    ),
  );
}

const _session = AuthSession(
  user: AuthUser(
    id: 'adopter-1',
    email: 'widget@example.test',
    authProvider: 'email',
    emailVerified: true,
  ),
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  accessTokenExpiresAt: '2030-01-01T00:00:00.000Z',
  refreshTokenExpiresAt: '2030-01-02T00:00:00.000Z',
);

AdoptionChatPage _chatPage({
  List<AdoptionChatMessage> messages = const [],
  bool hasMore = false,
  String? nextCursor,
  bool closed = false,
  int unreadCount = 0,
}) {
  return AdoptionChatPage(
    messages: messages,
    thread: AdoptionChatThread(
      threadId: 'thread-1',
      requestId: 'request-1',
      participantRole: AdoptionChatParticipantRole.adopter,
      lastReadAt: DateTime.utc(2026, 7, 28, 4),
      unreadCount: unreadCount,
      closedAt: closed ? DateTime.utc(2026, 7, 28, 5) : null,
    ),
    hasMore: hasMore,
    nextCursor: nextCursor,
    limit: 50,
  );
}

AdoptionChatMessage _chatMessage(
  String id, {
  required String sender,
  String body = 'Mình đã nhận được thông tin.',
  List<AdoptionChatMedia> media = const [],
}) {
  return AdoptionChatMessage(
    messageId: id,
    threadId: 'thread-1',
    senderUserId: sender,
    body: body,
    media: media,
    createdAt: DateTime.utc(2026, 7, 28, 5),
  );
}

AdoptionChatMedia _chatMedia(
  String id, {
  String mimeType = 'image/webp',
  Uri? publicUrl,
  String? downloadPath,
}) {
  return AdoptionChatMedia(
    mediaId: id,
    ownerUserId: 'shelter-1',
    mimeType: mimeType,
    sizeBytes: 100,
    sha256: 'test-only',
    status: 'attached',
    createdAt: DateTime.utc(2026, 7, 28, 5),
    publicUrl: publicUrl,
    downloadPath: downloadPath,
  );
}

class _WidgetMediaSource implements AdoptionChatMediaSource {
  _WidgetMediaSource(this.bytes);

  final Uint8List bytes;
  final List<String> requests = [];
  final List<String> tokens = [];
  bool failNext = false;
  Object? nextError;

  @override
  Future<Uint8List> downloadChatMedia({
    required String accessToken,
    required String threadId,
    required AdoptionChatMedia media,
  }) async {
    requests.add('$threadId/${media.mediaId}');
    tokens.add(accessToken);
    final error = nextError;
    if (error != null) throw error;
    if (failNext) {
      failNext = false;
      throw const AdoptionApiException(
        'Không thể tải ảnh.',
        code: 'NETWORK_OFFLINE',
      );
    }
    return bytes;
  }
}

class _WidgetSource implements AdoptionSource, AdoptionRequestChatSource {
  _WidgetSource({
    AdoptionListingDetail? detail,
    this.detailError,
    this.chatPage,
    this.readError,
  }) : detail = detail ?? uiAdoptionDetail();

  AdoptionListingDetail detail;
  Object? detailError;
  AdoptionChatPage? chatPage;
  Object? readError;
  Object? markReadError;
  int failRequests = 0;
  int failMessages = 0;
  final requestKeys = <String>[];
  final messageKeys = <String>[];
  final List<String?> readCursors = <String?>[];

  @override
  Future<AdoptionListingPage> listListings(
    AdoptionListQuery query, {
    required String accessToken,
  }) async => uiAdoptionPage();

  @override
  Future<AdoptionListingDetail> getListing(
    String listingId, {
    required String accessToken,
  }) async {
    if (detailError != null) throw detailError!;
    return detail;
  }

  @override
  Future<AdoptionDecisionResult> recordDecision(
    String listingId,
    AdoptionDecision decision, {
    required String accessToken,
    required String idempotencyKey,
  }) async => adoptionDecisionResult(listingId: listingId, decision: decision);

  @override
  Future<AdoptionRequestResult> createRequest({
    required String accessToken,
    required String listingId,
    required AdoptionRequestDraft draft,
    required String idempotencyKey,
  }) async {
    requestKeys.add(idempotencyKey);
    if (failRequests > 0) {
      failRequests--;
      throw const AdoptionApiException(
        'Chưa gửi được yêu cầu.',
        statusCode: 503,
      );
    }
    return AdoptionRequestResult(
      requestId: 'request-1',
      listingId: listingId,
      adopterUserId: 'adopter-1',
      shelterId: 'shelter-1',
      livingCondition: draft.livingCondition,
      petExperience: draft.petExperience,
      carePlan: draft.carePlan,
      commitmentAccepted: true,
      status: AdoptionRequestStatus.submitted,
      threadId: 'thread-1',
      createdAt: DateTime.utc(2026, 7, 28, 5),
    );
  }

  @override
  Future<AdoptionChatPage> readChat({
    required String accessToken,
    required String threadId,
    String? cursor,
    int limit = 50,
  }) async {
    if (readError != null) throw readError!;
    readCursors.add(cursor);
    return chatPage ?? _chatPage();
  }

  @override
  Future<AdoptionChatMessage> sendMessage({
    required String accessToken,
    required String threadId,
    required String body,
    required List<String> mediaIds,
    required String idempotencyKey,
  }) async {
    messageKeys.add(idempotencyKey);
    if (failMessages > 0) {
      failMessages--;
      throw const AdoptionApiException(
        'Chưa gửi được tin nhắn.',
        statusCode: 503,
      );
    }
    return _chatMessage('sent-message', sender: 'adopter-1', body: body);
  }

  @override
  Future<AdoptionChatReadState> markRead({
    required String accessToken,
    required String threadId,
    required String throughMessageId,
  }) async {
    if (markReadError != null) throw markReadError!;
    return AdoptionChatReadState(
      threadId: threadId,
      lastReadAt: DateTime.utc(2026, 7, 28, 6),
      unreadCount: 0,
    );
  }

  @override
  Future<AdoptionChatDraftMedia> uploadChatMedia({
    required String accessToken,
    required String threadId,
    required AdoptionChatDraftMedia media,
    required ValueChanged<double> onProgress,
  }) async => media.copyWith(
    status: AdoptionChatUploadStatus.uploaded,
    mediaId: 'media-1',
    progress: 1,
  );
}

class _WidgetStore implements AdoptionRequestChatDraftStore {
  AdoptionChatContext? context;
  AdoptionChatDraft chatDraft = const AdoptionChatDraft();
  AdoptionRequestDraft requestDraft = const AdoptionRequestDraft();

  @override
  Future<AdoptionRequestDraft> readRequestDraft({
    required String userId,
    required String listingId,
  }) async => requestDraft;

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
  Future<AdoptionChatDraft> readChatDraft({
    required String userId,
    required String threadId,
  }) async => chatDraft;

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
  Future<AdoptionChatContext?> readChatContext({
    required String userId,
    required String threadId,
  }) async => context;

  @override
  Future<void> saveChatContext({
    required String userId,
    required String threadId,
    required AdoptionChatContext context,
  }) async {
    this.context = context;
  }
}
