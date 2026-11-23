import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_session_coordinator.dart';
import '../data/preference_api.dart';
import '../domain/preference_models.dart';

final notificationPreferencesProvider =
    AsyncNotifierProvider<
      NotificationPreferencesNotifier,
      NotificationPreferences
    >(NotificationPreferencesNotifier.new);

final privacyDefaultsProvider =
    AsyncNotifierProvider<PrivacyDefaultsNotifier, PrivacyDefaults>(
      PrivacyDefaultsNotifier.new,
    );

class NotificationPreferencesNotifier
    extends AsyncNotifier<NotificationPreferences> {
  NotificationPreferences? lastSuccessful;
  int _scopeGeneration = 0;

  @override
  Future<NotificationPreferences> build() async {
    final generation = ++_scopeGeneration;
    lastSuccessful = null;
    ref.onDispose(() {
      ++_scopeGeneration;
      lastSuccessful = null;
    });
    ref.watch(authSessionRevisionProvider);
    final accessToken = await ref.watch(authAccessTokenProvider.future);
    if (accessToken == null || accessToken.trim().isEmpty) {
      throw const PreferenceApiException(
        'Bạn cần đăng nhập để quản lý cài đặt thông báo.',
        code: 'AUTH_REQUIRED',
        statusCode: 401,
      );
    }
    final loaded = await ref
        .watch(preferenceSourceProvider)
        .getNotificationPreferences(accessToken: accessToken.trim());
    if (ref.mounted && generation == _scopeGeneration) {
      lastSuccessful = loaded;
    }
    return loaded;
  }

  Future<bool> save(NotificationPreferences preferences) async {
    final generation = _scopeGeneration;
    state = const AsyncLoading<NotificationPreferences>();
    try {
      final accessToken = await ref.read(authAccessTokenProvider.future);
      if (!ref.mounted || generation != _scopeGeneration) return false;
      if (accessToken == null || accessToken.trim().isEmpty) {
        throw const PreferenceApiException(
          'Phiên đăng nhập đã hết hạn.',
          code: 'AUTH_REQUIRED',
          statusCode: 401,
        );
      }
      final saved = await ref
          .read(preferenceSourceProvider)
          .updateNotificationPreferences(
            preferences,
            accessToken: accessToken.trim(),
          );
      if (!ref.mounted || generation != _scopeGeneration) return false;
      lastSuccessful = saved;
      state = AsyncData(saved);
      return true;
    } on Object catch (error, stackTrace) {
      if (!ref.mounted || generation != _scopeGeneration) return false;
      state = AsyncValue<NotificationPreferences>.error(error, stackTrace);
      return false;
    }
  }
}

class PrivacyDefaultsNotifier extends AsyncNotifier<PrivacyDefaults> {
  PrivacyDefaults? lastSuccessful;
  int _scopeGeneration = 0;

  @override
  Future<PrivacyDefaults> build() async {
    final generation = ++_scopeGeneration;
    lastSuccessful = null;
    ref.onDispose(() {
      ++_scopeGeneration;
      lastSuccessful = null;
    });
    ref.watch(authSessionRevisionProvider);
    final accessToken = await ref.watch(authAccessTokenProvider.future);
    if (accessToken == null || accessToken.trim().isEmpty) {
      throw const PreferenceApiException(
        'Bạn cần đăng nhập để quản lý quyền riêng tư.',
        code: 'AUTH_REQUIRED',
        statusCode: 401,
      );
    }
    final loaded = await ref
        .watch(preferenceSourceProvider)
        .getPrivacyDefaults(accessToken: accessToken.trim());
    if (ref.mounted && generation == _scopeGeneration) {
      lastSuccessful = loaded;
    }
    return loaded;
  }

  Future<bool> save(PrivacyDefaults defaults) async {
    final generation = _scopeGeneration;
    state = const AsyncLoading<PrivacyDefaults>();
    try {
      final accessToken = await ref.read(authAccessTokenProvider.future);
      if (!ref.mounted || generation != _scopeGeneration) return false;
      if (accessToken == null || accessToken.trim().isEmpty) {
        throw const PreferenceApiException(
          'Phiên đăng nhập đã hết hạn.',
          code: 'AUTH_REQUIRED',
          statusCode: 401,
        );
      }
      final saved = await ref
          .read(preferenceSourceProvider)
          .updatePrivacyDefaults(defaults, accessToken: accessToken.trim());
      if (!ref.mounted || generation != _scopeGeneration) return false;
      lastSuccessful = saved;
      state = AsyncData(saved);
      return true;
    } on Object catch (error, stackTrace) {
      if (!ref.mounted || generation != _scopeGeneration) return false;
      state = AsyncValue<PrivacyDefaults>.error(error, stackTrace);
      return false;
    }
  }
}
