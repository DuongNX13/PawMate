import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/application/auth_session_coordinator.dart';
import '../../preferences/application/privacy_surface_policy.dart';
import '../data/rescue_write_api.dart';
import '../domain/rescue_case_models.dart';
import '../domain/rescue_draft_models.dart';

@immutable
class RescueCreateState {
  const RescueCreateState({
    this.draft = const RescueDraft(),
    this.isBusy = false,
    this.errorMessage,
    this.published = false,
    this.publishedCase,
    this.privacyFingerprint = -1,
    this.hideHouseNumber = true,
    this.hidePhoneByDefault = true,
    this.reviewMediaBeforePublish = true,
    this.contactPreferenceTouched = false,
    this.mediaReviewConfirmed = false,
    this.locationPrivacyTouched = false,
  });

  final RescueDraft draft;
  final bool isBusy;
  final String? errorMessage;
  final bool published;
  final RescueCaseDetail? publishedCase;
  final int privacyFingerprint;
  final bool hideHouseNumber;
  final bool hidePhoneByDefault;
  final bool reviewMediaBeforePublish;
  final bool contactPreferenceTouched;
  final bool mediaReviewConfirmed;
  final bool locationPrivacyTouched;

  RescueCreateState copyWith({
    RescueDraft? draft,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
    bool? published,
    RescueCaseDetail? publishedCase,
    bool clearPublishedCase = false,
    int? privacyFingerprint,
    bool? hideHouseNumber,
    bool? hidePhoneByDefault,
    bool? reviewMediaBeforePublish,
    bool? contactPreferenceTouched,
    bool? mediaReviewConfirmed,
    bool? locationPrivacyTouched,
  }) => RescueCreateState(
    draft: draft ?? this.draft,
    isBusy: isBusy ?? this.isBusy,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    published: published ?? this.published,
    publishedCase: clearPublishedCase
        ? null
        : (publishedCase ?? this.publishedCase),
    privacyFingerprint: privacyFingerprint ?? this.privacyFingerprint,
    hideHouseNumber: hideHouseNumber ?? this.hideHouseNumber,
    hidePhoneByDefault: hidePhoneByDefault ?? this.hidePhoneByDefault,
    reviewMediaBeforePublish:
        reviewMediaBeforePublish ?? this.reviewMediaBeforePublish,
    contactPreferenceTouched:
        contactPreferenceTouched ?? this.contactPreferenceTouched,
    mediaReviewConfirmed: mediaReviewConfirmed ?? this.mediaReviewConfirmed,
    locationPrivacyTouched:
        locationPrivacyTouched ?? this.locationPrivacyTouched,
  );
}

final rescueCreateProvider =
    NotifierProvider<RescueCreateNotifier, RescueCreateState>(
      RescueCreateNotifier.new,
    );

class RescueCreateNotifier extends Notifier<RescueCreateState> {
  String? _reviewedFingerprint;
  var _sessionGeneration = 0;
  bool _mediaPickInProgress = false;
  RescueDraft get draft => state.draft;

  @override
  RescueCreateState build() {
    ref.listen<int>(authSessionRevisionProvider, (previous, next) {
      if (previous != null && previous != next) {
        _sessionGeneration += 1;
        _reviewedFingerprint = null;
        state = const RescueCreateState();
      }
    });
    ref.onDispose(() => _sessionGeneration += 1);
    return const RescueCreateState();
  }

  void setPetName(String value) =>
      state = state.copyWith(draft: state.draft.copyWith(petName: value));

  void setBreedOrColor(String value) =>
      state = state.copyWith(draft: state.draft.copyWith(breedOrColor: value));

  void setSpecies(RescueDraftSpecies value) =>
      state = state.copyWith(draft: state.draft.copyWith(species: value));

  void setLostAt(DateTime value) =>
      state = state.copyWith(draft: state.draft.copyWith(lostAt: value));

  void setLocation(RescueDraftLocation value) =>
      state = state.copyWith(draft: state.draft.copyWith(exactLocation: value));

  void setIdentifyingFeatures(String value) => state = state.copyWith(
    draft: state.draft.copyWith(identifyingFeatures: value),
  );

  void setBehaviorHint(String value) =>
      state = state.copyWith(draft: state.draft.copyWith(behaviorHint: value));

  void setContactPreference(RescueContactPreference value) =>
      state = state.copyWith(
        draft: state.draft.copyWith(contactPreference: value),
        contactPreferenceTouched: true,
      );

  void setMedia(List<RescueDraftMedia> media) => state = state.copyWith(
    draft: state.draft.copyWith(media: media),
    mediaReviewConfirmed: false,
  );

  void applyPrivacyPolicy(PrivacySurfacePolicy policy) {
    final fingerprint =
        (policy.hideHouseNumber ? 1 : 0) |
        (policy.hidePhoneByDefault ? 2 : 0) |
        (policy.reviewMediaBeforePublish ? 4 : 0);
    if (state.privacyFingerprint == fingerprint) return;
    final mediaReviewWasRequired = state.reviewMediaBeforePublish;
    final contactPreference = state.contactPreferenceTouched
        ? state.draft.contactPreference
        : policy.hidePhoneByDefault
        ? RescueContactPreference.inApp
        : RescueContactPreference.phoneWithConsent;
    state = state.copyWith(
      draft: state.draft.copyWith(contactPreference: contactPreference),
      privacyFingerprint: fingerprint,
      hideHouseNumber: state.locationPrivacyTouched
          ? state.hideHouseNumber
          : policy.hideHouseNumber,
      hidePhoneByDefault: policy.hidePhoneByDefault,
      reviewMediaBeforePublish: policy.reviewMediaBeforePublish,
      mediaReviewConfirmed: policy.reviewMediaBeforePublish
          ? mediaReviewWasRequired && state.mediaReviewConfirmed
          : true,
    );
  }

  void confirmMediaReview(bool value) {
    state = state.copyWith(mediaReviewConfirmed: value);
  }

  void setHideHouseNumber(bool value) {
    state = state.copyWith(
      hideHouseNumber: value,
      locationPrivacyTouched: true,
    );
  }

  /// All local validation is repeated at final confirmation, before any write.
  List<String> get reviewErrors => [
    ...state.draft.validateStepTwo().map(_stepTwoMessage),
    if (state.reviewMediaBeforePublish && !state.mediaReviewConfirmed)
      'Hãy xác nhận đã kiểm tra ảnh/video trước khi đăng tin.',
    ...state.draft.validateStepOne().map(_stepOneMessage),
    if (state.draft.contactPreference == RescueContactPreference.inApp &&
        PrivacySurfacePolicy.containsPhoneNumber(
          '${state.draft.identifyingFeatures} ${state.draft.behaviorHint}',
        ))
      'Hãy bỏ số điện thoại khỏi mô tả khi chỉ liên hệ trong PawMate.',
  ];

  String get _reviewFingerprint => jsonEncode([
    state.draft.toPatchJson(),
    state.hideHouseNumber,
    state.reviewMediaBeforePublish,
    state.mediaReviewConfirmed,
    for (final media in state.draft.media)
      [media.path, media.mimeType, media.sizeBytes],
  ]);

  bool confirmReportReview() {
    if (state.isBusy || reviewErrors.isNotEmpty) return false;
    _reviewedFingerprint = _reviewFingerprint;
    return true;
  }

  Future<void> pickMedia(ImagePicker picker) => _pickMediaFile(
    () => picker.pickImage(source: ImageSource.gallery),
    maxBytes: RescueMediaPolicy.maxImagesBytes,
  );

  Future<void> pickVideo(ImagePicker picker) => _pickMediaFile(
    () => picker.pickVideo(source: ImageSource.gallery),
    maxBytes: RescueMediaPolicy.maxVideoBytes,
  );

  Future<void> _pickMediaFile(
    Future<XFile?> Function() select, {
    required int maxBytes,
  }) async {
    if (_mediaPickInProgress) return;
    _mediaPickInProgress = true;
    final generation = _sessionGeneration;
    try {
      final file = await select();
      if (file == null || generation != _sessionGeneration) return;
      await _addMediaFile(file, maxBytes: maxBytes, generation: generation);
    } on PlatformException catch (error) {
      if (generation != _sessionGeneration) return;
      state = state.copyWith(
        errorMessage:
            error.code == 'photo_access_denied' ||
                error.code == 'photo_access_restricted'
            ? 'Chưa có quyền truy cập ảnh/video. Hãy kiểm tra quyền trong cài đặt thiết bị rồi thử lại.'
            : 'Không thể chọn ảnh/video lúc này. Vui lòng thử lại.',
      );
    } finally {
      _mediaPickInProgress = false;
    }
  }

  Future<void> _addMediaFile(
    XFile file, {
    required int maxBytes,
    required int generation,
  }) async {
    final mimeType = _mimeType(file.path);
    final size = await file.length();
    if (generation != _sessionGeneration) return;
    if (mimeType == null || size > maxBytes) {
      state = state.copyWith(
        errorMessage: mimeType == 'video/mp4'
            ? 'Video phải là MP4 và không quá 50 MB.'
            : 'Ảnh phải là JPEG, PNG hoặc WebP và không quá 10 MB.',
      );
      return;
    }
    if (state.draft.media.length >= RescueMediaPolicy.maxItems) {
      state = state.copyWith(
        errorMessage: 'Mỗi tin chỉ được tối đa 5 ảnh/video.',
      );
      return;
    }
    state = state.copyWith(
      draft: state.draft.copyWith(
        media: [
          ...state.draft.media,
          RescueDraftMedia(
            path: file.path,
            mimeType: mimeType,
            sizeBytes: size,
          ),
        ],
      ),
      mediaReviewConfirmed: false,
      clearError: true,
    );
  }

  void removeMedia(RescueDraftMedia media) {
    state = state.copyWith(
      draft: state.draft.copyWith(media: [...state.draft.media]..remove(media)),
      mediaReviewConfirmed: false,
    );
  }

  Future<bool> continueToDetails() async {
    if (state.isBusy || state.published) return false;
    final errors = state.draft.validateStepOne();
    if (errors.isNotEmpty) {
      state = state.copyWith(errorMessage: _stepOneMessage(errors.first));
      return false;
    }
    // The write contract stores this value in the owner's private location.
    // Public readers receive the backend-generated approximate projection, so
    // redacting here would destroy owner-only recovery data without improving
    // the public privacy boundary.
    return _saveStep(state.draft.toStepOnePatchJson());
  }

  /// Persist private draft fields only. Local files remain selected, but this
  /// recovery action never uploads media, publishes, or clears the draft.
  Future<bool> saveDraft() {
    if (state.isBusy || state.published) return Future.value(false);
    return _saveStep({
      ...state.draft.toStepOnePatchJson(),
      ...state.draft.toStepTwoPatchJson(),
    });
  }

  Future<bool> publish() async {
    if (state.isBusy || state.published) return false;
    final generation = _sessionGeneration;
    final errors = reviewErrors;
    if (errors.isNotEmpty) {
      state = state.copyWith(errorMessage: errors.first);
      return false;
    }
    if (_reviewedFingerprint != _reviewFingerprint) {
      state = state.copyWith(
        errorMessage:
            'Vui lòng xem lại và xác nhận thông tin trước khi đăng tin.',
      );
      return false;
    }
    state = state.copyWith(
      isBusy: true,
      clearError: true,
      clearPublishedCase: true,
    );
    try {
      final accessToken = await _accessToken(generation: generation);
      if (generation != _sessionGeneration) return false;
      if (accessToken == null) {
        state = state.copyWith(isBusy: false);
        return false;
      }
      var draft = await _ensureDraft(accessToken, generation: generation);
      if (draft == null || generation != _sessionGeneration) return false;
      final media = <RescueDraftMedia>[];
      for (final item in draft.media) {
        if (item.uploaded && item.mediaId != null) {
          media.add(item);
        } else {
          media.add(
            await ref
                .read(rescueWriteSourceProvider)
                .uploadMedia(accessToken: accessToken, media: item),
          );
          if (generation != _sessionGeneration) return false;
          // Keep each completed receipt even if a later file fails. Retrying
          // must not create a second storage object for an earlier upload.
          state = state.copyWith(
            draft: draft.copyWith(
              media: [...media, ...draft.media.skip(media.length)],
            ),
          );
        }
      }
      draft = draft.copyWith(media: media);
      final persistedDraft = await ref
          .read(rescueWriteSourceProvider)
          .updateDraft(
            accessToken: accessToken,
            draftId: draft.draftId!,
            expectedVersion: draft.version!,
            patch: {
              ...draft.toStepTwoPatchJson(),
              ...draft.toStepOnePatchJson(),
            },
          );
      if (generation != _sessionGeneration) return false;
      // The draft-write contract returns ordered `mediaIds`, not local media
      // descriptors. Keep the successfully uploaded local records so a failed
      // publish can be retried without forcing the owner to choose files again.
      draft = persistedDraft.copyWith(media: media);
      // Persist the merged local state before the publish request. If that
      // final request fails, the error state can retry with the current draft
      // version and uploaded media rather than restarting the upload flow.
      state = state.copyWith(draft: draft);
      final publishedCase = await ref
          .read(rescueWriteSourceProvider)
          .publishDraft(
            accessToken: accessToken,
            draftId: draft.draftId!,
            expectedVersion: draft.version!,
          );
      if (generation != _sessionGeneration) return false;
      state = state.copyWith(
        draft: draft,
        isBusy: false,
        published: true,
        publishedCase: publishedCase,
      );
      return true;
    } on RescueWriteApiException catch (error) {
      if (generation != _sessionGeneration) return false;
      state = state.copyWith(isBusy: false, errorMessage: _errorMessage(error));
      return false;
    } catch (_) {
      if (generation != _sessionGeneration) return false;
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Không thể đăng tin. Bản nháp vẫn được giữ để thử lại.',
      );
      return false;
    }
  }

  void completePublishedFlow() {
    if (state.published && !state.isBusy) {
      _reviewedFingerprint = null;
      state = const RescueCreateState();
    }
  }

  Future<bool> _saveStep(Map<String, Object?> patch) async {
    final generation = _sessionGeneration;
    if (state.isBusy || state.published) return false;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final accessToken = await _accessToken(generation: generation);
      if (generation != _sessionGeneration) return false;
      if (accessToken == null) {
        state = state.copyWith(isBusy: false);
        return false;
      }
      final draft = await _ensureDraft(accessToken, generation: generation);
      if (draft == null || generation != _sessionGeneration) return false;
      final updated = await ref
          .read(rescueWriteSourceProvider)
          .updateDraft(
            accessToken: accessToken,
            draftId: draft.draftId!,
            expectedVersion: draft.version!,
            patch: patch,
          );
      if (generation != _sessionGeneration) return false;
      final current = state.draft;
      if (current.draftId != draft.draftId ||
          current.version != draft.version ||
          updated.draftId != draft.draftId ||
          updated.version == null ||
          updated.version! <= draft.version!) {
        state = state.copyWith(
          isBusy: false,
          errorMessage: 'Bản nháp đã thay đổi. Dữ liệu đang giữ trên màn hình.',
        );
        return false;
      }
      // The wire draft has no local file descriptors. Only apply its current
      // identity/version to this same-session local draft, keeping all inputs
      // and selected files (including edits made while the request was busy).
      state = state.copyWith(
        draft: current.copyWith(
          draftId: updated.draftId,
          version: updated.version,
        ),
        isBusy: false,
      );
      return true;
    } on RescueWriteApiException catch (error) {
      if (generation != _sessionGeneration) return false;
      state = state.copyWith(isBusy: false, errorMessage: _errorMessage(error));
      return false;
    } catch (_) {
      if (generation != _sessionGeneration) return false;
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Không thể lưu bản nháp. Dữ liệu đang giữ trên màn hình.',
      );
      return false;
    }
  }

  Future<RescueDraft?> _ensureDraft(
    String accessToken, {
    required int generation,
  }) async {
    final current = state.draft;
    if (current.draftId != null && current.version != null) return current;
    final created = await ref
        .read(rescueWriteSourceProvider)
        .createDraft(accessToken: accessToken);
    if (generation != _sessionGeneration) return null;
    final local = state.draft;
    final merged = created.copyWith(
      petName: local.petName,
      species: local.species,
      breedOrColor: local.breedOrColor,
      lostAt: local.lostAt,
      exactLocation: local.exactLocation,
      identifyingFeatures: local.identifyingFeatures,
      behaviorHint: local.behaviorHint,
      contactPreference: local.contactPreference,
      media: local.media,
    );
    state = state.copyWith(draft: merged);
    return merged;
  }

  Future<String?> _accessToken({required int generation}) async {
    final token = await ref.read(authAccessTokenProvider.future);
    if (generation != _sessionGeneration) return null;
    if (token == null || token.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Bạn cần đăng nhập để tạo tin báo mất.',
      );
      return null;
    }
    return token;
  }

  String _errorMessage(RescueWriteApiException error) => error.isConflict
      ? 'Bản nháp đã thay đổi ở nơi khác. Vui lòng tải lại trước khi tiếp tục.'
      : error.message;

  static String _stepOneMessage(String field) => switch (field) {
    'petName' => 'Vui lòng nhập tên thú cưng (tối đa 50 ký tự).',
    'breedOrColor' => 'Vui lòng nhập giống hoặc màu lông.',
    'lostAt' => 'Vui lòng chọn thời gian thất lạc.',
    'exactLocation' => 'Vui lòng chọn khu vực thất lạc trên bản đồ.',
    _ => 'Vui lòng kiểm tra lại thông tin.',
  };

  static String _stepTwoMessage(String field) => switch (field) {
    'identifyingFeatures' => 'Vui lòng nhập đặc điểm nhận dạng.',
    'behaviorHint' => 'Mô tả tính cách không được quá 500 ký tự.',
    'media' => 'Vui lòng thêm ít nhất một ảnh thú cưng.',
    _ => 'Vui lòng kiểm tra lại thông tin.',
  };

  static String? _mimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    return null;
  }
}
