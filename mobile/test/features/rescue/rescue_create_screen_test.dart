import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_create_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_write_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_draft_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_create_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_info_form_screen.dart';

import '../../test_support/day114_capture.dart';
import '../../test_support/ui_test_helpers.dart';
import 'rescue_test_fixtures.dart';

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

  testWidgets('P2-02 keeps its top-bar title readable at text scale 2.0', (
    tester,
  ) async {
    await _pump(
      tester,
      const RescueCreateScreen(),
      size: const Size(320, 568),
      textScale: 2,
    );

    expect(find.bySemanticsLabel('Tạo tin báo mất'), findsOneWidget);
    final title = find.text('Tạo tin');
    expect(title, findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
      isFalse,
      reason: 'Visible P2-02 title must not ellipsize at text scale 2.0',
    );
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    'P2-03 keeps long descriptions inside fields at 360 and text scale 2.0',
    (tester) async {
      await _pump(
        tester,
        const RescueInfoFormScreen(),
        size: const Size(360, 844),
        textScale: 2,
        seedDraft: true,
      );

      expect(find.text('Chi tiết'), findsOneWidget);
      expect(find.bySemanticsLabel('Thông tin chi tiết'), findsOneWidget);
      expect(
        find.byKey(const Key('rescue-info-identifying-features-field')),
        findsOneWidget,
      );
      expect(find.text('Đăng tin tìm'), findsOneWidget);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets(
    'P2-03 keeps its top-bar and progress labels readable at text scale 2.0',
    (tester) async {
      await _pump(
        tester,
        const RescueInfoFormScreen(),
        size: const Size(320, 568),
        textScale: 2,
        seedDraft: true,
      );

      expect(find.bySemanticsLabel('Thông tin chi tiết'), findsOneWidget);

      for (final label in ['Chi tiết', 'Hoàn thiện hồ sơ']) {
        final finder = find.text(label);
        expect(finder, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(finder).didExceedMaxLines,
          isFalse,
          reason: 'Visible P2-03 copy must not ellipsize: $label',
        );
      }
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets(
    'P2-03 keeps its writable field above fixed CTA at text scale 2.0 with keyboard',
    (tester) async {
      await _pump(
        tester,
        const RescueInfoFormScreen(),
        size: const Size(320, 568),
        textScale: 2,
        seedDraft: true,
      );

      final nicknameField = find.descendant(
        of: find.byKey(const Key('rescue-info-behavior-field')),
        matching: find.byType(TextFormField),
      );
      await tester.scrollUntilVisible(
        nicknameField,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(nicknameField);
      await tester.drag(
        find.byKey(const Key('rescue-info-form')),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(nicknameField).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(const Key('rescue-info-publish-cta'))).top,
        ),
      );
      await tester.tap(nicknameField);
      await setKeyboardInset(tester, bottom: 300);
      await tester.enterText(nicknameField, 'Mochi');

      _expectCtaAboveKeyboard(tester, const Key('rescue-info-publish-cta'));
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets(
    'P2-02 keeps its final writable field above fixed CTA at text scale 2.0 with keyboard',
    (tester) async {
      await _pump(
        tester,
        const RescueCreateScreen(),
        size: const Size(320, 568),
        textScale: 2,
      );

      final breedField = find.descendant(
        of: find.byKey(const Key('rescue-create-breed-field')),
        matching: find.byType(TextFormField),
      );
      await tester.scrollUntilVisible(
        breedField,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(breedField);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(breedField).bottom,
        lessThanOrEqualTo(
          tester
              .getRect(find.byKey(const Key('rescue-create-continue-cta')))
              .top,
        ),
      );

      await tester.tap(breedField);
      await setKeyboardInset(tester, bottom: 300);
      await tester.enterText(breedField, 'Poodle trắng kem');

      _expectCtaAboveKeyboard(tester, const Key('rescue-create-continue-cta'));
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets(
    'ST-13 keeps the save failure, draft and retry CTA reachable at text scale 2.0',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final container = await _pump(
        tester,
        const RescueCreateScreen(),
        size: const Size(320, 568),
        textScale: 2,
        writeSource: _NoopWriteSource(failUpdates: true),
      );
      final notifier = container.read(rescueCreateProvider.notifier);
      notifier
        ..setPetName('Mochi')
        ..setBreedOrColor('Poodle trắng kem')
        ..setLostAt(DateTime.utc(2026, 7, 23, 10, 30))
        ..setLocation(
          const RescueDraftLocation(latitude: 10.7769, longitude: 106.7009),
        );
      await tester.pump();

      await tester.tap(find.byKey(const Key('rescue-create-continue-cta')));
      await tester.pumpAndSettle();

      final failureCopy = find.text(
        'Không thể lưu bản nháp. Dữ liệu đang giữ trên màn hình.',
      );
      expect(failureCopy, findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Không thể lưu bản nháp. Dữ liệu đang giữ trên màn hình.',
        ),
        findsOneWidget,
      );
      expect(container.read(rescueCreateProvider).draft.petName, 'Mochi');
      expect(
        tester
            .getSize(find.byKey(const Key('rescue-create-continue-cta')))
            .height,
        greaterThanOrEqualTo(48),
      );
      expectNoFlutterOverflow(tester);
      semantics.dispose();
    },
  );

  testWidgets(
    'P2-03 keeps publish failure announced and retry-ready at text scale 2.0',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final container = await _pump(
        tester,
        const RescueInfoFormScreen(),
        size: const Size(320, 568),
        textScale: 2,
        writeSource: _NoopWriteSource(failPublishes: true),
      );
      final notifier = container.read(rescueCreateProvider.notifier);
      notifier
        ..setPetName('Mochi')
        ..setBreedOrColor('Poodle')
        ..setLostAt(DateTime.utc(2026, 9, 4))
        ..setLocation(
          const RescueDraftLocation(latitude: 10.7, longitude: 106.7),
        )
        ..setIdentifyingFeatures('Vòng cổ đỏ và bốn chân trắng.')
        ..setMedia([
          const RescueDraftMedia(
            path: 'fixture.jpg',
            mimeType: 'image/jpeg',
            sizeBytes: 1024,
          ),
        ])
        ..confirmMediaReview(true);
      await tester.pump();

      await tester.tap(find.byKey(const Key('rescue-info-publish-cta')));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('rescue-review-confirm'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rescue-review-confirm')));
      await tester.pumpAndSettle();

      const failureMessage =
          'Không thể đăng tin. Bản nháp vẫn được giữ để thử lại.';
      expect(find.text(failureMessage), findsOneWidget);
      expect(find.bySemanticsLabel(failureMessage), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(failureMessage))
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      expect(container.read(rescueCreateProvider).draft.media, hasLength(1));
      expect(
        tester.getSize(find.byKey(const Key('rescue-info-publish-cta'))).height,
        greaterThanOrEqualTo(48),
      );
      expectNoFlutterOverflow(tester);
      semantics.dispose();
    },
  );

  testWidgets(
    'D114-ST13-02 publish failure offers reachable retry and save-only recovery',
    (tester) async {
      final source = _NoopWriteSource(failPublishes: true);
      final container = await _pump(
        tester,
        const RescueInfoFormScreen(),
        size: const Size(320, 568),
        textScale: 2,
        writeSource: source,
      );
      final notifier = container.read(rescueCreateProvider.notifier);
      const media = RescueDraftMedia(
        path: 'keep-local.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1024,
      );
      notifier
        ..setPetName('Mochi')
        ..setBreedOrColor('Poodle')
        ..setLostAt(DateTime.utc(2026, 10, 13))
        ..setLocation(
          const RescueDraftLocation(latitude: 10.7, longitude: 106.7),
        )
        ..setIdentifyingFeatures('Vòng cổ đỏ')
        ..setBehaviorHint('Hiền và dễ gần')
        ..setMedia([media])
        ..confirmMediaReview(true);
      await tester.pump();
      await tester.tap(find.byKey(const Key('rescue-info-publish-cta')));
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('rescue-review-confirm'));
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      final back = find.byKey(const Key('rescue-review-back'));
      await tester.ensureVisible(back);
      await tester.pumpAndSettle();
      await tester.tap(back);
      await tester.pumpAndSettle();

      final retry = find.widgetWithText(PawMateButton, 'Đăng lại');
      final save = find.widgetWithText(PawMateButton, 'Lưu nháp');
      expect(retry, findsOneWidget);
      expect(save, findsOneWidget);
      for (final control in [retry, save]) {
        final rect = tester.getRect(control);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(568));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(control.hitTestable(), findsOneWidget);
      }
      final publishCalls = source.publishCalls;
      final uploadCalls = source.uploadCalls;
      final updateCalls = source.updateCalls;
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(source.publishCalls, publishCalls);
      expect(source.uploadCalls, uploadCalls);
      expect(source.updateCalls, updateCalls + 1);
      expect(source.lastPatch?['identifyingFeatures'], 'Vòng cổ đỏ');
      expect(source.lastPatch?['behaviorHint'], 'Hiền và dễ gần');
      expect(container.read(rescueCreateProvider).draft.media, hasLength(1));
      expect(container.read(rescueCreateProvider).draft.petName, 'Mochi');
      expect(container.read(rescueCreateProvider).published, isFalse);
      expect(find.text('Đã lưu bản nháp. Tin chưa được đăng.'), findsOneWidget);
      expectNoFlutterOverflow(tester);
    },
  );

  for (final compact in [false, true]) {
    final size = compact ? const Size(320, 568) : const Size(390, 844);
    final screenshotName = compact ? 'ST-13-small-text2' : 'ST-13';
    testWidgets(
      'D114-ST13 contextual capture $screenshotName uses the production recovery form',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final source = _NoopWriteSource(failPublishes: true);
        final container = await _pump(
          tester,
          const RescueInfoFormScreen(),
          size: size,
          textScale: compact ? 2 : 1,
          writeSource: source,
          seedRecoveryDraft: true,
          captureBoundary: true,
        );

        await tester.tap(find.byKey(const Key('rescue-info-publish-cta')));
        await tester.pumpAndSettle();
        final confirm = find.byKey(const Key('rescue-review-confirm'));
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        final back = find.byKey(const Key('rescue-review-back'));
        await tester.ensureVisible(back);
        await tester.pumpAndSettle();
        await tester.tap(back);
        await tester.pumpAndSettle();

        const errorCopy =
            'Không thể đăng tin. Bản nháp vẫn được giữ để thử lại.';
        final error = find.text(errorCopy);
        expect(error, findsOneWidget);
        await tester.ensureVisible(error);
        await tester.pumpAndSettle();
        final retry = find.widgetWithText(PawMateButton, 'Đăng lại');
        final save = find.widgetWithText(PawMateButton, 'Lưu nháp');
        for (final control in [retry, save]) {
          expect(control, findsOneWidget);
          await tester.ensureVisible(control);
          await tester.pumpAndSettle();
          final rect = tester.getRect(control);
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(control.hitTestable(), findsOneWidget);
        }
        expect(find.bySemanticsLabel(errorCopy), findsOneWidget);
        expect(
          container.read(rescueCreateProvider).draft.identifyingFeatures,
          'Vòng cổ đỏ và bốn chân trắng.',
        );
        expect(container.read(rescueCreateProvider).draft.media, hasLength(1));
        expectNoFlutterOverflow(tester);
        // Fixed footer verification must not leave the scrollable error
        // behind the top bar in the contextual screenshot.
        Scrollable.of(tester.element(error)).position.jumpTo(0);
        await tester.pumpAndSettle();
        await captureDay114(tester, screenshotName);

        final publishCalls = source.publishCalls;
        final uploadCalls = source.uploadCalls;
        final updateCalls = source.updateCalls;
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(source.publishCalls, publishCalls);
        expect(source.uploadCalls, uploadCalls);
        expect(source.updateCalls, updateCalls + 1);
        expect(container.read(rescueCreateProvider).published, isFalse);
        expect(container.read(rescueCreateProvider).draft.media, hasLength(1));
        expect(
          find.text('Đã lưu bản nháp. Tin chưa được đăng.'),
          findsOneWidget,
        );
        semantics.dispose();
        expectNoFlutterOverflow(tester);
      },
    );
  }

  testWidgets('create form remains responsive across supported widths', (
    tester,
  ) async {
    for (final width in [360.0, 390.0, 412.0, 430.0]) {
      await _pump(tester, const RescueCreateScreen(), size: Size(width, 844));
      expectNoFlutterOverflow(tester);
    }
  });

  testWidgets('selected local media renders the picked file, not a demo pet', (
    tester,
  ) async {
    await _pump(
      tester,
      const RescueCreateScreen(),
      size: const Size(390, 844),
      seedMediaPath: 'assets/images/rescue/p2_02_pet.png',
    );

    final preview = find.byKey(const ValueKey('rescue-create-media-preview-0'));
    final image = tester.widget<Image>(
      find.descendant(of: preview, matching: find.byType(Image)),
    );
    expect(image.image, isA<FileImage>());
    final mapSize = tester.getSize(
      find.byKey(const Key('rescue-create-location-card')),
    );
    expect(mapSize.width, 358);
    expect(mapSize.height, closeTo(160, 0.5));
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    'create form keeps touch targets and copy safe at text scale 2.0',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        const RescueCreateScreen(),
        size: const Size(360, 844),
        textScale: 2,
        seedMediaPath: 'asset:assets/images/rescue/p2_02_pet.png',
      );

      expect(
        tester
            .getSize(find.byKey(const Key('rescue-create-media-upload')))
            .height,
        greaterThanOrEqualTo(48),
      );
      expect(find.bySemanticsLabel('Thêm ảnh hoặc video'), findsOneWidget);
      expectNoFlutterOverflow(tester);
      semantics.dispose();
    },
  );

  testWidgets('P2-03 stores nickname and personality in the frozen API field', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      const RescueInfoFormScreen(),
      size: const Size(390, 844),
    );

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('rescue-info-behavior-field')),
        matching: find.byType(TextFormField),
      ),
      'Mochi',
    );
    await tester.tap(find.byKey(const Key('rescue-info-personality-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hiền').last);
    await tester.pumpAndSettle();

    expect(
      container.read(rescueCreateProvider).draft.behaviorHint,
      'Mochi\nTính cách: Hiền',
    );

    await tester.tap(find.text('Công khai số điện thoại'));
    await tester.pumpAndSettle();
    expect(
      container.read(rescueCreateProvider).draft.contactPreference,
      RescueContactPreference.phoneWithConsent,
    );
    expectNoFlutterOverflow(tester);
  });
}

void _expectCtaAboveKeyboard(WidgetTester tester, Key ctaKey) {
  final cta = find.byKey(ctaKey);
  final button = find.descendant(of: cta, matching: find.byType(PawMateButton));
  expect(cta, findsOneWidget);
  expect(button, findsOneWidget);

  final buttonRect = tester.getRect(button);
  // The actual control needs to sit inside the remaining 268dp viewport, not
  // just be mounted in the fixed footer underneath the IME.
  expect(buttonRect.top, greaterThanOrEqualTo(0));
  expect(buttonRect.bottom, lessThanOrEqualTo(568 - 300.0));
  expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget child, {
  required Size size,
  double textScale = 1,
  bool seedDraft = false,
  bool seedRecoveryDraft = false,
  bool captureBoundary = false,
  String? seedMediaPath,
  RescueWriteSource? writeSource,
}) async {
  await setTestViewport(tester, size: size);
  final source = writeSource ?? _NoopWriteSource();
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
  if (seedRecoveryDraft) {
    container.read(rescueCreateProvider.notifier)
      ..setPetName('Mochi')
      ..setBreedOrColor('Poodle')
      ..setLostAt(DateTime.utc(2026, 10, 13))
      ..setLocation(const RescueDraftLocation(latitude: 10.7, longitude: 106.7))
      ..setIdentifyingFeatures('Vòng cổ đỏ và bốn chân trắng.')
      ..setBehaviorHint('Mochi')
      ..setMedia([
        const RescueDraftMedia(
          path: 'keep-local.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 1024,
        ),
      ])
      ..confirmMediaReview(true);
  }
  if (seedMediaPath != null) {
    container.read(rescueCreateProvider.notifier).setMedia([
      RescueDraftMedia(
        path: seedMediaPath,
        mimeType: 'image/png',
        sizeBytes: 29196,
      ),
    ]);
  }
  final app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    builder: testTextScaleBuilder(textScale),
    home: child,
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: captureBoundary
          ? RepaintBoundary(key: const Key('day114-capture'), child: app)
          : app,
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

class _NoopWriteSource implements RescueWriteSource {
  _NoopWriteSource({this.failUpdates = false, this.failPublishes = false});

  final bool failUpdates;
  final bool failPublishes;
  int updateCalls = 0;
  int publishCalls = 0;
  int uploadCalls = 0;
  Map<String, Object?>? lastPatch;

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
  }) async {
    updateCalls += 1;
    lastPatch = patch;
    if (failUpdates) {
      throw const RescueWriteApiException(
        'Không thể lưu bản nháp. Dữ liệu đang giữ trên màn hình.',
        code: 'NETWORK',
      );
    }
    return RescueDraft.fromJson({
      'draftId': draftId,
      'version': expectedVersion + 1,
      ...patch,
    });
  }

  @override
  Future<RescueCaseDetail> publishDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
  }) async {
    publishCalls += 1;
    if (failPublishes) throw StateError('publish unavailable');
    return sampleCaseDetail(caseId: 'create-screen-published');
  }

  @override
  Future<RescueDraftMedia> uploadMedia({
    required String accessToken,
    required RescueDraftMedia media,
  }) async {
    uploadCalls += 1;
    return media.copyWith(mediaId: 'media-1', uploaded: true);
  }
}
