import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_adaptive.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  setUpAll(loadPawMateTestFonts);

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    final platformName = platform.name;

    testWidgets('adaptive back icon matches $platformName', (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));
      await tester.pumpWidget(
        _app(platform, const Center(child: PawMateAdaptiveBackButton())),
      );

      expect(find.byTooltip('Quay lại'), findsOneWidget);
      expect(
        find.byIcon(
          platform == TargetPlatform.iOS
              ? Icons.arrow_back_ios_new_rounded
              : Icons.arrow_back,
        ),
        findsOneWidget,
      );
    });

    testWidgets('adaptive back can be disabled on $platformName', (
      tester,
    ) async {
      await setTestViewport(tester, size: const Size(390, 844));
      await tester.pumpWidget(
        _app(
          platform,
          const Center(child: PawMateAdaptiveBackButton(enabled: false)),
        ),
      );

      expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
    });

    testWidgets('adaptive dialog uses native $platformName primitive', (
      tester,
    ) async {
      await setTestViewport(tester, size: const Size(390, 844));
      String? selected;
      await tester.pumpWidget(
        _app(
          platform,
          Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  selected = await showPawMateAdaptiveDialog<String>(
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
                },
                child: const Text('Mở hộp thoại'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở hộp thoại'));
      await tester.pumpAndSettle();
      expect(
        platform == TargetPlatform.iOS
            ? find.byType(CupertinoAlertDialog)
            : find.byType(AlertDialog),
        findsOneWidget,
      );
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();
      expect(selected, 'delete');
      expectNoFlutterOverflow(tester);
    });

    testWidgets('adaptive pickers and action sheet use $platformName widgets', (
      tester,
    ) async {
      await setTestViewport(tester, size: const Size(390, 844));
      await tester.pumpWidget(
        _app(
          platform,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () => showPawMateAdaptiveDatePicker(
                        context: context,
                        initialDate: DateTime(2026, 7, 21),
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2027, 12, 31),
                        currentDate: DateTime(2026, 7, 21),
                      ),
                      child: const Text('Mở chọn ngày'),
                    ),
                    ElevatedButton(
                      onPressed: () => showPawMateAdaptiveTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 9, minute: 30),
                      ),
                      child: const Text('Mở chọn giờ'),
                    ),
                    ElevatedButton(
                      onPressed: () => showPawMateAdaptiveActionSheet<String>(
                        context: context,
                        title: 'Chọn thao tác',
                        actions: const [
                          PawMateAdaptiveAction(
                            label: 'Chỉnh sửa',
                            value: 'edit',
                            icon: Icons.edit_outlined,
                          ),
                          PawMateAdaptiveAction(
                            label: 'Xóa',
                            value: 'delete',
                            icon: Icons.delete_outline,
                            isDestructiveAction: true,
                          ),
                        ],
                      ),
                      child: const Text('Mở bảng thao tác'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở chọn ngày'));
      await tester.pumpAndSettle();
      expect(
        platform == TargetPlatform.iOS
            ? find.byType(CupertinoDatePicker)
            : find.byType(DatePickerDialog),
        findsOneWidget,
      );
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mở chọn giờ'));
      await tester.pumpAndSettle();
      expect(
        platform == TargetPlatform.iOS
            ? find.byType(CupertinoDatePicker)
            : find.byType(TimePickerDialog),
        findsOneWidget,
      );
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mở bảng thao tác'));
      await tester.pumpAndSettle();
      if (platform == TargetPlatform.iOS) {
        expect(find.byType(CupertinoActionSheet), findsOneWidget);
      } else {
        expect(find.byType(ListTile), findsNWidgets(2));
      }
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expectNoFlutterOverflow(tester);
    });
  }
}

Widget _app(TargetPlatform platform, Widget home) {
  return MaterialApp(
    theme: AppTheme.light().copyWith(platform: platform),
    locale: const Locale('vi', 'VN'),
    supportedLocales: const [Locale('vi', 'VN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: home,
  );
}
