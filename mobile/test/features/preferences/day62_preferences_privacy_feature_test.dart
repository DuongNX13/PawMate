import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/preferences/application/preference_providers.dart';
import 'package:pawmate_mobile/features/preferences/application/privacy_surface_policy.dart';
import 'package:pawmate_mobile/features/preferences/data/preference_api.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';

const _userId = '62000000-0000-4000-8000-000000000001';
final _updatedAt = DateTime.utc(2026, 7, 29, 11, 30);

void main() {
  test(
    'D111-AUTH-02 a late save cannot restore the previous owner cache',
    () async {
      final source = _PersistentPreferenceSource();
      String? token = 'owner-token';
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          authAccessTokenProvider.overrideWith((ref) async => token),
          preferenceSourceProvider.overrideWithValue(source),
        ],
      );
      addTearDown(container.dispose);
      final signedOut = Completer<Object>();
      final subscription = container.listen(notificationPreferencesProvider, (
        _,
        next,
      ) {
      if (next.hasError && !signedOut.isCompleted) {
        signedOut.complete(next.error!);
      }
      });
      addTearDown(subscription.close);
      final loaded = await container.read(
        notificationPreferencesProvider.future,
      );
      source.pendingNotificationSave = Completer<NotificationPreferences>();
      final saveStarted = Completer<void>();
      source.notificationSaveStarted = saveStarted;
      final pendingSave = container
          .read(notificationPreferencesProvider.notifier)
          .save(loaded.copyWith(nearbyLostCases: false));
      await saveStarted.future.timeout(const Duration(seconds: 5));
      token = null;
      container.invalidate(authAccessTokenProvider);
      await signedOut.future.timeout(const Duration(seconds: 5));
      source.pendingNotificationSave!.complete(
        loaded.copyWith(nearbyLostCases: false),
      );
      expect(await pendingSave, isFalse);
      expect(container.read(notificationPreferencesProvider).hasError, isTrue);
      expect(
        container.read(notificationPreferencesProvider.notifier).lastSuccessful,
        isNull,
      );
    },
  );

  test(
    'D111-AUTH-01 owner cache is cleared when the session disappears',
    () async {
      final source = _PersistentPreferenceSource();
      String? token = 'owner-token';
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          authAccessTokenProvider.overrideWith((ref) async => token),
          preferenceSourceProvider.overrideWithValue(source),
        ],
      );
      addTearDown(container.dispose);
      final notificationError = Completer<Object>();
      final privacyError = Completer<Object>();
      final notificationSubscription = container.listen(
        notificationPreferencesProvider,
        (_, next) {
          if (next.hasError && !notificationError.isCompleted) {
            notificationError.complete(next.error!);
          }
        },
      );
      final privacySubscription = container.listen(privacyDefaultsProvider, (
        _,
        next,
      ) {
        if (next.hasError && !privacyError.isCompleted) {
          privacyError.complete(next.error!);
        }
      });
      addTearDown(notificationSubscription.close);
      addTearDown(privacySubscription.close);
      final notification = await container.read(
        notificationPreferencesProvider.future,
      );
      final privacy = await container.read(privacyDefaultsProvider.future);
      expect(
        container.read(notificationPreferencesProvider.notifier).lastSuccessful,
        notification,
      );
      expect(
        container.read(privacyDefaultsProvider.notifier).lastSuccessful,
        privacy,
      );
      token = null;
      container.invalidate(authAccessTokenProvider);
      expect(
        await notificationError.future.timeout(const Duration(seconds: 5)),
        isA<PreferenceApiException>(),
      );
      expect(
        await privacyError.future.timeout(const Duration(seconds: 5)),
        isA<PreferenceApiException>(),
      );
      expect(
        container.read(notificationPreferencesProvider.notifier).lastSuccessful,
        isNull,
      );
      expect(
        container.read(privacyDefaultsProvider.notifier).lastSuccessful,
        isNull,
      );
    },
  );

  test(
    'D62-AUTH-01 both owner providers fail closed without a token',
    () async {
      final source = _PersistentPreferenceSource();
      final container = ProviderContainer(
        overrides: [
          authAccessTokenProvider.overrideWith((ref) async => null),
          preferenceSourceProvider.overrideWithValue(source),
        ],
      );
      addTearDown(container.dispose);
      final notificationError = Completer<Object>();
      final privacyError = Completer<Object>();
      final notificationSubscription = container.listen(
        notificationPreferencesProvider,
        (_, next) {
          if (next.hasError && !notificationError.isCompleted) {
            notificationError.complete(next.error!);
          }
        },
        fireImmediately: true,
      );
      final privacySubscription = container.listen(privacyDefaultsProvider, (
        _,
        next,
      ) {
        if (next.hasError && !privacyError.isCompleted) {
          privacyError.complete(next.error!);
        }
      }, fireImmediately: true);
      addTearDown(notificationSubscription.close);
      addTearDown(privacySubscription.close);

      await expectLater(
        notificationError.future,
        completion(
          isA<PreferenceApiException>()
              .having((error) => error.statusCode, 'statusCode', 401)
              .having((error) => error.code, 'code', 'AUTH_REQUIRED'),
        ),
      );
      await expectLater(
        privacyError.future,
        completion(
          isA<PreferenceApiException>()
              .having((error) => error.statusCode, 'statusCode', 401)
              .having((error) => error.code, 'code', 'AUTH_REQUIRED'),
        ),
      );
      expect(source.readCalls, 0);
    },
  );

  test(
    'D62-PERSIST-01 notification and privacy values survive provider restart',
    () async {
      final source = _PersistentPreferenceSource();
      final first = _ownerContainer(source);

      final notification = await first.read(
        notificationPreferencesProvider.future,
      );
      final privacy = await first.read(privacyDefaultsProvider.future);
      expect(
        await first
            .read(notificationPreferencesProvider.notifier)
            .save(
              notification.copyWith(
                nearbyLostCases: false,
                quietHoursEnabled: true,
                quietHoursStart: '21:30',
                quietHoursEnd: '06:30',
              ),
            ),
        isTrue,
      );
      expect(
        await first
            .read(privacyDefaultsProvider.notifier)
            .save(
              privacy.copyWith(
                hideHouseNumber: false,
                hidePhoneByDefault: false,
                reviewMediaBeforePublish: false,
              ),
            ),
        isTrue,
      );
      first.dispose();

      final reopened = _ownerContainer(source);
      addTearDown(reopened.dispose);
      final reloadedNotification = await reopened.read(
        notificationPreferencesProvider.future,
      );
      final reloadedPrivacy = await reopened.read(
        privacyDefaultsProvider.future,
      );

      expect(reloadedNotification.version, 2);
      expect(reloadedNotification.nearbyLostCases, isFalse);
      expect(reloadedNotification.quietHoursEnabled, isTrue);
      expect(reloadedNotification.quietHoursStart, '21:30');
      expect(reloadedNotification.quietHoursEnd, '06:30');
      expect(reloadedPrivacy.version, 2);
      expect(reloadedPrivacy.hideHouseNumber, isFalse);
      expect(reloadedPrivacy.hidePhoneByDefault, isFalse);
      expect(reloadedPrivacy.reviewMediaBeforePublish, isFalse);
    },
  );

  test('D62-PRIV-01 all eight privacy combinations map without drift', () {
    for (var mask = 0; mask < 8; mask += 1) {
      final hideHouse = mask & 1 != 0;
      final hidePhone = mask & 2 != 0;
      final reviewMedia = mask & 4 != 0;
      final policy = PrivacySurfacePolicy.fromDefaults(
        PrivacyDefaults(
          userId: _userId,
          version: mask + 1,
          hideHouseNumber: hideHouse,
          hidePhoneByDefault: hidePhone,
          reviewMediaBeforePublish: reviewMedia,
          updatedAt: _updatedAt,
        ),
      );

      expect(policy.hideHouseNumber, hideHouse, reason: 'mask=$mask');
      expect(policy.hidePhoneByDefault, hidePhone, reason: 'mask=$mask');
      expect(
        policy.reviewMediaBeforePublish,
        reviewMedia,
        reason: 'mask=$mask',
      );
      expect(
        policy.redactHouseNumber('12 Lê Lợi, Quận 1'),
        hideHouse ? 'Lê Lợi, Quận 1' : '12 Lê Lợi, Quận 1',
        reason: 'mask=$mask',
      );
      expect(
        policy.requiresPhoneConsent('Gọi 0901234567'),
        hidePhone,
        reason: 'mask=$mask',
      );
      expect(
        policy.requiresMediaReview(const ['photo.jpg']),
        reviewMedia,
        reason: 'mask=$mask',
      );
    }
  });
}

ProviderContainer _ownerContainer(PreferenceSource source) {
  return ProviderContainer(
    overrides: [
      authAccessTokenProvider.overrideWith((ref) async => 'owner-token'),
      preferenceSourceProvider.overrideWithValue(source),
    ],
  );
}

class _PersistentPreferenceSource implements PreferenceSource {
  var readCalls = 0;
  Completer<NotificationPreferences>? pendingNotificationSave;
  Completer<void>? notificationSaveStarted;
  NotificationPreferences notification = NotificationPreferences(
    userId: _userId,
    version: 1,
    nearbyLostCases: true,
    chatMessages: true,
    adoptionUpdates: true,
    quietHoursEnabled: false,
    updatedAt: _updatedAt,
  );
  PrivacyDefaults privacy = PrivacyDefaults(
    userId: _userId,
    version: 1,
    hideHouseNumber: true,
    hidePhoneByDefault: true,
    reviewMediaBeforePublish: true,
    updatedAt: _updatedAt,
  );

  @override
  Future<NotificationPreferences> getNotificationPreferences({
    required String accessToken,
  }) async {
    readCalls += 1;
    return notification;
  }

  @override
  Future<PrivacyDefaults> getPrivacyDefaults({
    required String accessToken,
  }) async {
    readCalls += 1;
    return privacy;
  }

  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences, {
    required String accessToken,
  }) async {
    notificationSaveStarted?.complete();
    if (pendingNotificationSave != null) return pendingNotificationSave!.future;
    notification = NotificationPreferences(
      userId: preferences.userId,
      version: preferences.version + 1,
      nearbyLostCases: preferences.nearbyLostCases,
      chatMessages: preferences.chatMessages,
      adoptionUpdates: preferences.adoptionUpdates,
      quietHoursEnabled: preferences.quietHoursEnabled,
      quietHoursStart: preferences.quietHoursStart,
      quietHoursEnd: preferences.quietHoursEnd,
      updatedAt: _updatedAt,
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
      updatedAt: _updatedAt,
    );
    return privacy;
  }
}
