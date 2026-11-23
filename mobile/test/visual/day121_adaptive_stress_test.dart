import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_adaptive.dart';

import '../test_support/ui_test_helpers.dart';
import 'day121_stress_platform_test.dart' show capture121;

const _size = Size(320, 568);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final kind in ['back', 'dialog', 'sheet', 'date', 'time']) {
      testWidgets(
        'D121 adaptive ${platform.name} $kind text2 cancellation value and semantics',
        (t) async {
          debugDefaultTargetPlatformOverride = platform;
          t.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
          try {
            await setTestViewport(t, size: _size);
            t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
            t.view.padding = const FakeViewPadding(top: 24, bottom: 34);
            addTearDown(t.view.resetViewPadding);
            addTearDown(t.view.resetPadding);
            final key = GlobalKey<NavigatorState>();
            Object? result = 'not-returned';
            Future<void> open(BuildContext context) async {
              result = switch (kind) {
                'dialog' => await showPawMateAdaptiveDialog<String>(
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
                ),
                'sheet' => await showPawMateAdaptiveActionSheet<String>(
                  context: context,
                  title: 'Chọn ảnh thú cưng',
                  message: 'Chỉ chia sẻ ảnh bạn đồng ý công khai.',
                  actions: const [
                    PawMateAdaptiveAction(
                      label: 'Thư viện ảnh',
                      value: 'gallery',
                      icon: Icons.photo,
                    ),
                  ],
                ),
                'date' => await showPawMateAdaptiveDatePicker(
                  context: context,
                  initialDate: DateTime(2026, 10, 19),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  currentDate: DateTime(2026, 10, 19),
                  title: 'Chọn ngày sinh',
                ),
                'time' => await showPawMateAdaptiveTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 9, minute: 30),
                  title: 'Chọn giờ nhắc',
                ),
                _ => await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      body: SafeArea(
                        child: Column(
                          children: [
                            PawMateAdaptiveBackButton(),
                            Text('Chi tiết fixture'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              };
            }

            await t.pumpWidget(
              MaterialApp(
                navigatorKey: key,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(),
                locale: const Locale('vi', 'VN'),
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                supportedLocales: const [
                  Locale('vi', 'VN'),
                  Locale('en', 'US'),
                ],
                home: Scaffold(
                  body: SafeArea(
                    child: Builder(
                      builder: (context) => Center(
                        child: ElevatedButton(
                          onPressed: () => open(context),
                          child: const Text('Mở fixture'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
            Future<void> launch() async {
              await t.tap(find.text('Mở fixture'));
              await t.pumpAndSettle();
              expectNoFlutterOverflow(t);
            }

            await launch();
            if (platform == TargetPlatform.android && kind == 'date') {
              expect(
                t
                    .widget<DatePickerDialog>(find.byType(DatePickerDialog))
                    .initialEntryMode,
                DatePickerEntryMode.input,
                reason: 'Large text must not clip calendar cells at 320dp',
              );
            }
            if (platform == TargetPlatform.android && kind == 'time') {
              expect(
                t
                    .widget<TimePickerDialog>(find.byType(TimePickerDialog))
                    .initialEntryMode,
                TimePickerEntryMode.input,
                reason: 'Large text must not overlap dial numbers at 320dp',
              );
            }
            if (kind == 'back') {
              expect(find.byTooltip('Quay lại'), findsOneWidget);
              if (platform == TargetPlatform.android) {
                await t.binding.handlePopRoute();
              } else {
                // Flutter Cupertino page transition edge gesture, not iOS device proof.
                await t.dragFrom(const Offset(1, 250), const Offset(290, 0));
              }
              await t.pumpAndSettle();
              expect(find.text('Chi tiết fixture'), findsNothing);
              await launch();
              await t.tap(find.byTooltip('Quay lại'));
              await t.pumpAndSettle();
              expect(find.text('Mở fixture'), findsOneWidget);
            } else {
              final native = switch (kind) {
                'dialog' =>
                  platform == TargetPlatform.iOS
                      ? find.byType(CupertinoAlertDialog)
                      : find.byType(AlertDialog),
                'sheet' =>
                  platform == TargetPlatform.iOS
                      ? find.byType(CupertinoActionSheet)
                      : find.byType(BottomSheet),
                'date' =>
                  platform == TargetPlatform.iOS
                      ? find.byType(CupertinoDatePicker)
                      : find.byType(DatePickerDialog),
                _ =>
                  platform == TargetPlatform.iOS
                      ? find.byType(CupertinoDatePicker)
                      : find.byType(TimePickerDialog),
              };
              expect(native, findsOneWidget);
              _labels(t);
              await capture121(
                t,
                'Adaptive-${platform.name}-$kind-open',
                _size,
              );
              await expectLater(
                find.byType(MaterialApp),
                matchesGoldenFile(
                  'goldens/day121/Adaptive-${platform.name}-$kind.png',
                ),
              );
              await t.tap(find.text('Hủy'));
              await t.pumpAndSettle();
              expect(result, isNull);
              await launch();
              final confirm = kind == 'dialog'
                  ? 'Xóa'
                  : kind == 'sheet'
                  ? 'Thư viện ảnh'
                  : 'Xong';
              await t.tap(find.text(confirm));
              await t.pumpAndSettle();
              expect(result, switch (kind) {
                'dialog' => 'delete',
                'sheet' => 'gallery',
                'date' => DateTime(2026, 10, 19),
                _ => const TimeOfDay(hour: 9, minute: 30),
              });
            }
            expectNoFlutterOverflow(t);
            await t.pumpWidget(const SizedBox.shrink());
            await t.pumpAndSettle();
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        },
      );
    }
  }
}

void _labels(WidgetTester t) {
  // Check PawMate-owned copy and important actions. Material's calendar month
  // selector may visually ellipsize at 320dp/text2 while retaining its complete
  // semantic name; do not redefine the SDK's calendar rendering contract.
  const owned = {
    'Chọn ngày sinh',
    'Chọn giờ nhắc',
    'Xong',
    'Hủy',
    'Xóa',
    'Thư viện ảnh',
    'Chọn ảnh thú cưng',
    'Xóa lịch nhắc?',
  };
  for (final e in find.byType(Text).evaluate()) {
    if (ModalRoute.of(e)?.isCurrent == false) continue;
    if (!owned.contains((e.widget as Text).data)) continue;
    final p = e.renderObject;
    if (p is! RenderParagraph || !p.hasSize) continue;
    expect(
      p.didExceedMaxLines,
      isFalse,
      reason: 'Adaptive labels must not truncate: ${(e.widget as Text).data}',
    );
  }
}
