import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_create_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_write_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_draft_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_create_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_info_form_screen.dart';

import '../../test_support/ui_test_helpers.dart';

void main() {
  testWidgets('P2-02 keeps compact CTA below content at canonical width', (
    tester,
  ) async {
    await _pump(tester, const RescueCreateScreen(), size: const Size(390, 844));

    expect(find.text('Tạo tin báo mất'), findsOneWidget);
    expect(find.byKey(const Key('rescue-create-media-upload')), findsOneWidget);
    expect(find.byKey(const Key('rescue-create-continue-cta')), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    'P2-03 keeps long descriptions inside fields at 360 and large text',
    (tester) async {
      await _pump(
        tester,
        const RescueInfoFormScreen(),
        size: const Size(360, 844),
        textScale: 1.3,
        seedDraft: true,
      );

      expect(find.text('Thông tin chi tiết'), findsOneWidget);
      expect(
        find.byKey(const Key('rescue-info-identifying-features-field')),
        findsOneWidget,
      );
      expect(find.text('Đăng tin tìm'), findsOneWidget);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('create form remains responsive across supported widths', (
    tester,
  ) async {
    for (final width in [360.0, 390.0, 412.0, 430.0]) {
      await _pump(tester, const RescueCreateScreen(), size: Size(width, 844));
      expectNoFlutterOverflow(tester);
    }
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Size size,
  double textScale = 1,
  bool seedDraft = false,
}) async {
  await setTestViewport(tester, size: size);
  final source = _NoopWriteSource();
  final container = ProviderContainer(
    overrides: [
      rescueWriteSourceProvider.overrideWithValue(source),
      authAccessTokenProvider.overrideWith((ref) async => 'token'),
    ],
  );
  addTearDown(container.dispose);
  if (seedDraft) {
    final notifier = container.read(rescueCreateProvider.notifier);
    notifier.setIdentifyingFeatures(
      'Vòng cổ màu đỏ, có vết sẹo nhỏ ở tai trái, bốn chân trắng.',
    );
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        builder: testTextScaleBuilder(textScale),
        home: child,
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
