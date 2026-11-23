import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_create_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_write_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_draft_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_info_form_screen.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../test_support/day120_privacy_fixture.dart';
import 'package:pawmate_mobile/features/preferences/application/preference_providers.dart';
import 'rescue_test_fixtures.dart';

void seedReviewDraft(RescueCreateNotifier notifier) {
  notifier
    ..setPetName('Mochi')
    ..setBreedOrColor('Poodle trắng kem')
    ..setLostAt(DateTime(2026, 9, 4, 9))
    ..setLocation(
      const RescueDraftLocation(
        latitude: 10.77,
        longitude: 106.7,
        formattedAddress: '120 Nguyễn Lương Bằng, Quận 7',
      ),
    )
    ..setIdentifyingFeatures('Vòng cổ đỏ, bốn chân trắng')
    ..setBehaviorHint('Mochi\nTính cách: Hiền')
    ..setMedia(const [
      RescueDraftMedia(
        path: 'fixture.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 100,
      ),
    ])
    ..confirmMediaReview(true);
}

class ReviewWriteSource implements RescueWriteSource {
  int publishes = 0;
  bool failPublish = false;
  final patches = <Map<String, Object?>>[];
  Map<String, Object?> stored = {};
  @override
  Future<RescueDraft> createDraft({
    required String accessToken,
    String source = 'rescue_home',
  }) async => const RescueDraft(draftId: 'draft', version: 1);
  @override
  Future<RescueDraft> updateDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
    required Map<String, Object?> patch,
  }) async {
    patches.add(patch);
    stored.addAll(patch);
    return RescueDraft.fromJson({
      'draftId': draftId,
      'version': expectedVersion + 1,
      ...stored,
    });
  }

  @override
  Future<RescueCaseDetail> publishDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
  }) async {
    publishes++;
    if (failPublish) {
      throw const RescueWriteApiException(
        'Mất kết nối. Hãy thử lại.',
        code: 'NETWORK',
      );
    }
    return sampleCaseDetail(caseId: 'day102-published');
  }

  @override
  Future<RescueDraftMedia> uploadMedia({
    required String accessToken,
    required RescueDraftMedia media,
  }) async => media.copyWith(mediaId: 'media', uploaded: true);
}

Future<ProviderContainer> pumpReviewForm(
  WidgetTester tester,
  ReviewWriteSource source, {
  Size size = const Size(390, 844),
  double scale = 1,
  bool seed = true,
  bool localPrivacy = false,
}) async {
  await setTestViewport(tester, size: size);
  final container = ProviderContainer(
    overrides: [
      rescueWriteSourceProvider.overrideWithValue(source),
      if (localPrivacy)
        privacyDefaultsProvider.overrideWith(Day120PrivacyFixture.new),
      authAccessTokenProvider.overrideWith((ref) async => 'test-token'),
    ],
  );
  addTearDown(container.dispose);
  if (seed) seedReviewDraft(container.read(rescueCreateProvider.notifier));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        debugShowCheckedModeBanner: false,
        builder: testTextScaleBuilder(scale),
        home: const RescueInfoFormScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  testWidgets(
    'Day102 form opens review without publishing and back retains draft',
    (tester) async {
      final source = ReviewWriteSource()..failPublish = true;
      final container = await pumpReviewForm(tester, source);
      await tester.tap(find.byKey(const Key('rescue-info-publish-cta')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('rescue-report-review-sheet')),
        findsOneWidget,
      );
      expect(source.publishes, 0);
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('rescue-review-back'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rescue-review-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('rescue-report-review-sheet')), findsNothing);
      expect(
        container.read(rescueCreateProvider).draft.behaviorHint,
        'Mochi\nTính cách: Hiền',
      );
      expect(container.read(rescueCreateProvider).draft.media, hasLength(1));
    },
  );

  testWidgets(
    'invalid review lists missing data and disables publish at large text',
    (tester) async {
      final source = ReviewWriteSource();
      await pumpReviewForm(
        tester,
        source,
        seed: false,
        size: const Size(320, 568),
        scale: 2,
      );
      await tester.tap(find.byKey(const Key('rescue-info-publish-cta')));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('rescue-review-validation'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập đặc điểm nhận dạng.'), findsOneWidget);
      expect(
        tester
            .widget<PawMateButton>(
              find.byKey(const Key('rescue-review-confirm')),
            )
            .onPressed,
        isNull,
      );
      expect(source.publishes, 0);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets(
    'privacy switches keep local choices and failure retains review for retry',
    (tester) async {
      final source = ReviewWriteSource()..failPublish = true;
      final container = await pumpReviewForm(tester, source);
      await tester.tap(find.byKey(const Key('rescue-info-publish-cta')));
      await tester.pumpAndSettle();
      expect(container.read(rescueCreateProvider).hideHouseNumber, isTrue);
      expect(
        container.read(rescueCreateProvider).draft.contactPreference,
        RescueContactPreference.inApp,
      );
      for (final key in ['rescue-review-phone', 'rescue-review-location']) {
        await Scrollable.ensureVisible(
          tester.element(find.byKey(Key(key))),
          alignment: .4,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }
      expect(container.read(rescueCreateProvider).hideHouseNumber, isFalse);
      expect(
        container.read(rescueCreateProvider).draft.contactPreference,
        RescueContactPreference.phoneWithConsent,
      );
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('rescue-review-confirm'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rescue-review-confirm')));
      await tester.pumpAndSettle();
      expect(source.publishes, 1);
      expect(find.text('Mất kết nối. Hãy thử lại.'), findsOneWidget);
      expect(
        find.byKey(const Key('rescue-report-review-sheet')),
        findsOneWidget,
      );
      expect(
        container.read(rescueCreateProvider).draft.media.single.uploaded,
        isTrue,
      );
      expectNoFlutterOverflow(tester);
    },
  );

  test(
    'publish requires current review; edits invalidate it; safe payload and duplicate prevention',
    () async {
      final source = ReviewWriteSource();
      final container = ProviderContainer(
        overrides: [
          rescueWriteSourceProvider.overrideWithValue(source),
          authAccessTokenProvider.overrideWith((ref) async => 'token'),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(rescueCreateProvider.notifier);
      seedReviewDraft(notifier);
      expect(await notifier.publish(), isFalse);
      expect(source.publishes, 0);
      expect(notifier.confirmReportReview(), isTrue);
      notifier.setBehaviorHint('Mochi\nTính cách: Nhút nhát');
      expect(await notifier.publish(), isFalse);
      expect(notifier.confirmReportReview(), isTrue);
      final first = notifier.publish();
      expect(await notifier.publish(), isFalse);
      expect(await first, isTrue);
      expect(source.publishes, 1);
      expect(source.patches.last['contactPreference'], 'in_app');
      expect(
        (source.patches.last['exactLocation'] as Map)['formattedAddress'],
        '120 Nguyễn Lương Bằng, Quận 7',
        reason:
            'The exact address is owner-only input; public APIs project an approximate area.',
      );
      expect(source.patches.last.keys, isNot(contains('publicExactLocation')));
    },
  );

  test(
    'phone in description blocks private-contact review and missing auth retains draft',
    () async {
      final source = ReviewWriteSource();
      final container = ProviderContainer(
        overrides: [
          rescueWriteSourceProvider.overrideWithValue(source),
          authAccessTokenProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(rescueCreateProvider.notifier);
      seedReviewDraft(notifier);
      notifier.setIdentifyingFeatures('Gọi 0901234567');
      expect(notifier.confirmReportReview(), isFalse);
      expect(
        notifier.reviewErrors,
        contains(
          'Hãy bỏ số điện thoại khỏi mô tả khi chỉ liên hệ trong PawMate.',
        ),
      );
      notifier.setIdentifyingFeatures('Vòng cổ đỏ');
      expect(notifier.confirmReportReview(), isTrue);
      expect(await notifier.publish(), isFalse);
      expect(container.read(rescueCreateProvider).isBusy, isFalse);
      expect(container.read(rescueCreateProvider).draft.petName, 'Mochi');
      expect(source.publishes, 0);
    },
  );

  testWidgets(
    'successful review publishes once then clears draft and returns home',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      final source = ReviewWriteSource();
      final container = ProviderContainer(
        overrides: [
          rescueWriteSourceProvider.overrideWithValue(source),
          authAccessTokenProvider.overrideWith((ref) async => 'token'),
        ],
      );
      addTearDown(container.dispose);
      seedReviewDraft(container.read(rescueCreateProvider.notifier));
      final router = GoRouter(
        initialLocation: '/form',
        routes: [
          GoRoute(
            path: '/form',
            builder: (_, _) => const RescueInfoFormScreen(),
          ),
          GoRoute(
            path: '/rescue',
            builder: (_, _) => const Scaffold(body: Text('Rescue home')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rescue-info-publish-cta')));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('rescue-review-confirm'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rescue-review-confirm')));
      await tester.pumpAndSettle();
      expect(source.publishes, 1);
      expect(find.text('Rescue home'), findsOneWidget);
      expect(container.read(rescueCreateProvider).draft.petName, isEmpty);
      expectNoFlutterOverflow(tester);
    },
  );
}
