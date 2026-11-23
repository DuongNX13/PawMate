import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/rescue/application/rescue_create_provider.dart';
import 'package:pawmate_mobile/features/rescue/data/rescue_location_service.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_draft_models.dart';
import 'package:pawmate_mobile/features/rescue/domain/rescue_map_models.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_create_screen.dart';
import 'package:pawmate_mobile/features/rescue/presentation/rescue_location_picker_sheet.dart';

import '../../test_support/ui_test_helpers.dart';

class PickerLocationService implements RescueLocationService {
  int calls = 0;
  Object? error;
  Completer<RescueMapLocation>? pending;

  @override
  Future<RescueMapLocation> resolveCurrentLocation({
    RescueLocationRequest? request,
  }) async {
    calls++;
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    return const RescueMapLocation(latitude: 21.0321, longitude: 105.8422);
  }
}

class _DelayedPermissionPlatform extends GeolocatorPlatform {
  final permission = Completer<LocationPermission>();
  int positionCalls = 0;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;
  @override
  Future<LocationPermission> requestPermission() => permission.future;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    positionCalls++;
    return Position(
      latitude: 10.7769,
      longitude: 106.7009,
      timestamp: DateTime.utc(2026, 9, 7),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

class _RealPickerService extends PickerLocationService {
  @override
  Future<RescueMapLocation> resolveCurrentLocation({
    RescueLocationRequest? request,
  }) => GeolocatorRescueLocationService().resolveCurrentLocation(
    request: request,
  );
}

Widget _fakeMap(
  RescueDraftLocation? selected,
  ValueChanged<RescueDraftLocation> onSelect,
  VoidCallback onUnavailable,
) => ColoredBox(
  key: const Key('day103-fake-map'),
  color: const Color(0xffdff3ea),
  child: Stack(
    children: [
      Center(
        child: TextButton.icon(
          key: const Key('day103-fake-map-select'),
          onPressed: () => onSelect(
            const RescueDraftLocation(latitude: 10.7812, longitude: 106.6984),
          ),
          icon: const Icon(Icons.location_on_outlined),
          label: Text(selected == null ? 'Chọn trên bản đồ' : 'Đổi vị trí'),
        ),
      ),
      Align(
        alignment: Alignment.topRight,
        child: IconButton(
          key: const Key('day103-fake-map-fail'),
          tooltip: 'Giả lập bản đồ lỗi',
          onPressed: onUnavailable,
          icon: const Icon(Icons.cloud_off_outlined),
        ),
      ),
    ],
  ),
);

Future<ProviderContainer> _pumpCreate(
  WidgetTester tester,
  PickerLocationService service, {
  Size size = const Size(390, 844),
  double textScale = 1,
  double keyboardInset = 0,
}) async {
  await setTestViewport(tester, size: size, keyboardInset: keyboardInset);
  final container = ProviderContainer(
    overrides: [
      rescueLocationServiceProvider.overrideWithValue(service),
      rescuePickerMapBuilderProvider.overrideWithValue(_fakeMap),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: testTextScaleBuilder(textScale),
        home: const RescueCreateScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _openPicker(WidgetTester tester) async {
  final card = find.byKey(const Key('rescue-create-location-card'));
  await tester.scrollUntilVisible(
    card,
    140,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(card), alignment: .3);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('rescue-location-picker')), findsOneWidget);
}

Future<void> _scrollTo(WidgetTester tester, Key key) async {
  final target = find.byKey(key);
  final scrollable = find
      .descendant(
        of: find.byKey(const Key('rescue-location-picker')),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(target, 180, scrollable: scrollable);
  await Scrollable.ensureVisible(tester.element(target), alignment: .55);
  await tester.pumpAndSettle();
}

void main() {
  for (final action in ['dispose', 'map', 'deny']) {
    testWidgets('pending permission lifecycle: $action', (tester) async {
      final original = GeolocatorPlatform.instance;
      final platform = _DelayedPermissionPlatform();
      GeolocatorPlatform.instance = platform;
      addTearDown(() => GeolocatorPlatform.instance = original);
      await _pumpCreate(tester, _RealPickerService());
      await _openPicker(tester);
      await tester.tap(find.byKey(const Key('rescue-location-gps')));
      await tester.pump();
      if (action == 'dispose') {
        await tester.pumpWidget(const SizedBox.shrink());
      } else if (action == 'map') {
        await tester.tap(find.byKey(const Key('day103-fake-map-select')));
        await tester.pump();
      }
      await tester.pump(const Duration(seconds: 30));
      platform.permission.complete(
        action == 'deny'
            ? LocationPermission.denied
            : LocationPermission.whileInUse,
      );
      await tester.pumpAndSettle();
      expect(platform.positionCalls, 0);
      expect(tester.takeException(), isNull);
      if (action == 'deny') {
        expect(find.textContaining('Chưa có quyền định vị'), findsOneWidget);
      } else if (action == 'map') {
        expect(find.text('10.7812'), findsOneWidget);
        expect(find.byKey(const Key('rescue-location-error')), findsNothing);
      }
    });
  }
  testWidgets('30 second permission decision completes without GPS retry', (
    tester,
  ) async {
    final original = GeolocatorPlatform.instance;
    final platform = _DelayedPermissionPlatform();
    GeolocatorPlatform.instance = platform;
    addTearDown(() => GeolocatorPlatform.instance = original);
    final container = await _pumpCreate(tester, _RealPickerService());
    await _openPicker(tester);
    await tester.tap(find.byKey(const Key('rescue-location-gps')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(platform.positionCalls, 0);
    platform.permission.complete(LocationPermission.whileInUse);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rescue-location-error')), findsNothing);
    await _scrollTo(tester, const Key('rescue-location-confirm'));
    await tester.tap(find.byKey(const Key('rescue-location-confirm')));
    await tester.pumpAndSettle();
    expect(
      container.read(rescueCreateProvider).draft.exactLocation?.latitude,
      10.7769,
    );
    expect(platform.positionCalls, 1);
  });
  test('invalid precise coordinates cannot pass step one', () {
    final draft = RescueDraft(
      petName: 'Mochi',
      breedOrColor: 'Poodle',
      lostAt: DateTime(2026, 9, 4),
    );
    for (final point in [
      const RescueDraftLocation(latitude: 91, longitude: 106),
      const RescueDraftLocation(latitude: 21, longitude: double.nan),
    ]) {
      expect(
        draft.copyWith(exactLocation: point).validateStepOne(),
        contains('exactLocation'),
      );
    }
  });

  testWidgets('GPS remains a preview until explicit owner confirmation', (
    tester,
  ) async {
    final service = PickerLocationService();
    final container = await _pumpCreate(tester, service);
    await _openPicker(tester);
    await tester.tap(find.byKey(const Key('rescue-location-gps')));
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    expect(container.read(rescueCreateProvider).draft.exactLocation, isNull);
    await _scrollTo(tester, const Key('rescue-location-confirm'));
    await tester.tap(find.byKey(const Key('rescue-location-confirm')));
    await tester.pumpAndSettle();
    final selected = container.read(rescueCreateProvider).draft.exactLocation!;
    expect(selected.latitude, 21.0321);
    expect(selected.longitude, 105.8422);
    expect(selected.formattedAddress, isNull);
  });

  testWidgets('permission denied falls back to valid manual selection', (
    tester,
  ) async {
    final service = PickerLocationService()
      ..error = const RescueLocationException(
        RescueLocationFailureType.permissionDenied,
        'denied',
      );
    final container = await _pumpCreate(tester, service);
    await _openPicker(tester);
    await tester.tap(find.byKey(const Key('rescue-location-gps')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có quyền định vị'), findsOneWidget);
    await _scrollTo(tester, const Key('rescue-location-latitude'));
    await tester.enterText(
      find.byKey(const Key('rescue-location-latitude')),
      '10.7769',
    );
    await tester.enterText(
      find.byKey(const Key('rescue-location-longitude')),
      '106.7009',
    );
    await tester.enterText(
      find.byKey(const Key('rescue-location-address')),
      '12 Lê Lợi, Quận 1',
    );
    await _scrollTo(tester, const Key('rescue-location-apply'));
    await tester.tap(find.byKey(const Key('rescue-location-apply')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, const Key('rescue-location-confirm'));
    await tester.tap(find.byKey(const Key('rescue-location-confirm')));
    await tester.pumpAndSettle();
    final selected = container.read(rescueCreateProvider).draft.exactLocation!;
    expect(selected.latitude, 10.7769);
    expect(selected.longitude, 106.7009);
    expect(selected.formattedAddress, '12 Lê Lợi, Quận 1');
  });

  testWidgets('map unavailable provides retry and manual fallback', (
    tester,
  ) async {
    await _pumpCreate(tester, PickerLocationService());
    await _openPicker(tester);
    await tester.tap(find.byKey(const Key('day103-fake-map-fail')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bản đồ chưa tải được'), findsOneWidget);
    expect(find.byKey(const Key('rescue-location-latitude')), findsOneWidget);
    await tester.tap(find.byKey(const Key('rescue-location-retry-map')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('day103-fake-map')), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('a later map selection wins over a stale GPS completion', (
    tester,
  ) async {
    final service = PickerLocationService()
      ..pending = Completer<RescueMapLocation>();
    final container = await _pumpCreate(tester, service);
    await _openPicker(tester);
    await tester.tap(find.byKey(const Key('rescue-location-gps')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('day103-fake-map-select')));
    await tester.pump();
    service.pending!.complete(
      const RescueMapLocation(latitude: 20.9, longitude: 105.7),
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, const Key('rescue-location-confirm'));
    await tester.tap(find.byKey(const Key('rescue-location-confirm')));
    await tester.pumpAndSettle();
    final selected = container.read(rescueCreateProvider).draft.exactLocation!;
    expect(selected.latitude, 10.7812);
    expect(selected.longitude, 106.6984);
  });

  testWidgets('cancel preserves the existing owner-only location', (
    tester,
  ) async {
    final container = await _pumpCreate(tester, PickerLocationService());
    const original = RescueDraftLocation(
      latitude: 10.77,
      longitude: 106.69,
      formattedAddress: 'Địa chỉ riêng tư',
    );
    container.read(rescueCreateProvider.notifier).setLocation(original);
    await tester.pump();
    await _openPicker(tester);
    await tester.tap(find.byKey(const Key('day103-fake-map-select')));
    await tester.pump();
    await _scrollTo(tester, const Key('rescue-location-cancel'));
    await tester.tap(find.byKey(const Key('rescue-location-cancel')));
    await tester.pumpAndSettle();
    expect(container.read(rescueCreateProvider).draft.exactLocation, original);
  });

  testWidgets('small screen, text scale 2 and IME remain scrollable', (
    tester,
  ) async {
    await _pumpCreate(
      tester,
      PickerLocationService(),
      size: const Size(320, 568),
      textScale: 2,
    );
    await _openPicker(tester);
    await _scrollTo(tester, const Key('rescue-location-address'));
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('rescue-location-address')),
        matching: find.byType(EditableText),
      ),
    );
    await setKeyboardInset(tester, bottom: 240);
    await tester.enterText(
      find.byKey(const Key('rescue-location-address')),
      'Địa chỉ gợi nhớ rất dài chỉ hiển thị cho chủ tin',
    );
    await tester.pump();
    expectNoFlutterOverflow(tester);
    await _scrollTo(tester, const Key('rescue-location-cancel'));
    expect(find.byKey(const Key('rescue-location-cancel')), findsOneWidget);
    expectNoFlutterOverflow(tester);
  });

  testWidgets('privacy explanation and selected marker expose semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pumpCreate(tester, PickerLocationService());
    await _openPicker(tester);
    expect(find.textContaining('chỉ lưu riêng cho chủ tin'), findsOneWidget);
    await tester.tap(find.byKey(const Key('day103-fake-map-select')));
    await tester.pump();
    expect(find.textContaining('Đã chọn vị trí'), findsOneWidget);
    expectNoFlutterOverflow(tester);
    handle.dispose();
  });
}
