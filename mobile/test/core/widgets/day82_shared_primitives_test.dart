import 'dart:typed_data';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/app/theme/app_tokens.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_ui.dart';

import '../../test_support/day82_component_catalog.dart';
import '../../test_support/ui_test_helpers.dart';

void main() {
  setUpAll(loadPawMateTestFonts);

  testWidgets('icon button variants keep a labeled 48dp target', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _app(
        Wrap(
          children: [
            PawMateIconButton(
              key: const Key('standard-icon-button'),
              icon: Icons.notifications_outlined,
              tooltip: 'Thông báo',
              onPressed: () => taps++,
            ),
            PawMateIconButton(
              key: const Key('tonal-icon-button'),
              icon: Icons.favorite_outline,
              tooltip: 'Yêu thích',
              variant: PawMateIconButtonVariant.tonal,
              onPressed: () => taps++,
            ),
            const PawMateIconButton(
              key: Key('disabled-danger-icon-button'),
              icon: Icons.delete_outline,
              tooltip: 'Xóa',
              variant: PawMateIconButtonVariant.danger,
              onPressed: null,
            ),
          ],
        ),
      ),
    );

    for (final key in const [
      Key('standard-icon-button'),
      Key('tonal-icon-button'),
      Key('disabled-danger-icon-button'),
    ]) {
      final size = tester.getSize(find.byKey(key));
      expect(size.width, greaterThanOrEqualTo(AppControlSize.minTouchTarget));
      expect(size.height, greaterThanOrEqualTo(AppControlSize.minTouchTarget));
    }
    final notification = tester.getSemantics(
      find.bySemanticsLabel('Thông báo'),
    );
    expect(notification.flagsCollection.isButton, isTrue);
    expect(notification.flagsCollection.isEnabled, Tristate.isTrue);
    await tester.tap(find.bySemanticsLabel('Thông báo'));
    expect(taps, 1);
    expectNoFlutterOverflow(tester);
    semantics.dispose();
  });

  testWidgets('badge grows at text scale 2 instead of clipping copy', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(320, 568));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: testTextScaleBuilder(2),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              child: PawMateBadge(
                key: Key('large-badge'),
                label: 'Đang chờ trung tâm xác nhận hồ sơ',
                variant: PawMateBadgeVariant.warning,
                icon: Icons.schedule_outlined,
              ),
            ),
          ),
        ),
      ),
    );

    final badge = find.byKey(const Key('large-badge'));
    final text = tester.widget<Text>(
      find.descendant(of: badge, matching: find.byType(Text)),
    );
    expect(
      tester.getSize(badge).height,
      greaterThan(AppControlSize.chipHeight),
    );
    expect(text.maxLines, isNull);
    expect(text.overflow, isNull);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('avatar and media center-crop imagery with semantic fallback', (
    tester,
  ) async {
    final bytes = Uint8List.fromList(_transparentPng);
    await setTestViewport(tester, size: const Size(390, 844));
    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PawMateAvatar(
              key: const Key('pet-avatar'),
              semanticLabel: 'Ảnh đại diện của Mochi',
              image: MemoryImage(bytes),
              fallbackText: 'M',
              size: 64,
            ),
            PawMateMedia(
              key: const Key('pet-media'),
              semanticLabel: 'Ảnh toàn thân của Mochi',
              image: MemoryImage(bytes),
              aspectRatio: 4 / 3,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    final avatarImage = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('pet-avatar')),
        matching: find.byType(Image),
      ),
    );
    final mediaImage = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('pet-media')),
        matching: find.byType(Image),
      ),
    );
    expect(avatarImage.fit, BoxFit.cover);
    expect(avatarImage.alignment, Alignment.center);
    expect(mediaImage.fit, BoxFit.cover);
    expect(mediaImage.alignment, Alignment.center);
    expect(find.bySemanticsLabel('Ảnh đại diện của Mochi'), findsOneWidget);
    expect(find.bySemanticsLabel('Ảnh toàn thân của Mochi'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('component catalog fits 320dp at text scale $scale', (
      tester,
    ) async {
      await setTestViewport(tester, size: const Size(320, 568));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: testTextScaleBuilder(scale),
          home: const Scaffold(body: Day82ComponentCatalog()),
        ),
      );
      await tester.pump();
      expect(find.text('PawMate primitives'), findsOneWidget);
      expectNoFlutterOverflow(tester);
    });
  }
}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: child,
      ),
    ),
  ),
);

const _transparentPng = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  8,
  215,
  99,
  248,
  207,
  192,
  240,
  31,
  0,
  5,
  0,
  1,
  255,
  137,
  153,
  13,
  29,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];
