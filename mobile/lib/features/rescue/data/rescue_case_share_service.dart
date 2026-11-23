import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/rescue_case_models.dart';

abstract interface class RescueCaseShareSource {
  Future<void> shareCase(
    RescueCaseDetail detail, {
    required Rect sharePositionOrigin,
  });
}

final rescueCaseShareSourceProvider = Provider<RescueCaseShareSource>((ref) {
  return NativeRescueCaseShareSource();
});

/// Shares only the public rescue context and the existing case deep link.
/// The OS sheet leaves the actual destination selection to the user.
class NativeRescueCaseShareSource implements RescueCaseShareSource {
  NativeRescueCaseShareSource({SharePlus? sharePlus})
    : _sharePlus = sharePlus ?? SharePlus.instance;

  final SharePlus _sharePlus;

  @override
  Future<void> shareCase(
    RescueCaseDetail detail, {
    required Rect sharePositionOrigin,
  }) async {
    await _sharePlus.share(
      ShareParams(
        title: 'Tin báo cứu hộ ${detail.petName}',
        subject: 'Cùng tìm ${detail.petName} trên PawMate',
        text:
            'PawMate · ${detail.petName} · ${detail.status.label}\n'
            '${detail.publicLocation.areaLabel}\n'
            'pawmate://rescue/${Uri.encodeComponent(detail.caseId)}',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
