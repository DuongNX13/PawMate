import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_button.dart';
import '../../../core/widgets/pawmate_card.dart';
import '../../../core/widgets/pawmate_page_scaffold.dart';
import '../../../core/widgets/pawmate_skeleton.dart';
import '../../../core/widgets/pawmate_state_view.dart';
import '../../../core/widgets/pawmate_top_bar.dart';
import '../application/my_adoption_requests_provider.dart';
import '../data/adoption_api.dart';
import '../domain/adoption_request_chat_models.dart';

class MyAdoptionRequestsScreen extends ConsumerWidget {
  const MyAdoptionRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myAdoptionRequestsProvider);
    return PawMatePageScaffold(
      layoutMode: PawMatePageLayoutMode.fullResponsive,
      key: const Key('my-adoption-requests-screen'),
      backgroundColor: AppColors.background,
      topBar: PawMateTopBar(
        title: 'Lịch sử nhận nuôi',
        semanticTitle: 'Lịch sử nhận nuôi',
        showBackButton: true,
        centerTitle: true,
        onBack: () => _back(context),
      ),
      body: requests.when(
        data: (items) => items.isEmpty
            ? PawMateStateView(
                key: const Key('my-adoption-requests-empty'),
                type: PawMateStateType.empty,
                icon: Icons.inbox_outlined,
                title: 'Bạn chưa có đơn nhận nuôi',
                message:
                    'Khám phá các bé đang tìm mái ấm và gửi yêu cầu khi bạn đã sẵn sàng.',
                primaryActionLabel: 'Khám phá bé cần nhận nuôi',
                onPrimaryAction: () => context.go('/adoption'),
              )
            : _RequestList(items: items),
        loading: () => const _RequestListLoading(),
        error: (error, _) => PawMateStateView(
          key: const Key('my-adoption-requests-error'),
          type: error is AdoptionApiException && error.isOffline
              ? PawMateStateType.offline
              : PawMateStateType.error,
          title: 'Chưa tải được đơn nhận nuôi',
          message: _errorMessage(error),
          primaryActionLabel: 'Thử lại',
          onPrimaryAction: () => ref.invalidate(myAdoptionRequestsProvider),
          secondaryActionLabel: 'Khám phá các bé',
          onSecondaryAction: () => context.go('/adoption'),
        ),
      ),
    );
  }

  static void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/adoption');
    }
  }

  static String _errorMessage(Object error) {
    if (error is AdoptionApiException) {
      if (error.isOffline) {
        return 'Không thể kết nối. Vui lòng kiểm tra mạng rồi thử lại.';
      }
      if (error.isAuthRequired) {
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      }
      return error.message;
    }
    return 'PawMate chưa thể tải danh sách. Vui lòng thử lại sau.';
  }
}

class _RequestList extends ConsumerWidget {
  const _RequestList({required this.items});

  final List<AdoptionRequestSummary> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppColors.primary700,
      onRefresh: () async {
        ref.invalidate(myAdoptionRequestsProvider);
        await ref.read(myAdoptionRequestsProvider.future);
      },
      child: ListView.separated(
        key: const Key('my-adoption-requests-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s16,
          AppSpacing.s16,
          AppSpacing.s32,
        ),
        itemCount: items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s4),
              child: Text(
                '${items.length} đơn đang được theo dõi',
                style: AppTextStyles.bodyCompact(),
              ),
            );
          }
          return _RequestCard(request: items[index - 1]);
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final AdoptionRequestSummary request;

  @override
  Widget build(BuildContext context) {
    return PawMateCard(
      key: Key('my-adoption-request-${request.requestId}'),
      semanticLabel:
          'Đơn nhận nuôi ${request.petName}, ${request.status.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.pets_outlined,
                    color: AppColors.primary700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.petName, style: AppTextStyles.cardTitle()),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'Cập nhật ${_formatDate(request.updatedAt)}',
                      style: AppTextStyles.meta(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          _StatusPill(status: request.status),
          if (request.listingAvailability !=
              AdoptionRequestListingAvailability.available) ...[
            const SizedBox(height: AppSpacing.s12),
            _ListingAvailabilityNotice(
              availability: request.listingAvailability,
            ),
          ],
          const SizedBox(height: AppSpacing.s16),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              if (request.listingAvailability.canOpenProfile)
                PawMateButton(
                  key: Key('my-adoption-request-profile-${request.requestId}'),
                  label: 'Xem hồ sơ',
                  leadingIcon: Icons.visibility_outlined,
                  variant: PawMateButtonVariant.secondary,
                  compact: true,
                  fullWidth: false,
                  onPressed: () => context.go(
                    '/adoption/${Uri.encodeComponent(request.listingId)}',
                  ),
                )
              else
                PawMateButton(
                  key: Key(
                    'my-adoption-request-discovery-${request.requestId}',
                  ),
                  label: 'Khám phá bé khác',
                  leadingIcon: Icons.pets_outlined,
                  variant: PawMateButtonVariant.secondary,
                  compact: true,
                  fullWidth: false,
                  onPressed: () => context.go('/adoption'),
                ),
              if (request.threadId case final threadId?)
                PawMateButton(
                  key: Key('my-adoption-request-chat-${request.requestId}'),
                  label: 'Nhắn mái ấm',
                  leadingIcon: Icons.chat_bubble_outline,
                  compact: true,
                  fullWidth: false,
                  onPressed: () => context.go(
                    '/adoption/chat/${Uri.encodeComponent(threadId)}',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final utc = value.toUtc();
    return '${utc.day.toString().padLeft(2, '0')}/'
        '${utc.month.toString().padLeft(2, '0')}/${utc.year}';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final AdoptionRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = PawMateStatusColors.of(context);
    final (background, foreground) = switch (status) {
      AdoptionRequestStatus.submitted => (colors.infoContainer, colors.info),
      AdoptionRequestStatus.reviewing => (
        colors.warningContainer,
        colors.warning,
      ),
      AdoptionRequestStatus.approved => (
        colors.successContainer,
        colors.success,
      ),
      AdoptionRequestStatus.rejected => (colors.errorContainer, colors.error),
      AdoptionRequestStatus.cancelled => (
        colors.disabledContainer,
        colors.disabledContent,
      ),
    };
    return Semantics(
      label: 'Trạng thái ${status.label}',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          alignment: Alignment.center,
          child: Text(
            status.label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: AppTextStyles.captionStrong(color: foreground),
          ),
        ),
      ),
    );
  }
}

class _ListingAvailabilityNotice extends StatelessWidget {
  const _ListingAvailabilityNotice({required this.availability});

  final AdoptionRequestListingAvailability availability;

  @override
  Widget build(BuildContext context) {
    final colors = PawMateStatusColors.of(context);
    final isClosed =
        availability == AdoptionRequestListingAvailability.expired ||
        availability == AdoptionRequestListingAvailability.deleted;
    final foreground = isClosed ? colors.warning : AppColors.primary700;
    final background = isClosed
        ? colors.warningContainer
        : AppColors.primarySoft;
    return Semantics(
      container: true,
      label: availability.label,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isClosed ? Icons.info_outline : Icons.pets_outlined,
                size: 20,
                color: foreground,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  availability.label,
                  style: AppTextStyles.bodyCompact(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestListLoading extends StatelessWidget {
  const _RequestListLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const Key('my-adoption-requests-loading'),
      padding: const EdgeInsets.all(AppSpacing.s16),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s12),
      itemBuilder: (_, _) => const PawMateSkeleton(
        width: double.infinity,
        height: 152,
        borderRadius: AppRadius.md,
      ),
    );
  }
}
