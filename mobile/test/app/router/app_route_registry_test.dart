import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/router/app_feature_availability.dart';
import 'package:pawmate_mobile/app/router/app_route_registry.dart';

void main() {
  group('AppRouteRegistry authenticated allowlist', () {
    const exactLocations = <String>[
      '/pets',
      '/pets/list',
      '/pets/create?returnTo=%2Fpets',
      '/vets/map',
      '/vets/list?availability=24h',
      '/health',
      '/health/events/new?petId=pet-1',
      '/health/reminders',
      '/notifications?returnTo=%2Fprofile',
      '/community',
      '/adoption',
      '/profile',
      '/profile/controls',
      '/profile/privacy',
      '/rescue',
      '/rescue/create',
      '/rescue/create/details',
      '/rescue/map',
    ];

    for (final location in exactLocations) {
      test('accepts $location', () {
        expect(
          AppRouteRegistry.isSupportedAuthenticatedLocation(location),
          isTrue,
        );
      });
    }

    const dynamicLocations = <String>[
      '/pets/pet-1',
      '/pets/pet_1/edit?returnTo=%2Fpets%2Flist',
      '/vets/vet.alpha-1',
      '/rescue/case-1',
      '/rescue/case_1/comment',
      '/rescue/case.1/status',
      '/rescue/case~1/discussion',
    ];

    for (final location in dynamicLocations) {
      test('accepts dynamic route $location', () {
        expect(
          AppRouteRegistry.isSupportedAuthenticatedLocation(location),
          isTrue,
        );
      });
    }

    const rejectedLocations = <String>[
      '',
      'pets',
      'https://evil.example/profile',
      '//evil.example/profile',
      r'/\evil.example\profile',
      '/%2F%2Fevil.example/profile',
      '/pets/not-safe%2Fchild',
      '/pets/..',
      '/pets/create/extra',
      '/rescue/case-1/unknown',
      '/adoption/pets/pet-1',
      '/adoption/requests/new',
      '/adoption/requests/request-1/chat',
      '/adoption/requests',
      '/notifications/preferences',
      '/auth/login',
      '/launch',
      '/totally-unknown',
      '/profile#private',
    ];

    for (final location in rejectedLocations) {
      test('rejects $location', () {
        expect(
          AppRouteRegistry.isSupportedAuthenticatedLocation(location),
          isFalse,
        );
      });
    }
  });

  test('shell locations map to five stable branch indexes', () {
    expect(AppRouteRegistry.shellRoots, const <String>[
      '/pets',
      '/vets/map',
      '/health',
      '/rescue',
      '/profile',
    ]);
    expect(AppRouteRegistry.shellBranchIndexForLocation('/pets/list'), 0);
    expect(AppRouteRegistry.shellBranchIndexForLocation('/adoption'), 0);
    expect(AppRouteRegistry.shellBranchIndexForLocation('/vets/list'), 1);
    expect(
      AppRouteRegistry.shellBranchIndexForLocation('/health/reminders'),
      2,
    );
    expect(AppRouteRegistry.shellBranchIndexForLocation('/rescue/map'), 3);
    expect(AppRouteRegistry.shellBranchIndexForLocation('/notifications'), 4);
    expect(AppRouteRegistry.shellBranchIndexForLocation('/pets/pet-1'), isNull);
    expect(AppRouteRegistry.shellBranchIndexForLocation('/unknown'), isNull);
  });

  group('AppFeatureAvailability', () {
    test('matches the selected compile-time deployment profile', () {
      const availability = AppFeatureAvailability.fromEnvironment();
      const isDay39BrowseStaging = bool.fromEnvironment(
        'PAWMATE_DAY39_RESCUE_BROWSE_STAGING',
        defaultValue: false,
      );

      expect(availability.rescueBrowse, isDay39BrowseStaging);
      expect(availability.rescueCreate, isFalse);
    });

    test('create cannot be enabled without browse', () {
      const availability = AppFeatureAvailability(
        rescueBrowse: false,
        rescueCreate: true,
      );

      expect(availability.rescueBrowse, isFalse);
      expect(availability.rescueCreate, isFalse);
    });

    test('explicit browse and create can be enabled together', () {
      const availability = AppFeatureAvailability(
        rescueBrowse: true,
        rescueCreate: true,
      );

      expect(availability.rescueBrowse, isTrue);
      expect(availability.rescueCreate, isTrue);
    });
  });
}
