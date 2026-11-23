import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/profile/data/privacy_guidance_share_service.dart';
import 'package:share_plus/share_plus.dart';
// Test-only platform fake for the public SharePlus.custom constructor.
// ignore: depend_on_referenced_packages
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

void main() {
  test('native privacy guidance share preserves the reviewed contract', () async {
    final platform = _FakeSharePlatform();
    final source = NativePrivacyGuidanceShareSource(
      sharePlus: SharePlus.custom(platform),
    );

    await source.shareGuidance(
      sharePositionOrigin: const Rect.fromLTWH(12, 24, 48, 48),
    );

    expect(platform.calls, 1);
    expect(platform.lastParams?.title, 'Hướng dẫn quyền riêng tư PawMate');
    expect(
      platform.lastParams?.subject,
      'Giữ an toàn khi chia sẻ trên PawMate',
    );
    expect(
      platform.lastParams?.text,
      'PawMate · Hướng dẫn quyền riêng tư\n'
      'Hãy kiểm tra cài đặt quyền riêng tư trước khi chia sẻ thông tin thú cưng.',
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
