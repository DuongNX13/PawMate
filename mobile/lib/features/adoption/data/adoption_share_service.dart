import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/adoption_models.dart';

abstract interface class AdoptionShareSource {
  Future<void> shareProfile(
    AdoptionListingDetail detail, {
    required Rect sharePositionOrigin,
  });
}

final adoptionShareSourceProvider = Provider<AdoptionShareSource>((ref) {
  return NativeAdoptionShareSource();
});

/// Opens the platform share sheet. This is intentionally separate from
/// clipboard behavior so the UI cannot misreport a copied link as native
/// sharing.
class NativeAdoptionShareSource implements AdoptionShareSource {
  NativeAdoptionShareSource({SharePlus? sharePlus})
    : _sharePlus = sharePlus ?? SharePlus.instance;

  final SharePlus _sharePlus;

  @override
  Future<void> shareProfile(
    AdoptionListingDetail detail, {
    required Rect sharePositionOrigin,
  }) async {
    await _sharePlus.share(
      ShareParams(
        title: 'Hồ sơ nhận nuôi ${detail.petName}',
        subject: 'Cùng xem hồ sơ của ${detail.petName} trên PawMate',
        text:
            'PawMate · ${detail.petName} · ${detail.status.label}\n'
            'Mã hồ sơ: ${detail.listingId}',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
