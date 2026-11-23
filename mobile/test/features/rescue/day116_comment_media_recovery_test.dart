import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/media/image_picker_service.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/preferences/application/preference_providers.dart';
import 'package:pawmate_mobile/features/preferences/domain/preference_models.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_comment_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_comment_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_comment_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_comment_screen.dart';

import '../../test_support/day116_capture.dart';
import '../../test_support/ui_test_helpers.dart';
import 'rescue_comment_test_fixtures.dart';
import 'rescue_test_fixtures.dart';

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final owner in ['P2-06', 'P2-08']) {
    for (final kind in ['image', 'video']) {
      for (final action in ['retry', 'remove']) {
        for (final scale in [1.0, 1.3, 2.0]) {
          testWidgets('D116 R21 ST-16 $owner $kind $action text$scale', (
            tester,
          ) async {
            final handle = tester.ensureSemantics();
            try {
              await setTestViewport(tester, size: const Size(320, 568));
              final source = _UploadBoundary()..failUploads = 1;
              final picker = _Picker();
              final container = ProviderContainer(
                retry: (_, _) => null,
                overrides: [
                  rescueCommentSourceProvider.overrideWithValue(source),
                  rescueApiProvider.overrideWithValue(
                    FakeRescueSource(detail: sampleCaseDetail()),
                  ),
                  authAccessTokenProvider.overrideWith(
                    (_) async => 'fixture-token',
                  ),
                  imagePickerProvider.overrideWithValue(picker),
                  privacyDefaultsProvider.overrideWith(_Privacy.new),
                ],
              );
              addTearDown(container.dispose);
              await tester.pumpWidget(
                UncontrolledProviderScope(
                  container: container,
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.light(),
                    builder: testTextScaleBuilder(scale),
                    home: RescueCommentScreen(
                      caseId: sampleCommentCaseId,
                      discussionMode: owner == 'P2-08',
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              final field = find.byKey(const Key('rescue-comment-field'));
              await tester.enterText(field, 'Đã thấy bé gần công viên.');
              if (owner == 'P2-08') {
                await _tap(
                  tester,
                  find.byKey(Key('rescue-comment-attach-$kind')),
                );
              } else {
                await _tap(
                  tester,
                  find.byKey(const Key('rescue-comment-attach')),
                );
                await _tap(
                  tester,
                  find.byKey(Key('rescue-comment-pick-$kind')),
                );
              }
              final provider = rescueCommentProvider(sampleCommentCaseId);
              final failed = container.read(provider);
              expect(source.uploadAttempts, 1);
              expect(picker.calls, 1);
              expect(
                failed.media.single.status,
                RescueCommentUploadStatus.failed,
              );
              expect(failed.media.single.isVideo, kind == 'video');
              expect(failed.draftText, 'Đã thấy bé gần công viên.');
              expect(failed.canSend, isFalse);
              expect(
                tester.widget<TextField>(field).controller!.text,
                failed.draftText,
              );
              final retry = find.byTooltip('Thử tải lại');
              final remove = find.byTooltip('Xóa tệp');
              // Both alternatives must exist while the upload is FAILED.
              expect(retry, findsOneWidget);
              expect(remove, findsOneWidget);
              expect(
                find.widgetWithText(TextButton, 'Thử tải lại'),
                findsNothing,
                reason:
                    'A media failure must not offer a collection reload as upload recovery.',
              );
              final status = find.text('Tải lỗi');
              expect(status, findsOneWidget);
              expect(
                tester.renderObject<RenderParagraph>(status).didExceedMaxLines,
                isFalse,
              );
              tester.view.viewInsets = const FakeViewPadding(bottom: 200);
              await tester.pumpAndSettle();
              final stem =
                  'R21-${owner.replaceAll('-', '')}-$kind-$action-text${scale.toString().replaceAll('.', '-')}';
              await _capture(tester, '$stem-failed');
              await _tap(
                tester,
                action == 'retry' ? retry : remove,
                keyboard: true,
              );
              final recovered = container.read(provider);
              expect(recovered.draftText, failed.draftText);
              expect(
                picker.calls,
                1,
                reason: 'Recovery does not open the gallery again.',
              );
              if (action == 'retry') {
                expect(source.uploadAttempts, 2);
                expect(
                  recovered.media.single.localId,
                  failed.media.single.localId,
                );
                expect(recovered.media.single.path, failed.media.single.path);
                expect(
                  recovered.media.single.status,
                  RescueCommentUploadStatus.uploaded,
                );
                expect(
                  source.attempts
                      .map((m) => [m.localId, m.path, m.mimeType, m.sizeBytes])
                      .toList(),
                  [
                    [
                      failed.media.single.localId,
                      failed.media.single.path,
                      failed.media.single.mimeType,
                      failed.media.single.sizeBytes,
                    ],
                    [
                      failed.media.single.localId,
                      failed.media.single.path,
                      failed.media.single.mimeType,
                      failed.media.single.sizeBytes,
                    ],
                  ],
                );
              } else {
                expect(source.uploadAttempts, 1);
                expect(recovered.media, isEmpty);
                expect(find.byTooltip('Thử tải lại'), findsNothing);
              }
              expect(recovered.canSend, isTrue);
              await _capture(tester, '$stem-recovered');
              await _tap(
                tester,
                find.byKey(const Key('rescue-comment-send')),
                keyboard: true,
              );
              if (action == 'retry') {
                await _tap(
                  tester,
                  find.byKey(const Key('rescue-comment-privacy-confirm-send')),
                  keyboard: true,
                );
              }
              expect(source.comments, hasLength(1));
              expect(source.comments.single.caseId, sampleCommentCaseId);
              expect(source.sentBodies, [failed.draftText]);
              expect(source.sentMediaIds, [
                action == 'retry'
                    ? ['bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb']
                    : <String>[],
              ]);
              expect(container.read(provider).draftText, isEmpty);
              expect(container.read(provider).media, isEmpty);
              expect(tester.widget<TextField>(field).controller!.text, isEmpty);
              tester.view.resetViewInsets();
              FocusManager.instance.primaryFocus?.unfocus();
              await tester.pumpAndSettle();
              await _capture(tester, '$stem-sent');
              expectNoFlutterOverflow(tester);
            } finally {
              handle.dispose();
            }
          });
        }
      }
    }
  }
}

Future<void> _tap(
  WidgetTester tester,
  Finder finder, {
  bool keyboard = false,
}) async {
  expect(finder, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(finder), alignment: .05);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  final rect = tester.getRect(finder);
  expect(rect.width, greaterThanOrEqualTo(48));
  expect(rect.height, greaterThanOrEqualTo(48));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(keyboard ? 368 : 568));
  final node = tester.getSemantics(finder).getSemanticsData();
  expect('${node.label} ${node.tooltip}'.trim(), isNotEmpty);
  expect(node.hasAction(SemanticsAction.tap), isTrue);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String id) =>
    captureDay116(tester, id);

class _Privacy extends PrivacyDefaultsNotifier {
  @override
  Future<PrivacyDefaults> build() async => PrivacyDefaults(
    userId: 'r21-owner',
    version: 1,
    hideHouseNumber: true,
    hidePhoneByDefault: true,
    reviewMediaBeforePublish: true,
    updatedAt: DateTime.utc(2026, 10, 16),
  );
}

/// Declared file metadata, gallery and upload boundaries; no native/file decoder proof.
class _FixtureFile extends XFile {
  _FixtureFile(super.path);
  @override
  Future<int> length() async => 1024;
}

class _Picker extends ImagePicker {
  int calls = 0;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    expect(source, ImageSource.gallery);
    calls++;
    return _FixtureFile('declared-fixture.jpg');
  }

  @override
  Future<XFile?> pickVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async {
    expect(source, ImageSource.gallery);
    calls++;
    return _FixtureFile('declared-fixture.mp4');
  }
}

class _UploadBoundary extends FakeRescueCommentSource {
  _UploadBoundary() : super(comments: []);
  final attempts = <RescueCommentDraftMedia>[];
  @override
  Future<RescueCommentDraftMedia> uploadMedia({
    required String accessToken,
    required RescueCommentDraftMedia media,
    required void Function(double) onProgress,
  }) {
    attempts.add(media);
    return super.uploadMedia(
      accessToken: accessToken,
      media: media,
      onProgress: onProgress,
    );
  }
}
