import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';

void main() {
  test('prefers canonical vetId while keeping id as a compatibility alias', () {
    final result = VetSearchResult.fromJson({
      'data': [
        {
          'id': 'legacy-hcm-001',
          'vetId': 'hcm-001',
          'name': 'New Pet Hospital',
          'city': 'TP Hồ Chí Minh',
          'district': 'Quận 1',
          'address': '53 Đặng Dung',
          'phone': '02862693939',
          'services': ['Cấp cứu 24/7'],
          'seedRank': 1,
          'reviewCount': 12,
          'readyForMap': true,
          'latitude': 10.78798,
          'longitude': 106.69231,
          'distanceMeters': 180,
        },
      ],
      'pageInfo': {'nextCursor': '20', 'hasMore': true, 'limit': 20},
      // The old envelope remains present during the migration window.
      'pagination': {'total': 21, 'limit': 20, 'nextCursor': '20'},
    });

    expect(result.items.single.id, 'hcm-001');
    expect(result.items.single.vetId, 'hcm-001');
    expect(result.nextCursor, '20');
    expect(result.hasMore, isTrue);
    expect(result.limit, 20);
  });

  test('falls back to the legacy pagination envelope for old responses', () {
    final result = VetNearbyResult.fromJson({
      'data': const [],
      'pagination': {'total': 0, 'limit': 20},
    });

    expect(result.items, isEmpty);
    expect(result.nextCursor, isNull);
    expect(result.hasMore, isFalse);
    expect(result.total, 0);
    expect(result.limit, 20);
  });
}
