import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/preferences/application/preference_providers.dart';
import 'package:pawmate_mobile/features/preferences/application/privacy_surface_policy.dart';
import 'package:pawmate_mobile/features/preferences/data/preference_api.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_create_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_write_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_draft_models.dart';

import '../features/rescue/rescue_test_fixtures.dart';

const _userId = '63000000-0000-4000-8000-000000000001';
final _now = DateTime.utc(2026, 7, 29, 11, 45);

void main() {
  test(
    'D63-INT-01 restart state propagates to Rescue without overriding manual contact',
    () async {
      final source = _PersistentSource();
      final first = _container(source);
      final initialNotification = await first.read(
        notificationPreferencesProvider.future,
      );
      final initialPrivacy = await first.read(privacyDefaultsProvider.future);

      expect(
        await first
            .read(notificationPreferencesProvider.notifier)
            .save(
              initialNotification.copyWith(
                nearbyLostCases: false,
                chatMessages: false,
                quietHoursEnabled: true,
                quietHoursStart: '22:30',
                quietHoursEnd: '06:30',
              ),
            ),
        isTrue,
      );
      expect(
        await first
            .read(privacyDefaultsProvider.notifier)
            .save(
              initialPrivacy.copyWith(
                hideHouseNumber: false,
                hidePhoneByDefault: false,
                reviewMediaBeforePublish: false,
              ),
            ),
        isTrue,
      );
      first.dispose();

      final reopened = _container(source);
      addTearDown(reopened.dispose);
      final notification = await reopened.read(
        notificationPreferencesProvider.future,
      );
      final privacy = await reopened.read(privacyDefaultsProvider.future);
      expect(notification.version, 2);
      expect(notification.nearbyLostCases, isFalse);
      expect(notification.chatMessages, isFalse);
      expect(notification.quietHoursStart, '22:30');
      expect(privacy.version, 2);

      final rescue = reopened.read(rescueCreateProvider.notifier);
      rescue.applyPrivacyPolicy(PrivacySurfacePolicy.fromDefaults(privacy));
      expect(
        reopened.read(rescueCreateProvider).draft.contactPreference,
        RescueContactPreference.phoneWithConsent,
      );
      expect(reopened.read(rescueCreateProvider).hideHouseNumber, isFalse);
      expect(reopened.read(rescueCreateProvider).mediaReviewConfirmed, isTrue);

      rescue.setContactPreference(RescueContactPreference.inApp);
      source.privacy = PrivacyDefaults(
        userId: _userId,
        version: 3,
        hideHouseNumber: true,
        hidePhoneByDefault: true,
        reviewMediaBeforePublish: true,
        updatedAt: _now,
      );
      reopened.invalidate(privacyDefaultsProvider);
      final refreshed = await reopened.read(privacyDefaultsProvider.future);
      rescue.applyPrivacyPolicy(PrivacySurfacePolicy.fromDefaults(refreshed));

      final integrated = reopened.read(rescueCreateProvider);
      expect(integrated.hideHouseNumber, isTrue);
      expect(integrated.hidePhoneByDefault, isTrue);
      expect(integrated.reviewMediaBeforePublish, isTrue);
      expect(integrated.mediaReviewConfirmed, isFalse);
      expect(
        integrated.draft.contactPreference,
        RescueContactPreference.inApp,
        reason: 'An explicit owner choice must survive a preference refresh.',
      );
    },
  );

  test('D63-INT-02 unavailable preferences remain privacy-safe', () {
    const fallback = PrivacySurfacePolicy.safeFallback();

    expect(fallback.redactHouseNumber('12 Lê Lợi, Quận 1'), 'Lê Lợi, Quận 1');
    expect(fallback.requiresPhoneConsent('0901234567'), isTrue);
    expect(fallback.requiresMediaReview(const ['photo.jpg']), isTrue);
  });

  test('D63-INT-03 confirmed review survives unrelated privacy changes', () {
    final source = _PersistentSource();
    final container = _container(source);
    addTearDown(container.dispose);
    final rescue = container.read(rescueCreateProvider.notifier);

    rescue.applyPrivacyPolicy(
      const PrivacySurfacePolicy(
        hideHouseNumber: true,
        hidePhoneByDefault: true,
        reviewMediaBeforePublish: true,
      ),
    );
    rescue
      ..setMedia([
        const RescueDraftMedia(
          path: 'day63.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 128,
        ),
      ])
      ..confirmMediaReview(true)
      ..applyPrivacyPolicy(
        const PrivacySurfacePolicy(
          hideHouseNumber: false,
          hidePhoneByDefault: true,
          reviewMediaBeforePublish: true,
        ),
      );

    expect(container.read(rescueCreateProvider).mediaReviewConfirmed, isTrue);
  });
}

ProviderContainer _container(_PersistentSource source) {
  return ProviderContainer(
    overrides: [
      authAccessTokenProvider.overrideWith((ref) async => 'owner-token'),
      preferenceSourceProvider.overrideWithValue(source),
      rescueWriteSourceProvider.overrideWithValue(_NoopRescueSource()),
    ],
  );
}

class _PersistentSource implements PreferenceSource {
  NotificationPreferences notification = NotificationPreferences(
    userId: _userId,
    version: 1,
    nearbyLostCases: true,
    chatMessages: true,
    adoptionUpdates: true,
    quietHoursEnabled: false,
    updatedAt: _now,
  );
  PrivacyDefaults privacy = PrivacyDefaults(
    userId: _userId,
    version: 1,
    hideHouseNumber: true,
    hidePhoneByDefault: true,
    reviewMediaBeforePublish: true,
    updatedAt: _now,
  );

  @override
  Future<NotificationPreferences> getNotificationPreferences({
    required String accessToken,
  }) async => notification;

  @override
  Future<PrivacyDefaults> getPrivacyDefaults({
    required String accessToken,
  }) async => privacy;

  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences, {
    required String accessToken,
  }) async {
    notification = NotificationPreferences(
      userId: preferences.userId,
      version: preferences.version + 1,
      nearbyLostCases: preferences.nearbyLostCases,
      chatMessages: preferences.chatMessages,
      adoptionUpdates: preferences.adoptionUpdates,
      quietHoursEnabled: preferences.quietHoursEnabled,
      quietHoursStart: preferences.quietHoursStart,
      quietHoursEnd: preferences.quietHoursEnd,
      updatedAt: _now,
    );
    return notification;
  }

  @override
  Future<PrivacyDefaults> updatePrivacyDefaults(
    PrivacyDefaults defaults, {
    required String accessToken,
  }) async {
    privacy = PrivacyDefaults(
      userId: defaults.userId,
      version: defaults.version + 1,
      hideHouseNumber: defaults.hideHouseNumber,
      hidePhoneByDefault: defaults.hidePhoneByDefault,
      reviewMediaBeforePublish: defaults.reviewMediaBeforePublish,
      updatedAt: _now,
    );
    return privacy;
  }
}

class _NoopRescueSource implements RescueWriteSource {
  @override
  Future<RescueDraft> createDraft({
    required String accessToken,
    String source = 'rescue_home',
  }) async => const RescueDraft(draftId: 'day63-draft', version: 1);

  @override
  Future<RescueCaseDetail> publishDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
  }) async => sampleCaseDetail(caseId: 'day63-published');

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
  }) async => media.copyWith(mediaId: 'day63-media', uploaded: true);
}
