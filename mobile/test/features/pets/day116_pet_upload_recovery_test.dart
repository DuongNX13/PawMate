import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/features/pets/application/pet_form_draft_provider.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/data/pet_api.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/create_pet_screen.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';

import '../../test_support/day116_capture.dart';
import '../../test_support/ui_test_helpers.dart';

const _message =
    'Đã lưu hồ sơ nhưng chưa tải được ảnh. Bản nháp vẫn được giữ để bạn thử lại.';
void main() {
  setUpAll(loadPawMateTestFonts);
  _registerMediaActions();
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets(
      'D116 R13 P1-06 text$scale upload failure retry keeps partial pet and never creates twice',
      (tester) async {
        await setTestViewport(tester, size: const Size(320, 568));
        final photoPath = File(
          'assets/images/rescue/p2_02_pet.png',
        ).absolute.path;
        final bytes = await tester.runAsync(
          () => File(photoPath).readAsBytes(),
        );
        expect(bytes, isNotEmpty);
        final source = _PhotoSource();
        final readPaths = <String>[];
        final c = ProviderContainer(
          overrides: [
            petApiProvider.overrideWithValue(source),
            petAccessTokenProvider.overrideWith((ref) async => 'fixture-token'),
            petPhotoBytesReaderProvider.overrideWithValue((path) async {
              readPaths.add(path);
              return bytes!;
            }),
          ],
        );
        addTearDown(c.dispose);
        c
            .read(petFormDraftProvider.notifier)
            .replace(
              PetFormDraft(
                name: 'Mochi upload',
                breed: 'Poodle',
                color: 'Vàng kem',
                avatarPath: photoPath,
              ),
            );
        final router = GoRouter(
          initialLocation: '/pets/create',
          routes: [
            GoRoute(
              path: '/pets/create',
              builder: (context, state) =>
                  const CreatePetScreen(returnTo: '/pets/list'),
            ),
            GoRoute(
              path: '/pets/list',
              builder: (context, state) => const PetListScreen(),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: MaterialApp.router(
              theme: AppTheme.light(),
              builder: testTextScaleBuilder(scale),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await setKeyboardInset(tester, bottom: 250);
        final save = find.descendant(
          of: find.byKey(const Key('pet-form-save-button')),
          matching: find.byType(PawMateButton),
        );
        expect(save.hitTestable(), findsOneWidget);
        expect(tester.getRect(save).height, greaterThanOrEqualTo(48));
        expect(tester.getRect(save).bottom, lessThanOrEqualTo(318));
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(source.createCalls, 1);
        expect(source.uploads.length, 1);
        expect(source.updateIds, isEmpty);
        final draft = c.read(petFormDraftProvider);
        expect(draft.petId, 'partial-pet');
        expect(draft.avatarPath, photoPath);
        expect(draft.name, 'Mochi upload');
        expect(draft.breed, 'Poodle');
        expect(draft.color, 'Vàng kem');
        expect(c.read(petListProvider).single.id, 'partial-pet');
        expect(source.record!.avatarPath, isNull);
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/pets/create',
        );
        final error = find.text(_message);
        await tester.scrollUntilVisible(
          error,
          140,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(error.hitTestable(), findsOneWidget);
        // At text2 + IME250 this paragraph is taller than the remaining scroll
        // viewport. Prove its beginning and end can both be read, not that the
        // entire paragraph fits simultaneously above the fixed CTA.
        expect(tester.widget<Text>(error).maxLines, isNull);
        expect(
          tester.widget<Text>(error).overflow,
          isNot(TextOverflow.ellipsis),
        );
        await captureDay116(
          tester,
          'R13-P106-upload-error-start-text${scale.toString().replaceAll('.', '-')}',
        );
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(error).bottom,
          lessThanOrEqualTo(tester.getRect(save).top),
        );
        await captureDay116(
          tester,
          'R13-P106-upload-error-text${scale.toString().replaceAll('.', '-')}',
        );
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(source.createCalls, 1);
        expect(source.updateIds, ['partial-pet']);
        expect(source.uploads.length, 2);
        expect(source.uploadIds, ['partial-pet', 'partial-pet']);
        expect(source.uploads[1].bytes, source.uploads[0].bytes);
        expect(source.uploads[1].fileName, source.uploads[0].fileName);
        expect(source.uploads[1].contentType, 'image/png');
        expect(readPaths, [photoPath, photoPath]);
        expect(source.record!.avatarPath, 'assets/images/rescue/p2_02_pet.png');
        expect(c.read(petListProvider), hasLength(1));
        expect(c.read(petFormDraftProvider).isEmpty, isTrue);
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/pets/list',
        );
        await setKeyboardInset(tester, bottom: 0);
        await tester.pumpAndSettle();
        expect(find.byType(PetListScreen), findsOneWidget);
        expect(find.text('Mochi upload'), findsWidgets);
        expect(find.text(_message), findsNothing);
        expectNoFlutterOverflow(tester);
        await captureDay116(
          tester,
          'R13-P106-upload-success-text${scale.toString().replaceAll('.', '-')}',
        );
      },
    );
  }
}

void _registerMediaActions() {
  for (final scale in [1.0, 1.3, 2.0]) {
    for (final remove in [false, true]) {
      final action = remove ? 'remove' : 'retry';
      testWidgets('D116 R20 ST-16 P1-06 $action text$scale', (tester) async {
        await setTestViewport(tester, size: const Size(320, 568));
        final path = File('assets/images/rescue/p2_02_pet.png').absolute.path;
        final bytes = await tester.runAsync(() => File(path).readAsBytes());
        expect(bytes, isNotEmpty);
        final api = _PhotoSource();
        final c = ProviderContainer(
          overrides: [
            petApiProvider.overrideWithValue(api),
            petAccessTokenProvider.overrideWith((ref) async => 'fixture-token'),
            petPhotoBytesReaderProvider.overrideWithValue((_) async => bytes!),
          ],
        );
        addTearDown(c.dispose);
        c
            .read(petFormDraftProvider.notifier)
            .replace(
              PetFormDraft(
                name: 'Mochi media',
                breed: 'Poodle',
                color: 'Vàng kem',
                avatarPath: path,
              ),
            );
        final router = GoRouter(
          initialLocation: '/pets/create',
          routes: [
            GoRoute(
              path: '/pets/create',
              builder: (_, _) => const CreatePetScreen(returnTo: '/pets/list'),
            ),
            GoRoute(
              path: '/pets/list',
              builder: (_, _) => const PetListScreen(),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              builder: testTextScaleBuilder(scale),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await setKeyboardInset(tester, bottom: 200);
        final save = find.descendant(
          of: find.byKey(const Key('pet-form-save-button')),
          matching: find.byType(PawMateButton),
        );
        expect(save.hitTestable(), findsOneWidget);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(api.createCalls, 1);
        expect(api.uploads, hasLength(1));
        expect(api.updateIds, isEmpty);
        expect(c.read(petFormDraftProvider).petId, 'partial-pet');
        expect(c.read(petFormDraftProvider).avatarPath, path);
        final recovery = find.widgetWithText(
          PawMateButton,
          remove ? 'Xóa ảnh' : 'Tải lại ảnh',
        );
        expect(recovery, findsOneWidget);
        await tester.scrollUntilVisible(
          recovery,
          140,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(recovery);
        await tester.pumpAndSettle();
        expect(recovery.hitTestable(), findsOneWidget);
        expect(tester.getSize(recovery).shortestSide, greaterThanOrEqualTo(48));
        expect(tester.getRect(recovery).bottom, lessThanOrEqualTo(368));
        final handle = tester.ensureSemantics();
        try {
          await tester.pump();
          final data = tester.getSemantics(recovery).getSemanticsData();
          expect(data.label, isNotEmpty);
          expect(data.hasAction(SemanticsAction.tap), isTrue);
        } finally {
          handle.dispose();
        }
        final suffix = scale.toString().replaceAll('.', '-');
        await captureDay116(tester, 'R20-ST16-P106-$action-error-text$suffix');
        await tester.tap(recovery);
        await tester.pumpAndSettle();
        if (remove) {
          expect(api.uploads, hasLength(1));
          expect(api.updateIds, isEmpty);
          final draft = c.read(petFormDraftProvider);
          expect(draft.avatarPath, isNull);
          expect(draft.petId, 'partial-pet');
          expect(draft.name, 'Mochi media');
          expect(draft.breed, 'Poodle');
          expect(draft.color, 'Vàng kem');
          expect(find.text(_message), findsNothing);
          expect(recovery, findsNothing);
          await captureDay116(tester, 'R20-ST16-P106-remove-draft-text$suffix');
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(api.uploads, hasLength(1));
          expect(api.record!.avatarPath, isNull);
        } else {
          expect(api.uploads, hasLength(2));
          expect(api.uploadIds, ['partial-pet', 'partial-pet']);
          expect(api.uploads[1].bytes, api.uploads[0].bytes);
          expect(api.uploads[1].contentType, api.uploads[0].contentType);
          expect(api.uploads[1].fileName, api.uploads[0].fileName);
        }
        expect(api.createCalls, 1);
        expect(api.updateIds, ['partial-pet']);
        expect(router.routeInformationProvider.value.uri.path, '/pets/list');
        expect(c.read(petFormDraftProvider).isEmpty, isTrue);
        await setKeyboardInset(tester, bottom: 0);
        await tester.pumpAndSettle();
        expect(find.byType(PetListScreen), findsOneWidget);
        expect(find.text('Mochi media'), findsWidgets);
        expect(c.read(petListProvider), hasLength(1));
        expectNoFlutterOverflow(tester);
        await captureDay116(tester, 'R20-ST16-P106-$action-result-text$suffix');
      });
    }
  }
}

/// Actual widgets/provider; declared API boundary stores one in-memory record.
/// Not native photo permission or backend/cloud persistence evidence. Save is
/// the existing retry action; dedicated ST16 retry/remove CTA parity is separate.
class _PhotoSource extends PetApi {
  _PhotoSource() : super(Dio());
  int createCalls = 0;
  PetProfile? record;
  final updateIds = <String>[];
  final uploadIds = <String>[];
  final uploads = <PetPhotoInput>[];
  @override
  Future<List<PetProfile>> listPets({required String accessToken}) async => [
    ?record,
  ];
  @override
  Future<PetProfile> createPet(
    CreatePetProfileInput input, {
    required String accessToken,
  }) async {
    expect(accessToken, 'fixture-token');
    createCalls++;
    return record = PetProfile(
      id: 'partial-pet',
      name: input.name,
      species: input.species,
      breed: input.breed,
      gender: input.gender,
      healthStatus: input.healthStatus,
      color: input.color,
    );
  }

  @override
  Future<PetProfile> updatePet(
    String petId,
    UpdatePetProfileInput input, {
    required String accessToken,
  }) async {
    expect(accessToken, 'fixture-token');
    expect(petId, record!.id);
    updateIds.add(petId);
    return record!;
  }

  @override
  Future<PetProfile> uploadPetPhoto(
    String petId,
    PetPhotoInput photo, {
    required String accessToken,
  }) async {
    expect(accessToken, 'fixture-token');
    uploadIds.add(petId);
    uploads.add(photo);
    if (uploads.length == 1) {
      throw const PetApiException(
        'Upload unavailable',
        code: 'SERVER_ERROR',
        statusCode: 503,
      );
    }
    return record = record!.copyWith(
      avatarPath: 'assets/images/rescue/p2_02_pet.png',
    );
  }
}
