import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';

import '../features/rescue/rescue_test_fixtures.dart';
import '../test_support/ui_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets('P2-04 case detail golden at 390x844', (tester) async {
    await setTestViewport(tester, size: const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rescueApiProvider.overrideWithValue(
            FakeRescueSource(detail: _figmaCaseDetail()),
          ),
        ],
        child: RepaintBoundary(
          key: const Key('rescue-case-detail-golden-root'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: const RescueCaseDetailScreen(
              caseId: '11111111-1111-4111-8111-111111111111',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final context = tester.element(
      find.byKey(const Key('rescue-case-detail-golden-root')),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/rescue/p2_04_case_detail.png'),
        context,
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('rescue-case-detail-golden-root')),
      matchesGoldenFile(
        'goldens/ui-v031-rescue/rescue-case-detail-390x844.png',
      ),
    );
    expectNoFlutterOverflow(tester);
  });
}

Future<void> pumpDay118RescueDetail(WidgetTester tester, Size viewport) async {
  await setTestViewport(tester, size: viewport);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rescueApiProvider.overrideWithValue(
          FakeRescueSource(detail: _figmaCaseDetail()),
        ),
      ],
      child: RepaintBoundary(
        key: const Key('rescue-case-detail-golden-root'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const RescueCaseDetailScreen(
            caseId: '11111111-1111-4111-8111-111111111111',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

RescueCaseDetail _figmaCaseDetail() {
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
    behaviorHint: null,
    viewerPermissions: const RescueViewerPermissions(
      canComment: true,
      canUpdateStatus: true,
      canViewPrivateContact: false,
    ),
  );
}
