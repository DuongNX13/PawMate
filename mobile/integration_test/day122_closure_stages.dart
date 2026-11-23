// QA-only mounted-screen and metric contract. No native input acceptance.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_profile_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_swipe_deck_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/my_adoption_requests_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/shelter_chat_screen.dart';
import 'package:pawmate_mobile/features/auth/presentation/register_screen.dart';
import 'package:pawmate_mobile/features/health/presentation/health_timeline_screen.dart';
import 'package:pawmate_mobile/features/notifications/presentation/notification_center_screen.dart';
import 'package:pawmate_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_detail_screen.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';
import 'package:pawmate_mobile/features/profile/presentation/notification_preferences_screen.dart';
import 'package:pawmate_mobile/features/reminders/presentation/reminder_calendar_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_detail_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_list_screen.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_screen.dart';

import '../test/test_support/day119_detail_support.dart' as detail;
import 'day122_closure_journeys.dart';

const closureJourneyIds = [
  'TB-AUTH',
  'TB-HOME-PET',
  'TB-VET',
  'TB-HEALTH',
  'TB-NOTIFICATIONS',
  'TB-RESCUE',
  'TB-ADOPTION-CHAT',
];
const closureRehearsalScope =
    'NATIVE_RENDER_WIDGET_ACTION_REHEARSAL_NOT_TALKBACK';

/// Runtime selection only for this QA APK; production routes/flags are untouched.
class ClosureLaunchConfig {
  ClosureLaunchConfig.fromJson(Map<String, dynamic> value)
    : run = value['run'] as String,
      journey = value['journey'] as String,
      width = value['width'] as int,
      height = value['height'] as int,
      font = value['font_scale'] as num {
    const viewports = {360: 800, 390: 844, 430: 932};
    if (!RegExp(r'^closure-[a-z0-9-]+$').hasMatch(run) ||
        !closureJourneyIds.contains(journey) ||
        viewports[width] != height ||
        ![1, 2].contains(font)) {
      throw StateError('Explicit allowed QA journey/viewport/font required');
    }
  }
  final String run;
  final String journey;
  final int width;
  final int height;
  final num font;
}

class ClosureStageTarget {
  const ClosureStageTarget(this.owner, this.route, {this.key});
  final Type owner;
  final String route;
  // Private modal implementations are identified by their existing viewport key.
  final String? key;
  bool get overlay => key != null;
  Finder get screen {
    if (key == null) return find.byType(owner);
    // Test-only counterfactual restores the nullable-generic locator defect.
    if (const bool.fromEnvironment('D122_MUTATE_OVERLAY_KEY')) {
      return find.byKey(ValueKey<String?>(key));
    }
    return find.byKey(ValueKey<String>(key!));
  }

  Finder get routeOwner => find.byType(owner, skipOffstage: false);
  String get screenName => key ?? owner.toString();
}

Map<String, ClosureStageTarget> closureStageTargets(String journey) {
  const onboarding = ClosureStageTarget(OnboardingScreen, '/onboarding');
  const register = ClosureStageTarget(RegisterScreen, '/auth/register');
  const home = ClosureStageTarget(PetHomeScreen, '/pets');
  const vetMap = ClosureStageTarget(VetMapScreen, '/vets/map');
  const vetList = ClosureStageTarget(VetListScreen, '/vets/list');
  const vetDetail = ClosureStageTarget(VetDetailScreen, '/vets/qa-clinic');
  const calendar = ClosureStageTarget(
    ReminderCalendarScreen,
    '/health/reminders',
  );
  const editor = ClosureStageTarget(
    ReminderCalendarScreen,
    '/health/reminders',
    key: 'reminder-create-sheet-viewport',
  );
  const notifications = ClosureStageTarget(
    NotificationCenterScreen,
    '/notifications',
  );
  const rescue = ClosureStageTarget(RescueHomeScreen, '/rescue');
  const chat = ClosureStageTarget(
    ShelterChatScreen,
    '/adoption/chat/qa-thread',
  );
  return switch (journey) {
    'TB-AUTH' => {
      'onboarding-empty': onboarding,
      'onboarding-validation': onboarding,
      'register-empty-disabled': register,
      'register-valid-enabled': register,
      'register-error-retains-form': register,
    },
    'TB-HOME-PET' => {
      'home-first-pet-selected': home,
      'second-pet-detail': const ClosureStageTarget(
        PetDetailScreen,
        '/pets/bap',
      ),
      'home-retains-second-pet': home,
    },
    'TB-VET' => {
      'vet-location-denied': vetMap,
      'vet-manual-list-fallback': vetList,
      'vet-detail': vetDetail,
      'vet-review-sheet-empty': const ClosureStageTarget(
        VetDetailScreen,
        '/vets/qa-clinic',
        key: 'review-list-scroll',
      ),
      'vet-review-closed': vetDetail,
      'vet-back-to-list': vetList,
      'vet-location-fixture-granted': vetMap,
    },
    'TB-HEALTH' => {
      'health-timeline': const ClosureStageTarget(
        HealthTimelineScreen,
        '/health',
      ),
      'reminder-calendar': calendar,
      'reminder-editor-empty': editor,
      'reminder-api-validation': editor,
      'reminder-saved': calendar,
      'reminder-cancel-no-write': calendar,
    },
    'TB-NOTIFICATIONS' => {
      'notifications-error': notifications,
      'retry-empty': notifications,
      'notification-settings': const ClosureStageTarget(
        NotificationPreferencesScreen,
        '/profile/notifications',
      ),
      'settings-back': notifications,
      'notifications-list': notifications,
      'notification-opens-calendar': calendar,
    },
    'TB-RESCUE' => {
      'home-collapsed': rescue,
      'home-expanded': rescue,
      'home-recollapsed': rescue,
      'case-selected': rescue,
      'case-detail': ClosureStageTarget(
        RescueCaseDetailScreen,
        '/rescue/${detail.day119FirstCaseId}',
      ),
      'back-retains-selection': rescue,
      'selection-cleared': rescue,
    },
    'TB-ADOPTION-CHAT' => {
      'adoption-profile': const ClosureStageTarget(
        AdoptionProfileScreen,
        '/adoption/qa-listing',
      ),
      'my-adoption-requests': const ClosureStageTarget(
        MyAdoptionRequestsScreen,
        '/adoption/requests',
      ),
      'shelter-chat': chat,
      'chat-quick-reply-draft': chat,
      'chat-quick-reply-sent': chat,
      'chat-composed-message-sent': chat,
      'chat-back-to-adoption': const ClosureStageTarget(
        AdoptionSwipeDeckScreen,
        '/adoption',
      ),
    },
    _ => throw StateError('Unknown journey $journey'),
  };
}

Map<String, Object> closureViewMetrics(ui.FlutterView view) => {
  'physical': [view.physicalSize.width, view.physicalSize.height],
  'dpr': view.devicePixelRatio,
  'padding': [
    view.padding.left,
    view.padding.top,
    view.padding.right,
    view.padding.bottom,
  ],
  'view_padding': [
    view.viewPadding.left,
    view.viewPadding.top,
    view.viewPadding.right,
    view.viewPadding.bottom,
  ],
  'view_insets': [
    view.viewInsets.left,
    view.viewInsets.top,
    view.viewInsets.right,
    view.viewInsets.bottom,
  ],
};

/// Check actual mounted route/foreground and all view metrics before any capture.
/// The caller must label a local expectedMetrics fixture as local, not native.
Map<String, Object?> inspectClosureStage(
  WidgetTester tester,
  String journey,
  String stage,
  Map<String, Object> expectedMetrics,
) {
  final target = closureStageTargets(journey)[stage];
  if (target == null) throw StateError('Unknown $journey stage $stage');
  expect(
    target.screen,
    findsOneWidget,
    reason: 'Actual stage foreground required',
  );
  expect(
    target.routeOwner,
    findsOneWidget,
    reason: 'Unique mounted route owner',
  );
  final route = GoRouterState.of(tester.element(target.routeOwner)).uri.path;
  expect(
    route,
    target.route,
    reason: 'Capture must match mounted route, not root URI',
  );
  final modal = ModalRoute.of(tester.element(target.screen));
  expect(
    modal?.isCurrent,
    isTrue,
    reason: 'Capture must not target a covered route',
  );
  final actual = closureViewMetrics(tester.view);
  expect(
    actual,
    expectedMetrics,
    reason: 'Native metric overrides must be restored',
  );
  final context = tester.element(target.screen);
  final media = MediaQuery.of(context);
  final ownerMedia = MediaQuery.of(tester.element(target.routeOwner));
  final expectedMedia = MediaQueryData.fromView(tester.view);
  expect(
    ownerMedia.padding,
    expectedMedia.padding,
    reason: 'Route padding must be laid out before capture',
  );
  expect(
    ownerMedia.viewPadding,
    expectedMedia.viewPadding,
    reason: 'Route viewPadding must match restored native view',
  );
  final physical = actual['physical']! as List<double>;
  final dpr = actual['dpr']! as double;
  expect(media.size, Size(physical[0] / dpr, physical[1] / dpr));
  expect(media.viewInsets.bottom, tester.view.viewInsets.bottom / dpr);
  return {
    'proof_scope': closureRehearsalScope,
    'input_method': 'flutter_widget_test_api',
    'talkback_acceptance': false,
    'journey': journey,
    'mounted_route': route,
    'foreground_route_current': true,
    'stage_overlay': target.overlay,
    'view_metrics': actual,
    'route_media': {
      'padding': _edgeValues(ownerMedia.padding),
      'view_padding': _edgeValues(ownerMedia.viewPadding),
      'view_insets': _edgeValues(ownerMedia.viewInsets),
      'target_padding': _edgeValues(media.padding),
      'target_bounds': _rectValues(tester.getRect(target.screen)),
    },
    'control_geometry': [
      for (final type in [AppBar, BackButton, CloseButton])
        for (final element
            in find
                .descendant(of: target.screen, matching: find.byType(type))
                .evaluate())
          {
            'kind': type.toString(),
            'bounds': _rectValues(
              tester.getRect(
                find.byElementPredicate(
                  (candidate) => identical(candidate, element),
                ),
              ),
            ),
          },
    ],
  };
}

List<double> _edgeValues(EdgeInsets value) => [
  value.left,
  value.top,
  value.right,
  value.bottom,
];
List<double> _rectValues(Rect value) => [
  value.left,
  value.top,
  value.right,
  value.bottom,
];

/// Engine timing fence, not a pixel/visual oracle. Local fixtures are not native.
Map<String, Object> closureRasterTiming(
  Iterable<ui.FrameTiming> timings,
  int requestedFrame,
) {
  if (requestedFrame < 0) throw StateError('Native frame identity required');
  final matches = timings
      .where((timing) => timing.frameNumber == requestedFrame)
      .toList();
  if (matches.length != 1) {
    throw StateError('Exactly one raster timing for requested frame required');
  }
  final timing = matches.single;
  final vsync = timing.timestampInMicroseconds(ui.FramePhase.vsyncStart);
  final buildStart = timing.timestampInMicroseconds(ui.FramePhase.buildStart);
  final buildFinish = timing.timestampInMicroseconds(ui.FramePhase.buildFinish);
  final rasterStart = timing.timestampInMicroseconds(ui.FramePhase.rasterStart);
  final rasterFinish = timing.timestampInMicroseconds(
    ui.FramePhase.rasterFinish,
  );
  if (vsync < 0 ||
      buildStart < vsync ||
      buildFinish < buildStart ||
      rasterStart < buildFinish ||
      rasterFinish < rasterStart) {
    throw StateError('Invalid engine frame timing');
  }
  return {
    'source': 'ENGINE_FRAME_TIMING',
    'identity_method': 'ENGINE_FRAME_NUMBER',
    'requested_frame_number': requestedFrame,
    'vsync_us': vsync,
    'build_start_us': buildStart,
    'build_finish_us': buildFinish,
    'frame_number': timing.frameNumber,
    'raster_start_us': rasterStart,
    'raster_finish_us': rasterFinish,
  };
}

class ClosureJourneySession {
  const ClosureJourneySession(this.journey, this.harness);
  final String journey;
  final Object harness;
  Future<void> rehearse(WidgetTester tester, ClosureStage capture) =>
      switch (journey) {
        'TB-AUTH' => rehearseClosureAuthJourney(
          tester,
          harness as ClosureAuthSource,
          capture: capture,
        ),
        'TB-HOME-PET' => rehearseClosureHomePetJourney(
          tester,
          harness as ClosureHomePetHarness,
          capture: capture,
        ),
        'TB-VET' => rehearseClosureVetJourney(
          tester,
          harness as ClosureVetHarness,
          capture: capture,
        ),
        'TB-HEALTH' => rehearseClosureHealthJourney(
          tester,
          harness as ClosureReminderSource,
          capture: capture,
        ),
        'TB-NOTIFICATIONS' => rehearseClosureNotificationJourney(
          tester,
          harness as ClosureNotificationHarness,
          capture: capture,
        ),
        'TB-RESCUE' => rehearseClosureRescueJourney(
          tester,
          harness as detail.Day119Harness,
          capture: capture,
        ),
        'TB-ADOPTION-CHAT' => rehearseClosureAdoptionChatJourney(
          tester,
          harness as ClosureChatSource,
          capture: capture,
        ),
        _ => throw StateError('Unknown journey $journey'),
      };
}

Future<ClosureJourneySession> pumpClosureJourney(
  WidgetTester tester,
  String journey,
  Size size, {
  required VoidCallback restoreMetrics,
}) async {
  final Object harness = switch (journey) {
    'TB-AUTH' => await pumpClosureAuthJourney(tester, size),
    'TB-HOME-PET' => await pumpClosureHomePetJourney(tester, size),
    'TB-VET' => await pumpClosureVetJourney(tester, size),
    'TB-HEALTH' => await pumpClosureHealthJourney(tester, size),
    'TB-NOTIFICATIONS' => await pumpClosureNotificationJourney(tester, size),
    'TB-RESCUE' => await pumpClosureRescueJourney(tester, size),
    'TB-ADOPTION-CHAT' => await pumpClosureAdoptionChatJourney(tester, size),
    _ => throw StateError('Unknown journey $journey'),
  };
  // All seven paths use the same final metrics restoration, before any action.
  restoreMetrics();
  await tester.pumpAndSettle();
  return ClosureJourneySession(journey, harness);
}
