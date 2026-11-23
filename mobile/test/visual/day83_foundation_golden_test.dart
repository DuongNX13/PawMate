import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_text_styles.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_ui.dart';

import '../test_support/day83_deterministic_harness.dart';
import '../test_support/ui_test_helpers.dart';

const _goldenRoot = Key('day83-golden-root');

void main() {
  setUpAll(loadPawMateTestFonts);

  for (final size in <ui.Size>[
    const ui.Size(320, 568),
    const ui.Size(390, 844),
    const ui.Size(430, 932),
  ]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('app shell and responsive frame golden at $tag', (
      tester,
    ) async {
      await setTestViewport(tester, size: size);
      await tester.pumpWidget(
        RepaintBoundary(
          key: _goldenRoot,
          child: buildDay83GoldenHarness(home: const _Day83ShellSurface()),
        ),
      );
      await _precacheNav(tester);
      await tester.pumpAndSettle();

      expectNoFlutterOverflow(tester);
      await expectLater(
        find.byKey(_goldenRoot),
        matchesGoldenFile('goldens/day83/app-shell-$tag.png'),
      );
    });
  }

  for (final size in <ui.Size>[
    const ui.Size(360, 800),
    const ui.Size(430, 932),
  ]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('proportional frame golden at $tag', (tester) async {
      await setTestViewport(tester, size: size);
      await tester.pumpWidget(
        RepaintBoundary(
          key: _goldenRoot,
          child: buildDay83GoldenHarness(home: const _Day83ScaledSurface()),
        ),
      );
      await tester.pumpAndSettle();

      expectNoFlutterOverflow(tester);
      final transforms = tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(PawMateScaledFrame),
          matching: find.byType(Transform),
        ),
      );
      for (final transform in transforms) {
        expect(transform.transform.storage[0], 1);
        expect(transform.transform.storage[5], 1);
      }
      await expectLater(
        find.byKey(_goldenRoot),
        matchesGoldenFile('goldens/day83/proportional-$tag.png'),
      );
    });
  }
}

class _Day83ShellSurface extends StatelessWidget {
  const _Day83ShellSurface();

  @override
  Widget build(BuildContext context) {
    final services = Day83GoldenEnvironment.of(context).services;
    return PawMatePageScaffold(
      layoutMode: PawMatePageLayoutMode.fullResponsive,
      topBar: const PawMateTopBar(title: 'PawMate', brandTitle: true),
      fixedCtaBar: PawMateFixedCtaBar(
        primaryAction: PawMateAction(
          label: 'Xem lịch hôm nay',
          onPressed: () {},
        ),
      ),
      bottomNavigationBar: PawMateBottomNav(
        currentRoute: '/health',
        onDestinationSelected: (_) {},
      ),
      body: PawMateResponsiveFrame(
        builder: (context, metrics) => ListView(
          padding: EdgeInsets.only(top: metrics.sectionGap),
          children: [
            Text('Sức khỏe của Mochi', style: AppTextStyles.h3()),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Cập nhật lúc ${services.now().hour.toString().padLeft(2, '0')}:41 · $day83Timezone',
              style: AppTextStyles.bodyCompact(),
            ),
            const SizedBox(height: AppSpacing.s16),
            PawMateCard(
              variant: PawMateCardVariant.task,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PawMateBadge(label: 'Nhắc nhở sắp tới'),
                  const SizedBox(height: AppSpacing.s12),
                  Text(
                    'Tiêm ngừa dại · Ngày mai, 09:30',
                    style: AppTextStyles.h4(),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text('PetCare Elite', style: AppTextStyles.bodyCompact()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Day83ScaledSurface extends StatelessWidget {
  const _Day83ScaledSurface();

  @override
  Widget build(BuildContext context) {
    return PawMatePageScaffold(
      topBar: const PawMateTopBar(title: 'Xác nhận'),
      body: PawMateScaledFrame(
        child: PawMateCard(
          variant: PawMateCardVariant.raised,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PawMateAvatar(
                semanticLabel: 'Mochi',
                fallbackText: 'Mochi',
              ),
              const SizedBox(height: AppSpacing.s16),
              Text('Đã lưu thay đổi', style: AppTextStyles.h4()),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Hồ sơ của Mochi đã được cập nhật an toàn.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyCompact(),
              ),
              const SizedBox(height: AppSpacing.s24),
              PawMateButton(label: 'Hoàn tất', onPressed: () {}),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _precacheNav(WidgetTester tester) async {
  final context = tester.element(find.byType(PawMateBottomNav));
  await tester.runAsync(() async {
    for (final destination in PawMateBottomNav.destinations) {
      await precacheImage(AssetImage(destination.iconAsset), context);
    }
  });
  await tester.pump();
}
