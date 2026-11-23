import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/preferences/data/preference_api.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_comment_api.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_comment_screen.dart';

import '../../test_support/ui_test_helpers.dart';
import '../rescue/rescue_comment_test_fixtures.dart';
import '../rescue/rescue_test_fixtures.dart';

void main() {
  testWidgets('Rescue comment requires consent before sharing a phone number', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final comments = FakeRescueCommentSource(comments: const []);
    final preferences = _PrivacyPreferenceSource();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferenceSourceProvider.overrideWithValue(preferences),
          authAccessTokenProvider.overrideWith((ref) async => 'owner-token'),
          rescueCommentSourceProvider.overrideWithValue(comments),
          rescueApiProvider.overrideWithValue(
            FakeRescueSource(detail: sampleCaseDetail()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RescueCommentScreen(caseId: sampleCommentCaseId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('rescue-comment-field')),
      'Gọi mình theo số 090 123 4567',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('rescue-comment-send')));
    await tester.pump();

    expect(
      find.byKey(const Key('rescue-comment-privacy-confirmation')),
      findsOneWidget,
    );
    expect(comments.sentBodies, isEmpty);

    await tester.tap(
      find.byKey(const Key('rescue-comment-privacy-confirm-send')),
    );
    await tester.pumpAndSettle();

    expect(comments.sentBodies, ['Gọi mình theo số 090 123 4567']);
    expectNoFlutterOverflow(tester);
  });
}

class _PrivacyPreferenceSource implements PreferenceSource {
  @override
  Future<PrivacyDefaults> getPrivacyDefaults({
    required String accessToken,
  }) async => PrivacyDefaults(
    userId: 'owner-1',
    version: 1,
    hideHouseNumber: true,
    hidePhoneByDefault: true,
    reviewMediaBeforePublish: true,
    updatedAt: DateTime.utc(2026, 7, 29),
  );

  @override
  Future<NotificationPreferences> getNotificationPreferences({
    required String accessToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences, {
    required String accessToken,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PrivacyDefaults> updatePrivacyDefaults(
    PrivacyDefaults defaults, {
    required String accessToken,
  }) async => defaults;
}
