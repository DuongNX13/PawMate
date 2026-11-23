import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/media/image_picker_service.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/pets/application/pet_form_draft_provider.dart';
import 'package:pawmate_mobile/features/pets/presentation/create_pet_screen.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_create_provider.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_draft_models.dart';

import '../test_support/ui_test_helpers.dart';

const _existing = RescueDraftMedia(
  path: 'old.jpg',
  mimeType: 'image/jpeg',
  sizeBytes: 3,
);
XFile _image() =>
    XFile.fromData(Uint8List.fromList([1, 2, 3]), path: 'new.jpg');

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final video in [false, true]) {
    for (final code in [
      'photo_access_denied',
      'photo_access_restricted',
      'picker_unavailable',
    ]) {
      test(
        'D116-P03 Rescue ${video ? 'video' : 'image'} $code retains media and retries',
        () async {
          final c = ProviderContainer();
          addTearDown(c.dispose);
          final n = c.read(rescueCreateProvider.notifier)
            ..setPetName('Mochi')
            ..setMedia([_existing]);
          final picker = _Picker(
            () async => throw PlatformException(code: code),
          );
          await (video ? n.pickVideo(picker) : n.pickMedia(picker));
          final failed = c.read(rescueCreateProvider);
          expect(
            failed.errorMessage,
            contains(
              code == 'picker_unavailable' ? 'Không thể chọn' : 'Chưa có quyền',
            ),
          );
          expect(failed.draft.petName, 'Mochi');
          expect(failed.draft.media, [_existing]);
          expect(failed.isBusy, isFalse);
          picker.select = () async => XFile.fromData(
            Uint8List.fromList([1, 2]),
            path: video ? 'new.mp4' : 'new.jpg',
          );
          await (video ? n.pickVideo(picker) : n.pickMedia(picker));
          expect(c.read(rescueCreateProvider).errorMessage, isNull);
          expect(c.read(rescueCreateProvider).draft.media.length, 2);
          expect(c.read(rescueCreateProvider).draft.media.first, _existing);
          expect(picker.calls, 2);
        },
      );
    }
  }
  test(
    'D116-P03 Rescue duplicate selection opens only one picker; cancel retains media',
    () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(rescueCreateProvider.notifier)..setMedia([_existing]);
      final gate = Completer<XFile?>();
      final picker = _Picker(() => gate.future);
      final pending = n.pickMedia(picker);
      await n.pickMedia(picker).timeout(const Duration(seconds: 1));
      await n.pickVideo(picker).timeout(const Duration(seconds: 1));
      expect(picker.calls, 1);
      gate.complete(null);
      await pending;
      expect(c.read(rescueCreateProvider).draft.media, [_existing]);
      expect(c.read(rescueCreateProvider).errorMessage, isNull);
    },
  );
  for (final error in [false, true]) {
    test(
      'D116-P03 Rescue ignores late ${error ? 'denial' : 'image'} after session reset',
      () async {
        final c = ProviderContainer();
        addTearDown(c.dispose);
        final n = c.read(rescueCreateProvider.notifier)
          ..setPetName('Old session');
        final gate = Completer<XFile?>();
        final pending = n.pickMedia(_Picker(() => gate.future));
        c.read(authSessionRevisionProvider.notifier).bump();
        if (error) {
          gate.completeError(PlatformException(code: 'photo_access_denied'));
        } else {
          gate.complete(_image());
        }
        await pending;
        expect(c.read(rescueCreateProvider).draft.petName, isEmpty);
        expect(c.read(rescueCreateProvider).draft.media, isEmpty);
        expect(c.read(rescueCreateProvider).errorMessage, isNull);
      },
    );
  }
  test(
    'D116-P03 Rescue ignores file length completion after session reset',
    () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(rescueCreateProvider.notifier);
      final file = _PendingFile();
      final pending = n.pickMedia(_Picker(() async => file));
      await file.started.future;
      c.read(authSessionRevisionProvider.notifier).bump();
      file.size.complete(3);
      await pending;
      expect(c.read(rescueCreateProvider).draft.media, isEmpty);
    },
  );
  for (final error in [false, true]) {
    test(
      'D116-P03 Rescue ignores late ${error ? 'denial' : 'image'} after dispose',
      () async {
        final c = ProviderContainer();
        final n = c.read(rescueCreateProvider.notifier);
        final gate = Completer<XFile?>();
        final pending = n.pickMedia(_Picker(() => gate.future));
        c.dispose();
        if (error) {
          gate.completeError(PlatformException(code: 'photo_access_denied'));
        } else {
          gate.complete(_image());
        }
        await expectLater(pending, completes);
      },
    );
  }

  testWidgets(
    'D116-P03 Pet denied retains existing avatar; actual retry clears live error',
    (tester) async {
      final picker = _Picker(
        () async => throw PlatformException(code: 'photo_access_denied'),
      );
      final c = ProviderContainer(
        overrides: [imagePickerProvider.overrideWithValue(picker)],
      );
      addTearDown(c.dispose);
      const old = 'assets/images/rescue/p2_02_pet.png';
      c
          .read(petFormDraftProvider.notifier)
          .replace(
            const PetFormDraft(name: 'Mochi', breed: 'Poodle', avatarPath: old),
          );
      await _pet(tester, c);
      final add = find.byKey(const Key('pet-form-avatar-picker'));
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.textContaining('Chưa có quyền truy cập ảnh'), findsOneWidget);
      expect(c.read(petFormDraftProvider).avatarPath, old);
      picker.select = () async => XFile(old);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(picker.calls, 2);
      expect(c.read(petFormDraftProvider).name, 'Mochi');
      expect(c.read(petFormDraftProvider).avatarPath, old);
      expect(find.textContaining('Chưa có quyền truy cập ảnh'), findsNothing);
      expectNoFlutterOverflow(tester);
    },
  );
  for (final error in [false, true]) {
    testWidgets(
      'D116-P03 Pet duplicate and late ${error ? 'denial' : 'image'} after dispose',
      (tester) async {
        final gate = Completer<XFile?>();
        final picker = _Picker(() => gate.future);
        final c = ProviderContainer(
          overrides: [imagePickerProvider.overrideWithValue(picker)],
        );
        addTearDown(c.dispose);
        await _pet(tester, c);
        final add = find.byKey(const Key('pet-form-avatar-picker'));
        await tester.tap(add);
        await tester.pump();
        await tester.tap(add);
        await tester.pump();
        expect(picker.calls, 1);
        await tester.pumpWidget(const SizedBox());
        if (error) {
          gate.completeError(PlatformException(code: 'photo_access_denied'));
        } else {
          gate.complete(_image());
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(c.read(petFormDraftProvider).avatarPath, isNull);
      },
    );
  }
}

Future<void> _pet(WidgetTester tester, ProviderContainer c) async {
  await setTestViewport(tester, size: const Size(390, 844));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const CreatePetScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Plugin boundary double, not a native permission or file upload proof.
class _Picker extends ImagePicker {
  _Picker(this.select);
  Future<XFile?> Function() select;
  int calls = 0;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) {
    calls++;
    return select();
  }

  @override
  Future<XFile?> pickVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) {
    calls++;
    return select();
  }
}

class _PendingFile extends XFile {
  _PendingFile() : super('new.jpg');
  final started = Completer<void>();
  final size = Completer<int>();
  @override
  Future<int> length() {
    started.complete();
    return size.future;
  }
}
