import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_ui.dart';

import '../../test_support/day10_foundation_harness.dart';
import '../../test_support/ui_test_helpers.dart';

void main() {
  setUpAll(loadPawMateTestFonts);

  testWidgets('button exposes primary, loading and disabled semantics', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    var taps = 0;
    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PawMateButton(
              key: const Key('primary-button'),
              label: 'Lưu hồ sơ',
              onPressed: () => taps++,
            ),
            PawMateButton(
              key: const Key('loading-button'),
              label: 'Đang lưu',
              onPressed: () => taps++,
              isLoading: true,
            ),
            const PawMateButton(
              key: Key('disabled-button'),
              label: 'Không khả dụng',
              onPressed: null,
            ),
            PawMateButton(
              key: const Key('compact-button'),
              label: 'Để sau',
              onPressed: () => taps++,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('primary-button'))).height,
      greaterThanOrEqualTo(AppControlSize.buttonHeight),
    );
    final compactSize = tester.getSize(find.byKey(const Key('compact-button')));
    expect(compactSize.width, inInclusiveRange(48, 160));
    expect(
      compactSize.height,
      greaterThanOrEqualTo(AppControlSize.buttonHeight),
    );
    await tester.tap(find.text('Lưu hồ sơ'));
    await tester.tap(find.text('Đang lưu'));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Lưu hồ sơ'), findsOneWidget);
    expect(find.bySemanticsLabel('Không khả dụng'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('compact button keeps a 36dp visual inside a 48dp target', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    await tester.pumpWidget(
      _app(
        PawMateButton(
          key: const Key('compact-cta'),
          label: 'Để sau',
          onPressed: () {},
          fullWidth: false,
          compact: true,
        ),
      ),
    );

    final button = find.byKey(const Key('compact-cta'));
    final visual = find.descendant(
      of: button,
      matching: find.byType(AnimatedContainer),
    );
    expect(tester.getSize(button).height, AppControlSize.minTouchTarget);
    expect(
      tester.getSize(visual).height,
      AppControlSize.compactButtonVisualHeight,
    );
    expect(find.byType(FittedBox), findsNothing);
    expectNoFlutterOverflow(tester);
  });

  for (final scale in [1.31, 2.0]) {
    testWidgets('compact CTA auto-grows without truncating at scale $scale', (
      tester,
    ) async {
      await setTestViewport(tester, size: const Size(320, 568));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(scale),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 210,
                child: PawMateButton(
                  key: const Key('scaled-cta'),
                  label: 'Xác nhận lịch chăm sóc thú cưng hôm nay',
                  onPressed: () {},
                  compact: true,
                ),
              ),
            ),
          ),
        ),
      );

      final button = find.byKey(const Key('scaled-cta'));
      final text = tester.widget<Text>(
        find.descendant(of: button, matching: find.byType(Text)),
      );
      expect(tester.getSize(button).height, greaterThan(48));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
      expect(find.byType(FittedBox), findsNothing);
      expectNoFlutterOverflow(tester);
    });
  }

  testWidgets('action cluster stacks for long labels and accessibility text', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));

    Future<void> pumpCluster({
      required double scale,
      required String primaryLabel,
      required String secondaryLabel,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(scale),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: PawMateActionCluster(
                key: const Key('action-cluster'),
                primaryAction: PawMateAction(
                  label: primaryLabel,
                  onPressed: () {},
                ),
                secondaryAction: PawMateAction(
                  label: secondaryLabel,
                  onPressed: () {},
                  variant: PawMateButtonVariant.secondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Finder horizontalCluster() => find.descendant(
      of: find.byKey(const Key('action-cluster')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Row && widget.children.whereType<Expanded>().length == 2,
      ),
    );
    Finder verticalCluster() => find.descendant(
      of: find.byKey(const Key('action-cluster')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Column &&
            widget.children.whereType<PawMateButton>().length == 2,
      ),
    );

    await pumpCluster(
      scale: 1,
      primaryLabel: 'Tiếp tục',
      secondaryLabel: 'Để sau',
    );
    expect(horizontalCluster(), findsOneWidget);
    expect(verticalCluster(), findsNothing);

    await pumpCluster(
      scale: 1,
      primaryLabel: 'Xác nhận lịch chăm sóc thú cưng hôm nay',
      secondaryLabel: 'Quay lại và chỉnh sửa thông tin',
    );
    expect(horizontalCluster(), findsNothing);
    expect(verticalCluster(), findsOneWidget);
    expectNoFlutterOverflow(tester);

    await pumpCluster(
      scale: 2,
      primaryLabel: 'Tiếp tục',
      secondaryLabel: 'Để sau',
    );
    expect(horizontalCluster(), findsNothing);
    expect(verticalCluster(), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('text field keeps visible label, error and 48dp input', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(360, 800));
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        PawMateTextField(
          label: 'Tên thú cưng',
          hintText: 'Ví dụ: Bắp',
          isRequired: true,
          errorText: 'Vui lòng nhập tên',
          controller: controller,
        ),
      ),
    );

    expect(find.textContaining('Tên thú cưng'), findsOneWidget);
    expect(find.text('Vui lòng nhập tên'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Mochi');
    expect(controller.text, 'Mochi');
    expect(
      tester.getSize(find.byType(TextFormField)).height,
      greaterThanOrEqualTo(AppControlSize.inputHeight),
    );
    expectNoFlutterOverflow(tester);
  });

  testWidgets('card, chip and status have non-color interaction cues', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    var cardTaps = 0;
    var chipTaps = 0;
    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PawMateCard(
              semanticLabel: 'Hồ sơ Mochi',
              onTap: () => cardTaps++,
              child: const Text('Mochi'),
            ),
            PawMateChip(
              key: const Key('compact-chip'),
              label: 'Đang mở',
              selected: true,
              onPressed: () => chipTaps++,
            ),
            const PawMateStatus(
              label: 'Trạng thái tìm kiếm',
              value: PawMateStatusValue.unresolved,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Mochi'));
    await tester.tap(find.text('Đang mở'));
    expect(cardTaps, 1);
    expect(chipTaps, 1);
    expect(
      tester.getSize(find.byKey(const Key('compact-chip'))).height,
      greaterThanOrEqualTo(AppControlSize.minTouchTarget),
    );
    expect(find.text('Chưa thấy'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Trạng thái tìm kiếm: Chưa thấy'),
      findsOneWidget,
    );
    expectNoFlutterOverflow(tester);
  });

  testWidgets('upload tile exposes retry and remove states', (tester) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final semantics = tester.ensureSemantics();
    var retries = 0;
    var removes = 0;
    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PawMateUploadTile(
              label: 'Ảnh thú cưng',
              state: PawMateUploadState.error,
              onRetry: () => retries++,
            ),
            PawMateUploadTile(
              label: 'Video thú cưng',
              state: PawMateUploadState.uploaded,
              onRemove: () => removes++,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Tải lên thất bại'));
    await tester.tap(find.byTooltip('Xóa tệp đã tải lên'));
    expect(retries, 1);
    expect(removes, 1);
    expect(find.bySemanticsLabel('Xóa tệp đã tải lên'), findsOneWidget);
    expectNoFlutterOverflow(tester);
    semantics.dispose();
  });

  testWidgets('top bar and fixed CTA keep 48dp targets at large text', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(360, 800));
    final semantics = tester.ensureSemantics();
    var backTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: testTextScaleBuilder(1.3),
        home: PawMatePageScaffold(
          topBar: PawMateTopBar(
            title: 'Biểu mẫu dài',
            showBackButton: true,
            onBack: () => backTaps++,
          ),
          fixedCtaBar: PawMateFixedCtaBar(
            primaryAction: PawMateAction(label: 'Tiếp tục', onPressed: () {}),
            secondaryAction: PawMateAction(
              label: 'Để sau',
              onPressed: () {},
              variant: PawMateButtonVariant.secondary,
            ),
          ),
          body: const SizedBox.expand(),
        ),
      ),
    );

    final backFinder = find.byTooltip('Quay lại');
    final backRect = tester.getRect(backFinder);
    final ctaRect = tester.getRect(find.text('Tiếp tục'));
    expect(
      backRect.bottom,
      lessThanOrEqualTo(ctaRect.top),
      reason: 'Back button $backRect must not overlap fixed CTA $ctaRect.',
    );
    expect(ctaRect.top, greaterThan(600));
    await tester.tap(backFinder);
    expect(backTaps, 1);
    expect(tester, meetsGuideline(androidTapTargetGuideline));
    expect(tester, meetsGuideline(labeledTapTargetGuideline));
    expectNoFlutterOverflow(tester);
    semantics.dispose();
  });

  testWidgets('page scaffold makes safe-area ownership explicit', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    tester.view.padding = const FakeViewPadding(
      top: 24,
      bottom: 20,
      left: 8,
      right: 8,
    );
    addTearDown(tester.view.resetPadding);

    Future<void> pump(PawMateSafeAreaPolicy policy) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PawMatePageScaffold(
          safeAreaPolicy: policy,
          body: const ColoredBox(
            key: Key('safe-body'),
            color: AppColors.surface,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    await pump(PawMateSafeAreaPolicy.automatic);
    final safeRect = tester.getRect(find.byKey(const Key('safe-body')));
    expect(safeRect, const Rect.fromLTRB(8, 24, 382, 824));

    await pump(PawMateSafeAreaPolicy.none);
    final edgeRect = tester.getRect(find.byKey(const Key('safe-body')));
    expect(edgeRect, const Rect.fromLTRB(0, 0, 390, 844));
    expectNoFlutterOverflow(tester);
  });

  testWidgets('state view announces recovery and toast uses live region', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: PawMateStateView(
                    type: PawMateStateType.offline,
                    title: 'Không tải được dữ liệu',
                    message: 'Kiểm tra Wifi hoặc 4G.',
                    primaryActionLabel: 'Thử lại',
                    onPrimaryAction: () {},
                  ),
                ),
                PawMateButton(
                  label: 'Hiện thông báo',
                  onPressed: () => PawMateToast.show(
                    context,
                    message: 'Cập nhật thành công',
                    type: PawMateToastType.success,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final stateSemantics = tester.getSemantics(find.byType(PawMateStateView));
    expect(
      stateSemantics.label,
      contains('Không tải được dữ liệu. Kiểm tra Wifi hoặc 4G.'),
    );
    final recoverySemantics = tester.getSemantics(
      find.bySemanticsLabel('Thử lại'),
    );
    final recoveryData = recoverySemantics.getSemanticsData();
    expect(recoveryData.flagsCollection.isButton, isTrue);
    expect(recoveryData.flagsCollection.isEnabled, Tristate.isTrue);
    expect(recoveryData.hasAction(SemanticsAction.tap), isTrue);
    await tester.tap(find.text('Hiện thông báo'));
    await tester.pump();
    expect(find.text('Cập nhật thành công'), findsOneWidget);
    expectNoFlutterOverflow(tester);
    semantics.dispose();
  });

  for (final width in [390.0, 360.0, 412.0, 430.0]) {
    testWidgets('foundation harness fits ${width.toInt()}x844', (tester) async {
      await setTestViewport(tester, size: Size(width, 844));
      for (final surface in Day10FoundationSurface.values) {
        await tester.pumpWidget(buildDay10FoundationHarness(surface));
        await tester.pump();
        expectNoFlutterOverflow(tester);
      }
    });
  }
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: child,
        ),
      ),
    ),
  );
}
