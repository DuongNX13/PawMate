// Stage and fixture probes for the QA-only real-device runner. No touch,
// semantics actions, keyboard injection or navigation is performed here.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/features/notifications/application/notification_providers.dart';

import '../test/test_support/day119_detail_support.dart' as detail;
import 'day122_closure_journeys.dart';
import 'day122_closure_stages.dart';

// Set when the reminder sheet is observed open; cleared once reminder-saved passes.
bool _reminderSheetSeen = false;

Finder _key(String key) => find.byKey(ValueKey<String>(key));
void _shown(String value) => expect(_key(value), findsOneWidget);
void _hidden(String value) => expect(_key(value), findsNothing);
void _text(String value) => expect(find.text(value), findsOneWidget);

String readTalkBackField(WidgetTester t, String id) {
  final edit = find.descendant(
    of: _key(id),
    matching: find.byType(EditableText),
    matchRoot: true,
  );
  expect(edit, findsOneWidget, reason: 'Exact QA input identity is required');
  return t.widget<EditableText>(edit).controller.text;
}

Map<String, Object?> observeTalkBackStage(
  WidgetTester tester,
  ClosureJourneySession session,
  String stage,
) {
  final journey = session.journey;
  // Must run before inspectClosureStage, which throws while the sheet covers the route.
  if (journey == 'TB-HEALTH' &&
      _key('reminder-create-sheet-viewport').evaluate().isNotEmpty) {
    _reminderSheetSeen = true;
  }
  final metadata = inspectClosureStage(
    tester,
    journey,
    stage,
    closureViewMetrics(tester.view),
  );
  switch (journey) {
    case 'TB-AUTH':
      final src = session.harness as ClosureAuthSource;
      if (stage.startsWith('onboarding-')) {
        expect(readTalkBackField(tester, 'onboarding-pet-name-field'), isEmpty);
        expect(
          find.text('Vui lòng nhập tên thú cưng'),
          stage == 'onboarding-validation' ? findsOneWidget : findsNothing,
        );
      } else {
        final submit = tester.widget<PawMateButton>(
          _key('register-submit-button'),
        );
        expect(submit.onPressed != null, stage != 'register-empty-disabled');
        if (stage != 'register-empty-disabled') {
          expect(
            readTalkBackField(tester, 'register-email-field'),
            'fixture@example.test',
          );
          final password = readTalkBackField(tester, 'register-password-field');
          expect(password, isNotEmpty);
          expect(
            password,
            readTalkBackField(tester, 'register-confirm-password-field'),
          );
          expect(
            readTalkBackField(tester, 'register-phone-field'),
            '0900000000',
          );
        }
      }
      expect(src.registerCalls, stage == 'register-error-retains-form' ? 1 : 0);
      if (stage == 'register-error-retains-form') {
        expect(src.lastEmail, 'fixture@example.test');
        _text(ClosureAuthSource.rejection);
      }
    case 'TB-VET':
      final h = session.harness as ClosureVetHarness;
      if (stage == 'vet-location-denied') {
        _shown('permission-denied');
        expect(h.location.requests, 1);
        expect(h.source.nearbyQueries, isEmpty);
      } else if (stage == 'vet-location-fixture-granted') {
        // The observer polls between "Xem trên bản đồ" and "Lấy lại vị trí hiện tại",
        // before the granted query exists; that is "not met yet", not a harness fault.
        expect(
          h.source.nearbyQueries,
          isNotEmpty,
          reason: 'Granted-location query has not happened yet',
        );
        final query = h.source.nearbyQueries.last;
        expect(query.latitude, 10.7769);
        expect(query.longitude, 106.7009);
      } else if (stage == 'vet-detail') {
        expect(h.source.details, ['qa-clinic']);
      } else if (stage == 'vet-review-sheet-empty') {
        _shown('review-list-empty');
        expect(h.source.reviews, isNotEmpty);
        expect(h.source.reviews.every((value) => value == 'qa-clinic'), isTrue);
      } else if (stage == 'vet-review-closed') {
        _hidden('review-list-scroll');
      } else {
        _shown('vet-list-card-qa-clinic');
      }
    case 'TB-HEALTH':
      final src = session.harness as ClosureReminderSource;
      final sheet =
          stage == 'reminder-editor-empty' ||
          stage == 'reminder-api-validation';
      if (sheet) {
        expect(
          readTalkBackField(tester, 'reminder-create-title-field'),
          isEmpty,
        );
      }
      if (stage == 'reminder-api-validation') {
        _text('QA: Vui lòng nhập tiêu đề lịch nhắc.');
      }
      // reminder-cancel-no-write ends in the same state reminder-saved leaves
      // behind, so without this it would pass before any gesture happened.
      if (stage == 'reminder-cancel-no-write') {
        expect(
          _reminderSheetSeen,
          isTrue,
          reason: 'Sheet must be opened and closed during this stage',
        );
      }
      final saved =
          stage == 'reminder-saved' || stage == 'reminder-cancel-no-write';
      expect(
        src.createAttempts,
        saved
            ? 2
            : stage == 'reminder-api-validation'
            ? 1
            : 0,
      );
      if (saved) {
        expect(src.saved.single.petId, 'mochi');
        expect(src.saved.single.title, 'QA Reminder Mochi');
        _hidden('reminder-create-sheet-viewport');
        if (stage == 'reminder-saved') _reminderSheetSeen = false;
      } else {
        expect(src.saved, isEmpty);
      }
    case 'TB-NOTIFICATIONS':
      final src = (session.harness as ClosureNotificationHarness).source;
      if (stage == 'notifications-error') {
        _text('Chưa tải được thông báo');
        expect(src.lists, 1);
      } else if (stage == 'retry-empty') {
        _shown('notification-empty-profile-button');
        expect(src.lists, 2);
      } else if (stage == 'notifications-list') {
        _text(src.item.title);
      } else if (stage == 'notification-opens-calendar') {
        expect(src.readIds, ['qa-health']);
      } else if (stage == 'notification-settings') {
        _text('Cài đặt thông báo');
      } else {
        _shown('notification-settings-button');
      }
    case 'TB-RESCUE':
      final h = session.harness as detail.Day119Harness;
      final selected =
          stage == 'case-selected' || stage == 'back-retains-selection';
      final opened =
          stage == 'case-detail' ||
          stage == 'back-retains-selection' ||
          stage == 'selection-cleared';
      expect(
        h.source.detailCaseIds,
        opened ? [detail.day119FirstCaseId] : isEmpty,
      );
      if (stage != 'case-detail') {
        expect(
          _key('rescue-selected-case-card'),
          selected ? findsOneWidget : findsNothing,
        );
        final marker = _key('rescue-marker-${detail.day119FirstCaseId}');
        expect(
          tester.getSemantics(marker).flagsCollection.isSelected,
          selected ? Tristate.isTrue : Tristate.isFalse,
        );
        expect(
          find.text('Thu gọn'),
          stage == 'home-expanded' ? findsOneWidget : findsNothing,
        );
      } else {
        _shown('rescue-case-detail-screen');
      }
    case 'TB-ADOPTION-CHAT':
      final src = session.harness as ClosureChatSource;
      if (stage == 'shelter-chat') _text('QA: Chào bạn và Mochi.');
      if (stage == 'chat-quick-reply-draft') {
        expect(
          readTalkBackField(tester, 'adoption-chat-composer'),
          'Đặt lịch hẹn',
        );
      }
      final two =
          stage == 'chat-composed-message-sent' ||
          stage == 'chat-back-to-adoption';
      final one = stage == 'chat-quick-reply-sent';
      expect(
        src.sent,
        two
            ? ['Đặt lịch hẹn', 'QA Mochi']
            : one
            ? ['Đặt lịch hẹn']
            : isEmpty,
      );
      if (one || stage == 'chat-composed-message-sent') {
        final message = find.descendant(
          of: _key('adoption-chat-message-list'),
          matching: find.text(one ? 'Đặt lịch hẹn' : 'QA Mochi'),
        );
        expect(message.hitTestable(), findsOneWidget);
        expect(readTalkBackField(tester, 'adoption-chat-composer'), isEmpty);
      }
    default:
      throw StateError('Unimplemented native journey $journey');
  }
  return {
    ...metadata,
    'screen': closureStageTargets(journey)[stage]!.screenName,
    'stage': stage,
    'input_method': 'NONE_OBSERVER_ONLY',
    'assertions_met': true,
  };
}

// These commands adjust only synthetic provider responses. Vet's separate
// granted-location fixture is remounted as a fresh fixture by the host;
// a route push cannot stand in for TalkBack activation.
void transitionTalkBackFixture(ClosureJourneySession session, String name) {
  switch ((session.journey, name)) {
    case ('TB-NOTIFICATIONS', 'notification-empty-response'):
      (session.harness as ClosureNotificationHarness).source.mode = 'empty';
    case ('TB-NOTIFICATIONS', 'notification-data-response'):
      final h = session.harness as ClosureNotificationHarness;
      h.source.mode = 'data';
      h.container.invalidate(notificationListProvider);
    case ('TB-VET', 'vet-granted-response'):
      (session.harness as ClosureVetHarness).location.denied = false;
    default:
      throw StateError('Unapproved fixture transition');
  }
}
