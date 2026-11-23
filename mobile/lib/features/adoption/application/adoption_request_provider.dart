import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../auth/application/auth_session_coordinator.dart';
import '../../auth/data/auth_api.dart';
import '../data/adoption_api.dart';
import '../data/adoption_request_chat_api.dart';
import '../data/adoption_request_chat_draft_store.dart';
import '../domain/adoption_models.dart';
import '../domain/adoption_request_chat_models.dart';
import 'adoption_runtime_providers.dart';

typedef AdoptionSessionReader = Future<AuthSession?> Function();
typedef AdoptionRequestKeyFactory =
    String Function(String listingId, DateTime timestamp, int sequence);

final adoptionRequestKeyFactoryProvider = Provider<AdoptionRequestKeyFactory>((
  ref,
) {
  return (listingId, timestamp, sequence) {
    final safeId = listingId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
    return 'pawmate-day55-request-$safeId-'
        '${timestamp.microsecondsSinceEpoch}-$sequence';
  };
});

final adoptionRequestProvider = StateNotifierProvider.autoDispose
    .family<AdoptionRequestNotifier, AdoptionRequestState, String>((
      ref,
      listingId,
    ) {
      ref.watch(adoptionSessionRevisionProvider);
      final notifier = AdoptionRequestNotifier(
        listingId: listingId,
        listingSource: ref.watch(adoptionSourceProvider),
        requestSource: ref.watch(adoptionRequestChatSourceProvider),
        draftStore: ref.watch(adoptionRequestChatDraftStoreProvider),
        readSession: () => ref.read(authSessionSnapshotProvider.future),
        now: ref.watch(adoptionClockProvider),
        keyFactory: ref.watch(adoptionRequestKeyFactoryProvider),
      );
      unawaited(notifier.load());
      return notifier;
    });

class AdoptionRequestState {
  const AdoptionRequestState({
    this.isLoading = true,
    this.listing,
    this.draft = const AdoptionRequestDraft(),
    this.isSubmitting = false,
    this.showValidation = false,
    this.duplicateActive = false,
    this.result,
    this.errorMessage,
    this.draftPersistenceWarning,
  });

  final bool isLoading;
  final AdoptionListingDetail? listing;
  final AdoptionRequestDraft draft;
  final bool isSubmitting;
  final bool showValidation;
  final bool duplicateActive;
  final AdoptionRequestResult? result;
  final String? errorMessage;
  final String? draftPersistenceWarning;

  bool get canSubmit =>
      !isLoading &&
      !isSubmitting &&
      result == null &&
      listing?.status.isAvailable == true &&
      listing?.viewerPermissions.canRequest == true &&
      draft.isValid;

  AdoptionRequestState copyWith({
    bool? isLoading,
    AdoptionListingDetail? listing,
    AdoptionRequestDraft? draft,
    bool? isSubmitting,
    bool? showValidation,
    bool? duplicateActive,
    AdoptionRequestResult? result,
    String? errorMessage,
    String? draftPersistenceWarning,
    bool clearError = false,
    bool clearPersistenceWarning = false,
    bool clearResult = false,
  }) {
    return AdoptionRequestState(
      isLoading: isLoading ?? this.isLoading,
      listing: listing ?? this.listing,
      draft: draft ?? this.draft,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      showValidation: showValidation ?? this.showValidation,
      duplicateActive: duplicateActive ?? this.duplicateActive,
      result: clearResult ? null : result ?? this.result,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      draftPersistenceWarning: clearPersistenceWarning
          ? null
          : draftPersistenceWarning ?? this.draftPersistenceWarning,
    );
  }
}

class AdoptionRequestNotifier extends StateNotifier<AdoptionRequestState> {
  AdoptionRequestNotifier({
    required this.listingId,
    required AdoptionSource listingSource,
    required AdoptionRequestChatSource requestSource,
    required AdoptionRequestChatDraftStore draftStore,
    required AdoptionSessionReader readSession,
    required DateTime Function() now,
    required AdoptionRequestKeyFactory keyFactory,
  }) : _listingSource = listingSource,
       _requestSource = requestSource,
       _draftStore = draftStore,
       _readSession = readSession,
       _now = now,
       _keyFactory = keyFactory,
       super(const AdoptionRequestState());

  final String listingId;
  final AdoptionSource _listingSource;
  final AdoptionRequestChatSource _requestSource;
  final AdoptionRequestChatDraftStore _draftStore;
  final AdoptionSessionReader _readSession;
  final DateTime Function() _now;
  final AdoptionRequestKeyFactory _keyFactory;

  int _sequence = 0;
  String? _userId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final session = await _readSession();
    if (!mounted) return;
    if (session == null ||
        session.user.id.trim().isEmpty ||
        session.accessToken.trim().isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Bạn cần đăng nhập để gửi yêu cầu nhận nuôi.',
      );
      return;
    }
    _userId = session.user.id.trim();
    try {
      final results = await Future.wait<Object>([
        _listingSource.getListing(
          listingId,
          accessToken: session.accessToken.trim(),
        ),
        _draftStore.readRequestDraft(userId: _userId!, listingId: listingId),
      ]);
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        listing: results[0] as AdoptionListingDetail,
        draft: results[1] as AdoptionRequestDraft,
        clearError: true,
      );
    } on Object catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageFor(error),
      );
    }
  }

  void setLivingCondition(String value) => _replaceDraft(
    state.draft.copyWith(livingCondition: value, clearPendingSubmitKey: true),
  );

  void setPetExperience(String value) => _replaceDraft(
    state.draft.copyWith(petExperience: value, clearPendingSubmitKey: true),
  );

  void setCarePlan(String value) => _replaceDraft(
    state.draft.copyWith(carePlan: value, clearPendingSubmitKey: true),
  );

  void setNote(String value) => _replaceDraft(
    state.draft.copyWith(note: value, clearPendingSubmitKey: true),
  );

  void setCommitmentAccepted(bool value) => _replaceDraft(
    state.draft.copyWith(
      commitmentAccepted: value,
      clearPendingSubmitKey: true,
    ),
  );

  Future<bool> submit() async {
    state = state.copyWith(
      showValidation: true,
      duplicateActive: false,
      clearError: true,
    );
    if (state.isSubmitting || state.result != null) return false;
    if (!state.draft.isValid) {
      state = state.copyWith(
        errorMessage: 'Vui lòng kiểm tra các trường bắt buộc và cam kết.',
      );
      return false;
    }
    final listing = state.listing;
    if (listing == null ||
        !listing.status.isAvailable ||
        !listing.viewerPermissions.canRequest) {
      state = state.copyWith(
        errorMessage: 'Tin này hiện không nhận thêm yêu cầu.',
      );
      return false;
    }
    final session = await _readSession();
    if (!mounted) return false;
    if (session == null ||
        session.user.id.trim().isEmpty ||
        session.accessToken.trim().isEmpty) {
      state = state.copyWith(
        errorMessage:
            'Phiên đăng nhập đã hết hạn. Nội dung của bạn vẫn được giữ.',
      );
      return false;
    }
    _userId = session.user.id.trim();
    final key =
        state.draft.pendingSubmitKey ??
        _keyFactory(listingId, _now(), _sequence++);
    final draft = state.draft.copyWith(pendingSubmitKey: key);
    state = state.copyWith(draft: draft, isSubmitting: true, clearError: true);
    try {
      await _draftStore.saveRequestDraft(
        userId: _userId!,
        listingId: listingId,
        draft: draft,
      );
      final result = await _requestSource.createRequest(
        accessToken: session.accessToken.trim(),
        listingId: listingId,
        draft: draft,
        idempotencyKey: key,
      );
      await _draftStore.saveChatContext(
        userId: _userId!,
        threadId: result.threadId,
        context: AdoptionChatContext.fromListing(listing),
      );
      await _draftStore.clearRequestDraft(
        userId: _userId!,
        listingId: listingId,
      );
      if (!mounted) return false;
      state = state.copyWith(
        isSubmitting: false,
        result: result,
        draft: const AdoptionRequestDraft(),
        clearError: true,
        clearPersistenceWarning: true,
      );
      return true;
    } on Object catch (error) {
      if (!mounted) return false;
      final apiError = error is AdoptionApiException ? error : null;
      final clearKey =
          apiError?.code == 'ADOPTION_006' ||
          apiError?.code == 'IDEMPOTENCY_001';
      final failedDraft = clearKey
          ? draft.copyWith(clearPendingSubmitKey: true)
          : draft;
      state = state.copyWith(
        isSubmitting: false,
        draft: failedDraft,
        duplicateActive: apiError?.code == 'ADOPTION_006',
        errorMessage: apiError?.code == 'ADOPTION_006'
            ? 'Bạn đã có một yêu cầu đang hoạt động cho bé này.'
            : _messageFor(error),
      );
      if (clearKey) {
        await _persist(failedDraft);
      }
      return false;
    }
  }

  void _replaceDraft(AdoptionRequestDraft draft) {
    state = state.copyWith(
      draft: draft,
      duplicateActive: false,
      clearError: true,
      clearPersistenceWarning: true,
    );
    unawaited(_persist(draft));
  }

  Future<void> _persist(AdoptionRequestDraft draft) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await _draftStore.saveRequestDraft(
        userId: userId,
        listingId: listingId,
        draft: draft,
      );
    } on Object {
      if (!mounted) return;
      state = state.copyWith(
        draftPersistenceWarning:
            'Chưa thể lưu bản nháp trên thiết bị. Đừng đóng màn hình này.',
      );
    }
  }

  static String _messageFor(Object error) {
    if (error is AdoptionApiException) {
      if (error.isAuthRequired) {
        return 'Phiên đăng nhập đã hết hạn. Nội dung của bạn vẫn được giữ.';
      }
      if (error.isOffline) {
        return 'Không thể kết nối. Bản nháp vẫn được giữ để thử lại.';
      }
      return error.message;
    }
    return 'Không thể hoàn tất thao tác. Bản nháp vẫn được giữ.';
  }
}
