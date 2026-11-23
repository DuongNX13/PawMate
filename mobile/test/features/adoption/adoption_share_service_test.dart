import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_share_service.dart';
import 'package:share_plus/share_plus.dart';
// Test-only platform fake for the public SharePlus.custom constructor.
// ignore: depend_on_referenced_packages
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import 'adoption_test_fixtures.dart';

void main() {
  test('native share sends the profile contract exactly once', () async {
    final platform = _FakeSharePlatform();
    final source = NativeAdoptionShareSource(
      sharePlus: SharePlus.custom(platform),
    );

    await source.shareProfile(
      adoptionDetail(listingId: 'listing-42', petName: 'Mochi'),
      sharePositionOrigin: const Rect.fromLTWH(12, 24, 48, 48),
    );

    expect(platform.calls, 1);
    expect(platform.lastParams?.title, 'Hồ sơ nhận nuôi Mochi');
    expect(
      platform.lastParams?.subject,
      'Cùng xem hồ sơ của Mochi trên PawMate',
    );
    expect(
      platform.lastParams?.text,
      'PawMate · Mochi · Đang tìm nhà\n'
      'Mã hồ sơ: listing-42',
    );
    expect(
      platform.lastParams?.sharePositionOrigin,
      const Rect.fromLTWH(12, 24, 48, 48),
    );
  });
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
