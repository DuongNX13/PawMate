import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_chat_provider.dart';

import '../../integration_test/day122_closure_journeys.dart';
import '../test_support/ui_test_helpers.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  for (final size in [const Size(360, 800), const Size(430, 932)]) {
    testWidgets('TB-ADOPTION-CHAT unregistered keyboard Back regression $size', (
      tester,
    ) async {
      final source = await pumpClosureAdoptionChatJourney(tester, size);
      final stages = <String>[];
      final platformCalls = <String>[];
      try {
        await rehearseClosureAdoptionChatJourney(
          tester,
          source,
          capture: (stage) async {
            stages.add(stage);
            if (stage == 'chat-composed-message-sent') {
              // IntegrationTest uses the real text-input channel. Reproduce
              // its unregistered stub at the exact R21 failure boundary.
              tester.testTextInput.unregister();
              tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
                SystemChannels.textInput,
                (call) async {
                  platformCalls.add(call.method);
                  return null;
                },
              );
              expect(tester.testTextInput.isRegistered, isFalse);
            }
            expectNoFlutterOverflow(tester);
          },
        );
        expect(stages, hasLength(7));
        expect(stages.last, 'chat-back-to-adoption');
        expect(platformCalls, contains('TextInput.hide'));
        expect(source.sent, ['Đặt lịch hẹn', 'QA: Tôi muốn tìm hiểu về Mochi.']);
      } finally {
        tester.testTextInput.register();
      }
    });
    testWidgets('TB-ADOPTION-CHAT requested keyboard scroll regression $size', (
      tester,
    ) async {
      final source = await pumpClosureAdoptionChatJourney(tester, size);
      final stages = <String>[];
      ProviderContainer? chatContainer;
      try {
        await rehearseClosureAdoptionChatJourney(
          tester,
          source,
          capture: (stage) async {
            stages.add(stage);
            if (stage == 'chat-quick-reply-draft') {
              chatContainer = ProviderScope.containerOf(
                tester.element(find.byKey(const Key('adoption-chat-composer'))),
              );
              await setKeyboardInset(tester, bottom: 303);
              await tester.pumpAndSettle();
              expect(tester.view.viewInsets.bottom, 303);
              // Scaffold consumes the inset below its body. Inspect above
              // that boundary, where ShelterChatScreen reads IME state.
              expect(MediaQuery.viewInsetsOf(tester.element(
                find.byKey(const Key('adoption-chat-screen')),
              )).bottom, 303);
            }
            if (stage == 'chat-quick-reply-sent' ||
                stage == 'chat-composed-message-sent') {
              final body = stage == 'chat-quick-reply-sent'
                  ? 'Đặt lịch hẹn'
                  : 'QA: Tôi muốn tìm hiểu về Mochi.';
              expect(find.text(body).hitTestable(), findsOneWidget);
              expect(chatContainer!.read(adoptionChatProvider('qa-thread'))
                  .messages.any((m) => m.body == body), isTrue);
            }
            expectNoFlutterOverflow(tester);
          },
        );
        expect(stages, hasLength(7));
        expect(source.sent, ['Đặt lịch hẹn', 'QA: Tôi muốn tìm hiểu về Mochi.']);
      } finally {
        if (chatContainer != null) {
          final state = chatContainer!.read(adoptionChatProvider('qa-thread'));
          debugPrint('D122_CHAT_REPRO sent=${source.sent}; '
              'messages=${state.messages.map((m) => '${m.messageId}:${m.body}').toList()}; '
              'draft=${state.draft.body}; stages=$stages');
        }
      }
    });
    testWidgets('TB-ADOPTION-CHAT local route/action rehearsal $size', (
      tester,
    ) async {
      final source = await pumpClosureAdoptionChatJourney(tester, size);
      final stages = <String>[];
      await rehearseClosureAdoptionChatJourney(
        tester,
        source,
        capture: (stage) async {
          expect(stages, isNot(contains(stage)));
          expectNoFlutterOverflow(tester);
          stages.add(stage);
        },
      );
      expect(stages, [
        'adoption-profile',
        'my-adoption-requests',
        'shelter-chat',
        'chat-quick-reply-draft',
        'chat-quick-reply-sent',
        'chat-composed-message-sent',
        'chat-back-to-adoption',
      ]);
    });
    testWidgets('TB-VET local route/action rehearsal $size', (tester) async {
      final harness = await pumpClosureVetJourney(tester, size);
      final stages = <String>[];
      await rehearseClosureVetJourney(
        tester,
        harness,
        capture: (stage) async {
          expect(stages, isNot(contains(stage)));
          expectNoFlutterOverflow(tester);
          stages.add(stage);
        },
      );
      expect(stages, [
        'vet-location-denied',
        'vet-manual-list-fallback',
        'vet-detail',
        'vet-review-sheet-empty',
        'vet-review-closed',
        'vet-back-to-list',
        'vet-location-fixture-granted',
      ]);
    });
    testWidgets('TB-NOTIFICATIONS local route/action rehearsal $size', (
      tester,
    ) async {
      final harness = await pumpClosureNotificationJourney(tester, size);
      final stages = <String>[];
      await rehearseClosureNotificationJourney(
        tester,
        harness,
        capture: (stage) async {
          expect(stages, isNot(contains(stage)));
          expectNoFlutterOverflow(tester);
          stages.add(stage);
        },
      );
      expect(stages, [
        'notifications-error',
        'retry-empty',
        'notification-settings',
        'settings-back',
        'notifications-list',
        'notification-opens-calendar',
      ]);
    });
    testWidgets('TB-HEALTH local route/action rehearsal $size', (tester) async {
      final source = await pumpClosureHealthJourney(tester, size);
      final stages = <String>[];
      await rehearseClosureHealthJourney(
        tester,
        source,
        capture: (stage) async {
          expect(stages, isNot(contains(stage)));
          expectNoFlutterOverflow(tester);
          stages.add(stage);
        },
      );
      expect(stages, [
        'health-timeline',
        'reminder-calendar',
        'reminder-editor-empty',
        'reminder-api-validation',
        'reminder-saved',
        'reminder-cancel-no-write',
      ]);
    });
    testWidgets('TB-AUTH local route/action rehearsal $size', (tester) async {
      final source = await pumpClosureAuthJourney(tester, size);
      final stages = <String>[];
      await rehearseClosureAuthJourney(
        tester,
        source,
        capture: (stage) async {
          expect(stages, isNot(contains(stage)));
          expectNoFlutterOverflow(tester);
          stages.add(stage);
        },
      );
      expect(stages, [
        'onboarding-empty',
        'onboarding-validation',
        'register-empty-disabled',
        'register-valid-enabled',
        'register-error-retains-form',
      ]);
    });
    testWidgets('TB-HOME-PET local route/action rehearsal $size', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final harness = await pumpClosureHomePetJourney(tester, size);
        final stages = <String>[];
        await rehearseClosureHomePetJourney(
          tester,
          harness,
          pickWrongPetForCounterfactual: const bool.fromEnvironment(
            'D122_MUTATE_JOURNEY_PET',
          ),
          capture: (stage) async {
            expect(stages, isNot(contains(stage)));
            expectNoFlutterOverflow(tester);
            stages.add(stage);
          },
        );
        expect(stages, [
          'home-first-pet-selected',
          'second-pet-detail',
          'home-retains-second-pet',
        ]);
      } finally {
        semantics.dispose();
      }
    });
    testWidgets('TB-RESCUE local route/action rehearsal $size', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final harness = await pumpClosureRescueJourney(tester, size);
        final stages = <String>[];
        await rehearseClosureRescueJourney(
          tester,
          harness,
          omitMarkerForCounterfactual: const bool.fromEnvironment(
            'D122_MUTATE_JOURNEY_SELECTION',
          ),
          capture: (stage) async {
            expect(
              stages,
              isNot(contains(stage)),
              reason: 'No duplicated stage',
            );
            expectNoFlutterOverflow(tester);
            stages.add(stage);
          },
        );
        expect(stages, [
          'home-collapsed',
          'home-expanded',
          'home-recollapsed',
          'case-selected',
          'case-detail',
          'back-retains-selection',
          'selection-cleared',
        ]);
      } finally {
        // The binding checks handles before package:test addTearDown runs.
        semantics.dispose();
      }
    });
  }
}
