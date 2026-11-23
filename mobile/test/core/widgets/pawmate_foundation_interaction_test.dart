import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_ui.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  setUpAll(loadPawMateTestFonts);

  testWidgets('focus traverses fields then enabled CTA in reading order', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final nameFocus = FocusNode(debugLabel: 'pet-name');
    final breedFocus = FocusNode(debugLabel: 'pet-breed');
    final submitFocus = FocusNode(debugLabel: 'submit');
    addTearDown(nameFocus.dispose);
    addTearDown(breedFocus.dispose);
    addTearDown(submitFocus.dispose);

    await tester.pumpWidget(
      _app(
        Column(
          children: [
            PawMateTextField(
              label: 'Tên thú cưng',
              focusNode: nameFocus,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            PawMateTextField(label: 'Giống loài', focusNode: breedFocus),
            const SizedBox(height: 16),
            PawMateButton(
              label: 'Lưu hồ sơ',
              focusNode: submitFocus,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(nameFocus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(breedFocus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(submitFocus.hasFocus, isTrue);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('[D11-FND-001] fixed CTA remains above software keyboard', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(360, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PawMatePageScaffold(
          topBar: const PawMateTopBar(title: 'Form dài'),
          fixedCtaBar: PawMateFixedCtaBar(
            primaryAction: PawMateAction(label: 'Tiếp tục', onPressed: () {}),
          ),
          body: const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: PawMateTextField(
              label: 'Đặc điểm nhận dạng',
              autofocus: true,
              maxLines: 4,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await setKeyboardInset(tester, bottom: 300);
    await tester.pumpAndSettle();

    final ctaRect = tester.getRect(find.text('Tiếp tục'));
    expect(
      ctaRect.bottom,
      lessThanOrEqualTo(544),
      reason: 'CTA $ctaRect must stay above the keyboard top at y=544.',
    );
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    '[UI-A11Y] shared fixed CTA stays hit-testable at 320dp, scale 2.0 and IME',
    (tester) async {
      await setTestViewport(tester, size: const Size(320, 568));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(2),
          home: PawMatePageScaffold(
            topBar: const PawMateTopBar(title: 'Biểu mẫu dài'),
            fixedCtaBar: PawMateFixedCtaBar(
              primaryAction: PawMateAction(label: 'Tiếp tục', onPressed: () {}),
            ),
            body: const SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: PawMateTextField(
                label: 'Đặc điểm nhận dạng',
                autofocus: true,
                maxLines: 4,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await setKeyboardInset(tester, bottom: 300);
      await tester.pumpAndSettle();

      final cta = find.text('Tiếp tục');
      final ctaRect = tester.getRect(cta);
      expect(ctaRect.bottom, lessThanOrEqualTo(268));
      final ctaButton = find.ancestor(
        of: cta,
        matching: find.byType(PawMateButton),
      );
      expect(tester.getSize(ctaButton).height, greaterThanOrEqualTo(48));
      await tester.tap(cta);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('loading, disabled and error semantics expose exact state', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(supportsAnnounce: false);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await setTestViewport(tester, size: const Size(390, 844));
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            PawMateButton(
              key: const Key('loading'),
              label: 'Đang lưu',
              onPressed: () {},
              isLoading: true,
              trailingIcon: Icons.save,
            ),
            const SizedBox(height: 16),
            const PawMateButton(
              key: Key('disabled'),
              label: 'Không khả dụng',
              onPressed: null,
            ),
            const SizedBox(height: 16),
            const PawMateTextField(
              key: Key('invalid-field'),
              label: 'Tên thú cưng',
              isRequired: true,
              errorText: 'Vui lòng nhập tên',
            ),
          ],
        ),
      ),
    );

    final loading = tester.getSemantics(find.byKey(const Key('loading')));
    expect(loading.label, 'Đang lưu');
    expect(loading.value, 'Đang xử lý');
    expect(loading.flagsCollection.isEnabled, Tristate.isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.save), findsNothing);

    final disabled = tester.getSemantics(find.byKey(const Key('disabled')));
    expect(disabled.label, 'Không khả dụng');
    expect(disabled.flagsCollection.isEnabled, Tristate.isFalse);

    final invalid = tester.getSemantics(find.byType(EditableText));
    expect(invalid.label, 'Tên thú cưng, bắt buộc');
    expect(invalid.value, isEmpty);
    final error = tester.getSemantics(find.text('Vui lòng nhập tên'));
    expect(error.label, contains('Vui lòng nhập tên'));
    expect(
      error.getSemanticsData().flagsCollection.isLiveRegion ||
          (error.parent?.getSemanticsData().flagsCollection.isLiveRegion ??
              false),
      isTrue,
      reason: error.parent?.toStringDeep(),
    );
    expectNoFlutterOverflow(tester);
    semantics.dispose();
  });

  testWidgets('all state types expose announcement and recovery action', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final semantics = tester.ensureSemantics();
    for (final entry in const <PawMateStateType, IconData>{
      PawMateStateType.empty: Icons.pets_outlined,
      PawMateStateType.error: Icons.error_outline,
      PawMateStateType.offline: Icons.cloud_off_outlined,
      PawMateStateType.success: Icons.check_circle_outline,
    }.entries) {
      var retries = 0;
      await tester.pumpWidget(
        _app(
          PawMateStateView(
            type: entry.key,
            title: 'Trạng thái ${entry.key.name}',
            message: 'Thông điệp có thể phục hồi.',
            primaryActionLabel: 'Thử lại',
            onPrimaryAction: () => retries++,
          ),
        ),
      );
      await tester.pump();

      final node = tester.getSemantics(find.byType(PawMateStateView));
      expect(
        node.label,
        contains('Trạng thái ${entry.key.name}. Thông điệp có thể phục hồi.'),
      );
      expect(find.byIcon(entry.value), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      expect(retries, 1);
      expectNoFlutterOverflow(tester);
    }
    semantics.dispose();
  });

  testWidgets('state recovery action remains reachable at 320dp/text scale 2', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(320, 568));
    var retries = 0;
    var secondaryActions = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: testTextScaleBuilder(2),
        home: Scaffold(
          bottomNavigationBar: const PawMateBottomNav(currentRoute: '/pets'),
          body: PawMateStateView(
            key: const Key('large-text-state'),
            type: PawMateStateType.offline,
            title: 'Không tải được dữ liệu',
            message:
                'Không thể đồng bộ hồ sơ thú cưng. Vui lòng kiểm tra kết nối và thử lại.',
            primaryActionLabel: 'Thử lại',
            onPrimaryAction: () => retries++,
            secondaryActionLabel: 'Về trang chủ',
            onSecondaryAction: () => secondaryActions++,
          ),
        ),
      ),
    );
    await tester.pump();

    final retry = find.text('Thử lại');
    await tester.ensureVisible(retry);
    final retryRect = tester.getRect(retry);
    expect(retryRect.top, greaterThanOrEqualTo(0));
    expect(retryRect.bottom, lessThanOrEqualTo(568));
    await tester.tap(retry);
    expect(retries, 1);
    final secondary = find.text('Về trang chủ');
    await tester.ensureVisible(secondary);
    final secondaryRect = tester.getRect(secondary);
    expect(secondaryRect.top, greaterThanOrEqualTo(0));
    expect(secondaryRect.bottom, lessThanOrEqualTo(568));
    await tester.tap(secondary);
    expect(secondaryActions, 1);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('top bar default back action pops current route', (tester) async {
    await setTestViewport(tester, size: const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      appBar: PawMateTopBar(
                        title: 'Chi tiết',
                        showBackButton: true,
                      ),
                      body: Center(child: Text('Màn chi tiết')),
                    ),
                  ),
                ),
                child: const Text('Mở chi tiết'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở chi tiết'));
    await tester.pumpAndSettle();
    expect(find.text('Màn chi tiết'), findsOneWidget);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('Mở chi tiết'), findsOneWidget);
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}
