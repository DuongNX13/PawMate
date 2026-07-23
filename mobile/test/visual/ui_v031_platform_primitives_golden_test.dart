import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pawmate_mobile/app/theme/app_text_styles.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_ui.dart';

import '../test_support/ui_test_helpers.dart';

const _goldenRootKey = Key('ui-v031-platform-primitive-root');
const _launcherKey = Key('ui-v031-platform-primitive-launcher');

enum _PrimitiveKind {
  back,
  bottomNav,
  dialog,
  datePicker,
  timePicker,
  actionSheet,
}

void main() {
  setUpAll(loadPawMateTestFonts);

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final kind in _PrimitiveKind.values) {
      testWidgets('${platform.name} ${kind.name} primitive golden', (
        tester,
      ) async {
        await setTestViewport(tester, size: const Size(390, 844));
        await tester.pumpWidget(_harness(platform, kind));
        if (kind == _PrimitiveKind.bottomNav) {
          await _precacheNavigationIcons(tester);
        }
        await tester.pumpAndSettle();

        if (_opensModal(kind)) {
          await tester.tap(find.byKey(_launcherKey));
          await tester.pumpAndSettle();
        }

        expectNoFlutterOverflow(tester);
        await expectLater(
          find.byKey(_goldenRootKey),
          matchesGoldenFile(
            'goldens/ui-v031-platform-primitives/'
            '${platform.name}-${kind.name}.png',
          ),
        );
      });
    }
  }
}

Widget _harness(TargetPlatform platform, _PrimitiveKind kind) {
  return RepaintBoundary(
    key: _goldenRootKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light().copyWith(platform: platform),
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Builder(builder: (context) => _surface(context, kind)),
    ),
  );
}

Widget _surface(BuildContext context, _PrimitiveKind kind) {
  if (kind == _PrimitiveKind.back) {
    return const Scaffold(
      appBar: PawMateTopBar(title: 'Chi tiết thú cưng', showBackButton: true),
      body: _PrimitiveCanvas(
        icon: Icons.arrow_back_rounded,
        title: 'Nút quay lại theo nền tảng',
        message: 'Android dùng mũi tên; iOS dùng chevron.',
      ),
    );
  }
  if (kind == _PrimitiveKind.bottomNav) {
    return Scaffold(
      body: const _PrimitiveCanvas(
        icon: Icons.space_dashboard_outlined,
        title: 'Điều hướng PawMate',
        message: 'Giữ nguyên Home / Vet / Health / Rescue / Profile.',
      ),
      bottomNavigationBar: PawMateBottomNav(
        currentRoute: '/health',
        onDestinationSelected: (_) {},
      ),
    );
  }

  return Scaffold(
    appBar: const PawMateTopBar(title: 'Native adaptive primitives'),
    body: _PrimitiveCanvas(
      icon: _iconFor(kind),
      title: _titleFor(kind),
      message: 'Chocomint, Be Vietnam Pro và vùng chạm tối thiểu 48dp.',
      action: PawMateButton(
        key: _launcherKey,
        label: 'Mở ${_shortLabelFor(kind)}',
        onPressed: () => _open(context, kind),
        fullWidth: false,
        compact: true,
      ),
    ),
  );
}

void _open(BuildContext context, _PrimitiveKind kind) {
  switch (kind) {
    case _PrimitiveKind.dialog:
      showPawMateAdaptiveDialog<String>(
        context: context,
        title: 'Xóa lịch nhắc?',
        message: 'Bạn có thể tạo lại lịch nhắc sau.',
        actions: const [
          PawMateAdaptiveAction(label: 'Hủy'),
          PawMateAdaptiveAction(
            label: 'Xóa',
            value: 'delete',
            isDestructiveAction: true,
          ),
        ],
      );
    case _PrimitiveKind.datePicker:
      showPawMateAdaptiveDatePicker(
        context: context,
        initialDate: DateTime(2026, 7, 21),
        firstDate: DateTime(2025),
        lastDate: DateTime(2027, 12, 31),
        currentDate: DateTime(2026, 7, 21),
      );
    case _PrimitiveKind.timePicker:
      showPawMateAdaptiveTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 9, minute: 30),
      );
    case _PrimitiveKind.actionSheet:
      showPawMateAdaptiveActionSheet<String>(
        context: context,
        title: 'Chọn thao tác',
        message: 'Áp dụng cho hồ sơ Mochi',
        actions: const [
          PawMateAdaptiveAction(
            label: 'Chỉnh sửa',
            value: 'edit',
            icon: Icons.edit_outlined,
            isDefaultAction: true,
          ),
          PawMateAdaptiveAction(
            label: 'Xóa',
            value: 'delete',
            icon: Icons.delete_outline,
            isDestructiveAction: true,
          ),
        ],
      );
    case _PrimitiveKind.back || _PrimitiveKind.bottomNav:
      break;
  }
}

bool _opensModal(_PrimitiveKind kind) => switch (kind) {
  _PrimitiveKind.dialog ||
  _PrimitiveKind.datePicker ||
  _PrimitiveKind.timePicker ||
  _PrimitiveKind.actionSheet => true,
  _ => false,
};

IconData _iconFor(_PrimitiveKind kind) => switch (kind) {
  _PrimitiveKind.dialog => Icons.chat_bubble_outline,
  _PrimitiveKind.datePicker => Icons.calendar_month_outlined,
  _PrimitiveKind.timePicker => Icons.schedule_outlined,
  _PrimitiveKind.actionSheet => Icons.more_horiz,
  _ => Icons.pets_outlined,
};

String _titleFor(_PrimitiveKind kind) => switch (kind) {
  _PrimitiveKind.dialog => 'Hộp thoại xác nhận',
  _PrimitiveKind.datePicker => 'Bộ chọn ngày',
  _PrimitiveKind.timePicker => 'Bộ chọn giờ',
  _PrimitiveKind.actionSheet => 'Bảng thao tác',
  _ => 'PawMate',
};

String _shortLabelFor(_PrimitiveKind kind) => switch (kind) {
  _PrimitiveKind.dialog => 'hộp thoại',
  _PrimitiveKind.datePicker => 'chọn ngày',
  _PrimitiveKind.timePicker => 'chọn giờ',
  _PrimitiveKind.actionSheet => 'bảng thao tác',
  _ => 'primitive',
};

class _PrimitiveCanvas extends StatelessWidget {
  const _PrimitiveCanvas({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: PawMateCard(
            variant: PawMateCardVariant.raised,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 32, color: AppColors.primary700),
                ),
                const SizedBox(height: AppSpacing.s16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h4(),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyCompact(),
                ),
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.s24),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _precacheNavigationIcons(WidgetTester tester) async {
  final context = tester.element(find.byType(PawMateBottomNav));
  await tester.runAsync(() async {
    for (final destination in PawMateBottomNav.destinations) {
      await precacheImage(AssetImage(destination.iconAsset), context);
    }
  });
  await tester.pump();
}
