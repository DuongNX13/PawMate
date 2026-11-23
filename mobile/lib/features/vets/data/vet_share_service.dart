import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/vet_models.dart';

abstract interface class VetShareSource {
  Future<void> shareVet(VetDetail vet, {required Rect sharePositionOrigin});
}

final vetShareSourceProvider = Provider<VetShareSource>((ref) {
  return NativeVetShareSource();
});

/// Opens the platform share sheet rather than relabelling a clipboard write as
/// a completed share. The payload contains only public clinic contact data.
class NativeVetShareSource implements VetShareSource {
  NativeVetShareSource({SharePlus? sharePlus})
    : _sharePlus = sharePlus ?? SharePlus.instance;

  final SharePlus _sharePlus;

  @override
  Future<void> shareVet(
    VetDetail vet, {
    required Rect sharePositionOrigin,
  }) async {
    final address = [
      vet.address,
      vet.district,
      vet.city,
    ].where((part) => part.trim().isNotEmpty).join(', ');
    final details = [
      'PawMate · ${vet.name}',
      if (address.isNotEmpty) address,
      if (vet.phone.trim().isNotEmpty) vet.phone,
      if ((vet.website ?? '').trim().isNotEmpty) vet.website!.trim(),
      'pawmate://vets/${Uri.encodeComponent(vet.id)}',
    ].join('\n');

    await _sharePlus.share(
      ShareParams(
        title: vet.name,
        subject: 'Thông tin phòng khám ${vet.name}',
        text: details,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
