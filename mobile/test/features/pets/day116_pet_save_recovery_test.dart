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

const _error = 'Chưa lưu được hồ sơ. Hãy thử lại.';

void main() {
  setUpAll(loadPawMateTestFonts);
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('D116 R22 ST-04 P1-06 empty list actual create text$scale', (
      tester,
    ) async {
      await setTestViewport(tester, size: const Size(320, 568));
      final source = _PetSource();
      final container = ProviderContainer(
        overrides: [
          petApiProvider.overrideWithValue(source),
          petAccessTokenProvider.overrideWith((_) async => 'fixture-token'),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/pets/list',
        routes: [
          GoRoute(path: '/pets/list', builder: (_, _) => const PetListScreen()),
          GoRoute(
            path: '/pets/create',
            builder: (_, state) => CreatePetScreen(
              returnTo: state.uri.queryParameters['returnTo'],
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            builder: testTextScaleBuilder(scale),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(petListProvider), isEmpty);
      final add = find.byKey(const Key('pet-list-empty-create-button'));
      await tester.ensureVisible(add);
      expect(add.hitTestable(), findsOneWidget);
      await captureDay116(
        tester,
        'R22-ST04-P106-empty-text${scale.toString().replaceAll('.', '-')}',
      );
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.byType(CreatePetScreen), findsOneWidget);
      expect(
        tester.widget<CreatePetScreen>(find.byType(CreatePetScreen)).returnTo,
        '/pets/list',
      );
      final name = find.descendant(
        of: find.byKey(const Key('pet-form-name-field')),
        matching: find.byType(TextFormField),
      );
      await tester.scrollUntilVisible(
        name,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(name, 'Mochi R22');
      for (final fieldValue in [
        ('pet-form-breed-field', 'Poodle'),
        ('pet-form-color-field', 'Vàng kem'),
      ]) {
        final field = find.descendant(
          of: find.byKey(Key(fieldValue.$1)),
          matching: find.byType(TextFormField),
        );
        await tester.scrollUntilVisible(field, 180, scrollable: find.byType(Scrollable).first);
        await tester.enterText(field, fieldValue.$2);
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final save = find.descendant(
        of: find.byKey(const Key('pet-form-save-button')),
        matching: find.byType(PawMateButton),
      );
      expect(save.hitTestable(), findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(source.inputs, hasLength(1));
      expect(source.records, isEmpty);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(source.inputs, hasLength(2));
      expect(source.records.single.name, 'Mochi R22');
      expect(find.byType(PetListScreen), findsOneWidget);
      expect(find.text('Mochi R22'), findsWidgets);
      expect(
        find.byKey(const Key('pet-list-empty-create-button')),
        findsNothing,
      );
      expect(container.read(petFormDraftProvider).isEmpty, isTrue);
      await captureDay116(
        tester,
        'R22-ST04-P106-created-text${scale.toString().replaceAll('.', '-')}',
      );
      expectNoFlutterOverflow(tester);
    });
    testWidgets(
      'D116 R10 ST-12 P1-06 text$scale IME save failure retained draft and pet list result',
      (tester) async {
        await setTestViewport(tester, size: const Size(320, 568));
        final source = _PetSource();
        final container = ProviderContainer(
          overrides: [
            petApiProvider.overrideWithValue(source),
            petAccessTokenProvider.overrideWith((ref) async => 'fixture-token'),
          ],
        );
        addTearDown(container.dispose);
        container
            .read(petFormDraftProvider.notifier)
            .replace(
              const PetFormDraft(
                name: 'Mochi',
                breed: 'Poodle',
                color: 'Vàng kem',
              ),
            );
        final router = GoRouter(
          initialLocation: '/pets/create?returnTo=/pets/list',
          routes: [
            GoRoute(
              path: '/pets/list',
              builder: (context, state) => const PetListScreen(),
            ),
            GoRoute(
              path: '/pets/create',
              builder: (context, state) => CreatePetScreen(
                returnTo: state.uri.queryParameters['returnTo'],
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.light(),
              builder: testTextScaleBuilder(scale),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await setKeyboardInset(tester, bottom: 300);
        final name = find.descendant(
          of: find.byKey(const Key('pet-form-name-field')),
          matching: find.byType(TextFormField),
        );
        await tester.scrollUntilVisible(
          name,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(name, 'Mochi R10');
        final save = find.descendant(
          of: find.byKey(const Key('pet-form-save-button')),
          matching: find.byType(PawMateButton),
        );
        expect(save.hitTestable(), findsOneWidget);
        expect(tester.getRect(save).bottom, lessThanOrEqualTo(268));
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(source.inputs, hasLength(1));
        expect(source.records, isEmpty);
        expect(container.read(petListProvider), isEmpty);
        final draft = container.read(petFormDraftProvider);
        expect(draft.name, 'Mochi R10');
        expect(draft.color, 'Vàng kem');
        expect(draft.breed, 'Poodle');
        expect(draft.petId, isNull);
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/pets/create',
        );
        final error = find.text(_error);
        await tester.scrollUntilVisible(
          error,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(error.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(error).bottom,
          lessThanOrEqualTo(tester.getRect(save).top),
        );
        await captureDay116(
          tester,
          'R10-P106-error-text${scale.toString().replaceAll('.', '-')}',
        );
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(source.inputs, hasLength(2));
        expect(source.inputs[1].toJson(), source.inputs[0].toJson());
        expect(source.records, hasLength(1));
        expect(container.read(petListProvider).single.id, 'r10-created-pet');
        expect(container.read(petFormDraftProvider).isEmpty, isTrue);
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/pets/list',
        );
        await setKeyboardInset(tester, bottom: 0);
        await tester.pumpAndSettle();
        expect(find.byType(PetListScreen), findsOneWidget);
        expect(find.text('Mochi R10'), findsWidgets);
        expect(find.text(_error), findsNothing);
        expectNoFlutterOverflow(tester);
        await captureDay116(
          tester,
          'R10-P106-success-text${scale.toString().replaceAll('.', '-')}',
        );
      },
    );
  }
}

/// Controlled API boundary; no backend, upload or native permission claim.
class _PetSource extends PetApi {
  _PetSource() : super(Dio());
  final inputs = <CreatePetProfileInput>[];
  final records = <PetProfile>[];
  @override
  Future<List<PetProfile>> listPets({required String accessToken}) async {
    expect(accessToken, 'fixture-token');
    return [...records];
  }

  @override
  Future<PetProfile> createPet(
    CreatePetProfileInput input, {
    required String accessToken,
  }) async {
    expect(accessToken, 'fixture-token');
    inputs.add(input);
    if (inputs.length == 1) {
      throw const PetApiException(_error, code: 'NETWORK_ERROR');
    }
    final pet = PetProfile(
      id: 'r10-created-pet',
      name: input.name,
      species: input.species,
      breed: input.breed,
      gender: input.gender,
      dateOfBirth: input.dateOfBirth,
      weightKg: input.weightKg,
      healthStatus: input.healthStatus,
      color: input.color,
      microchip: input.microchip,
      isNeutered: input.isNeutered,
    );
    records.add(pet);
    return pet;
  }
}
