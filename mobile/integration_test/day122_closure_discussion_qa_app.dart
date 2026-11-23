import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_comment_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_comment_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_comment_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_comment_screen.dart';
import '../test/features/rescue/rescue_comment_test_fixtures.dart';
import '../test/features/rescue/rescue_test_fixtures.dart';

const _discussionPetAsset = 'assets/images/rescue/p2_08_case_mochi.png';
const _discussionOwnerAsset = 'assets/images/rescue/p2_08_owner_avatar.png';

// Exact P2-08 fixture. Native viewport, no real network or composer actions.
void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(
    ProviderScope(
      overrides: [
        rescueApiProvider.overrideWithValue(
          FakeRescueSource(detail: _discussionGoldenDetail()),
        ),
        rescueCommentSourceProvider.overrideWithValue(
          FakeRescueCommentSource(
            comments: [
              for (var i = 0; i < 12; i++)
                RescueComment(
                  commentId: 'discussion-$i',
                  caseId: sampleCommentCaseId,
                  author: RescueCommentAuthor(
                    displayName: i == 0 ? 'Chủ tin (Bạn)' : 'Người hỗ trợ $i',
                    avatarUrl: Uri.parse('asset:$_discussionOwnerAsset'),
                  ),
                  body:
                      'Mình vừa thấy một bé khá giống Mochi ở ngõ 12 Lạc Long Quân. Bé chạy rất nhanh nên mình chỉ kịp chụp mờ mờ như này thôi. Cảm ơn mọi người đã quan tâm và giúp đỡ!',
                  media: const [],
                  createdAt: DateTime(2026, 5, 22, 18, 30),
                  updatedAt: DateTime(2026, 5, 22, 18, 30),
                  moderationState: RescueCommentModerationState.visible,
                ),
            ],
          ),
        ),
        rescueCommentClockProvider.overrideWithValue(
          () => DateTime(2026, 5, 22, 18, 40),
        ),
        authAccessTokenProvider.overrideWith((ref) async => 'golden-viewer'),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const RescueCommentScreen(
          caseId: sampleCommentCaseId,
          discussionMode: true,
        ),
      ),
    ),
  );
}

RescueCaseDetail _discussionGoldenDetail() {
  final base = sampleCaseDetail(canComment: true);
  final lostAt = DateTime(2026, 5, 22, 18, 20);
  return RescueCaseDetail(
    caseId: base.caseId,
    petName: 'Mochi',
    species: RescueSpecies.cat,
    status: RescueCaseStatus.missing,
    version: base.version,
    lostAt: lostAt,
    publicLocation: const RescuePublicLocation(
      areaLabel: 'Tây Hồ, Hà Nội',
      approximateLatitude: 21.069,
      approximateLongitude: 105.818,
      privacyRadiusMeters: 500,
    ),
    media: [
      RescuePublicMedia(
        mediaId: '66666666-6666-4666-8666-666666666666',
        mimeType: 'image/png',
        publicUrl: Uri.parse('asset:$_discussionPetAsset'),
        createdAt: lostAt,
      ),
    ],
    commentCount: 3,
    createdAt: lostAt,
    updatedAt: lostAt,
    identifyingFeatures: base.identifyingFeatures,
    viewerPermissions: base.viewerPermissions,
    breedOrColor: 'Mèo tam thể',
    ageLabel: base.ageLabel,
    distanceMeters: base.distanceMeters,
    behaviorHint: base.behaviorHint,
  );
}
