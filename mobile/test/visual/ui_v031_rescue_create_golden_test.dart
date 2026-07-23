import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_create_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_write_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_draft_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_create_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_info_form_screen.dart';

import '../test_support/ui_test_helpers.dart';

const _viewports = [Size(360, 844), Size(390, 844)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  for (final viewport in _viewports) {
    final tag = '${viewport.width.toInt()}x${viewport.height.toInt()}';
    testWidgets('P2-02 create alert golden at $tag', (tester) async {
      await _pump(tester, const RescueCreateScreen(), viewport);
      await expectLater(
        find.byKey(const Key('rescue-create-golden-root')),
        matchesGoldenFile('goldens/ui-v031-rescue/rescue-create-$tag.png'),
      );
      expectNoFlutterOverflow(tester);
    });

    testWidgets('P2-03 lost info golden at $tag', (tester) async {
      await _pump(
        tester,
        const RescueInfoFormScreen(),
        viewport,
        seedDraft: true,
      );
      await expectLater(
        find.byKey(const Key('rescue-info-golden-root')),
        matchesGoldenFile('goldens/ui-v031-rescue/rescue-info-$tag.png'),
      );
      expectNoFlutterOverflow(tester);
    });
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  Size viewport, {
  bool seedDraft = false,
}) async {
  await setTestViewport(tester, size: viewport);
  final container = ProviderContainer(
    overrides: [
      rescueWriteSourceProvider.overrideWithValue(_NoopWriteSource()),
    ],
  );
  addTearDown(container.dispose);
  if (seedDraft) {
    final notifier = container.read(rescueCreateProvider.notifier);
    notifier.setIdentifyingFeatures('Vòng cổ màu đỏ, bốn chân trắng.');
    notifier.setBehaviorHint('Bé hiền, quen tên Mochi.');
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: ValueKey(
          child is RescueCreateScreen
              ? 'rescue-create-golden-root'
              : 'rescue-info-golden-root',
        ),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _NoopWriteSource implements RescueWriteSource {
  @override
  Future<RescueDraft> createDraft({
    required String accessToken,
    String source = 'rescue_home',
  }) async => const RescueDraft(draftId: 'draft', version: 1);

  @override
  Future<RescueDraft> updateDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
    required Map<String, Object?> patch,
  }) async => RescueDraft.fromJson({
    'draftId': draftId,
    'version': expectedVersion + 1,
    ...patch,
  });

  @override
  Future<void> publishDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
  }) async {}

  @override
  Future<RescueDraftMedia> uploadMedia({
    required String accessToken,
    required RescueDraftMedia media,
  }) async => media;
}
