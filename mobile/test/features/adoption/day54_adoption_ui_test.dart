import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_layout.dart';
import 'package:pawmate_mobile/features/adoption/application/adoption_runtime_providers.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_api.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_location_service.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_saved_listing_store.dart';
import 'package:pawmate_mobile/features/adoption/data/adoption_share_service.dart';
import 'package:pawmate_mobile/features/adoption/domain/adoption_models.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_profile_screen.dart';
import 'package:pawmate_mobile/features/adoption/presentation/adoption_swipe_deck_screen.dart';

import '../../test_support/ui_test_helpers.dart';
import '../../test_support/day115_capture.dart';
import 'adoption_ui_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadPawMateTestFonts();
  });

  testWidgets(
    'P2-09 ready deck exposes alternate actions and requests location only after opt-in',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final source = FakeAdoptionUiSource();
      final location = _DeferredLocationSource();

      await _pumpDeck(tester, source: source, location: location);

      expect(find.text('VUỐT PHẢI ĐỂ XEM HỒ SƠ'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('adoption-card-$adoptionListingId')),
        findsOneWidget,
      );
      expect(location.calls, 0);
      expect(source.listQueries.single.coordinates, isNull);

      for (final label in const [
        'Bỏ qua',
        'Xem hồ sơ',
        'Quan tâm và xem hồ sơ',
      ]) {
        final action = find.bySemanticsLabel(label);
        expect(action, findsOneWidget);
        expect(
          tester.getSemantics(action).flagsCollection.isEnabled,
          Tristate.isTrue,
        );
      }

      final cardSemantics = tester.getSemantics(
        find.byKey(const ValueKey('adoption-swipe-$adoptionListingId')),
      );
      final customLabels =
          (cardSemantics.getSemanticsData().customSemanticsActionIds ??
                  const <int>[])
              .map(CustomSemanticsAction.getAction)
              .whereType<CustomSemanticsAction>()
              .map((action) => action.label)
              .toSet();
      expect(
        customLabels,
        containsAll(const ['Bỏ qua', 'Xem hồ sơ', 'Quan tâm']),
      );
      semantics.dispose();

      await tester.tap(find.byKey(const Key('adoption-location-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5 km'));
      await tester.tap(find.byKey(const Key('adoption-apply-filters')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(location.calls, 1);
      expect(find.text('Đang áp dụng…'), findsOneWidget);
      location.completer.complete(
        const AdoptionCoordinates(latitude: 10.7769, longitude: 106.7009),
      );
      await tester.pumpAndSettle();
      expect(source.listQueries.last.coordinates?.latitude, 10.7769);
      expect(source.listQueries.last.coordinates?.longitude, 106.7009);
      expect(find.text('Bán kính 5km'), findsOneWidget);

      await tester.tap(find.byKey(const Key('adoption-location-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tất cả').last);
      await tester.tap(find.byKey(const Key('adoption-apply-filters')));
      await tester.pumpAndSettle();

      expect(source.listQueries.last.coordinates, isNull);
      expect(find.text('Theo gợi ý'), findsOneWidget);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('P2-09 exposes deterministic loading then ready state', (
    tester,
  ) async {
    final source = _DeferredListSource();

    await _pumpDeck(
      tester,
      source: source,
      location: FakeAdoptionLocationSource(),
      settle: false,
    );

    expect(find.byKey(const Key('adoption-deck-loading')), findsOneWidget);
    expect(find.byKey(const Key('adoption-like-action')), findsNothing);

    source.completer.complete(uiAdoptionPage());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adoption-card-$adoptionListingId')),
      findsOneWidget,
    );
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P2-09 initial error retries into the ready deck', (
    tester,
  ) async {
    final source = FakeAdoptionUiSource(
      listError: StateError('Synthetic list failure.'),
    );

    await _pumpDeck(
      tester,
      source: source,
      location: FakeAdoptionLocationSource(),
    );

    expect(find.text('Chưa tải được hồ sơ'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    source.listError = null;

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(source.listQueries, hasLength(2));
    expect(
      find.byKey(const ValueKey('adoption-card-$adoptionListingId')),
      findsOneWidget,
    );
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P2-09 empty state clears filters atomically', (tester) async {
    final source = FakeAdoptionUiSource(
      page: uiAdoptionPage(items: const <AdoptionListingSummary>[]),
    );

    await _pumpDeck(
      tester,
      source: source,
      location: FakeAdoptionLocationSource(),
    );

    expect(find.text('Chưa có hồ sơ phù hợp'), findsOneWidget);
    expect(find.byKey(const Key('adoption-skip-action')), findsNothing);
    expect(find.byKey(const Key('adoption-profile-action')), findsNothing);
    expect(find.byKey(const Key('adoption-like-action')), findsNothing);
    await captureDay115(tester, 'UX-28-Adoption');
    await tester.tap(find.text('Xóa bộ lọc'));
    await tester.pumpAndSettle();

    expect(source.listQueries, hasLength(2));
    expect(source.listQueries.last.species, isNull);
    expect(source.listQueries.last.coordinates, isNull);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P2-09 pull-to-refresh failure retains a stale usable card', (
    tester,
  ) async {
    final source = FakeAdoptionUiSource();

    await _pumpDeck(
      tester,
      source: source,
      location: FakeAdoptionLocationSource(),
    );
    source.listError = StateError('Synthetic refresh failure.');

    await tester.drag(
      find.byKey(const Key('adoption-deck-scroll')),
      const Offset(0, 360),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const Key('adoption-stale-notice')), findsOneWidget);
    expect(find.byKey(const Key('adoption-state-message')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('adoption-card-$adoptionListingId')),
      findsOneWidget,
    );
    expectNoFlutterOverflow(tester);
  });

  testWidgets('DT-10 keeps a local draft until Apply and clears atomically', (
    tester,
  ) async {
    final source = FakeAdoptionUiSource();

    await _pumpDeck(
      tester,
      source: source,
      location: FakeAdoptionLocationSource(),
    );

    await tester.tap(find.byKey(const Key('adoption-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mèo'));
    await tester.pumpAndSettle();
    expect(source.listQueries, hasLength(1));
    await tester.tap(find.text('1–3 tuổi'));
    await tester.pumpAndSettle();
    expect(source.listQueries, hasLength(1));
    await tester.tap(find.text('10 km'));
    await tester.pumpAndSettle();
    expect(source.listQueries, hasLength(1));
    await tester.tap(find.byKey(const Key('adoption-apply-filters')));
    await tester.pumpAndSettle();
    expect(source.listQueries.last.species, AdoptionSpecies.cat);
    expect(source.listQueries.last.ageGroup, AdoptionAgeGroup.oneToThree);
    expect(source.listQueries.last.distanceKm, 10);

    await tester.tap(find.byKey(const Key('adoption-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('adoption-clear-filters')));
    await tester.pumpAndSettle();
    expect(source.listQueries.last.species, isNull);
    expect(source.listQueries.last.ageGroup, isNull);
    expect(source.listQueries.last.distanceKm, isNull);
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    'P2-09 left swipe defers skip POST and undo restores the listing',
    (tester) async {
      final source = FakeAdoptionUiSource();

      await _pumpDeck(
        tester,
        source: source,
        location: FakeAdoptionLocationSource(),
      );

      await tester.drag(
        find.byKey(const ValueKey('adoption-dismissible-$adoptionListingId')),
        const Offset(-500, 0),
      );
      await tester.pump();

      expect(source.decisionCalls, isEmpty);
      expect(find.text('Bạn đã xem hết rồi'), findsOneWidget);
      expect(find.text('Hoàn tác'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byType(SnackBarAction));
      await tester.pump(const Duration(milliseconds: 300));

      expect(source.decisionCalls, isEmpty);
      expect(
        find.byKey(const ValueKey('adoption-card-$adoptionListingId')),
        findsOneWidget,
      );
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets(
    'P2-09 shows loading-more instead of exhausted while next page is pending',
    (tester) async {
      final source = _DeferredNextPageSource();
      await _pumpDeck(
        tester,
        source: source,
        location: FakeAdoptionLocationSource(),
      );

      await tester.tap(find.byKey(const Key('adoption-skip-action')));
      await tester.pump();

      expect(
        find.byKey(const Key('adoption-deck-loading-more')),
        findsOneWidget,
      );
      expect(find.text('Bạn đã xem hết rồi'), findsNothing);
      expect(source.decisionCalls, isEmpty);

      source.nextPage.complete(
        uiAdoptionPage(
          items: [
            uiAdoptionSummary(
              listingId: adoptionSecondListingId,
              petName: 'Lulu',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('adoption-card-$adoptionSecondListingId')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('adoption-deck-loading-more')), findsNothing);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('P2-09 right swipe likes then opens the exact profile', (
    tester,
  ) async {
    final source = FakeAdoptionUiSource();
    await _pumpDeckWithRouter(
      tester,
      source: source,
      location: FakeAdoptionLocationSource(),
    );

    await tester.drag(
      find.byKey(const ValueKey('adoption-dismissible-$adoptionListingId')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();

    expect(source.decisionCalls, hasLength(1));
    expect(source.decisionCalls.single.decision, AdoptionDecision.like);
    expect(find.text('Profile target: $adoptionListingId'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P2-09 like failure keeps the card and explains the error', (
    tester,
  ) async {
    final source = _FailingDecisionSource();

    await _pumpDeck(
      tester,
      source: source,
      location: FakeAdoptionLocationSource(),
    );

    await tester.tap(find.byKey(const Key('adoption-like-action')));
    await tester.pumpAndSettle();

    expect(source.decisionCalls, hasLength(1));
    expect(find.byKey(const Key('adoption-state-message')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('adoption-card-$adoptionListingId')),
      findsOneWidget,
    );
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    'P2-10 ready profile shares exact detail, saves locally, and opens request route',
    (tester) async {
      final detail = uiAdoptionDetail();
      final source = FakeAdoptionUiSource(detail: detail);
      final store = MemoryAdoptionSavedListingStore();
      final share = FakeAdoptionShareSource();

      await _pumpProfile(tester, source: source, store: store, share: share);

      expect(find.text('Hồ sơ nhận nuôi'), findsOneWidget);
      expect(find.text('Mochi'), findsOneWidget);
      final request = find.bySemanticsLabel(
        'Mở biểu mẫu gửi yêu cầu nhận nuôi Mochi',
      );
      expect(request, findsOneWidget);
      expect(
        tester.getSemantics(request).flagsCollection.isEnabled,
        Tristate.isTrue,
      );

      await tester.tap(find.byKey(const Key('adoption-profile-share')));
      await tester.pump();
      expect(share.sharedDetails, hasLength(1));
      expect(share.sharedDetails.single, same(detail));
      expect(share.sharePositionOrigins.single, isNot(Rect.zero));
      expect(share.sharePositionOrigins.single.width, greaterThan(0));
      expect(share.sharePositionOrigins.single.height, greaterThan(0));

      final saveAction = find.byKey(const Key('adoption-profile-save-action'));
      await tester.ensureVisible(saveAction);
      await tester.pumpAndSettle();
      await tester.tap(saveAction);
      await tester.pumpAndSettle();
      expect(store.values, contains(adoptionListingId));
      expect(store.writes, 1);
      expect(find.text('Đã lưu trên máy'), findsOneWidget);
      expect(
        find.text(
          'Đã lưu Mochi trên thiết bị này. Dữ liệu chưa đồng bộ tài khoản.',
        ),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 4));
      await tester.tap(find.text('Gửi yêu cầu nhận nuôi'));
      await tester.pumpAndSettle();

      expect(find.text('Request target: $adoptionListingId'), findsOneWidget);
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('P2-10 disables share while one platform request is pending', (
    tester,
  ) async {
    final share = _DeferredShareSource();

    await _pumpProfile(tester, source: FakeAdoptionUiSource(), share: share);

    await tester.tap(find.byKey(const Key('adoption-profile-share')));
    await tester.pump();

    expect(share.calls, 1);
    expect(find.byTooltip('Đang mở bảng chia sẻ'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byKey(const Key('adoption-profile-share')));
    await tester.pump();
    expect(share.calls, 1);

    share.completer.complete();
    await tester.pumpAndSettle();

    expect(find.byTooltip('Chia sẻ hồ sơ'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P2-10 disables local-save CTA while its write is pending', (
    tester,
  ) async {
    final store = _DeferredSavedStore();
    await _pumpProfile(tester, source: FakeAdoptionUiSource(), store: store);

    final saveAction = find.byKey(const Key('adoption-profile-save-action'));
    await tester.ensureVisible(saveAction);
    await tester.pumpAndSettle();
    await tester.tap(saveAction);
    await tester.pump();

    expect(store.writes, [
      {adoptionListingId},
    ]);
    final pendingAction = find.bySemanticsLabel(
      'Đang cập nhật danh sách lưu trên thiết bị này',
    );
    expect(pendingAction, findsOneWidget);
    expect(
      tester.getSemantics(pendingAction).flagsCollection.isEnabled,
      Tristate.isFalse,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('adoption-profile-actions')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    await tester.tap(saveAction);
    await tester.pump();
    expect(store.writes, hasLength(1));

    store.completer.complete();
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu trên máy'), findsOneWidget);
    expect(store.writes, hasLength(1));
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P2-10 restores share action and explains platform failure', (
    tester,
  ) async {
    final share = FakeAdoptionShareSource()
      ..error = StateError('Synthetic share failure.');

    await _pumpProfile(tester, source: FakeAdoptionUiSource(), share: share);

    await tester.tap(find.byKey(const Key('adoption-profile-share')));
    await tester.pumpAndSettle();

    expect(
      find.text('Không mở được bảng chia sẻ. Vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Chia sẻ hồ sơ'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P2-10 owner sees an honest disabled request action', (
    tester,
  ) async {
    final source = FakeAdoptionUiSource(
      detail: uiAdoptionDetail(canRequest: true, canManageListing: true),
    );

    await _pumpProfile(tester, source: source);

    final ownerAction = find.bySemanticsLabel('Đây là tin của bạn');
    expect(ownerAction, findsOneWidget);
    expect(
      tester.getSemantics(ownerAction).flagsCollection.isEnabled,
      Tristate.isFalse,
    );
    await tester.scrollUntilVisible(
      find.textContaining('Đây là tin do bạn quản lý'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('Yêu cầu nhận nuôi chỉ dành cho người xem khác'),
      findsOneWidget,
    );
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P2-10 deleted listing renders recoverable unavailable state', (
    tester,
  ) async {
    final source = FakeAdoptionUiSource(
      detailError: const AdoptionApiException(
        'Không tìm thấy hồ sơ nhận nuôi.',
        code: 'ADOPTION_003',
        statusCode: 404,
      ),
    );

    await _pumpProfile(tester, source: source);

    expect(find.text('Không còn hồ sơ này'), findsOneWidget);
    expect(find.text('Không tìm thấy hồ sơ nhận nuôi.'), findsOneWidget);
    expect(find.text('Về danh sách nhận nuôi'), findsOneWidget);
    expect(find.byKey(const Key('adoption-profile-actions')), findsNothing);

    await captureDay115(tester, 'UX-25-Adoption');
    await tester.tap(find.text('Về danh sách nhận nuôi'));
    await tester.pumpAndSettle();
    expect(find.text('Adoption home'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P2-10 exposes deterministic loading then profile content', (
    tester,
  ) async {
    final source = _DeferredDetailSource();

    await _pumpProfile(tester, source: source, settle: false);

    expect(find.byKey(const Key('adoption-profile-loading')), findsOneWidget);
    expect(find.byKey(const Key('adoption-profile-actions')), findsNothing);

    source.completer.complete(uiAdoptionDetail());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('adoption-profile-content')), findsOneWidget);
    expect(find.text('Mochi'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P2-10 generic error retries into the requested profile', (
    tester,
  ) async {
    final source = FakeAdoptionUiSource(
      detailError: StateError('Synthetic detail failure.'),
    );

    await _pumpProfile(tester, source: source);

    expect(find.text('Chưa tải được hồ sơ'), findsOneWidget);
    expect(
      find.text('Không tải được hồ sơ nhận nuôi. Vui lòng thử lại.'),
      findsOneWidget,
    );
    source.detailError = null;

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(source.detailCalls, hasLength(2));
    expect(find.byKey(const Key('adoption-profile-content')), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  for (final testCase in [
    (
      status: AdoptionListingStatus.pending,
      canRequest: true,
      label: 'Không còn nhận yêu cầu',
      notice: 'Đang xem xét',
    ),
    (
      status: AdoptionListingStatus.available,
      canRequest: false,
      label: 'Chưa thể gửi yêu cầu',
      notice: 'chưa được phép gửi yêu cầu',
    ),
  ]) {
    testWidgets(
      'P2-10 disables request honestly when label is ${testCase.label}',
      (tester) async {
        final source = FakeAdoptionUiSource(
          detail: uiAdoptionDetail(
            status: testCase.status,
            canRequest: testCase.canRequest,
          ),
        );

        await _pumpProfile(tester, source: source);

        final request = find.bySemanticsLabel(testCase.label);
        expect(request, findsOneWidget);
        expect(
          tester.getSemantics(request).flagsCollection.isEnabled,
          Tristate.isFalse,
        );
        await tester.scrollUntilVisible(
          find.textContaining(testCase.notice),
          240,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining(testCase.notice), findsOneWidget);
        expectNoFlutterOverflow(tester);
      },
    );
  }

  testWidgets(
    'P2-10 missing media is honest and local-save failure is explained',
    (tester) async {
      final store = MemoryAdoptionSavedListingStore()..failWrites = true;
      final source = FakeAdoptionUiSource(
        detail: uiAdoptionDetail(
          petName: 'Luna',
          species: AdoptionSpecies.cat,
          healthBadges: const [],
          verificationBadges: const [],
        ),
      );

      await _pumpProfile(tester, source: source, store: store);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Chưa có ảnh của Luna'), findsOneWidget);
      expect(find.text('Chưa có ảnh của Luna'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName !=
                  PawMateBrandCanvas.textureAsset,
        ),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.text('Chưa có dữ liệu y tế được xác nhận.'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Chưa có dữ liệu y tế được xác nhận.'), findsOneWidget);
      expect(find.text('Chưa có thông tin xác minh.'), findsOneWidget);

      final saveAction = find.byKey(const Key('adoption-profile-save-action'));
      await tester.ensureVisible(saveAction);
      await tester.pumpAndSettle();
      await tester.tap(saveAction);
      await tester.pumpAndSettle();

      expect(store.writes, 1);
      expect(
        find.text('Không lưu được trên thiết bị. Vui lòng thử lại.'),
        findsOneWidget,
      );
      expectNoFlutterOverflow(tester);
    },
  );

  testWidgets('P2-09 remains usable at 320x568 and text scale 2.0', (
    tester,
  ) async {
    await _pumpDeck(
      tester,
      source: FakeAdoptionUiSource(),
      location: FakeAdoptionLocationSource(),
      size: const Size(320, 568),
      textScale: 2,
    );

    expect(find.text('VUỐT PHẢI ĐỂ XEM HỒ SƠ'), findsOneWidget);
    expect(find.bySemanticsLabel('Bỏ qua'), findsOneWidget);
    expect(find.bySemanticsLabel('Xem hồ sơ'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P2-09 filter sheet remains scrollable at narrow large text', (
    tester,
  ) async {
    await _pumpDeck(
      tester,
      source: FakeAdoptionUiSource(),
      location: FakeAdoptionLocationSource(),
      size: const Size(320, 568),
      textScale: 2,
    );

    await tester.tap(find.byKey(const Key('adoption-filter-button')));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    final myRequests = find.byKey(const Key('adoption-my-requests-button'));
    expect(sheet, findsOneWidget);
    expect(myRequests, findsOneWidget);
    expect(tester.getSize(myRequests).height, greaterThanOrEqualTo(48));
    expect(
      tester.getRect(sheet).contains(tester.getRect(myRequests).center),
      isTrue,
    );

    final locationAction = find.byKey(const Key('adoption-apply-filters'));
    final scrollable = find.descendant(
      of: sheet,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      locationAction,
      180,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(locationAction).height, greaterThanOrEqualTo(48));
    expect(
      tester.getRect(sheet).contains(tester.getRect(locationAction).center),
      isTrue,
    );
    expectNoFlutterOverflow(tester);
  });

  testWidgets('P2-10 remains readable at 320x568 and text scale 2.0', (
    tester,
  ) async {
    final source = FakeAdoptionUiSource(
      detail: uiAdoptionDetail(
        description:
            'Mochi cần một gia đình kiên nhẫn, có thời gian làm quen chậm rãi '
            'và duy trì lịch đi dạo đều đặn mỗi ngày.',
        healthBadges: const [
          'Đã tiêm phòng đầy đủ theo lịch',
          'Đã tẩy giun và kiểm tra sức khỏe gần đây',
        ],
        verificationBadges: const [
          'Hồ sơ và người đăng đã được xác minh',
          'Thông tin chăm sóc được đối chiếu',
        ],
      ),
    );

    await _pumpProfile(
      tester,
      source: source,
      size: const Size(320, 568),
      textScale: 2,
    );

    expect(find.text('Hồ sơ nhận nuôi'), findsOneWidget);
    expectNoFlutterOverflow(tester);
    await tester.scrollUntilVisible(
      find.text('Xác thực'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Xác thực'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets(
    'P2-10 request CTA label stays fully readable at 320x568 and text scale 2.0',
    (tester) async {
      await _pumpProfile(
        tester,
        source: FakeAdoptionUiSource(),
        size: const Size(320, 568),
        textScale: 2,
      );

      final requestLabel = find.descendant(
        of: find.byKey(const Key('adoption-profile-actions')),
        matching: find.text('Gửi yêu cầu nhận nuôi'),
      );
      expect(requestLabel, findsOneWidget);

      final paragraph = tester.renderObject<RenderParagraph>(requestLabel);
      expect(paragraph.didExceedMaxLines, isFalse);
      expectNoFlutterOverflow(tester);
    },
  );

  for (final viewport in const [Size(412, 915), Size(430, 932)]) {
    testWidgets(
      'P2-09 has no overflow at ${viewport.width.toInt()}x${viewport.height.toInt()} and text scale 1.3',
      (tester) async {
        await _pumpDeck(
          tester,
          source: FakeAdoptionUiSource(),
          location: FakeAdoptionLocationSource(),
          size: viewport,
          textScale: 1.3,
        );

        expect(find.text('VUỐT PHẢI ĐỂ XEM HỒ SƠ'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('adoption-card-$adoptionListingId')),
          findsOneWidget,
        );
        expectNoFlutterOverflow(tester);
      },
    );

    testWidgets(
      'P2-10 has no overflow at ${viewport.width.toInt()}x${viewport.height.toInt()} and text scale 1.3',
      (tester) async {
        await _pumpProfile(
          tester,
          source: FakeAdoptionUiSource(),
          size: viewport,
          textScale: 1.3,
        );

        expect(find.text('Hồ sơ nhận nuôi'), findsOneWidget);
        expect(
          find.byKey(const Key('adoption-profile-content')),
          findsOneWidget,
        );
        expectNoFlutterOverflow(tester);
      },
    );
  }

  testWidgets('P2-09 reduced-motion swipe settles deterministically', (
    tester,
  ) async {
    final source = FakeAdoptionUiSource();
    await _pumpDeck(
      tester,
      source: source,
      location: FakeAdoptionLocationSource(),
      disableAnimations: true,
    );

    await tester.drag(
      find.byKey(const ValueKey('adoption-dismissible-$adoptionListingId')),
      const Offset(-500, 0),
    );
    await tester.pump();

    expect(source.decisionCalls, isEmpty);
    expect(find.text('Bạn đã xem hết rồi'), findsOneWidget);
    expect(find.text('Hoàn tác'), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });
}

Future<void> _pumpDeck(
  WidgetTester tester, {
  required FakeAdoptionUiSource source,
  required FakeAdoptionLocationSource location,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool settle = true,
  bool disableAnimations = false,
}) async {
  await setTestViewport(tester, size: size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adoptionSourceProvider.overrideWithValue(source),
        adoptionAccessTokenProvider.overrideWith(
          (ref) => Future<String?>.value('day54-test-token'),
        ),
        adoptionLocationSourceProvider.overrideWithValue(location),
        adoptionClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 7, 28, 4),
        ),
        adoptionIdempotencyKeyFactoryProvider.overrideWithValue(
          (decision, listingId, timestamp, sequence) =>
              'day54-${decision.wireValue}-$listingId-$sequence',
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        builder: disableAnimations
            ? _testMediaBuilder(textScale, disableAnimations: true)
            : testTextScaleBuilder(textScale),
        home: const AdoptionSwipeDeckScreen(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

Future<GoRouter> _pumpProfile(
  WidgetTester tester, {
  required FakeAdoptionUiSource source,
  AdoptionSavedListingStore? store,
  FakeAdoptionShareSource? share,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool settle = true,
}) async {
  await setTestViewport(tester, size: size);
  final router = GoRouter(
    initialLocation: '/adoption/$adoptionListingId',
    routes: [
      GoRoute(
        path: '/adoption',
        builder: (_, _) => const Scaffold(body: Text('Adoption home')),
      ),
      GoRoute(
        path: '/adoption/:listingId/request',
        builder: (_, state) => Scaffold(
          body: Text('Request target: ${state.pathParameters['listingId']}'),
        ),
      ),
      GoRoute(
        path: '/adoption/:listingId',
        builder: (_, state) => AdoptionProfileScreen(
          listingId: state.pathParameters['listingId']!,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adoptionSourceProvider.overrideWithValue(source),
        adoptionAccessTokenProvider.overrideWith(
          (ref) => Future<String?>.value('day54-test-token'),
        ),
        adoptionSavedListingStoreProvider.overrideWithValue(
          store ?? MemoryAdoptionSavedListingStore(),
        ),
        adoptionShareSourceProvider.overrideWithValue(
          share ?? FakeAdoptionShareSource(),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        builder: testTextScaleBuilder(textScale),
        routerConfig: router,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return router;
}

TransitionBuilder _testMediaBuilder(
  double textScale, {
  required bool disableAnimations,
}) {
  return (context, child) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: child ?? const SizedBox.shrink(),
    );
  };
}

Future<GoRouter> _pumpDeckWithRouter(
  WidgetTester tester, {
  required FakeAdoptionUiSource source,
  required FakeAdoptionLocationSource location,
}) async {
  await setTestViewport(tester, size: const Size(390, 844));
  final router = GoRouter(
    initialLocation: '/adoption',
    routes: [
      GoRoute(
        path: '/adoption',
        builder: (_, _) => const AdoptionSwipeDeckScreen(),
      ),
      GoRoute(
        path: '/adoption/:listingId',
        builder: (_, state) => Scaffold(
          body: Text('Profile target: ${state.pathParameters['listingId']}'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adoptionSourceProvider.overrideWithValue(source),
        adoptionAccessTokenProvider.overrideWith(
          (ref) => Future<String?>.value('day54-test-token'),
        ),
        adoptionLocationSourceProvider.overrideWithValue(location),
        adoptionClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 7, 28, 4),
        ),
        adoptionIdempotencyKeyFactoryProvider.overrideWithValue(
          (decision, listingId, timestamp, sequence) =>
              'day54-${decision.wireValue}-$listingId-$sequence',
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

class _DeferredListSource extends FakeAdoptionUiSource {
  final Completer<AdoptionListingPage> completer =
      Completer<AdoptionListingPage>();

  @override
  Future<AdoptionListingPage> listListings(
    AdoptionListQuery query, {
    required String accessToken,
  }) {
    listQueries.add(query);
    return completer.future;
  }
}

class _DeferredNextPageSource extends FakeAdoptionUiSource {
  _DeferredNextPageSource()
    : super(page: uiAdoptionPage(hasMore: true, nextCursor: 'day54-next-page'));

  final Completer<AdoptionListingPage> nextPage =
      Completer<AdoptionListingPage>();

  @override
  Future<AdoptionListingPage> listListings(
    AdoptionListQuery query, {
    required String accessToken,
  }) {
    listQueries.add(query);
    if (query.cursor == null) return Future.value(page);
    return nextPage.future;
  }
}

class _DeferredDetailSource extends FakeAdoptionUiSource {
  final Completer<AdoptionListingDetail> completer =
      Completer<AdoptionListingDetail>();

  @override
  Future<AdoptionListingDetail> getListing(
    String listingId, {
    required String accessToken,
  }) {
    detailCalls.add(listingId);
    return completer.future;
  }
}

class _DeferredLocationSource extends FakeAdoptionLocationSource {
  final Completer<AdoptionCoordinates> completer =
      Completer<AdoptionCoordinates>();

  @override
  Future<AdoptionCoordinates> resolveCurrentLocation() {
    calls += 1;
    return completer.future;
  }
}

class _FailingDecisionSource extends FakeAdoptionUiSource {
  @override
  Future<AdoptionDecisionResult> recordDecision(
    String listingId,
    AdoptionDecision decision, {
    required String accessToken,
    required String idempotencyKey,
  }) async {
    await super.recordDecision(
      listingId,
      decision,
      accessToken: accessToken,
      idempotencyKey: idempotencyKey,
    );
    throw StateError('Synthetic decision failure.');
  }
}

class _DeferredShareSource extends FakeAdoptionShareSource {
  final Completer<void> completer = Completer<void>();
  int calls = 0;

  @override
  Future<void> shareProfile(
    AdoptionListingDetail detail, {
    required Rect sharePositionOrigin,
  }) {
    calls += 1;
    sharedDetails.add(detail);
    sharePositionOrigins.add(sharePositionOrigin);
    return completer.future;
  }
}

class _DeferredSavedStore implements AdoptionSavedListingStore {
  final Completer<void> completer = Completer<void>();
  final List<Set<String>> writes = [];

  @override
  Future<Set<String>> readAll() async => const {};

  @override
  Future<void> writeAll(Set<String> listingIds) {
    writes.add(Set<String>.unmodifiable(listingIds));
    return completer.future;
  }
}
