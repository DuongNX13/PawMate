import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/adoption/presentation/adoption_profile_screen.dart';
import '../../features/adoption/presentation/adoption_request_form_screen.dart';
import '../../features/adoption/presentation/adoption_swipe_deck_screen.dart';
import '../../features/adoption/presentation/my_adoption_requests_screen.dart';
import '../../features/adoption/presentation/shelter_chat_screen.dart';
import '../../features/auth/application/auth_session_coordinator.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/health/presentation/add_health_event_screen.dart';
import '../../features/health/presentation/health_timeline_screen.dart';
import '../../features/health_hub/presentation/health_hub_screen.dart';
import '../../features/notifications/presentation/notification_center_screen.dart';
import '../../features/onboarding/presentation/onboarding_gate_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/pets/presentation/create_pet_screen.dart';
import '../../features/pets/presentation/pet_detail_screen.dart';
import '../../features/pets/presentation/pet_list_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/notification_preferences_screen.dart';
import '../../features/profile/presentation/privacy_defaults_screen.dart';
import '../../features/profile/presentation/profile_controls_screen.dart';
import '../../features/reminders/presentation/reminder_calendar_screen.dart';
import '../../features/rescue/presentation/rescue_case_detail_screen.dart';
import '../../features/rescue/presentation/rescue_comment_screen.dart';
import '../../features/rescue/presentation/rescue_home_screen.dart';
import '../../features/rescue/presentation/rescue_create_screen.dart';
import '../../features/rescue/presentation/rescue_info_form_screen.dart';
import '../../features/rescue/presentation/rescue_map_screen.dart';
import '../../features/rescue/presentation/rescue_status_screen.dart';
import '../../features/vets/presentation/vet_detail_screen.dart';
import '../../features/vets/presentation/vet_list_screen.dart';
import '../../features/vets/presentation/vet_map_screen.dart';
import 'app_feature_availability.dart';
import 'app_navigation.dart';
import 'app_route_registry.dart';
import 'feature_unavailable_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  const initialLocation = String.fromEnvironment(
    'PAWMATE_INITIAL_ROUTE',
    defaultValue: '/launch',
  );
  final availability = ref.watch(appFeatureAvailabilityProvider);
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final branchKeys = List.generate(
    AppRouteRegistry.shellRoots.length,
    (index) => GlobalKey<NavigatorState>(debugLabel: 'branch-$index'),
  );

  late final GoRouter router;
  router = GoRouter(
    navigatorKey: rootNavigatorKey,
    restorationScopeId: 'pawmate-router',
    initialLocation: initialLocation,
    redirect: (context, state) async {
      if (_isPublicRoute(state.uri.path)) return null;

      var hasValidSession = false;
      try {
        hasValidSession =
            await ref.read(authSessionSnapshotProvider.future) != null;
      } on Object {
        // Storage/network failures at the auth boundary must fail closed.
      }
      if (hasValidSession) return null;

      final returnTo = AppRouteRegistry.isSupportedAuthenticatedUri(state.uri)
          ? state.uri.toString()
          : '/pets';
      return Uri(
        path: '/auth/login',
        queryParameters: {'returnTo': returnTo},
      ).toString();
    },
    errorPageBuilder: (context, state) => PawMateNavigation.adaptivePage(
      context: context,
      state: state,
      child: FeatureUnavailableScreen(
        title: 'Không tìm thấy trang',
        message:
            'Liên kết này chưa được PawMate hỗ trợ. Bạn có thể quay lại trang chủ an toàn.',
        fallbackLocation: '/pets',
      ),
    ),
    routes: [
      GoRoute(
        path: '/launch',
        name: 'launch',
        builder: (context, state) => const OnboardingGateScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        name: 'login',
        builder: (context, state) => LoginScreen(
          initialEmail: state.uri.queryParameters['email'],
          showVerifiedMessage: state.uri.queryParameters['verified'] == '1',
          returnTo: state.uri.queryParameters['returnTo'],
        ),
      ),
      GoRoute(
        path: '/auth/register',
        name: 'register',
        builder: (context, state) => RegisterScreen(
          initialEmail: state.uri.queryParameters['email'],
          returnTo: state.uri.queryParameters['returnTo'],
        ),
      ),
      GoRoute(
        path: '/auth/otp',
        name: 'otp',
        builder: (context, state) => OtpScreen(
          email: state.uri.queryParameters['email'],
          registrationId: state.uri.queryParameters['registrationId'],
          verificationExpiresAt: _parseEpochMilliseconds(
            state.uri.queryParameters['expiresAt'],
          ),
          resendAvailableAt: _parseEpochMilliseconds(
            state.uri.queryParameters['resendAt'],
          ),
          returnTo: state.uri.queryParameters['returnTo'],
        ),
      ),
      StatefulShellRoute.indexedStack(
        restorationScopeId: 'pawmate-shell',
        builder: (context, state, navigationShell) =>
            PawMateStatefulNavigationHost(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: branchKeys[0],
            initialLocation: '/pets',
            restorationScopeId: 'home-branch',
            routes: [
              GoRoute(
                path: '/pets',
                name: 'pets-home',
                builder: (context, state) => const PetHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'list',
                    name: 'pets-list',
                    builder: (context, state) => const PetListScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: '/adoption',
                name: 'adoption',
                builder: (context, state) => const AdoptionSwipeDeckScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchKeys[1],
            initialLocation: '/vets/map',
            restorationScopeId: 'vet-branch',
            routes: [
              GoRoute(
                path: '/vets/map',
                name: 'vets-map',
                builder: (context, state) => const VetMapScreen(),
              ),
              GoRoute(
                path: '/vets/list',
                name: 'vets-list',
                builder: (context, state) => const VetListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchKeys[2],
            initialLocation: '/health',
            restorationScopeId: 'health-branch',
            routes: [
              GoRoute(
                path: '/health',
                name: 'health',
                builder: (context, state) => const HealthTimelineScreen(),
                routes: [
                  GoRoute(
                    path: 'reminders',
                    name: 'health-reminders',
                    builder: (context, state) => const ReminderCalendarScreen(),
                  ),
                  GoRoute(
                    path: 'knowledge',
                    name: 'health-knowledge',
                    builder: (context, state) => const HealthHubScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchKeys[3],
            initialLocation: '/rescue',
            restorationScopeId: 'rescue-branch',
            routes: [
              GoRoute(
                path: '/rescue',
                name: 'rescue',
                builder: (context, state) => RescueHomeScreen(
                  browseEnabled: availability.rescueBrowse,
                  createEnabled: availability.rescueCreate,
                ),
                routes: [
                  GoRoute(
                    path: 'map',
                    name: 'rescue-map',
                    builder: (context, state) => availability.rescueBrowse
                        ? const RescueMapScreen()
                        : const FeatureUnavailableScreen(
                            title: 'Bản đồ cứu hộ',
                            message:
                                'Bản đồ cứu hộ chưa được bật. PawMate không tải dữ liệu hoặc vị trí thật ở trạng thái này.',
                            fallbackLocation: '/rescue',
                            bottomNavRoute: '/rescue',
                          ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: branchKeys[4],
            initialLocation: '/profile',
            restorationScopeId: 'profile-branch',
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'controls',
                    name: 'profile-controls',
                    builder: (context, state) => const ProfileControlsScreen(),
                  ),
                  GoRoute(
                    path: 'privacy',
                    name: 'profile-privacy',
                    builder: (context, state) => const PrivacyDefaultsScreen(),
                  ),
                  GoRoute(
                    path: 'notifications',
                    name: 'profile-notifications',
                    builder: (context, state) =>
                        const NotificationPreferencesScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: '/notifications',
                name: 'notifications',
                builder: (context, state) => NotificationCenterScreen(
                  returnPath: _safeReturnTo(state, fallback: '/profile'),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/adoption/requests',
        name: 'adoption-requests',
        pageBuilder: (context, state) => PawMateNavigation.adaptivePage(
          context: context,
          state: state,
          child: const MyAdoptionRequestsScreen(),
        ),
      ),
      GoRoute(
        path: '/adoption/:listingId/request',
        name: 'adoption-request',
        pageBuilder: (context, state) {
          final listingId = state.pathParameters['listingId']!;
          return PawMateNavigation.adaptivePage(
            context: context,
            state: state,
            child: AdoptionRequestFormScreen(listingId: listingId),
          );
        },
      ),
      GoRoute(
        path: '/adoption/chat/:threadId',
        name: 'adoption-chat',
        pageBuilder: (context, state) => PawMateNavigation.adaptivePage(
          context: context,
          state: state,
          child: ShelterChatScreen(threadId: state.pathParameters['threadId']!),
        ),
      ),
      GoRoute(
        path: '/adoption/:listingId',
        name: 'adoption-profile',
        pageBuilder: (context, state) => PawMateNavigation.adaptivePage(
          context: context,
          state: state,
          child: AdoptionProfileScreen(
            listingId: state.pathParameters['listingId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/pets/create',
        name: 'pets-create',
        pageBuilder: (context, state) => PawMateNavigation.adaptivePage(
          context: context,
          state: state,
          child: CreatePetScreen(returnTo: _optionalSafeReturnTo(state)),
        ),
      ),
      GoRoute(
        path: '/pets/:id/edit',
        name: 'pets-edit',
        pageBuilder: (context, state) => PawMateNavigation.adaptivePage(
          context: context,
          state: state,
          child: CreatePetScreen(
            petId: state.pathParameters['id'],
            returnTo: _optionalSafeReturnTo(state),
          ),
        ),
      ),
      GoRoute(
        path: '/pets/:id',
        name: 'pets-detail',
        pageBuilder: (context, state) => PawMateNavigation.adaptivePage(
          context: context,
          state: state,
          child: PetDetailScreen(petId: state.pathParameters['id'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/vets/:id',
        name: 'vets-detail',
        pageBuilder: (context, state) => PawMateNavigation.adaptivePage(
          context: context,
          state: state,
          child: VetDetailScreen(
            vetId: state.pathParameters['id'] ?? 'unknown-vet',
            returnPath: _safeReturnTo(state, fallback: '/vets/list'),
          ),
        ),
      ),
      GoRoute(
        path: '/health/events/new',
        name: 'health-event-create',
        pageBuilder: (context, state) => PawMateNavigation.adaptivePage(
          context: context,
          state: state,
          child: AddHealthEventScreen(
            initialPetId: state.uri.queryParameters['petId'],
          ),
        ),
      ),
      GoRoute(
        path: '/community',
        name: 'community',
        pageBuilder: (context, state) => PawMateNavigation.adaptivePage(
          context: context,
          state: state,
          child: const FeatureUnavailableScreen(
            title: 'Cộng đồng',
            message: 'Sẽ mở lại sau khi core flow MVP ổn định.',
            fallbackLocation: '/pets',
          ),
        ),
      ),
      GoRoute(
        path: '/rescue/create/details',
        name: 'rescue-create-details',
        pageBuilder: (context, state) => availability.rescueCreate
            ? PawMateNavigation.adaptivePage(
                context: context,
                state: state,
                child: const RescueInfoFormScreen(),
              )
            : _rescueUnavailablePage(
                context,
                state,
                availability: availability,
                title: 'Thông tin thú cưng thất lạc',
                requiresCreate: true,
              ),
      ),
      GoRoute(
        path: '/rescue/create',
        name: 'rescue-create',
        pageBuilder: (context, state) => availability.rescueCreate
            ? PawMateNavigation.adaptivePage(
                context: context,
                state: state,
                child: const RescueCreateScreen(),
              )
            : _rescueUnavailablePage(
                context,
                state,
                availability: availability,
                title: 'Tạo tin cứu hộ',
                requiresCreate: true,
              ),
      ),
      GoRoute(
        path: '/rescue/:caseId/comment',
        name: 'rescue-comment',
        pageBuilder: (context, state) => availability.rescueCreate
            ? PawMateNavigation.adaptivePage(
                context: context,
                state: state,
                child: RescueCommentScreen(
                  caseId: state.pathParameters['caseId']!,
                ),
              )
            : _rescueUnavailablePage(
                context,
                state,
                availability: availability,
                title: 'Bình luận ca cứu hộ',
                requiresCreate: true,
              ),
      ),
      GoRoute(
        path: '/rescue/:caseId/status',
        name: 'rescue-status',
        pageBuilder: (context, state) => availability.rescueCreate
            ? PawMateNavigation.adaptivePage(
                context: context,
                state: state,
                child: RescueStatusScreen(
                  caseId: state.pathParameters['caseId']!,
                ),
              )
            : _rescueUnavailablePage(
                context,
                state,
                availability: availability,
                title: 'Cập nhật trạng thái',
                requiresCreate: true,
              ),
      ),
      GoRoute(
        path: '/rescue/:caseId/discussion',
        name: 'rescue-discussion',
        pageBuilder: (context, state) => availability.rescueCreate
            ? PawMateNavigation.adaptivePage(
                context: context,
                state: state,
                child: RescueCommentScreen(
                  caseId: state.pathParameters['caseId']!,
                  discussionMode: true,
                ),
              )
            : _rescueUnavailablePage(
                context,
                state,
                availability: availability,
                title: 'Trao đổi ca cứu hộ',
                requiresCreate: true,
              ),
      ),
      GoRoute(
        path: '/rescue/:caseId',
        name: 'rescue-case',
        pageBuilder: (context, state) => availability.rescueBrowse
            ? PawMateNavigation.adaptivePage(
                context: context,
                state: state,
                child: RescueCaseDetailScreen(
                  caseId: state.pathParameters['caseId']!,
                ),
              )
            : _rescueUnavailablePage(
                context,
                state,
                availability: availability,
                title: 'Chi tiết ca cứu hộ',
              ),
      ),
    ],
  );

  // Re-run the guard when a live session is refreshed, expires, or is cleared.
  ref.listen(authSessionSnapshotProvider, (_, _) => router.refresh());
  return router;
});

const _publicRoutes = <String>{
  '/launch',
  '/onboarding',
  '/auth/login',
  '/auth/register',
  '/auth/otp',
};

bool _isPublicRoute(String path) => _publicRoutes.contains(path);

String? _optionalSafeReturnTo(GoRouterState state) {
  final value = state.uri.queryParameters['returnTo'];
  return AppRouteRegistry.isSupportedAuthenticatedLocation(value ?? '')
      ? value
      : null;
}

String _safeReturnTo(GoRouterState state, {required String fallback}) {
  return _optionalSafeReturnTo(state) ?? fallback;
}

Page<void> _rescueUnavailablePage(
  BuildContext context,
  GoRouterState state, {
  required AppFeatureAvailability availability,
  required String title,
  bool requiresCreate = false,
}) {
  final enabled = requiresCreate
      ? availability.rescueCreate
      : availability.rescueBrowse;
  return PawMateNavigation.adaptivePage(
    context: context,
    state: state,
    child: FeatureUnavailableScreen(
      title: title,
      message: enabled
          ? 'Cờ tính năng đã bật nhưng luồng này chưa sẵn sàng trong lane UI hiện tại. PawMate không tạo dữ liệu giả.'
          : 'Tính năng này chưa được bật. PawMate không gọi API và không hiển thị dữ liệu giả.',
      fallbackLocation: '/rescue',
    ),
  );
}

DateTime? _parseEpochMilliseconds(String? value) {
  final milliseconds = int.tryParse(value ?? '');
  if (milliseconds == null || milliseconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(milliseconds);
}
