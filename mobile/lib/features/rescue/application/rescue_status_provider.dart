import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../auth/application/auth_session_coordinator.dart';
import '../data/rescue_status_api.dart';
import '../domain/rescue_case_models.dart';

enum RescueStatusSubmitState { idle, submitting, success, error }

@immutable
class RescueStatusState {
  const RescueStatusState({
    this.submitState = RescueStatusSubmitState.idle,
    this.confirmedSafe = false,
    this.needsRefresh = false,
    this.errorMessage,
    this.pendingIdempotencyKey,
    this.updatedDetail,
  });

  final RescueStatusSubmitState submitState;
  final bool confirmedSafe;
  final bool needsRefresh;
  final String? errorMessage;
  final String? pendingIdempotencyKey;
  final RescueCaseDetail? updatedDetail;

  bool get isSubmitting => submitState == RescueStatusSubmitState.submitting;
  bool get canSubmit => confirmedSafe && !isSubmitting && !needsRefresh;

  RescueStatusState copyWith({
    RescueStatusSubmitState? submitState,
    bool? confirmedSafe,
    bool? needsRefresh,
    String? errorMessage,
    bool clearError = false,
    String? pendingIdempotencyKey,
    bool clearPendingKey = false,
    RescueCaseDetail? updatedDetail,
    bool clearUpdatedDetail = false,
  }) => RescueStatusState(
    submitState: submitState ?? this.submitState,
    confirmedSafe: confirmedSafe ?? this.confirmedSafe,
    needsRefresh: needsRefresh ?? this.needsRefresh,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    pendingIdempotencyKey: clearPendingKey
        ? null
        : (pendingIdempotencyKey ?? this.pendingIdempotencyKey),
    updatedDetail: clearUpdatedDetail
        ? null
        : (updatedDetail ?? this.updatedDetail),
  );
}

final rescueStatusClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final rescueStatusProvider =
    StateNotifierProvider.family<
      RescueStatusNotifier,
      RescueStatusState,
      String
    >((ref, caseId) {
      final notifier = RescueStatusNotifier(
        caseId: caseId,
        source: ref.watch(rescueStatusSourceProvider),
        accessToken: () => ref.read(authAccessTokenProvider.future),
        now: ref.watch(rescueStatusClockProvider),
      );
      ref.listen<int>(authSessionRevisionProvider, (previous, next) {
        if (previous != null && previous != next) {
          notifier.resetForSessionChange();
        }
      });
      return notifier;
    });

class RescueStatusNotifier extends StateNotifier<RescueStatusState> {
  RescueStatusNotifier({
    required this.caseId,
    required RescueStatusSource source,
    required Future<String?> Function() accessToken,
    required DateTime Function() now,
  }) : _source = source,
       _accessToken = accessToken,
       _now = now,
       super(const RescueStatusState());

  final String caseId;
  final RescueStatusSource _source;
  final Future<String?> Function() _accessToken;
  final DateTime Function() _now;
  var _sessionGeneration = 0;
  var _sequence = 0;

  void setConfirmedSafe(bool value) {
    if (value == state.confirmedSafe) return;
    state = state.copyWith(
      confirmedSafe: value,
      submitState: RescueStatusSubmitState.idle,
      clearError: true,
      clearPendingKey: !value,
      needsRefresh: state.needsRefresh,
    );
  }

  Future<RescueCaseDetail?> submit(RescueCaseDetail detail) async {
    if (state.needsRefresh) {
      state = state.copyWith(
        submitState: RescueStatusSubmitState.error,
        errorMessage:
            'Trạng thái đã thay đổi ở thiết bị khác. Hãy tải lại trước khi tiếp tục.',
      );
      return null;
    }
    if (!detail.viewerPermissions.canUpdateStatus) {
      state = state.copyWith(
        submitState: RescueStatusSubmitState.error,
        errorMessage: 'Chỉ chủ bài viết mới được cập nhật trạng thái.',
      );
      return null;
    }
    if (detail.status != RescueCaseStatus.missing) {
      state = state.copyWith(
        submitState: RescueStatusSubmitState.error,
        errorMessage: 'Ca cứu hộ này đã ở trạng thái Đã thấy.',
      );
      return null;
    }
    if (!state.confirmedSafe) {
      state = state.copyWith(
        submitState: RescueStatusSubmitState.error,
        errorMessage: 'Vui lòng xác nhận bé đã về an toàn.',
      );
      return null;
    }

    final generation = _sessionGeneration;
    final token = await _accessToken();
    if (generation != _sessionGeneration) return null;
    if (token == null || token.trim().isEmpty) {
      state = state.copyWith(
        submitState: RescueStatusSubmitState.error,
        errorMessage: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
      return null;
    }

    final key =
        state.pendingIdempotencyKey ??
        'pawmate-day46-status-${_now().microsecondsSinceEpoch}-${_sequence++}';
    state = state.copyWith(
      submitState: RescueStatusSubmitState.submitting,
      pendingIdempotencyKey: key,
      needsRefresh: false,
      clearError: true,
    );
    try {
      final updated = await _source.markFound(
        accessToken: token.trim(),
        caseId: caseId,
        expectedVersion: detail.version,
        idempotencyKey: key,
      );
      if (generation != _sessionGeneration) return null;
      state = state.copyWith(
        submitState: RescueStatusSubmitState.success,
        updatedDetail: updated,
        clearPendingKey: true,
        clearError: true,
      );
      return updated;
    } on RescueStatusApiException catch (error) {
      if (generation != _sessionGeneration) return null;
      state = state.copyWith(
        submitState: RescueStatusSubmitState.error,
        needsRefresh: error.isConflict,
        errorMessage: _safeMessage(error),
      );
      return null;
    } catch (_) {
      if (generation != _sessionGeneration) return null;
      state = state.copyWith(
        submitState: RescueStatusSubmitState.error,
        errorMessage: 'Không thể cập nhật trạng thái. Vui lòng thử lại.',
      );
      return null;
    }
  }

  void prepareForRefresh() {
    state = state.copyWith(
      submitState: RescueStatusSubmitState.idle,
      confirmedSafe: false,
      needsRefresh: false,
      clearError: true,
      clearPendingKey: true,
      clearUpdatedDetail: true,
    );
  }

  void resetForSessionChange() {
    _sessionGeneration += 1;
    state = const RescueStatusState();
  }

  static String _safeMessage(RescueStatusApiException error) {
    if (error.isForbidden) {
      return 'Chỉ chủ bài viết mới được cập nhật trạng thái.';
    }
    if (error.isAuthRequired) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    if (error.isConflict) {
      return 'Trạng thái đã thay đổi ở thiết bị khác. Hãy tải lại trước khi tiếp tục.';
    }
    return error.message;
  }
}
