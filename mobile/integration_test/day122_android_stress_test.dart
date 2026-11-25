import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/features/vets/application/vet_map_provider.dart';
import 'package:pawmate_mobile/features/vets/domain/vet_map_models.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_screen.dart';
import 'package:pawmate_mobile/features/notifications/application/notification_providers.dart';
import 'package:pawmate_mobile/features/notifications/domain/pawmate_notification.dart';
import 'package:pawmate_mobile/features/notifications/presentation/notification_center_screen.dart';
import '../test/test_support/day119_detail_support.dart' as detail;
import '../test/visual/day120_support_scaling_test.dart' as support;
import '../test/visual/day55_adoption_request_chat_golden_test.dart' as chat;
import 'day122_android_responsive_test.dart' show restoreNativeMetrics122;

class NativeStressVetFixture extends VetMapNotifier {
  @override
  VetMapState build() => const VetMapState(
    status: VetMapStatus.permissionDenied,
    hasLoadedAtLeastOnce: true,
  );
  @override
  Future<void> initialize() async {}
  @override
  Future<void> refresh({bool forceLocationRefresh = false}) async {
    state = state.copyWith(mapUnavailable: true);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const chatOnly = bool.fromEnvironment('D122_CHAT_ONLY');
  const petOnly = bool.fromEnvironment('D122_PET_ONLY');
  const runtimeOnly = bool.fromEnvironment('D122_RUNTIME_ONLY');
  Future<void> capture(WidgetTester t, String name) async {
    if (runtimeOnly) return;
    // D124: a settled screen schedules no frame, and the Android capture
    // waits for one; force a frame so it cannot hang until the timeout.
    t.binding.scheduleFrame();
    await t.pump();
    await binding.takeScreenshot(name);
  }

  final families = chatOnly
      ? ['ShelterChat']
      : petOnly
      ? ['PetEdit']
      : [
          'Onboarding',
          'PetEdit',
          'VetMap',
          'Notifications',
          'RescueExpanded',
          'RescueSelected',
          'MyRequests',
        ];
  final priorDirectory = Directory.current;
  Directory? assets;
  binding.reportData = {
    'day': 122,
    'proof': 'ANDROID_NATIVE_STRESS_FIXTURE_DATA',
    'captures': runtimeOnly
        ? 'NOT_RUN_CAPTURE_BRANCH_STOPPED'
        : 'REVIEW_REQUIRED',
    'rows': <Map<String, dynamic>>[],
  };
  setUpAll(() async {
    assets = await Directory.systemTemp.createTemp('day122-stress-');
    Directory.current = assets!;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final asset in manifest.listAssets().where(
      (s) => s.startsWith('assets/images/') || s.startsWith('assets/icons/'),
    )) {
      final bytes = await rootBundle.load(asset);
      final f = File(asset);
      await f.parent.create(recursive: true);
      await f.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    }
  });
  tearDownAll(() async {
    Directory.current = priorDirectory;
    await assets?.delete(recursive: true);
  });
  for (final family in families) {
    testWidgets(
      'D122 native stress $family font2',
      (t) async {
        final n = ui.PlatformDispatcher.instance.views.single;
        final size = n.physicalSize / n.devicePixelRatio;
        expect(size, chatOnly ? const Size(360, 800) : const Size(320, 568));
        expect(ui.PlatformDispatcher.instance.textScaleFactor, closeTo(2, .01));
        switch (family) {
          case 'Onboarding':
          case 'PetEdit':
            await support.pumpFamily(
              t,
              family == 'Onboarding' ? 'P1-01' : 'DT-02',
              size,
            );
          case 'VetMap':
            await t.pumpWidget(
              ProviderScope(
                overrides: [
                  vetMapProvider.overrideWith(NativeStressVetFixture.new),
                ],
                child: MaterialApp(
                  theme: AppTheme.light(),
                  home: const VetMapScreen(),
                ),
              ),
            );
            await t.pumpAndSettle();
          case 'Notifications':
            await t.pumpWidget(
              ProviderScope(
                overrides: [
                  notificationListProvider.overrideWith(
                    (ref) async => const NotificationListResult(
                      items: [],
                      total: 0,
                      unreadCount: 0,
                      limit: 20,
                    ),
                  ),
                ],
                child: MaterialApp(
                  theme: AppTheme.light(),
                  home: const NotificationCenterScreen(),
                ),
              ),
            );
            await t.pumpAndSettle();
          case 'RescueExpanded':
          case 'RescueSelected':
          case 'MyRequests':
            await detail.pumpDay119(
              t,
              family == 'MyRequests' ? 'DT-03' : 'DT-04',
              size,
              longContent: true,
            );
          case 'ShelterChat':
            await chat.pumpDay118Chat(t, size);
        }
        restoreNativeMetrics122(t);
        await t.pump(const Duration(milliseconds: 500));
        if (!runtimeOnly) await binding.convertFlutterSurfaceToImage();
        await t.pump();
        expect(
          MediaQuery.textScalerOf(
            t.element(find.byType(Scaffold).first),
          ).scale(16),
          greaterThan(16),
        );
        await capture(t, 'D122-stress-${family.toLowerCase()}-top');
        if (family == 'Onboarding' ||
            family == 'PetEdit' ||
            family == 'ShelterChat') {
          final key = switch (family) {
            'Onboarding' => 'onboarding-pet-name-field',
            'PetEdit' => 'pet-form-name-field',
            _ => 'adoption-chat-composer',
          };
          final action = switch (family) {
            'Onboarding' => 'onboarding-continue-button',
            'PetEdit' => 'pet-form-save-button',
            _ => 'adoption-chat-send',
          };
          final field = find.byKey(Key(key));
          await t.ensureVisible(field);
          await t.tap(field);
          await t.showKeyboard(field);
          final end = DateTime.now().add(const Duration(seconds: 8));
          while (n.viewInsets.bottom <= 0 && DateTime.now().isBefore(end)) {
            await t.pump(const Duration(milliseconds: 100));
          }
          expect(n.viewInsets.bottom, greaterThan(0));
          await t.pumpAndSettle();
          // Pet Edit's key belongs to the whole fixed bar, including its IME
          // spacer. Assert the actionable button, not that intentional spacer.
          final cta = family == 'PetEdit'
              ? find.descendant(
                  of: find.byKey(Key(action)),
                  matching: find.byType(PawMateButton),
                )
              : find.byKey(Key(action));
          expect(cta, findsOneWidget);
          await t.ensureVisible(cta);
          await t.pumpAndSettle();
          await capture(
            t,
            'D122-stress-${family.toLowerCase()}-ime-diagnostic',
          );
          expect(cta.hitTestable(), findsOneWidget);
          expect(
            t.getRect(cta).bottom,
            lessThanOrEqualTo(
              size.height - n.viewInsets.bottom / n.devicePixelRatio + 1,
            ),
          );
          await capture(t, 'D122-stress-${family.toLowerCase()}-ime');
        } else if (family == 'RescueExpanded' || family == 'RescueSelected') {
          final target = family == 'RescueExpanded'
              ? find.byKey(const Key('rescue-load-more'))
              : find.byKey(
                  ValueKey('rescue-marker-${detail.day119FirstCaseId}'),
                );
          await t.ensureVisible(target);
          await t.pumpAndSettle();
          await t.tap(target);
          await t.pumpAndSettle();
          expect(
            family == 'RescueExpanded'
                ? find.text('Thu gọn')
                : find.byKey(const Key('rescue-selected-case-card')),
            findsOneWidget,
          );
          await capture(t, 'D122-stress-${family.toLowerCase()}-selected');
        } else {
          final scroll = find.byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          );
          if (scroll.evaluate().isNotEmpty) {
            final position = t.state<ScrollableState>(scroll.first).position;
            for (var i = 0; i < 5 && position.extentAfter > .5; i++) {
              position.jumpTo(position.maxScrollExtent);
              await t.pump(const Duration(milliseconds: 300));
            }
            expect(position.extentAfter, lessThanOrEqualTo(.5));
          }
          await capture(t, 'D122-stress-${family.toLowerCase()}-end');
        }
        expect(t.takeException(), isNull);
        (binding.reportData!['rows'] as List<Map<String, dynamic>>).add({
          'id': 'ANDROID-STRESS-$family',
          'at': DateTime.now().toUtc().toIso8601String(),
          'viewport': [size.width, size.height],
          'font_scale': ui.PlatformDispatcher.instance.textScaleFactor,
          'native_insets': [
            n.viewPadding.top,
            n.viewPadding.bottom,
            n.viewInsets.bottom,
          ],
          'state_coverage': family == 'VetMap'
              ? 'PERMISSION_DENIED_FIXTURE'
              : family == 'Notifications'
              ? 'EMPTY_COLLECTION_FIXTURE'
              : 'RUNTIME_ONLY',
          'verdict': 'RUNTIME_ASSERTIONS_PASS_VISUAL_REVIEW_REQUIRED',
          'talkback_proof': false,
        });
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
