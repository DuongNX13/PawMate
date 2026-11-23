import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';

import '../test/features/rescue/rescue_test_fixtures.dart';
import 'day122_closure_rescue_state_qa_app.dart' show day119Cases;

const rescueDetailMarker = 'D122: hồ sơ Mochi từ đúng mã ca';

class RescueSelectedActionFixture extends FakeRescueSource {
  RescueSelectedActionFixture() : this._(day119Cases(longContent: true));

  RescueSelectedActionFixture._(List<RescueCaseSummary> cases)
    : expected = cases.first,
      super(pages: [samplePage(items: cases)]);

  final RescueCaseSummary expected;

  @override
  Future<RescueCaseDetail> getCase(String caseId) async {
    if (caseId != expected.caseId) {
      throw StateError('Unexpected Rescue fixture case ID');
    }
    final item = expected;
    return RescueCaseDetail(
      caseId: item.caseId,
      petName: item.petName,
      species: item.species,
      status: item.status,
      version: 1,
      lostAt: item.lostAt,
      publicLocation: item.publicLocation,
      media: item.media,
      commentCount: item.commentCount,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      identifyingFeatures: rescueDetailMarker,
      viewerPermissions: const RescueViewerPermissions(
        canComment: false,
        canUpdateStatus: false,
        canViewPrivateContact: false,
      ),
      breedOrColor: item.breedOrColor,
      ageLabel: item.ageLabel,
      distanceMeters: item.distanceMeters,
    );
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final router = GoRouter(
    initialLocation: '/rescue',
    routes: [
      GoRoute(
        path: '/rescue',
        builder: (_, _) => const RescueHomeScreen(
          browseEnabled: true,
          createEnabled: true,
          mapPreviewAsset: 'assets/images/rescue/p2_01_map.png',
        ),
      ),
      GoRoute(
        path: '/rescue/:caseId',
        builder: (_, state) =>
            RescueCaseDetailScreen(caseId: state.pathParameters['caseId']!),
      ),
    ],
  );
  runApp(
    ProviderScope(
      overrides: [
        rescueApiProvider.overrideWithValue(RescueSelectedActionFixture()),
        rescueClockProvider.overrideWithValue(fixedRescueClock()),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
}
