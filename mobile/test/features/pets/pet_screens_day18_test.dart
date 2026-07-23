import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import 'package:pawmate_mobile/features/pets/application/pet_form_draft_provider.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/data/pet_api.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/create_pet_screen.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_detail_screen.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';

import '../../test_support/ui_test_helpers.dart';

const _viewports = <Size>[
  Size(360, 844),
  Size(390, 844),
  Size(412, 915),
  Size(430, 932),
];

void main() {
  testWidgets('P1-05 renders the loading skeleton state', (tester) async {
    await setTestViewport(tester, size: const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWithValue(
            const AsyncValue<List<PetProfile>>.loading(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PetListScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('pet-list-loading-state')), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P1-05 renders the network error and recovery action', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWithValue(
            AsyncValue<List<PetProfile>>.error(
              const PetApiException(
                'Không thể kết nối tới máy chủ hồ sơ thú cưng.',
              ),
              StackTrace.empty,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PetListScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('pet-list-error-state')), findsOneWidget);
    expect(find.text('Không tải được dữ liệu'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    'pet detail exposes loading, offline, and avatar fallback states',
    (tester) async {
      await setTestViewport(tester, size: const Size(390, 844));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petBackendListProvider.overrideWithValue(
              const AsyncValue<List<PetProfile>>.loading(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const PetDetailScreen(petId: 'missing'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('pet-detail-loading-state')), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petBackendListProvider.overrideWithValue(
              AsyncValue<List<PetProfile>>.error(
                const PetApiException('offline'),
                StackTrace.empty,
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const PetDetailScreen(petId: 'missing'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('pet-detail-error-state')), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petBackendListProvider.overrideWithValue(
              AsyncValue<List<PetProfile>>.data([
                _samplePet(id: 'mochi', name: 'Mochi'),
              ]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const PetDetailScreen(petId: 'mochi'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('pet-detail-avatar')),
          matching: find.byIcon(Icons.pets_rounded),
        ),
        findsOneWidget,
      );
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('P1-05 renders empty state and routes to P1-06', (tester) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final router = _day18Router(initialLocation: '/pets/list');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWithValue(
            const AsyncValue<List<PetProfile>>.data([]),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('pet-list-empty-illustration')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('pet-list-empty-create-button')));
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ thú cưng'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P1-05 uses the pet thumbnail asset instead of a placeholder', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final pet = _samplePet(
      id: 'mochi',
      name: 'Mochi',
      avatarPath: 'assets/images/pets/p1_05_mochi.png',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petBackendListProvider.overrideWithValue(
            AsyncValue<List<PetProfile>>.data([pet]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PetListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pet-list-avatar-mochi')), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P1-06 preserves an unfinished draft after leaving the form', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final container = _petContainer(_Day18PetApi());
    addTearDown(container.dispose);
    final router = _day18Router(
      initialLocation: '/pets/create?returnTo=/pets/list',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_textField('pet-form-name-field'), 'Bắp');
    await tester.enterText(
      _textField('pet-form-breed-field'),
      'Golden Retriever',
    );
    await tester.enterText(_textField('pet-form-color-field'), 'Vàng kem');
    await tester.tap(find.byKey(const Key('pet-form-back-button')));
    await tester.pumpAndSettle();

    router.go('/pets/create?returnTo=/pets/list');
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'pet-form-name-field'), 'Bắp');
    expect(_fieldText(tester, 'pet-form-breed-field'), 'Golden Retriever');
    expect(_fieldText(tester, 'pet-form-color-field'), 'Vàng kem');
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P1-06 edit mode pre-fills and updates the selected pet', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final api = _Day18PetApi();
    final container = _petContainer(api);
    addTearDown(container.dispose);
    container.read(petListProvider.notifier).replaceAll([
      _samplePet(id: 'pet-1', name: 'Mochi'),
    ]);
    final router = _day18Router(
      initialLocation: '/pets/pet-1/edit?returnTo=/pets/pet-1',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'pet-form-name-field'), 'Mochi');
    expect(find.text('Cập nhật hồ sơ'), findsOneWidget);
    await tester.enterText(_textField('pet-form-name-field'), 'Mochi mới');
    await tester.tap(find.byKey(const Key('pet-form-save-button')));
    await tester.pumpAndSettle();

    expect(api.lastUpdate?.name, 'Mochi mới');
    expect(find.text('Pet detail target: pet-1'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P1-06 upload failure keeps the saved pet and local draft', (
    tester,
  ) async {
    await setTestViewport(tester, size: const Size(390, 844));
    final localAvatar = File('assets/images/pets/p1_05_mochi.png').absolute;

    final api = _Day18PetApi(failUpload: true);
    final container = _petContainer(api);
    addTearDown(container.dispose);
    container
        .read(petFormDraftProvider.notifier)
        .replace(
          PetFormDraft(
            avatarPath: localAvatar.path,
            name: 'Mochi',
            breed: 'Mèo tam thể',
            color: 'Tam thể',
          ),
        );
    final router = _day18Router(
      initialLocation: '/pets/create?returnTo=/pets/list',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('pet-form-save-button')));
    await tester.pump();
    await tester.runAsync(() => api.uploadAttempted.future);
    await tester.pump();

    expect(
      find.text(
        'Đã lưu hồ sơ nhưng chưa tải được ảnh. '
        'Bản nháp vẫn được giữ để bạn thử lại.',
      ),
      findsOneWidget,
    );
    final draft = container.read(petFormDraftProvider);
    expect(draft.petId, 'pet-created');
    expect(draft.avatarPath, localAvatar.path);
    expect(container.read(petListProvider).single.id, 'pet-created');
    expectNoFlutterOverflow(tester);
  });

  for (final viewport in _viewports) {
    final label = '${viewport.width.toInt()}x${viewport.height.toInt()}';

    testWidgets('P1-05 remains stable at $label', (tester) async {
      await setTestViewport(tester, size: viewport);
      final pets = [
        _samplePet(
          id: 'mochi',
          name: 'Mochi',
          avatarPath: 'assets/images/pets/p1_05_mochi.png',
        ),
        _samplePet(
          id: 'kem',
          name: 'Kem',
          avatarPath: 'assets/images/pets/p1_05_kem.png',
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petBackendListProvider.overrideWithValue(
              AsyncValue<List<PetProfile>>.data(pets),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const PetListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pet-list-featured-mochi')), findsOneWidget);
      final navRect = tester.getRect(find.byType(PawMateBottomNav));
      expect(navRect.bottom, closeTo(viewport.height, 0.5));
      expectNoFlutterOverflow(tester);
    });

    testWidgets('P1-06 fixed CTA remains reachable at $label', (tester) async {
      await setTestViewport(tester, size: viewport);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const CreatePetScreen(returnTo: '/pets/list'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cta = find.byKey(const Key('pet-form-save-button'));
      expect(cta, findsOneWidget);
      final ctaRect = tester.getRect(cta);
      expect(ctaRect.bottom, closeTo(viewport.height, 0.5));
      expect(ctaRect.top, greaterThan(0));
      expectNoFlutterOverflow(tester);
    });
  }
}

Finder _textField(String key) {
  return find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(TextFormField),
  );
}

String _fieldText(WidgetTester tester, String key) {
  return tester.widget<TextFormField>(_textField(key)).controller!.text;
}

ProviderContainer _petContainer(_Day18PetApi api) {
  return ProviderContainer(
    overrides: [
      petApiProvider.overrideWith((ref) => api),
      petAccessTokenProvider.overrideWith((ref) async => 'day18-token'),
      petPhotoBytesReaderProvider.overrideWith(
        (ref) =>
            (path) async => <int>[1, 2, 3],
      ),
      petBackendListProvider.overrideWith(
        (ref) async => ref.watch(petListProvider),
      ),
    ],
  );
}

GoRouter _day18Router({required String initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/pets/list',
        builder: (context, state) => const PetListScreen(),
      ),
      GoRoute(
        path: '/pets/create',
        builder: (context, state) =>
            CreatePetScreen(returnTo: state.uri.queryParameters['returnTo']),
      ),
      GoRoute(
        path: '/pets/:id/edit',
        builder: (context, state) => CreatePetScreen(
          petId: state.pathParameters['id'],
          returnTo: state.uri.queryParameters['returnTo'],
        ),
      ),
      GoRoute(
        path: '/pets/:id',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('Pet detail target: ${state.pathParameters['id']}'),
          ),
        ),
      ),
    ],
  );
}

PetProfile _samplePet({
  required String id,
  required String name,
  String? avatarPath,
}) {
  return PetProfile(
    id: id,
    name: name,
    species: 'dog',
    breed: 'Golden Retriever',
    gender: 'unknown',
    dateOfBirth: DateTime(2022, 4, 12),
    weightKg: 12.4,
    healthStatus: 'healthy',
    avatarPath: avatarPath,
    color: 'Vàng kem',
  );
}

class _Day18PetApi extends PetApi {
  _Day18PetApi({this.failUpload = false}) : super(Dio());

  final bool failUpload;
  final Completer<void> uploadAttempted = Completer<void>();
  UpdatePetProfileInput? lastUpdate;

  @override
  Future<PetProfile> createPet(
    CreatePetProfileInput input, {
    required String accessToken,
  }) async {
    return PetProfile(
      id: 'pet-created',
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
  }

  @override
  Future<PetProfile> updatePet(
    String petId,
    UpdatePetProfileInput input, {
    required String accessToken,
  }) async {
    lastUpdate = input;
    return PetProfile(
      id: petId,
      name: input.name,
      species: input.species,
      breed: input.breed,
      gender: input.gender ?? 'unknown',
      dateOfBirth: input.dateOfBirth,
      weightKg: input.weightKg,
      healthStatus: input.healthStatus ?? 'healthy',
      color: input.color,
      microchip: input.microchip,
      isNeutered: input.isNeutered ?? false,
    );
  }

  @override
  Future<PetProfile> uploadPetPhoto(
    String petId,
    PetPhotoInput photo, {
    required String accessToken,
  }) async {
    if (!uploadAttempted.isCompleted) {
      uploadAttempted.complete();
    }
    if (failUpload) {
      throw const PetApiException(
        'Không thể tải ảnh lên.',
        code: 'PET_PHOTO_UPLOAD_FAILED',
      );
    }
    throw StateError('Unexpected successful upload in this Day 18 test.');
  }
}
