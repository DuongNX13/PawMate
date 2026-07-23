import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_actions.dart';

void main() {
  const vet = VetSummary(
    id: 'vet-1',
    name: 'Phòng khám PawMate',
    city: 'TP Hồ Chí Minh',
    district: 'Quận 1',
    address: '120 Nguyễn Huệ',
    phone: '0903 111 222',
    services: ['Khám tổng quát'],
    seedRank: 1,
    reviewCount: 12,
    readyForMap: true,
    latitude: 10.7769,
    longitude: 106.7009,
  );

  test('builds a normalized tel URI and rejects an empty number', () {
    expect(
      buildVetCallUri('0903 111 222'),
      Uri(scheme: 'tel', path: '0903111222'),
    );
    expect(buildVetCallUri('---'), isNull);
  });

  test(
    'builds Android directions with a native candidate before web fallbacks',
    () {
      final candidates = buildVetDirectionCandidates(
        vet,
        targetPlatform: TargetPlatform.android,
      );

      expect(candidates.first.scheme, 'google.navigation');
      expect(candidates.first.queryParameters['q'], '10.7769,106.7009');
      expect(candidates.any((uri) => uri.host == 'www.google.com'), isTrue);
    },
  );

  test('builds iOS directions with Apple Maps before web fallbacks', () {
    final candidates = buildVetDirectionCandidates(
      vet,
      targetPlatform: TargetPlatform.iOS,
    );

    expect(candidates.first.scheme, 'maps');
    expect(candidates.first.queryParameters['daddr'], '10.7769,106.7009');
  });
}
