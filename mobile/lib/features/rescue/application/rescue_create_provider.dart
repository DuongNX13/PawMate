import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/application/auth_session_coordinator.dart';
import '../data/rescue_write_api.dart';
import '../domain/rescue_draft_models.dart';

@immutable
class RescueCreateState {
  const RescueCreateState({
    this.draft = const RescueDraft(),
    this.isBusy = false,
    this.errorMessage,
    this.published = false,
  });

  final RescueDraft draft;
  final bool isBusy;
  final String? errorMessage;
  final bool published;

  RescueCreateState copyWith({
    RescueDraft? draft,
    bool? isBusy,
    String? errorMessage,
    bool clearError = false,
    bool? published,
  }) => RescueCreateState(
    draft: draft ?? this.draft,
    isBusy: isBusy ?? this.isBusy,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    published: published ?? this.published,
  );
}

final rescueCreateProvider =
    NotifierProvider<RescueCreateNotifier, RescueCreateState>(
      RescueCreateNotifier.new,
    );

class RescueCreateNotifier extends Notifier<RescueCreateState> {
  RescueDraft get draft => state.draft;

  @override
  RescueCreateState build() => const RescueCreateState();

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

  void setContactPreference(RescueContactPreference value) => state = state
      .copyWith(draft: state.draft.copyWith(contactPreference: value));

  void setMedia(List<RescueDraftMedia> media) =>
      state = state.copyWith(draft: state.draft.copyWith(media: media));

  Future<void> pickMedia(ImagePicker picker) async {
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    await _addMediaFile(file, maxBytes: RescueMediaPolicy.maxImagesBytes);
  }

  Future<void> pickVideo(ImagePicker picker) async {
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    await _addMediaFile(file, maxBytes: RescueMediaPolicy.maxVideoBytes);
  }

  Future<void> _addMediaFile(XFile file, {required int maxBytes}) async {
    final mimeType = _mimeType(file.path);
    final size = await file.length();
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
      clearError: true,
    );
  }

  void removeMedia(RescueDraftMedia media) {
    state = state.copyWith(
      draft: state.draft.copyWith(media: [...state.draft.media]..remove(media)),
    );
  }

  Future<bool> continueToDetails() async {
    final errors = state.draft.validateStepOne();
    if (errors.isNotEmpty) {
      state = state.copyWith(errorMessage: _stepOneMessage(errors.first));
      return false;
    }
    return _saveStep(state.draft.toStepOnePatchJson());
  }

  Future<bool> publish() async {
    final errors = state.draft.validateStepTwo();
    if (errors.isNotEmpty) {
      state = state.copyWith(errorMessage: _stepTwoMessage(errors.first));
      return false;
    }
    final accessToken = await _accessToken();
    if (accessToken == null) return false;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      var draft = await _ensureDraft(accessToken);
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
        }
      }
      draft = draft.copyWith(media: media);
      draft = await ref
          .read(rescueWriteSourceProvider)
          .updateDraft(
            accessToken: accessToken,
            draftId: draft.draftId!,
            expectedVersion: draft.version!,
            patch: draft.toStepTwoPatchJson(),
          );
      await ref
          .read(rescueWriteSourceProvider)
          .publishDraft(
            accessToken: accessToken,
            draftId: draft.draftId!,
            expectedVersion: draft.version!,
          );
      state = state.copyWith(draft: draft, isBusy: false, published: true);
      return true;
    } on RescueWriteApiException catch (error) {
      state = state.copyWith(isBusy: false, errorMessage: _errorMessage(error));
      return false;
    } catch (_) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Không thể đăng tin. Bản nháp vẫn được giữ để thử lại.',
      );
      return false;
    }
  }

  Future<bool> _saveStep(Map<String, Object?> patch) async {
    final accessToken = await _accessToken();
    if (accessToken == null) return false;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final draft = await _ensureDraft(accessToken);
      final updated = await ref
          .read(rescueWriteSourceProvider)
          .updateDraft(
            accessToken: accessToken,
            draftId: draft.draftId!,
            expectedVersion: draft.version!,
            patch: patch,
          );
      state = state.copyWith(draft: updated, isBusy: false);
      return true;
    } on RescueWriteApiException catch (error) {
      state = state.copyWith(isBusy: false, errorMessage: _errorMessage(error));
      return false;
    } catch (_) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: 'Không thể lưu bản nháp. Dữ liệu đang giữ trên màn hình.',
      );
      return false;
    }
  }

  Future<RescueDraft> _ensureDraft(String accessToken) async {
    final current = state.draft;
    if (current.draftId != null && current.version != null) return current;
    final created = await ref
        .read(rescueWriteSourceProvider)
        .createDraft(accessToken: accessToken);
    final merged = created.copyWith(
      petName: current.petName,
      species: current.species,
      breedOrColor: current.breedOrColor,
      lostAt: current.lostAt,
      exactLocation: current.exactLocation,
      identifyingFeatures: current.identifyingFeatures,
      behaviorHint: current.behaviorHint,
      contactPreference: current.contactPreference,
      media: current.media,
    );
    state = state.copyWith(draft: merged);
    return merged;
  }

  Future<String?> _accessToken() async {
    final token = await ref.read(authAccessTokenProvider.future);
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
