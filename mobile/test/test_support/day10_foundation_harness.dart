import 'package:flutter/material.dart';
import 'package:pawmate_mobile/app/theme/app_text_styles.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_ui.dart';

enum Day10FoundationSurface { appShell, form, state }

const day10GoldenRootKey = Key('day10-golden-root');

Widget buildDay10FoundationHarness(
  Day10FoundationSurface surface, {
  bool intentionalDrift = false,
}) {
  final page = switch (surface) {
    Day10FoundationSurface.appShell => const _AppShellSurface(),
    Day10FoundationSurface.form => const _FormSurface(),
    Day10FoundationSurface.state => const _StateSurface(),
  };

  return RepaintBoundary(
    key: day10GoldenRootKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Stack(
        fit: StackFit.expand,
        children: [
          page,
          if (intentionalDrift)
            const Positioned(
              top: 120,
              right: 16,
              child: ColoredBox(
                color: Color(0xFFFF00FF),
                child: SizedBox(width: 40, height: 40),
              ),
            ),
        ],
      ),
    ),
  );
}

class _AppShellSurface extends StatelessWidget {
  const _AppShellSurface();

  @override
  Widget build(BuildContext context) {
    return PawMatePageScaffold(
      topBar: PawMateTopBar(
        title: 'PawMate',
        brandTitle: true,
        actions: [
          IconButton(
            onPressed: () {},
            tooltip: 'Tìm kiếm',
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () {},
            tooltip: 'Thông báo',
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      bottomNavigationBar: PawMateBottomNav(
        currentRoute: '/pets',
        onDestinationSelected: (_) {},
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s16,
          AppSpacing.s16,
          AppSpacing.s24,
        ),
        children: [
          Text('Chào buổi sáng, Nam!', style: AppTextStyles.h3()),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Hôm nay thú cưng của bạn thế nào?',
            style: AppTextStyles.bodyCompact(),
          ),
          const SizedBox(height: AppSpacing.s24),
          PawMateCard(
            variant: PawMateCardVariant.task,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.favorite, color: AppColors.primary700),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        'Lịch nhắc sức khỏe',
                        style: AppTextStyles.overline(
                          color: AppColors.primary700,
                        ),
                      ),
                    ),
                    const PawMateStatus(
                      label: 'Tiến độ',
                      value: PawMateStatusValue.attention,
                      text: 'Ngày mai',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                Text('Tiêm ngừa cho Bắp', style: AppTextStyles.h4()),
                const SizedBox(height: AppSpacing.s4),
                Text('09:30 tại PetCare Elite', style: AppTextStyles.caption()),
                const SizedBox(height: AppSpacing.s16),
                Row(
                  children: [
                    Expanded(
                      child: PawMateButton(label: 'Xác nhận', onPressed: () {}),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: PawMateButton(
                        label: 'Để sau',
                        onPressed: () {},
                        variant: PawMateButtonVariant.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          PawMateCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hoạt động gần bạn', style: AppTextStyles.h4()),
                const SizedBox(height: AppSpacing.s12),
                const Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    PawMateChip(label: 'Gần nhất', selected: true),
                    PawMateChip(label: '24/7'),
                    PawMateChip(label: 'Đang mở'),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                const Row(
                  children: [
                    PawMateSkeleton(
                      width: 56,
                      height: 56,
                      circular: true,
                      animate: false,
                    ),
                    SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PawMateSkeleton(
                            width: 160,
                            height: 16,
                            animate: false,
                          ),
                          SizedBox(height: AppSpacing.s8),
                          PawMateSkeleton(
                            width: 112,
                            height: 12,
                            animate: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSurface extends StatelessWidget {
  const _FormSurface();

  @override
  Widget build(BuildContext context) {
    return PawMatePageScaffold(
      topBar: PawMateTopBar(
        title: 'Hồ sơ thú cưng',
        showBackButton: true,
        onBack: () {},
      ),
      fixedCtaBar: PawMateFixedCtaBar(
        primaryAction: PawMateAction(label: 'Lưu hồ sơ', onPressed: () {}),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s8,
          AppSpacing.s16,
          AppSpacing.s24,
        ),
        children: const [
          PawMateUploadTile(
            label: 'Thêm ảnh thú cưng',
            state: PawMateUploadState.empty,
          ),
          SizedBox(height: AppSpacing.s16),
          PawMateTextField(
            label: 'Tên thú cưng',
            hintText: 'Ví dụ: Bắp',
            isRequired: true,
          ),
          SizedBox(height: AppSpacing.s16),
          PawMateTextField(
            label: 'Giống loài',
            initialValue: 'Golden Retriever',
          ),
          SizedBox(height: AppSpacing.s16),
          PawMateTextField(
            label: 'Số Microchip (nếu có)',
            hintText: 'MC-8293-128',
            helperText: 'Thông tin này chỉ hiển thị cho chủ tài khoản.',
          ),
        ],
      ),
    );
  }
}

class _StateSurface extends StatelessWidget {
  const _StateSurface();

  @override
  Widget build(BuildContext context) {
    return PawMatePageScaffold(
      topBar: PawMateTopBar(
        title: 'PawMate',
        brandTitle: true,
        actions: [
          IconButton(
            onPressed: () {},
            tooltip: 'Thông báo',
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      bottomNavigationBar: PawMateBottomNav(
        currentRoute: '/pets',
        onDestinationSelected: (_) {},
      ),
      body: PawMateStateView(
        type: PawMateStateType.offline,
        title: 'Không tải được dữ liệu',
        message:
            'Có vẻ như kết nối mạng của bạn đang gặp vấn đề. Vui lòng kiểm tra lại Wifi hoặc 4G.',
        primaryActionLabel: 'Thử lại',
        onPrimaryAction: () {},
        secondaryActionLabel: 'Xem dữ liệu đã lưu',
        onSecondaryAction: () {},
      ),
    );
  }
}
