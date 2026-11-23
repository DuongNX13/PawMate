import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_case_share_service.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/vets/data/vet_share_service.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_models.dart';
import 'package:share_plus/share_plus.dart';
// Test-only platform fake for the public SharePlus.custom constructor.
// ignore: depend_on_referenced_packages
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

void main() {
  test(
    'P1-10 routes public vet details to the native share contract',
    () async {
      final platform = _FakeSharePlatform();
      final source = NativeVetShareSource(
        sharePlus: SharePlus.custom(platform),
      );

      await source.shareVet(
        _vet(),
        sharePositionOrigin: const Rect.fromLTWH(12, 24, 48, 48),
      );

      expect(platform.calls, 1);
      expect(platform.lastParams?.title, 'Mochi Vet');
      expect(platform.lastParams?.subject, 'Thông tin phòng khám Mochi Vet');
      expect(
        platform.lastParams?.text,
        'PawMate · Mochi Vet\n'
        '22 Bạch Đằng, Hải Châu, Đà Nẵng\n'
        '0912 333 444\n'
        'https://example.com/mochi-vet\n'
        'pawmate://vets/mochi-vet',
      );
      expect(
        platform.lastParams?.sharePositionOrigin,
        const Rect.fromLTWH(12, 24, 48, 48),
      );
    },
  );

  test(
    'P2-04 routes only public rescue context to the native share contract',
    () async {
      final platform = _FakeSharePlatform();
      final source = NativeRescueCaseShareSource(
        sharePlus: SharePlus.custom(platform),
      );

      await source.shareCase(
        _rescueCase(),
        sharePositionOrigin: const Rect.fromLTWH(6, 18, 48, 48),
      );

      expect(platform.calls, 1);
      expect(platform.lastParams?.title, 'Tin báo cứu hộ LuLu');
      expect(platform.lastParams?.subject, 'Cùng tìm LuLu trên PawMate');
      expect(
        platform.lastParams?.text,
      'PawMate · LuLu · Chưa thấy\n'
        'Q. Tân Bình\n'
        'pawmate://rescue/11111111-1111-4111-8111-111111111111',
      );
      expect(platform.lastParams?.text, isNot(contains('0900000000')));
      expect(
        platform.lastParams?.sharePositionOrigin,
        const Rect.fromLTWH(6, 18, 48, 48),
      );
    },
  );
}

class _FakeSharePlatform implements SharePlatform {
  int calls = 0;
  ShareParams? lastParams;

  @override
  Future<ShareResult> share(ShareParams params) async {
    calls += 1;
    lastParams = params;
    return ShareResult.unavailable;
  }
}

VetDetail _vet() => const VetDetail(
  id: 'mochi-vet',
  name: 'Mochi Vet',
  city: 'Đà Nẵng',
  district: 'Hải Châu',
  address: '22 Bạch Đằng',
  phone: '0912 333 444',
  website: 'https://example.com/mochi-vet',
  summary: 'Khám tổng quát',
  services: [],
  seedRank: 1,
  reviewCount: 0,
  is24h: false,
  readyForMap: false,
  openHours: [],
  photoUrls: [],
  source: VetSource(
    url: 'https://example.com/mochi-vet',
    list: 'Danh sách kiểm duyệt PawMate',
    priorityTier: 'P1',
    enrichmentStatus: 'BASE_ONLY',
    selectionReason: 'Top local vet',
  ),
);

RescueCaseDetail _rescueCase() => RescueCaseDetail(
  caseId: '11111111-1111-4111-8111-111111111111',
  petName: 'LuLu',
  species: RescueSpecies.dog,
  status: RescueCaseStatus.missing,
  version: 1,
  lostAt: DateTime.utc(2026, 7, 23, 10),
  publicLocation: const RescuePublicLocation(
    areaLabel: 'Q. Tân Bình',
    approximateLatitude: 10.8,
    approximateLongitude: 106.6,
    privacyRadiusMeters: 1000,
  ),
  media: const [],
  commentCount: 0,
  createdAt: DateTime.utc(2026, 7, 23, 10),
  updatedAt: DateTime.utc(2026, 7, 23, 10),
  identifyingFeatures: 'Đeo vòng cổ màu xanh.',
  viewerPermissions: const RescueViewerPermissions(
    canComment: false,
    canUpdateStatus: false,
    canViewPrivateContact: false,
  ),
);
