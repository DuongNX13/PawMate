import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';

import '../test/features/rescue/rescue_test_fixtures.dart';

// Keep native view metrics. The two entries differ only by the fixture hint.
const _hint = 'Nhút nhát khi gặp người lạ; hãy tiếp cận nhẹ nhàng.';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _RescueDetailQaEntry(),
    ),
  );
}

class _RescueDetailQaEntry extends StatelessWidget {
  const _RescueDetailQaEntry();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => _open(context, _figmaCaseDetail()),
              child: const Text('QA P2-04 chuẩn'),
            ),
            TextButton(
              onPressed: () => _open(
                context,
                _figmaCaseDetail(behaviorHint: _hint),
              ),
              child: const Text('QA P2-04 có lưu ý'),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, RescueCaseDetail detail) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProviderScope(
          overrides: [
            rescueApiProvider.overrideWithValue(
              FakeRescueSource(detail: detail),
            ),
          ],
          child: RescueCaseDetailScreen(caseId: detail.caseId),
        ),
      ),
    );
  }
}

RescueCaseDetail _figmaCaseDetail({String? behaviorHint}) {
  final lostAt = DateTime(2026, 5, 25, 18, 40);
  return RescueCaseDetail(
    caseId: '11111111-1111-4111-8111-111111111111',
    petName: 'Mochi',
    species: RescueSpecies.cat,
    status: RescueCaseStatus.missing,
    version: 1,
    lostAt: lostAt,
    publicLocation: const RescuePublicLocation(
      areaLabel: 'Q. Tân Bình',
      approximateLatitude: 10.8,
      approximateLongitude: 106.7,
      privacyRadiusMeters: 500,
    ),
    media: [
      RescuePublicMedia(
        mediaId: '44444444-4444-4444-8444-444444444444',
        mimeType: 'image/png',
        publicUrl: Uri.parse(
          'asset:assets/images/rescue/p2_04_case_detail.png',
        ),
        createdAt: lostAt,
      ),
    ],
    commentCount: 3,
    createdAt: lostAt,
    updatedAt: lostAt,
    breedOrColor: 'Mèo tam thể',
    ageLabel: null,
    distanceMeters: 1200,
    identifyingFeatures: 'Đuôi khoang vàng, đeo vòng xanh',
    behaviorHint: behaviorHint,
    viewerPermissions: const RescueViewerPermissions(
      canComment: true,
      canUpdateStatus: true,
      canViewPrivateContact: false,
    ),
  );
}
