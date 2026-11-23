import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_create_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_write_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_draft_models.dart';

import 'rescue_test_fixtures.dart';

void main() {
  test('media policy mirrors Rescue upload limits', () {
    expect(RescueMediaPolicy.isSupported('image/jpeg'), isTrue);
    expect(RescueMediaPolicy.isSupported('video/mp4'), isTrue);
    expect(RescueMediaPolicy.isSupported('image/gif'), isFalse);
    expect(RescueMediaPolicy.maxBytesFor('image/jpeg'), 10 * 1024 * 1024);
    expect(RescueMediaPolicy.maxBytesFor('video/mp4'), 50 * 1024 * 1024);
    expect(RescueMediaPolicy.maxItems, 5);
  });

  test(
    'draft validation keeps exact location private and enforces publish media',
    () {
      final draft = RescueDraft(
        petName: 'Mochi',
        breedOrColor: 'Poodle trắng kem',
        lostAt: DateTime.utc(2026, 7, 23, 10, 30),
        exactLocation: const RescueDraftLocation(
          latitude: 10.7769,
          longitude: 106.7009,
          formattedAddress: 'Khu vực Quận 1',
        ),
        identifyingFeatures: 'Vòng cổ đỏ',
      );

      expect(draft.validateStepOne(), isEmpty);
      expect(draft.validateStepTwo(), contains('media'));
      expect(
        draft
            .copyWith(
              media: const [
                RescueDraftMedia(
                  path: 'fixture.jpg',
                  mimeType: 'image/jpeg',
                  sizeBytes: 1024,
                ),
              ],
            )
            .validateStepTwo(),
        isEmpty,
      );
      expect(
        draft.toStepOnePatchJson(),
        containsPair('exactLocation', isNotNull),
      );
      expect(draft.toStepOnePatchJson(), isNot(contains('ownerUserId')));
    },
  );

  test(
    'draft provider creates, patches and publishes without losing draft on error',
    () async {
      final source = _FakeRescueWriteSource();
      final container = ProviderContainer(
        overrides: [
          rescueWriteSourceProvider.overrideWithValue(source),
          authAccessTokenProvider.overrideWith((ref) async => 'token'),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(rescueCreateProvider.notifier);
      notifier.setPetName('Mochi');
      notifier.setBreedOrColor('Poodle trắng kem');
      notifier.setLostAt(DateTime.utc(2026, 7, 23, 10, 30));
      notifier.setLocation(
        const RescueDraftLocation(latitude: 10.7769, longitude: 106.7009),
      );

      expect(await notifier.continueToDetails(), isTrue);
      expect(container.read(rescueCreateProvider).draft.draftId, 'draft-1');
      expect(container.read(rescueCreateProvider).draft.version, 2);

      notifier.setIdentifyingFeatures('Vòng cổ đỏ');
      notifier.setMedia([
        const RescueDraftMedia(
          path: 'fixture.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 1024,
        ),
      ]);
      notifier.confirmMediaReview(true);
      expect(notifier.confirmReportReview(), isTrue);
      expect(await notifier.publish(), isTrue);
      expect(source.published, isTrue);
      expect(container.read(rescueCreateProvider).published, isTrue);
    },
  );

  test(
    'D114-ST12-01 saving step one preserves previously selected local media',
    () async {
      final source = _FakeRescueWriteSource();
      final container = ProviderContainer(
        overrides: [
          rescueWriteSourceProvider.overrideWithValue(source),
          authAccessTokenProvider.overrideWith((ref) async => 'token'),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(rescueCreateProvider.notifier);
      const media = RescueDraftMedia(
        path: 'picked-before-continue.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1024,
      );
      notifier
        ..setPetName('Mochi')
        ..setBreedOrColor('Poodle')
        ..setLostAt(DateTime.utc(2026, 10, 13))
        ..setLocation(
          const RescueDraftLocation(latitude: 10.7, longitude: 106.7),
        )
        ..setMedia([media]);

      expect(await notifier.continueToDetails(), isTrue);
      final draft = container.read(rescueCreateProvider).draft;
      expect(draft.version, 2);
      expect(draft.media, [media]);
      expect(draft.media.single.uploaded, isFalse);
      expect(source.published, isFalse);
    },
  );

  test(
    'D114-ST13-03 save-only keeps media and privacy without publication',
    () async {
      final source = _FakeRescueWriteSource();
      final container = ProviderContainer(
        overrides: [
          rescueWriteSourceProvider.overrideWithValue(source),
          authAccessTokenProvider.overrideWith((ref) async => 'token'),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(rescueCreateProvider.notifier);
      const media = RescueDraftMedia(
        path: 'save-only-local.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1024,
      );
      notifier
        ..setPetName('Mochi')
        ..setBreedOrColor('Poodle')
        ..setLostAt(DateTime.utc(2026, 10, 13))
        ..setLocation(
          const RescueDraftLocation(latitude: 10.7, longitude: 106.7),
        )
        ..setIdentifyingFeatures('Vòng cổ đỏ')
        ..setBehaviorHint('Hiền')
        ..setMedia([media])
        ..setHideHouseNumber(false);
      final before = container.read(rescueCreateProvider);

      expect(await notifier.saveDraft(), isTrue);
      final after = container.read(rescueCreateProvider);
      expect(source.updateCalls, 1);
      expect(source.lastExpectedVersion, 1);
      expect(source.lastPatch?['petName'], 'Mochi');
      expect(source.lastPatch?['identifyingFeatures'], 'Vòng cổ đỏ');
      expect(source.lastPatch?['behaviorHint'], 'Hiền');
      expect(source.lastPatch?['contactPreference'], 'in_app');
      expect(source.lastPatch?['mediaIds'], isEmpty);
      expect(source.uploadCalls, 0);
      expect(source.published, isFalse);
      expect(after.published, isFalse);
      expect(after.draft.media, [media]);
      expect(after.draft.version, 2);
      expect(after.hideHouseNumber, before.hideHouseNumber);
      expect(after.hidePhoneByDefault, before.hidePhoneByDefault);
      expect(after.mediaReviewConfirmed, before.mediaReviewConfirmed);
    },
  );

  test(
    'D114-ST12-04 save failure and retry keep the same local draft',
    () async {
      final source = _FakeRescueWriteSource()..failUpdates = true;
      final container = ProviderContainer(
        overrides: [
          rescueWriteSourceProvider.overrideWithValue(source),
          authAccessTokenProvider.overrideWith((ref) async => 'token'),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(rescueCreateProvider.notifier);
      const media = RescueDraftMedia(
        path: 'retry-local.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1024,
      );
      notifier
        ..setPetName('Mochi')
        ..setIdentifyingFeatures('Vòng cổ đỏ')
        ..setMedia([media]);
      expect(await notifier.saveDraft(), isFalse);
      expect(container.read(rescueCreateProvider).draft.media, [media]);
      expect(
        container.read(rescueCreateProvider).draft.identifyingFeatures,
        'Vòng cổ đỏ',
      );
      expect(container.read(rescueCreateProvider).isBusy, isFalse);
      expect(
        container.read(rescueCreateProvider).errorMessage,
        contains('giữ'),
      );

      source.failUpdates = false;
      expect(await notifier.saveDraft(), isTrue);
      expect(container.read(rescueCreateProvider).draft.media, [media]);
      expect(source.lastExpectedVersion, 1);
      expect(source.uploadCalls, 0);
      expect(source.published, isFalse);
    },
  );

  test(
    'D114-ST12-05 a stale session response cannot restore private draft media',
    () async {
      final source = _FakeRescueWriteSource()..updateGate = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          rescueWriteSourceProvider.overrideWithValue(source),
          authAccessTokenProvider.overrideWith(
            (ref) async => 'old-owner-token',
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(rescueCreateProvider.notifier);
      notifier
        ..setPetName('Old owner')
        ..setMedia([
          const RescueDraftMedia(
            path: 'old-owner.jpg',
            mimeType: 'image/jpeg',
            sizeBytes: 1024,
          ),
        ]);
      final pending = notifier.saveDraft();
      await source.updateStarted.future;
      expect(await notifier.saveDraft(), isFalse);
      expect(source.updateCalls, 1);
      container.read(authSessionRevisionProvider.notifier).bump();
      source.updateGate!.complete();
      expect(await pending, isFalse);
      expect(container.read(rescueCreateProvider).draft.petName, isEmpty);
      expect(container.read(rescueCreateProvider).draft.media, isEmpty);
      expect(container.read(rescueCreateProvider).isBusy, isFalse);
    },
  );

  test(
    'D114-ST12-06 mismatched identity or stale version cannot replace a draft',
    () async {
      for (final wrongIdentity in [true, false]) {
        final source = _FakeRescueWriteSource()
          ..returnWrongIdentity = wrongIdentity
          ..returnStaleVersion = !wrongIdentity;
        final container = ProviderContainer(
          overrides: [
            rescueWriteSourceProvider.overrideWithValue(source),
            authAccessTokenProvider.overrideWith((ref) async => 'token'),
          ],
        );
        final notifier = container.read(rescueCreateProvider.notifier);
        const media = RescueDraftMedia(
          path: 'keep.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 1024,
        );
        notifier
          ..setPetName('Keep name')
          ..setMedia([media]);
        expect(await notifier.saveDraft(), isFalse);
        expect(container.read(rescueCreateProvider).draft.draftId, 'draft-1');
        expect(container.read(rescueCreateProvider).draft.version, 1);
        expect(container.read(rescueCreateProvider).draft.petName, 'Keep name');
        expect(container.read(rescueCreateProvider).draft.media, [media]);
        expect(container.read(rescueCreateProvider).isBusy, isFalse);
        container.dispose();
      }
    },
  );

  test(
    'network failure retains the typed draft and exposes retryable error',
    () async {
      final source = _FakeRescueWriteSource()..failUpdates = true;
      final container = ProviderContainer(
        overrides: [
          rescueWriteSourceProvider.overrideWithValue(source),
          authAccessTokenProvider.overrideWith((ref) async => 'token'),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(rescueCreateProvider.notifier);
      notifier.setPetName('Bắp');
      notifier.setBreedOrColor('Golden');
      notifier.setLostAt(DateTime.utc(2026, 7, 23, 10, 30));
      notifier.setLocation(
        const RescueDraftLocation(latitude: 10.77, longitude: 106.7),
      );

      expect(await notifier.continueToDetails(), isFalse);
      final state = container.read(rescueCreateProvider);
      expect(state.draft.petName, 'Bắp');
      expect(state.errorMessage, contains('giữ'));
    },
  );

  test(
    'publish failure after a draft patch retains uploaded media for retry',
    () async {
      final source = _FakeRescueWriteSource()..failPublishes = true;
      final container = ProviderContainer(
        overrides: [
          rescueWriteSourceProvider.overrideWithValue(source),
          authAccessTokenProvider.overrideWith((ref) async => 'token'),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(rescueCreateProvider.notifier);
      notifier
        ..setPetName('Mochi')
        ..setBreedOrColor('Poodle')
        ..setLostAt(DateTime.utc(2026, 9, 4))
        ..setLocation(
          const RescueDraftLocation(latitude: 10.7, longitude: 106.7),
        )
        ..setIdentifyingFeatures('Vòng cổ đỏ')
        ..setMedia([
          const RescueDraftMedia(
            path: 'fixture.jpg',
            mimeType: 'image/jpeg',
            sizeBytes: 1024,
          ),
        ])
        ..confirmMediaReview(true);

      expect(notifier.confirmReportReview(), isTrue);
      expect(await notifier.publish(), isFalse);
      expect(container.read(rescueCreateProvider).draft.media, hasLength(1));
      expect(
        container.read(rescueCreateProvider).draft.media.single,
        isA<RescueDraftMedia>()
            .having((media) => media.mediaId, 'mediaId', 'media-1')
            .having((media) => media.uploaded, 'uploaded', isTrue),
      );

      source.failPublishes = false;
      expect(notifier.confirmReportReview(), isTrue);
      expect(await notifier.publish(), isTrue);
    },
  );
}

class _FakeRescueWriteSource implements RescueWriteSource {
  bool failUpdates = false;
  bool failPublishes = false;
  bool published = false;
  int version = 1;
  int updateCalls = 0;
  int uploadCalls = 0;
  int? lastExpectedVersion;
  Map<String, Object?>? lastPatch;
  Completer<void>? updateGate;
  final updateStarted = Completer<void>();
  bool returnWrongIdentity = false;
  bool returnStaleVersion = false;

  @override
  Future<RescueDraft> createDraft({
    required String accessToken,
    String source = 'rescue_home',
  }) async => RescueDraft(draftId: 'draft-1', version: version);

  @override
  Future<RescueDraft> updateDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
    required Map<String, Object?> patch,
  }) async {
    updateCalls += 1;
    lastExpectedVersion = expectedVersion;
    lastPatch = Map.of(patch);
    if (!updateStarted.isCompleted) updateStarted.complete();
    if (updateGate != null) await updateGate!.future;
    if (failUpdates) {
      throw const RescueWriteApiException(
        'Không thể lưu bản nháp. Dữ liệu đang giữ trên màn hình.',
        code: 'NETWORK',
      );
    }
    version += 1;
    return RescueDraft.fromJson({
      'draftId': returnWrongIdentity ? 'other-owner-draft' : draftId,
      'version': returnStaleVersion ? expectedVersion : version,
      ...patch,
    });
  }

  @override
  Future<RescueCaseDetail> publishDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
  }) async {
    if (failPublishes) throw StateError('publish unavailable');
    published = true;
    return sampleCaseDetail(caseId: 'create-provider-published');
  }

  @override
  Future<RescueDraftMedia> uploadMedia({
    required String accessToken,
    required RescueDraftMedia media,
  }) async {
    uploadCalls += 1;
    return media.copyWith(mediaId: 'media-1', uploaded: true);
  }
}
