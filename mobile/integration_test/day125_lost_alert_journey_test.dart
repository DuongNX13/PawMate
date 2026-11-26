// Day 125 journey 6: Lost Alert -> Location -> Review -> Publish against the
// local backend and DB. Only the Supabase Storage upload is replaced: it would
// write outside this machine, so the test attaches a verified media row seeded
// in the local DB (output-evidence/day-125/lost-alert/*_media_seed.sql).
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/media/image_picker_service.dart';
import 'package:pawmate_mobile/core/network/app_dio.dart';
import 'package:pawmate_mobile/features/auth/application/auth_session_coordinator.dart';
import 'package:pawmate_mobile/features/auth/data/auth_api.dart';
import 'package:pawmate_mobile/features/auth/data/authenticated_dio.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_api.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_write_api.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_case_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_draft_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_case_detail_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_create_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_home_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_info_form_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_location_picker_sheet.dart';

const _apiBaseUrl = String.fromEnvironment(
  'PAWMATE_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);
const _email = 'mobile-e2e-owner@pawmate.test';
const _password = 'Pawmate123';
const _seededMediaId = '83000000-0000-4000-8000-000000000611';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Day125 journey 6 lost alert publishes through local backend', (
    tester,
  ) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: _apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: const {'Accept': 'application/json'},
      ),
    );
    final session = await AuthApi(
      dio,
    ).login(email: _email, password: _password);
    final photo = await _writePhoto();
    final writeSource = _SeededUploadSource(RescueWriteApi(dio));
    final petName = 'Mint D125 ${DateTime.now().millisecondsSinceEpoch % 100000}';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWith((ref) => dio),
          authenticatedDioProvider.overrideWith((ref) => dio),
          authAccessTokenProvider.overrideWith(
            (ref) async => session.accessToken,
          ),
          rescueWriteSourceProvider.overrideWithValue(writeSource),
          imagePickerProvider.overrideWithValue(_FilePicker(photo.path)),
          // Map tiles come from the internet; coordinates are typed instead.
          rescuePickerMapBuilderProvider.overrideWithValue(
            (selected, onSelect, onUnavailable) => const SizedBox.expand(),
          ),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: _router(),
        ),
      ),
    );
    await _waitFor(tester, find.byKey(const Key('rescue-create-entry')));

    // Lost Alert: step one.
    await tester.tap(find.byKey(const Key('rescue-create-entry')));
    await _waitFor(tester, find.byKey(const Key('rescue-create-form')));
    await tester.tap(find.text('Tải lên'));
    await _waitFor(tester, find.text('Chọn ảnh'));
    await tester.tap(find.text('Chọn ảnh'));
    await _waitFor(
      tester,
      find.byKey(const ValueKey('rescue-create-media-preview-0')),
    );
    await tester.enterText(
      find.byKey(const Key('rescue-create-pet-name-field')),
      petName,
    );
    await tester.enterText(
      find.byKey(const Key('rescue-create-breed-field')),
      'Mèo mướp, cổ trắng',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Location: manual coordinates in the picker sheet.
    await _scrollTo(tester, const Key('rescue-create-location-card'));
    await tester.tap(find.byKey(const Key('rescue-create-location-card')));
    await _waitFor(tester, find.byKey(const Key('rescue-location-picker')));
    await tester.enterText(
      find.byKey(const Key('rescue-location-latitude')),
      '10.7769',
    );
    await tester.enterText(
      find.byKey(const Key('rescue-location-longitude')),
      '106.7009',
    );
    await _tapInSheet(tester, const Key('rescue-location-apply'));
    await _tapInSheet(tester, const Key('rescue-location-confirm'));
    await _waitFor(tester, find.text('Đã chọn khu vực'));

    await _scrollTo(tester, const Key('rescue-create-lost-at-field'));
    await tester.tap(find.byKey(const Key('rescue-create-lost-at-field')));
    await _waitFor(tester, find.text('OK'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await _waitFor(tester, find.text('OK'));
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    expect(find.text('Chọn giờ và ngày'), findsNothing);

    await tester.tap(find.text('Tiếp tục'));
    await _waitFor(tester, find.byKey(const Key('rescue-info-form')));

    // Details, then the review sheet and publish.
    await tester.enterText(
      find.byKey(const Key('rescue-info-identifying-features-field')),
      'Vòng cổ xanh, đuôi cụt',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await _scrollTo(
      tester,
      const Key('rescue-info-media-review-confirmation'),
      scrollable: const Key('rescue-info-form'),
    );
    await tester.tap(
      find.byKey(const Key('rescue-info-media-review-confirmation')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng tin tìm'));
    await _waitFor(tester, find.byKey(const Key('rescue-report-review-sheet')));
    expect(find.byKey(const Key('rescue-review-location')), findsOneWidget);
    expect(find.byKey(const Key('rescue-review-validation')), findsNothing);
    await _tapInSheet(tester, const Key('rescue-review-confirm'));
    await _waitFor(
      tester,
      find.text('Đã đăng tin tìm thú cưng.'),
      timeout: const Duration(seconds: 30),
    );
    expect(writeSource.uploads, 1);
    expect(tester.takeException(), isNull);

    // API read-back: the published case is public, with an approximate area.
    final caseId = writeSource.publishedCaseId!;
    final detail = await RescueApi(dio).getCase(caseId);
    expect(detail.petName, petName);
    expect(detail.status, RescueCaseStatus.missing);
    // ignore: avoid_print
    print('DAY125 LOST-ALERT PASS caseId=$caseId pet=$petName');
  }, timeout: const Timeout(Duration(minutes: 5)));
}

GoRouter _router() => GoRouter(
  initialLocation: '/rescue',
  routes: [
    GoRoute(
      path: '/rescue',
      builder: (context, state) =>
          const RescueHomeScreen(browseEnabled: true, createEnabled: true),
    ),
    GoRoute(
      path: '/rescue/create',
      builder: (context, state) => const RescueCreateScreen(),
    ),
    GoRoute(
      path: '/rescue/create/details',
      builder: (context, state) => const RescueInfoFormScreen(),
    ),
    GoRoute(
      path: '/rescue/:caseId',
      builder: (context, state) =>
          RescueCaseDetailScreen(caseId: state.pathParameters['caseId']!),
    ),
  ],
);

Future<File> _writePhoto() async {
  final bytes = await rootBundle.load('assets/images/rescue/p2_02_map.png');
  final dir = await Directory.systemTemp.createTemp('day125-lost-alert-');
  final file = File('${dir.path}/mint.png');
  await file.writeAsBytes(
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
  );
  return file;
}

Future<void> _scrollTo(
  WidgetTester tester,
  Key target, {
  Key scrollable = const Key('rescue-create-form'),
}) async {
  await tester.dragUntilVisible(
    find.byKey(target),
    find.byKey(scrollable),
    const Offset(0, -200),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapInSheet(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(finder, findsAtLeastNWidgets(1));
}

class _FilePicker extends ImagePicker {
  _FilePicker(this.path);
  final String path;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => XFile(path);
}

/// Real draft/publish calls; upload returns the locally seeded verified asset.
class _SeededUploadSource implements RescueWriteSource {
  _SeededUploadSource(this._api);
  final RescueWriteApi _api;
  int uploads = 0;
  String? publishedCaseId;

  @override
  Future<RescueDraft> createDraft({
    required String accessToken,
    String source = 'rescue_home',
  }) => _api.createDraft(accessToken: accessToken, source: source);

  @override
  Future<RescueDraft> updateDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
    required Map<String, Object?> patch,
  }) => _api.updateDraft(
    accessToken: accessToken,
    draftId: draftId,
    expectedVersion: expectedVersion,
    patch: patch,
  );

  @override
  Future<RescueCaseDetail> publishDraft({
    required String accessToken,
    required String draftId,
    required int expectedVersion,
  }) async {
    final detail = await _api.publishDraft(
      accessToken: accessToken,
      draftId: draftId,
      expectedVersion: expectedVersion,
    );
    publishedCaseId = detail.caseId;
    return detail;
  }

  @override
  Future<RescueDraftMedia> uploadMedia({
    required String accessToken,
    required RescueDraftMedia media,
  }) async {
    uploads += 1;
    return media.copyWith(mediaId: _seededMediaId, uploaded: true);
  }
}
