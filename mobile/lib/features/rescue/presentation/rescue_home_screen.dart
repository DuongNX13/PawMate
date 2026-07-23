import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/pawmate_page_scaffold.dart';
import '../../../core/widgets/pawmate_state_view.dart';
import '../../../core/widgets/pawmate_top_bar.dart';

/// Honest fail-closed surface for Rescue before the Day 39 data lane ships.
///
/// This screen deliberately renders no example cases, counts, map markers, or
/// create controls. Feature flags describe rollout readiness only; they never
/// manufacture client-side rescue data.
class RescueHomeScreen extends StatelessWidget {
  const RescueHomeScreen({
    super.key,
    this.browseEnabled = false,
    this.createEnabled = false,
  });

  final bool browseEnabled;
  final bool createEnabled;

  @override
  Widget build(BuildContext context) {
    return PawMatePageScaffold(
      topBar: PawMateTopBar(
        title: 'Cứu hộ thú cưng',
        subtitle: 'Triển khai theo từng giai đoạn',
        actions: [
          IconButton(
            key: const ValueKey('rescue-notifications-button'),
            tooltip: 'Thông báo',
            onPressed: () => context.go('/notifications?returnTo=%2Frescue'),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      bottomNavCurrentRoute: '/rescue',
      body: ListView(
        key: const Key('rescue-staged-state'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s8,
          AppSpacing.s16,
          AppSpacing.s24,
        ),
        children: [
          PawMateStateView(
            type: PawMateStateType.empty,
            icon: Icons.health_and_safety_outlined,
            title: 'Rescue chưa mở dữ liệu thật',
            message: _statusMessage,
            primaryActionLabel: 'Về Trang chủ',
            onPrimaryAction: () => context.go('/pets'),
          ),
          const SizedBox(height: AppSpacing.s8),
          const _RescueSafetyCard(),
        ],
      ),
    );
  }

  String get _statusMessage {
    if (createEnabled) {
      return 'Cờ xem và tạo tin đã bật, nhưng giao diện Day 39 cùng API cứu hộ chưa được nối trong lane hiện tại. PawMate không hiển thị ca mẫu hoặc gửi dữ liệu giả.';
    }
    if (browseEnabled) {
      return 'Cờ xem tin đã bật, nhưng giao diện Day 39 cùng API cứu hộ chưa được nối trong lane hiện tại. PawMate không hiển thị ca mẫu hoặc vị trí giả.';
    }
    return 'Tính năng đang được chuẩn bị. Khi cờ Rescue tắt, PawMate không tải ca cứu hộ, bản đồ hoặc vị trí thật.';
  }
}

class _RescueSafetyCard extends StatelessWidget {
  const _RescueSafetyCard();

  @override
  Widget build(BuildContext context) {
    final status = PawMateStatusColors.of(context);
    return Semantics(
      container: true,
      label:
          'Cam kết an toàn. Chỉ dùng dữ liệu thử nghiệm. Không công khai vị trí chính xác hoặc thông tin liên hệ cá nhân.',
      child: Container(
        key: const Key('rescue-safety-note'),
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: status.infoContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: status.info.withValues(alpha: 0.35),
            width: AppBorderWidth.hairline,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.privacy_tip_outlined, color: status.info),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cam kết an toàn', style: AppTextStyles.bodyStrong()),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'Chỉ dùng tài khoản và dữ liệu thử nghiệm. Không công khai vị trí chính xác, số điện thoại hay địa chỉ cá nhân.',
                    style: AppTextStyles.bodyCompact(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
