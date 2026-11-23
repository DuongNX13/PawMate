import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_create_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_location_service.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_write_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_draft_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_map_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_create_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_info_form_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_location_picker_sheet.dart';

import '../../test_support/day116_capture.dart';
import '../../test_support/ui_test_helpers.dart';
import 'rescue_test_fixtures.dart';

const _point = RescueDraftLocation(latitude: 10.7769, longitude: 106.7009);
const _media = RescueDraftMedia(
  path: 'asset:assets/images/rescue/p2_02_pet.png',
  mimeType: 'image/png',
  sizeBytes: 29196,
);

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final scale in [1.0, 1.3, 2.0]) {
    for (final id in ['ST-01', 'ST-02']) {
      testWidgets('D116 R22 $id P2-03 draft retry text$scale', (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final h = await _pump(tester, scale, _LocationBoundary());
          h.container.read(rescueCreateProvider.notifier).setLocation(_point);
          await _tap(tester, find.widgetWithText(PawMateButton, 'Tiếp tục'));
          final field = find.descendant(
            of: find.byKey(const Key('rescue-info-identifying-features-field')),
            matching: find.byType(TextFormField),
          );
          await _reach(tester, field);
          await tester.enterText(field, 'Giữ bản nháp qua lỗi kết nối.');
          final message = id == 'ST-01'
              ? 'Không thể kết nối. Bản nháp vẫn được giữ.'
              : 'Máy chủ tạm thời chưa sẵn sàng. Hãy thử lại.';
          h.source.nextSaveFailure = RescueWriteApiException(
            message,
            statusCode: id == 'ST-02' ? 503 : null,
          );
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await _tap(
            tester,
            find.byKey(const Key('rescue-info-media-review-confirmation')),
          );
          await _tap(
            tester,
            find.widgetWithText(PawMateButton, 'Đăng tin tìm'),
          );
          await _tap(tester, find.byKey(const Key('rescue-review-confirm')));
          await _tap(tester, find.byKey(const Key('rescue-review-back')));
          tester.view.viewInsets = const FakeViewPadding(bottom: 200);
          await tester.pumpAndSettle();
          final save = find.widgetWithText(PawMateButton, 'Lưu nháp');
          final draft = h.container.read(rescueCreateProvider).draft;
          expect(h.source.failedUpdates, 1);
          expect(draft.draftId, 'r21-draft');
          expect(draft.media.single.path, _media.path);
          expect(draft.identifyingFeatures, 'Giữ bản nháp qua lỗi kết nối.');
          final error = find.text(message);
          // Review was opened from the bottom of the lazy form. Its error
          // banner is at the top: expose it by scrolling back, not down.
          await tester.scrollUntilVisible(
            error,
            -180,
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('rescue-info-form')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await _reach(tester, error);
          expect(
            find.ancestor(
              of: error,
              matching: find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.liveRegion == true,
              ),
            ),
            findsOneWidget,
          );
          final stem =
              'R22-$id-P203-text${scale.toString().replaceAll('.', '-')}';
          await captureDay116(tester, '$stem-failed');
          await _tap(tester, save, keyboard: true);
          expect(
            h.source.stored['identifyingFeatures'],
            draft.identifyingFeatures,
          );
          expect(h.source.creates, 1);
          expect(h.source.uploads, 1);
          expect(h.source.publishes, 0);
          expect(h.container.read(rescueCreateProvider).errorMessage, isNull);
          expect(
            tester.widget<TextFormField>(field).controller!.text,
            draft.identifyingFeatures,
          );
          await captureDay116(tester, '$stem-saved');
          tester.view.resetViewInsets();
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          expectNoFlutterOverflow(tester);
        } finally {
          semantics.dispose();
        }
      });
    }
    for (final owner in ['P2-02', 'P2-03']) {
      for (final recovery in ['retry', 'remove']) {
        testWidgets('D116 R22 ST-16 $owner $recovery text$scale', (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          try {
            final h = await _pump(
              tester,
              scale,
              _LocationBoundary(),
              mediaFailure: true,
            );
            final notifier = h.container.read(rescueCreateProvider.notifier);
            notifier.setLocation(_point);
            if (owner == 'P2-03') {
              await _tap(
                tester,
                find.widgetWithText(PawMateButton, 'Tiếp tục'),
              );
            }
            expect(
              find.byType(
                owner == 'P2-02' ? RescueCreateScreen : RescueInfoFormScreen,
              ),
              findsOneWidget,
            );
            if (owner == 'P2-02') {
              await _tap(
                tester,
                find.widgetWithText(PawMateButton, 'Tiếp tục'),
              );
            }
            final features = find.descendant(
              of: find.byKey(
                const Key('rescue-info-identifying-features-field'),
              ),
              matching: find.byType(TextFormField),
            );
            await _reach(tester, features);
            await tester.enterText(features, 'Vòng cổ đỏ và bốn chân trắng.');
            FocusManager.instance.primaryFocus?.unfocus();
            await tester.pumpAndSettle();
            await _tap(
              tester,
              find.byKey(const Key('rescue-info-media-review-confirmation')),
            );
            await _tap(
              tester,
              find.widgetWithText(PawMateButton, 'Đăng tin tìm'),
            );
            await _tap(tester, find.byKey(const Key('rescue-review-confirm')));
            final failed = h.container.read(rescueCreateProvider);
            expect(h.source.uploads, 2);
            expect(h.source.publishes, 0);
            expect(
              failed.draft.media.first.uploaded,
              isTrue,
              reason:
                  'A later upload failure must not erase an earlier successful upload receipt.',
            );
            expect(failed.draft.media.first.mediaId, 'r21-media');
            expect(failed.draft.media.last.uploaded, isFalse);
            expect(
              failed.draft.identifyingFeatures,
              'Vòng cổ đỏ và bốn chân trắng.',
            );
            final stem =
                'R22-ST16-$owner-$recovery-text${scale.toString().replaceAll('.', '-')}';
            await captureDay116(tester, '$stem-failed');
            await _tap(tester, find.byKey(const Key('rescue-review-back')));
            if (recovery == 'remove') {
              await _tap(tester, find.byTooltip('Quay lại'));
              expect(find.byType(RescueCreateScreen), findsOneWidget);
              final tile = find.byKey(
                const ValueKey('rescue-create-media-preview-1'),
              );
              await _reach(tester, tile);
              final remove = find.descendant(
                of: tile,
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is Semantics &&
                      w.properties.label == 'Xóa ảnh hoặc video',
                ),
              );
              await _tap(tester, remove);
              expect(
                h.container.read(rescueCreateProvider).draft.media.length,
                1,
              );
              expect(h.source.uploads, 2);
              expect(
                h.container.read(rescueCreateProvider).draft.petName,
                'Mochi',
              );
              await _tap(
                tester,
                find.widgetWithText(PawMateButton, 'Tiếp tục'),
              );
              await _tap(
                tester,
                find.byKey(const Key('rescue-info-media-review-confirmation')),
              );
            }
            await _tap(
              tester,
              find.widgetWithText(
                PawMateButton,
                recovery == 'remove' ? 'Đăng tin tìm' : 'Đăng lại',
              ),
            );
            await _tap(tester, find.byKey(const Key('rescue-review-confirm')));
            expect(h.source.creates, 1);
            expect(h.source.uploads, recovery == 'retry' ? 3 : 2);
            expect(
              h.source.uploadPaths.where((p) => p == _media.path).length,
              1,
            );
            expect(h.source.publishes, 1);
            expect(h.source.committed?.caseId, 'r21-case');
            expect(
              h.source.stored['mediaIds'],
              recovery == 'retry' ? ['r21-media', 'r22-video'] : ['r21-media'],
            );
            expect(find.byType(RescueHomeScreen), findsOneWidget);
            await captureDay116(tester, '$stem-published');
            expectNoFlutterOverflow(tester);
          } finally {
            semantics.dispose();
          }
        });
      }
    }
    for (final recovery in ['manual', 'retry', 'cancel']) {
      testWidgets('D116 R21 ST-15 P2-02 $recovery text$scale', (tester) async {
        final semantics = tester.ensureSemantics();
        final location = _LocationBoundary();
        final h = await _pump(tester, scale, location);
        final original = h.container.read(rescueCreateProvider).draft;
        await _tap(
          tester,
          find.byKey(const Key('rescue-create-location-card')),
        );
        await _tap(tester, find.byKey(const Key('rescue-location-gps')));
        final error = find.byKey(const Key('rescue-location-error'));
        await _reach(tester, error);
        expect(find.textContaining('Chưa có quyền định vị.'), findsOneWidget);
        expect(
          find.ancestor(
            of: error,
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.liveRegion == true,
            ),
          ),
          findsOneWidget,
        );
        expect(location.calls, 1);
        expect(h.container.read(rescueCreateProvider).draft, same(original));
        expect(h.source.creates, 0);
        await _capture(tester, recovery, scale, 'denied');
        if (recovery == 'manual') {
          tester.view.viewInsets = const FakeViewPadding(bottom: 200);
          await tester.pumpAndSettle();
          for (final entry in [
            ('rescue-location-latitude', '10.7769'),
            ('rescue-location-longitude', '106.7009'),
          ]) {
            final field = find.descendant(
              of: find.byKey(Key(entry.$1)),
              matching: find.byType(TextFormField),
            );
            await _reach(tester, field);
            expect(
              tester.widget<TextFormField>(field).controller!.text,
              isEmpty,
            );
            await tester.enterText(field, entry.$2);
            await tester.pump();
          }
          await _tap(
            tester,
            find.byKey(const Key('rescue-location-apply')),
            keyboard: true,
          );
          expect(h.container.read(rescueCreateProvider).draft, same(original));
          await _tap(
            tester,
            find.byKey(const Key('rescue-location-confirm')),
            keyboard: true,
          );
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
          expect(location.calls, 1);
        } else if (recovery == 'retry') {
          await _tap(tester, find.byKey(const Key('rescue-location-gps')));
          expect(location.calls, 2);
          expect(find.byKey(const Key('rescue-location-error')), findsNothing);
          expect(h.container.read(rescueCreateProvider).draft, same(original));
          await _tap(tester, find.byKey(const Key('rescue-location-confirm')));
        } else {
          await _tap(tester, find.byKey(const Key('rescue-location-cancel')));
          expect(h.container.read(rescueCreateProvider).draft, same(original));
          expect(h.source.creates, 0);
          expect(find.byType(RescueLocationPickerSheet), findsNothing);
          await _capture(tester, recovery, scale, 'cancelled');
          expectNoFlutterOverflow(tester);
          semantics.dispose();
          return;
        }
        final selected = h.container.read(rescueCreateProvider).draft;
        expect(selected.exactLocation!.latitude, _point.latitude);
        expect(selected.exactLocation!.longitude, _point.longitude);
        expect(selected.petName, original.petName);
        expect(selected.media.single, same(_media));
        expect(
          h.source.creates,
          0,
          reason: 'Confirm selects locally, not a write.',
        );
        await _tap(tester, find.widgetWithText(PawMateButton, 'Tiếp tục'));
        expect(find.byType(RescueInfoFormScreen), findsOneWidget);
        expect(h.source.creates, 1);
        expect(h.source.patches.single['exactLocation'], _point.toJson());
        expect(h.source.publishes, 0);
        await _capture(tester, recovery, scale, 'continued');
        expectNoFlutterOverflow(tester);
        semantics.dispose();
      });
    }
    testWidgets('D116 R21 ST-13 P2-02 entry publish recovery text$scale', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final h = await _pump(tester, scale, _LocationBoundary());
      h.container.read(rescueCreateProvider.notifier).setLocation(_point);
      await tester.pumpAndSettle();
      await _tap(tester, find.widgetWithText(PawMateButton, 'Tiếp tục'));
      expect(find.byType(RescueInfoFormScreen), findsOneWidget);
      expect(h.source.creates, 1);
      expect(
        h.container.read(rescueCreateProvider).draft.media.single,
        same(_media),
      );
      final features = find.descendant(
        of: find.byKey(const Key('rescue-info-identifying-features-field')),
        matching: find.byType(TextFormField),
      );
      await _reach(tester, features);
      await tester.enterText(features, 'Vòng cổ đỏ và bốn chân trắng.');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _tap(
        tester,
        find.byKey(const Key('rescue-info-media-review-confirmation')),
      );
      await _tap(tester, find.widgetWithText(PawMateButton, 'Đăng tin tìm'));
      await _tap(tester, find.byKey(const Key('rescue-review-confirm')));
      expect(h.source.publishes, 1);
      expect(h.source.committed, isNull);
      expect(h.source.uploads, 1);
      final failure = find.text(
        'Không thể đăng tin. Bản nháp vẫn được giữ để thử lại.',
      );
      await _reach(tester, failure);
      expect(
        find.ancestor(
          of: failure,
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.liveRegion == true,
          ),
        ),
        findsOneWidget,
      );
      await _capture(tester, 'publish', scale, 'failure');
      await _tap(tester, find.byKey(const Key('rescue-review-back')));
      final beforeSave = h.container.read(rescueCreateProvider).draft;
      expect(beforeSave.draftId, 'r21-draft');
      expect(beforeSave.media.single.uploaded, isTrue);
      final patchCount = h.source.patches.length;
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await tester.pumpAndSettle();
      await _tap(
        tester,
        find.widgetWithText(PawMateButton, 'Lưu nháp'),
        keyboard: true,
      );
      expect(h.source.patches.length, patchCount + 1);
      expect(h.source.publishes, 1);
      expect(h.source.uploads, 1);
      expect(
        h.source.stored['identifyingFeatures'],
        beforeSave.identifyingFeatures,
      );
      expect(h.source.stored['mediaIds'], ['r21-media']);
      expect(
        h.container.read(rescueCreateProvider).draft.draftId,
        beforeSave.draftId,
      );
      expect(
        h.container.read(rescueCreateProvider).draft.media.single.path,
        _media.path,
      );
      expect(find.text('Đã lưu bản nháp. Tin chưa được đăng.'), findsOneWidget);
      await _capture(tester, 'publish', scale, 'saved');
      tester.view.resetViewInsets();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      // saveDraft clears the error; the normal submit action is restored.
      await _tap(tester, find.widgetWithText(PawMateButton, 'Đăng tin tìm'));
      await _tap(tester, find.byKey(const Key('rescue-review-confirm')));
      expect(h.source.publishes, 2);
      expect(h.source.creates, 1);
      expect(h.source.uploads, 1, reason: 'Retry must reuse uploaded media.');
      expect(h.source.committed?.caseId, 'r21-case');
      expect(find.byType(RescueHomeScreen), findsOneWidget);
      expect(h.container.read(rescueCreateProvider).draft.draftId, isNull);
      await _capture(tester, 'publish', scale, 'published');
      expectNoFlutterOverflow(tester);
      semantics.dispose();
    });
  }
}

Future<void> _reach(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: .08);
  await tester.pumpAndSettle();
}

Future<void> _tap(
  WidgetTester tester,
  Finder finder, {
  bool keyboard = false,
}) async {
  await _reach(tester, finder);
  expect(finder.hitTestable(), findsOneWidget);
  final rect = tester.getRect(finder);
  expect(rect.height, greaterThanOrEqualTo(48));
  expect(rect.width, greaterThanOrEqualTo(48));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(keyboard ? 368 : 568));
  final node = tester.getSemantics(finder).getSemanticsData();
  expect(node.label, isNotEmpty);
  expect(node.hasAction(SemanticsAction.tap), isTrue);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _capture(
  WidgetTester tester,
  String action,
  double scale,
  String state,
) => captureDay116(
  tester,
  'R21-$action-$state-text${scale.toString().replaceAll('.', '-')}',
);

Future<_Harness> _pump(
  WidgetTester tester,
  double scale,
  _LocationBoundary location, {
  bool mediaFailure = false,
}) async {
  await setTestViewport(tester, size: const Size(320, 568));
  final source = _WriteBoundary();
  source.mediaFailure = mediaFailure;
  final cases = FakeRescueSource(pages: [samplePage()]);
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      rescueWriteSourceProvider.overrideWithValue(source),
      rescueApiProvider.overrideWithValue(cases),
      authAccessTokenProvider.overrideWith((_) async => 'fixture-token'),
      rescueLocationServiceProvider.overrideWithValue(location),
      rescuePickerMapBuilderProvider.overrideWithValue(
        (selected, onSelect, unavailable) => const ColoredBox(
          color: Color(0xffdff3ea),
          child: Center(child: Text('Declared map boundary')),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(rescueCreateProvider.notifier)
    ..setPetName('Mochi')
    ..setBreedOrColor('Poodle trắng kem')
    ..setLostAt(DateTime.utc(2026, 10, 15))
    ..setMedia([
      _media,
      if (mediaFailure)
        const RescueDraftMedia(
          path: 'declared-second.mp4',
          mimeType: 'video/mp4',
          sizeBytes: 1024,
        ),
    ]);
  final router = GoRouter(
    initialLocation: '/rescue/create',
    routes: [
      GoRoute(
        path: '/rescue',
        builder: (_, _) =>
            const RescueHomeScreen(browseEnabled: true, createEnabled: true),
      ),
      GoRoute(
        path: '/rescue/create',
        builder: (_, _) => const RescueCreateScreen(),
      ),
      GoRoute(
        path: '/rescue/create/details',
        builder: (_, _) => const RescueInfoFormScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        builder: testTextScaleBuilder(scale),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(container, source);
}

class _Harness {
  _Harness(this.container, this.source);
  final ProviderContainer container;
  final _WriteBoundary source;
}

/// Declared service/API boundaries, not GPS/system permission or cloud proof.
class _LocationBoundary implements RescueLocationService {
  int calls = 0;
  @override
  Future<RescueMapLocation> resolveCurrentLocation({
    RescueLocationRequest? request,
  }) async {
    calls++;
    if (calls == 1) {
      throw const RescueLocationException(
        RescueLocationFailureType.permissionDenied,
        'fixture denied',
      );
    }
    return const RescueMapLocation(latitude: 10.7769, longitude: 106.7009);
  }
}

class _WriteBoundary implements RescueWriteSource {
  RescueWriteApiException? nextSaveFailure;
  int failedUpdates = 0;
  bool mediaFailure = false;
  final uploadPaths = <String>[];
  int creates = 0, uploads = 0, publishes = 0, version = 1;
  final patches = <Map<String, Object?>>[];
  final stored = <String, Object?>{};
  RescueCaseDetail? committed;
  @override
  Future<RescueDraft> createDraft({
    required String accessToken,
    String source = 'rescue_home',
  }) async {
    creates++;
    return RescueDraft(draftId: 'r21-draft', version: version);
  }

  @override
  Future<RescueDraft> updateDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
    required Map<String, Object?> patch,
  }) async {
    expect(draftId, 'r21-draft');
    expect(expectedVersion, version);
    if (nextSaveFailure != null) {
      final error = nextSaveFailure!;
      nextSaveFailure = null;
      failedUpdates++;
      throw error;
    }
    patches.add(Map.of(patch));
    stored.addAll(patch);
    return RescueDraft.fromJson({
      'draftId': draftId,
      'version': ++version,
      ...stored,
    });
  }

  @override
  Future<RescueDraftMedia> uploadMedia({
    required String accessToken,
    required RescueDraftMedia media,
  }) async {
    uploads++;
    uploadPaths.add(media.path);
    if (mediaFailure && uploads == 2) {
      throw StateError('Declared second media failure');
    }
    return media.copyWith(
      mediaId: media.path == _media.path ? 'r21-media' : 'r22-video',
      uploaded: true,
    );
  }

  @override
  Future<RescueCaseDetail> publishDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
  }) async {
    expect(draftId, 'r21-draft');
    expect(expectedVersion, version);
    publishes++;
    if (!mediaFailure && publishes == 1) {
      throw StateError('Declared transient publish failure');
    }
    return committed = sampleCaseDetail(caseId: 'r21-case');
  }
}
