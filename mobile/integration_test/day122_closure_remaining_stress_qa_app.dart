import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/adoption/application/my_adoption_requests_provider.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_request_chat_models.dart';
import 'package:pawmate_mobile/features/adoption/presentation/my_adoption_requests_screen.dart';
import 'package:pawmate_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:pawmate_mobile/features/vets/application/vet_map_provider.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_map_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_screen.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final router = GoRouter(
    initialLocation: '/qa-day122',
    routes: [
      GoRoute(path: '/qa-day122', builder: (_, _) => const _StressMenu()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/vets/map', builder: (_, _) => const VetMapScreen()),
      GoRoute(
        path: '/adoption/requests',
        builder: (_, _) => const MyAdoptionRequestsScreen(),
      ),
      // This isolated QA build never submits or fetches data over the network.
      for (final target in const [
        '/auth/register',
        '/auth/login',
        '/vets/list',
        '/adoption',
      ])
        GoRoute(
          path: target,
          builder: (_, _) => Scaffold(body: Center(child: Text('QA: $target'))),
        ),
    ],
  );
  runApp(
    ProviderScope(
      overrides: [
        vetMapProvider.overrideWith(NativeStressVetFixture.new),
        myAdoptionRequestsProvider.overrideWithValue(
          AsyncValue.data(day119Requests(longContent: true)),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
}

class _StressMenu extends StatelessWidget {
  const _StressMenu();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in const {
              'Onboarding': '/onboarding',
              'VetMap': '/vets/map',
              'MyRequests': '/adoption/requests',
            }.entries)
              FilledButton(
                onPressed: () => context.push(entry.value),
                child: Text('QA ${entry.key}'),
              ),
          ],
        ),
      ),
    ),
  );
}

class NativeStressVetFixture extends VetMapNotifier {
  @override
  VetMapState build() => const VetMapState(
    status: VetMapStatus.permissionDenied,
    hasLoadedAtLeastOnce: true,
  );
  @override
  Future<void> initialize() async {}
  @override
  Future<void> refresh({bool forceLocationRefresh = false}) async {
    state = state.copyWith(mapUnavailable: true);
  }
}

const day119LongPetName = 'Mochi — bạn nhỏ đáng yêu của gia đình Nguyễn';

List<AdoptionRequestSummary> day119Requests({bool longContent = false}) => [
  for (var i = 0; i < (longContent ? 12 : 2); i++)
    AdoptionRequestSummary.fromJson({
      'requestId': 'request-$i',
      'listingId': 'listing-1',
      'petName': longContent
          ? '$day119LongPetName — đơn ${i + 1}'
          : (i == 0 ? 'Mochi' : 'Kem'),
      'status': [
        'reviewing',
        'approved',
        'submitted',
        'rejected',
        'cancelled',
      ][i % 5],
      'listingAvailability': i.isEven ? 'expired' : 'available',
      'threadId': 'thread-1',
      'createdAt': '2026-07-28T05:00:00.000Z',
      'updatedAt': '2026-09-18T05:00:00.000Z',
    }),
];
