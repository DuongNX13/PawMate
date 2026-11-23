import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_models.dart';

import 'adoption_test_fixtures.dart';

void main() {
  group('Adoption DTO contract', () {
    test('parses the frozen list envelope and typed summary fields', () {
      final page = AdoptionListingPage.fromJson(
        adoptionPageJson(nextCursor: 'opaque-next', hasMore: true),
      );

      expect(page.items, hasLength(1));
      expect(page.items.single.petName, 'Mochi');
      expect(page.items.single.species, AdoptionSpecies.dog);
      expect(page.items.single.status, AdoptionListingStatus.available);
      expect(page.items.single.heroMedia.publicUrl?.scheme, 'https');
      expect(page.items.single.healthBadges, ['Đã tiêm phòng']);
      expect(page.pageInfo.nextCursor, 'opaque-next');
      expect(page.pageInfo.hasMore, isTrue);
      expect(page.pageInfo.limit, 20);
    });

    test('parses profile permissions and fails closed when absent', () {
      final allowed = AdoptionListingDetail.fromJson(adoptionDetailJson());
      final missingPermissions = adoptionDetailJson()
        ..remove('viewerPermissions');

      expect(allowed.viewerPermissions.canLike, isTrue);
      expect(allowed.viewerPermissions.canRequest, isTrue);
      expect(allowed.viewerPermissions.canManageListing, isFalse);

      final closed = AdoptionListingDetail.fromJson(missingPermissions);
      expect(closed.viewerPermissions.canLike, isFalse);
      expect(closed.viewerPermissions.canRequest, isFalse);
      expect(closed.viewerPermissions.canManageListing, isFalse);
    });

    test('rejects invalid status and non-http media URL', () {
      expect(
        () => AdoptionListingSummary.fromJson(
          adoptionSummaryJson(status: 'unknown'),
        ),
        throwsFormatException,
      );
      final invalidUrl = adoptionSummaryJson();
      invalidUrl['heroMedia'] = adoptionMediaJson(
        publicUrl: 'file:///private/photo.webp',
      );
      expect(
        () => AdoptionListingSummary.fromJson(invalidUrl),
        throwsFormatException,
      );
    });
  });

  test('serializes only the exact backend list query keys', () {
    const query = AdoptionListQuery(
      species: AdoptionSpecies.cat,
      ageGroup: AdoptionAgeGroup.oneToThree,
      coordinates: AdoptionCoordinates(latitude: 10.7769, longitude: 106.7009),
      distanceKm: 5,
      sort: AdoptionReadSort.distance,
      cursor: 'opaque-before',
      limit: 20,
    );

    expect(query.toQueryParameters(), {
      'species': 'cat',
      'ageGroup': 'one_to_three',
      'lat': 10.7769,
      'lng': 106.7009,
      'distanceKm': 5,
      'sort': 'distance',
      'cursor': 'opaque-before',
      'limit': 20,
    });
  });
}
