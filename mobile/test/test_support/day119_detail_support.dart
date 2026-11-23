import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/adoption/application/my_adoption_requests_provider.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_request_chat_models.dart';
import 'package:pawmate_mobile/features/adoption/presentation/my_adoption_requests_screen.dart';
import 'package:pawmate_mobile/features/pets/application/pet_list_provider.dart';
import 'package:pawmate_mobile/features/pets/domain/pet_profile.dart';
import 'package:pawmate_mobile/features/pets/presentation/create_pet_screen.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_detail_screen.dart';
import 'package:pawmate_mobile/features/pets/presentation/pet_list_screen.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_home_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';

import '../features/rescue/rescue_test_fixtures.dart';
import 'ui_test_helpers.dart';

const day119Root = Key('day119-root');
const day119LongPetName = 'Mochi — bạn nhỏ đáng yêu của gia đình Nguyễn';
final day119FirstCaseId = sampleCases().first.caseId;

class Day119Harness {
  const Day119Harness(this.router, this.source);
  final GoRouter router;
  final FakeRescueSource source;
}

Future<Day119Harness> pumpDay119(
  WidgetTester tester,
  String family,
  Size viewport, {
  bool longContent = false,
  AsyncValue<List<AdoptionRequestSummary>>? requests,
  AsyncValue<List<PetProfile>>? pets,
  Object? detailError,
}) async {
  await setTestViewport(tester, size: viewport);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 34);
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetPadding);
  final source = FakeRescueSource(
    pages: [samplePage(items: day119Cases(longContent: longContent))],
    detailError: detailError,
  );
  final initial = switch (family) {
    'DT-01' => '/pets/mochi',
    'DT-03' => '/adoption/requests',
    _ => '/rescue',
  };
  final router = GoRouter(
    initialLocation: initial,
    restorationScopeId: 'day119-router',
    routes: [
      GoRoute(path: '/pets/list', builder: (_, _) => const PetListScreen()),
      GoRoute(
        path: '/pets/mochi',
        builder: (_, _) => const PetDetailScreen(petId: 'mochi'),
      ),
      GoRoute(
        path: '/pets/mochi/edit',
        builder: (_, state) => CreatePetScreen(
          petId: 'mochi',
          returnTo: state.uri.queryParameters['returnTo'],
        ),
      ),
      GoRoute(
        path: '/adoption/requests',
        builder: (_, _) => const MyAdoptionRequestsScreen(),
      ),
      GoRoute(
        path: '/rescue',
        builder: (_, _) => const RescueHomeScreen(
          browseEnabled: true,
          createEnabled: true,
          mapPreviewAsset: 'assets/images/rescue/p2_01_map.png',
        ),
      ),
      GoRoute(
        path: '/rescue/:caseId',
        builder: (_, s) =>
            RescueCaseDetailScreen(caseId: s.pathParameters['caseId']!),
      ),
      // Out-of-scope route targets are explicit sentinels, not claimed screens.
      for (final p in [
        '/adoption',
        '/adoption/listing-1',
        '/adoption/chat/thread-1',
      ])
        GoRoute(
          path: p,
          builder: (_, _) => Scaffold(body: Text('QA route target $p')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        petBackendListProvider.overrideWithValue(
          pets ?? AsyncValue.data([day119Pet(longContent: longContent)]),
        ),
        myAdoptionRequestsProvider.overrideWithValue(
          requests ?? AsyncValue.data(day119Requests(longContent: longContent)),
        ),
        rescueApiProvider.overrideWithValue(source),
        rescueClockProvider.overrideWithValue(fixedRescueClock()),
      ],
      child: RepaintBoundary(
        key: day119Root,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    ),
  );
  await readyDay119(tester);
  return Day119Harness(router, source);
}

PetProfile day119Pet({bool longContent = false}) => PetProfile(
  id: 'mochi',
  name: longContent ? day119LongPetName : 'Mochi',
  species: 'dog',
  breed: longContent
      ? 'Golden Retriever lai — bộ lông vàng kem mềm mại'
      : 'Golden Retriever',
  gender: 'male',
  dateOfBirth: DateTime(2022, 4, 12),
  weightKg: 12.4,
  healthStatus: 'healthy',
  avatarPath: 'assets/images/pets/p1_05_mochi.png',
  color: longContent
      ? 'Vàng kem, phần ngực và bàn chân có đốm trắng'
      : 'Vàng kem',
  microchip: 'MC-8293-128',
  isNeutered: true,
);

List<AdoptionRequestSummary> day119Requests({bool longContent = false}) => [
  for (var i = 0; i < (longContent ? 12 : 2); i++)
    AdoptionRequestSummary.fromJson({
      'requestId': 'request-$i',
      'listingId': 'listing-1',
      'petName': longContent
          ? '$day119LongPetName — đơn ${i + 1}'
          : (i == 0 ? 'Mochi' : 'Kem'),
      'status': [
        'reviewing',
        'approved',
        'submitted',
        'rejected',
        'cancelled',
      ][i % 5],
      'listingAvailability': i.isEven ? 'expired' : 'available',
      'threadId': 'thread-1',
      'createdAt': '2026-07-28T05:00:00.000Z',
      'updatedAt': '2026-09-18T05:00:00.000Z',
    }),
];

List<RescueCaseSummary> day119Cases({bool longContent = false}) {
  final values = [
    ...sampleCases(),
    rescueCase(
      caseId: '44444444-4444-4444-8444-444444444444',
      petName: 'Nắng',
      species: RescueSpecies.dog,
      status: RescueCaseStatus.missing,
      areaLabel: 'Q. 1',
      breedOrColor: 'Corgi',
    ),
    rescueCase(
      caseId: '55555555-5555-4555-8555-555555555555',
      petName: 'Mây',
      species: RescueSpecies.cat,
      status: RescueCaseStatus.missing,
      areaLabel: 'Q. 5',
      breedOrColor: 'Mèo Anh lông ngắn',
    ),
  ];
  const images = ['p2_01_lulu.png', 'p2_01_muc.png', 'p2_01_bong.png'];
  return [
    for (var i = 0; i < values.length; i++)
      RescueCaseSummary(
        caseId: values[i].caseId,
        petName: longContent && i == 0 ? day119LongPetName : values[i].petName,
        species: values[i].species,
        status: values[i].status,
        lostAt: values[i].lostAt,
        publicLocation: values[i].publicLocation,
        media: [
          RescuePublicMedia(
            mediaId: 'day119-$i',
            mimeType: 'image/png',
            publicUrl: Uri(
              scheme: 'asset',
              path: 'assets/images/rescue/${images[i % 3]}',
            ),
            createdAt: values[i].createdAt,
          ),
        ],
        commentCount: values[i].commentCount,
        createdAt: values[i].createdAt,
        updatedAt: values[i].updatedAt,
        breedOrColor: longContent && i == 0
            ? 'Poodle lai — lông nâu kem, đeo vòng cổ xanh'
            : values[i].breedOrColor,
        ageLabel: values[i].ageLabel,
        distanceMeters: values[i].distanceMeters,
      ),
  ];
}

Future<void> readyDay119(WidgetTester tester) async {
  await tester.pump();
  final context = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final d in ['assets/images', 'assets/icons']) {
      for (final f in Directory(
        d,
      ).listSync(recursive: true).whereType<File>()) {
        final p = f.path.replaceAll(r'\', '/');
        if (!RegExp(r'\.(png|jpg|jpeg|webp)$').hasMatch(p)) continue;
        Object? error;
        await precacheImage(
          AssetImage(p),
          context,
          onError: (e, _) => error = e,
        );
        if (error != null) throw StateError('$p: $error');
      }
    }
  });
  await tester.pumpAndSettle();
}

Future<void> captureDay119(WidgetTester tester, String id) async {
  final out = Platform.environment['D119_SCREENSHOTS'];
  if (out == null || out.isEmpty) return;
  final handle = tester.ensureSemantics();
  await tester.pump();
  final context = tester.element(find.byType(MaterialApp));
  String? tree;
  void visit(PipelineOwner owner) {
    tree ??= owner.semanticsOwner?.rootSemanticsNode?.toStringDeep();
    owner.visitChildren(visit);
  }

  visit(tester.binding.rootPipelineOwner);
  if (tree == null) throw StateError('Missing semantics root');
  await tester.runAsync(() async {
    final im = await captureImage(context);
    final data = await im.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Missing PNG bytes');
    Directory(out).createSync(recursive: true);
    final base = '$out/$id';
    for (final ext in ['png', 'json', 'semantics.txt']) {
      if (File('$base.$ext').existsSync()) {
        throw StateError('Immutable capture exists');
      }
    }
    File('$base.png').writeAsBytesSync(data.buffer.asUint8List());
    File('$base.semantics.txt').writeAsStringSync(tree!);
    File('$base.json').writeAsStringSync(
      jsonEncode({
        'id': id,
        'test': tester.testDescription,
        'at': DateTime.now().toUtc().toIso8601String(),
        'width': im.width,
        'height': im.height,
        'top_safe_area': 24,
        'bottom_safe_area': 34,
        'kind': 'WIDGET_API_MAP_CLOCK_DOUBLES_NOT_NATIVE',
      }),
    );
    im.dispose();
  });
  handle.dispose();
}
