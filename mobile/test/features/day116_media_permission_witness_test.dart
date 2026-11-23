import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/media/image_picker_service.dart';
import 'package:pawmate_mobile/features/pets/application/pet_form_draft_provider.dart';
import 'package:pawmate_mobile/features/pets/presentation/create_pet_screen.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_create_provider.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_create_screen.dart';

import '../test_support/day116_capture.dart';
import '../test_support/ui_test_helpers.dart';

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final owner in ['P1-06', 'P2-02']) {
    for (final denied in [false, true]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets(
          'D116 R12 D116-P03 $owner text$scale gallery ${denied ? 'denied' : 'cancel'} keeps draft and safe control',
          (tester) async {
            await setTestViewport(tester, size: const Size(320, 568));
            final picker = _GalleryBoundary(denied: denied);
            final container = ProviderContainer(
              overrides: [imagePickerProvider.overrideWithValue(picker)],
            );
            addTearDown(container.dispose);
            if (owner == 'P1-06') {
              container
                  .read(petFormDraftProvider.notifier)
                  .replace(const PetFormDraft(name: 'Mochi', breed: 'Poodle'));
            } else {
              container.read(rescueCreateProvider.notifier)
                ..setPetName('Mochi')
                ..setBreedOrColor('Poodle');
            }
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.light(),
                  builder: testTextScaleBuilder(scale),
                  home: owner == 'P1-06'
                      ? const CreatePetScreen()
                      : const RescueCreateScreen(),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final add = find.byKey(
              Key(
                owner == 'P1-06'
                    ? 'pet-form-avatar-picker'
                    : 'rescue-create-media-upload',
              ),
            );
            await tester.scrollUntilVisible(
              add,
              120,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            expect(add.hitTestable(), findsOneWidget);
            await tester.tap(add);
            await tester.pumpAndSettle();
            if (owner == 'P2-02') {
              expect(find.text('Chọn ảnh'), findsOneWidget);
              await tester.tap(find.text('Chọn ảnh'));
              await tester.pumpAndSettle();
            }
            final exception = tester.takeException();
            if (denied) {
              final feedback = find.textContaining(
                'Chưa có quyền truy cập ảnh',
              );
              expect(feedback, findsOneWidget);
              expect(
                find.ancestor(
                  of: feedback,
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is Semantics &&
                        widget.properties.liveRegion == true,
                  ),
                ),
                findsOneWidget,
              );
            } else {
              expect(
                find.textContaining('Chưa có quyền truy cập ảnh'),
                findsNothing,
              );
            }
            expect(picker.calls, 1);
            expect(picker.source, ImageSource.gallery);
            if (owner == 'P1-06') {
              expect(container.read(petFormDraftProvider).name, 'Mochi');
              expect(container.read(petFormDraftProvider).avatarPath, isNull);
            } else {
              final state = container.read(rescueCreateProvider);
              expect(state.draft.petName, 'Mochi');
              expect(state.draft.media, isEmpty);
              expect(state.isBusy, isFalse);
            }
            expect(add.hitTestable(), findsOneWidget);
            await captureDay116(
              tester,
              'R12-${owner.replaceAll('-', '')}-${denied ? 'denied' : 'cancel'}-text${scale.toString().replaceAll('.', '-')}',
            );
            if (denied) {
              final feedback = find.textContaining(
                'Chưa có quyền truy cập ảnh',
              );
              await tester.ensureVisible(feedback);
              await tester.pumpAndSettle();
              final bounds = tester.getRect(feedback);
              expect(bounds.top, greaterThanOrEqualTo(0));
              expect(bounds.bottom, lessThanOrEqualTo(474));
              await captureDay116(
                tester,
                'R12-${owner.replaceAll('-', '')}-feedback-text${scale.toString().replaceAll('.', '-')}',
              );
            }
            expect(
              exception,
              isNull,
              reason:
                  'Denied gallery must be handled by the owner, not escape its async callback.',
            );
            expectNoFlutterOverflow(tester);
          },
        );
      }
    }
  }
}

/// Declared plugin boundary, not native system-permission evidence. The exact
/// error code exists in the resolved image_picker_ios plugin's photo denial.
class _GalleryBoundary extends ImagePicker {
  _GalleryBoundary({required this.denied});
  final bool denied;
  int calls = 0;
  ImageSource? source;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    calls++;
    this.source = source;
    if (denied) {
      throw PlatformException(
        code: 'photo_access_denied',
        message: 'The user did not allow photo access.',
      );
    }
    return null;
  }
}
