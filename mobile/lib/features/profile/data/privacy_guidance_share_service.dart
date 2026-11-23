import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

abstract interface class PrivacyGuidanceShareSource {
  Future<void> shareGuidance({required Rect sharePositionOrigin});
}

final privacyGuidanceShareSourceProvider = Provider<PrivacyGuidanceShareSource>(
  (ref) {
    return NativePrivacyGuidanceShareSource();
  },
);

/// Opens the native share sheet for the privacy guidance. This remains
/// intentionally separate from clipboard behavior so the share icon cannot
/// report a copy operation as a completed share action.
class NativePrivacyGuidanceShareSource implements PrivacyGuidanceShareSource {
  NativePrivacyGuidanceShareSource({SharePlus? sharePlus})
    : _sharePlus = sharePlus ?? SharePlus.instance;

  final SharePlus _sharePlus;

  @override
  Future<void> shareGuidance({required Rect sharePositionOrigin}) async {
    await _sharePlus.share(
      ShareParams(
        title: 'Hướng dẫn quyền riêng tư PawMate',
        subject: 'Giữ an toàn khi chia sẻ trên PawMate',
        text:
            'PawMate · Hướng dẫn quyền riêng tư\n'
            'Hãy kiểm tra cài đặt quyền riêng tư trước khi chia sẻ thông tin thú cưng.',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
