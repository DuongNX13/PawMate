import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_create_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_write_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_draft_models.dart';

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
      expect(await notifier.publish(), isTrue);
      expect(source.published, isTrue);
      expect(container.read(rescueCreateProvider).published, isTrue);
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
}

class _FakeRescueWriteSource implements RescueWriteSource {
  bool failUpdates = false;
  bool published = false;
  int version = 1;

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
    if (failUpdates) {
      throw const RescueWriteApiException(
        'Không thể lưu bản nháp. Dữ liệu đang giữ trên màn hình.',
        code: 'NETWORK',
      );
    }
    version += 1;
    return RescueDraft.fromJson({
      'draftId': draftId,
      'version': version,
      ...patch,
    });
  }

  @override
  Future<void> publishDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
  }) async {
    published = true;
  }

  @override
  Future<RescueDraftMedia> uploadMedia({
    required String accessToken,
    required RescueDraftMedia media,
  }) async => media.copyWith(mediaId: 'media-1', uploaded: true);
}
