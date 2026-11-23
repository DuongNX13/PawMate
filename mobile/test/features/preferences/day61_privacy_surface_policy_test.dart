import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/preferences/application/privacy_surface_policy.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_create_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_write_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_draft_models.dart';

import '../rescue/rescue_test_fixtures.dart';

void main() {
  group('Day 61 privacy surface policy', () {
    test('safe fallback is fail-closed on all three controls', () {
      const policy = PrivacySurfacePolicy.safeFallback();

      expect(policy.hideHouseNumber, isTrue);
      expect(policy.hidePhoneByDefault, isTrue);
      expect(policy.reviewMediaBeforePublish, isTrue);
      expect(policy.requiresPhoneConsent('Gọi 090 123 4567'), isTrue);
      expect(policy.requiresMediaReview([Object()]), isTrue);
    });

    test(
      'maps authoritative defaults and recognizes Vietnamese phone forms',
      () {
        final policy = PrivacySurfacePolicy.fromDefaults(
          PrivacyDefaults(
            userId: 'owner',
            version: 7,
            hideHouseNumber: false,
            hidePhoneByDefault: true,
            reviewMediaBeforePublish: false,
            updatedAt: DateTime.utc(2026, 7, 29),
          ),
        );

        expect(policy.sourceVersion, 7);
        expect(
          policy.redactHouseNumber('12 Nguyễn Huệ, Quận 1'),
          contains('12'),
        );
        expect(policy.requiresPhoneConsent('+84 901-234-567'), isTrue);
        expect(policy.requiresPhoneConsent('Mã ca 12345'), isFalse);
        expect(policy.requiresMediaReview([Object()]), isFalse);
      },
    );

    test('redacts leading house number without damaging area-only labels', () {
      const policy = PrivacySurfacePolicy(
        hideHouseNumber: true,
        hidePhoneByDefault: true,
        reviewMediaBeforePublish: true,
      );

      expect(
        policy.redactHouseNumber('12/3A Nguyễn Huệ, Quận 1'),
        'Nguyễn Huệ, Quận 1',
      );
      expect(policy.redactHouseNumber('Số 42 Lê Lợi'), 'Lê Lợi');
      expect(policy.redactHouseNumber('Quận 1, TP.HCM'), 'Quận 1, TP.HCM');
    });
  });

  test(
    'Rescue create applies defaults without overriding explicit contact',
    () {
      final container = ProviderContainer(
        overrides: [
          rescueWriteSourceProvider.overrideWithValue(_NoopRescueSource()),
          authAccessTokenProvider.overrideWith((ref) async => 'token'),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(rescueCreateProvider.notifier);

      notifier.applyPrivacyPolicy(
        const PrivacySurfacePolicy(
          hideHouseNumber: true,
          hidePhoneByDefault: false,
          reviewMediaBeforePublish: true,
        ),
      );
      expect(
        container.read(rescueCreateProvider).draft.contactPreference,
        RescueContactPreference.phoneWithConsent,
      );

      notifier.setContactPreference(RescueContactPreference.inApp);
      notifier.applyPrivacyPolicy(
        const PrivacySurfacePolicy(
          hideHouseNumber: false,
          hidePhoneByDefault: false,
          reviewMediaBeforePublish: false,
        ),
      );
      expect(
        container.read(rescueCreateProvider).draft.contactPreference,
        RescueContactPreference.inApp,
      );
    },
  );

  test('Rescue create blocks media publish until explicit review', () async {
    final source = _NoopRescueSource();
    final container = ProviderContainer(
      overrides: [
        rescueWriteSourceProvider.overrideWithValue(source),
        authAccessTokenProvider.overrideWith((ref) async => 'token'),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(rescueCreateProvider.notifier);
    notifier
      ..setIdentifyingFeatures('Vòng cổ xanh')
      ..setMedia([
        const RescueDraftMedia(
          path: 'pet.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 128,
        ),
      ]);

    expect(await notifier.publish(), isFalse);
    expect(
      container.read(rescueCreateProvider).errorMessage,
      contains('kiểm tra ảnh/video'),
    );
    expect(source.published, isFalse);
  });
}

class _NoopRescueSource implements RescueWriteSource {
  bool published = false;

  @override
  Future<RescueDraft> createDraft({
    required String accessToken,
    String source = 'rescue_home',
  }) async => const RescueDraft(draftId: 'draft-1', version: 1);

  @override
  Future<RescueCaseDetail> publishDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
  }) async {
    published = true;
    return sampleCaseDetail(caseId: 'day61-published');
  }

  @override
  Future<RescueDraft> updateDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
    required Map<String, Object?> patch,
  }) async => RescueDraft.fromJson({
    'draftId': draftId,
    'version': expectedVersion + 1,
    ...patch,
  });

  @override
  Future<RescueDraftMedia> uploadMedia({
    required String accessToken,
    required RescueDraftMedia media,
  }) async => media.copyWith(mediaId: 'media-1', uploaded: true);
}
