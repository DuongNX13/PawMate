import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_button.dart';
import 'package:pawmate_mobile/core/widgets/pawmate_bottom_nav.dart';
import 'day122_android_responsive_test.dart' show restoreNativeMetrics122;
import 'day122_android_stress_test.dart' show NativeStressVetFixture;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawmate_mobile/app/theme/app_theme.dart';
import 'package:pawmate_mobile/features/vets/application/vet_map_provider.dart';
import 'package:pawmate_mobile/features/vets/presentation/vet_map_screen.dart';
import 'package:pawmate_mobile/features/notifications/application/notification_providers.dart';
import 'package:pawmate_mobile/features/notifications/domain/pawmate_notification.dart';
import 'package:pawmate_mobile/features/notifications/presentation/notification_center_screen.dart';
import '../test/test_support/day119_detail_support.dart' as detail;
import '../test/visual/day120_support_scaling_test.dart' as support;
import '../test/visual/day55_adoption_request_chat_golden_test.dart' as chat;

// A distinct host-compositor lane. The exhausted Onboarding semantics-handle
// branch is intentionally not retried or counted as passed here.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const run = String.fromEnvironment('D122_RUN');
  const selected = String.fromEnvironment('D122_FAMILIES');
  const width = int.fromEnvironment('D122_WIDTH');
  const height = int.fromEnvironment('D122_HEIGHT');
  const bridge = '/data/user/0/com.pawmate.pawmate_mobile/files/day122-r2';
  final size = Size(width.toDouble(), height.toDouble());
  final families = selected.split(',');
  final previous = Directory.current;
  Directory? assets;
  var sequence = 0;
  binding.reportData = {
    'day': 122,
    'run': run,
    'rows': <Map<String, Object?>>[],
  };
  setUpAll(() async {
    if (!run.startsWith('host-') ||
        families.any(
          (f) => !const [
            'PetEdit',
            'VetMap',
            'Notifications',
            'RescueExpanded',
            'RescueSelected',
            'MyRequests',
            'ShelterChat',
          ].contains(f),
        )) {
      throw StateError('Explicit unexhausted stress selection required');
    }
    assets = await Directory.systemTemp.createTemp('day122-host-stress-');
    Directory.current = assets!;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final asset in manifest.listAssets().where(
      (s) => s.startsWith('assets/images/') || s.startsWith('assets/icons/'),
    )) {
      final data = await rootBundle.load(asset);
      final f = File(asset);
      await f.parent.create(recursive: true);
      await f.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }
    final fixture = File('test/fixtures/images/golden_retriever_hero_v1.png');
    await fixture.parent.create(recursive: true);
    await File('$bridge/hero.png').copy(fixture.absolute.path);
  });
  tearDownAll(() async {
    Directory.current = previous;
    await assets?.delete(recursive: true);
  });
  Future<void> capture(WidgetTester t, String family, String stage) async {
    await t.pump(const Duration(milliseconds: 400));
    final n = ui.PlatformDispatcher.instance.views.single;
    final request = {
      'run': run,
      'sequence': ++sequence,
      'id': 'ANDROID-STRESS-$family',
      'stage': stage,
      'at': DateTime.now().toUtc().toIso8601String(),
      'physical': [n.physicalSize.width, n.physicalSize.height],
      'dpr': n.devicePixelRatio,
      'font_scale': ui.PlatformDispatcher.instance.textScaleFactor,
      'native_ime_bottom': n.viewInsets.bottom / n.devicePixelRatio,
      'visible_text': find
          .byType(Text)
          .evaluate()
          .map(
            (e) =>
                (e.widget as Text).data ??
                (e.widget as Text).textSpan?.toPlainText() ??
                '',
          )
          .where((s) => s.isNotEmpty)
          .toList(),
      'fixture_boundaries': 'BACKEND_MAP_CLOCK_DOUBLES_NOT_LIVE',
    };
    await t.runAsync(() async {
      final pending = File('$bridge/pending.json');
      if (await pending.exists()) throw StateError('Unacknowledged checkpoint');
      await pending.writeAsString(jsonEncode(request), flush: true);
      final ack = File('$bridge/ack-$sequence.json');
      final clock = Stopwatch()..start();
      while (!await ack.exists()) {
        if (clock.elapsed > const Duration(seconds: 25)) {
          throw StateError('Host capture deadline');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final value =
          jsonDecode(await ack.readAsString()) as Map<String, dynamic>;
      if (value['run'] != run ||
          value['sequence'] != sequence ||
          value['id'] != request['id']) {
        throw StateError('Checkpoint identity mismatch');
      }
      await pending.delete();
    });
  }

  for (final family in families) {
    testWidgets('D122 host stress $family', (t) async {
      final n = ui.PlatformDispatcher.instance.views.single;
      expect(n.physicalSize / n.devicePixelRatio, size);
      expect(ui.PlatformDispatcher.instance.textScaleFactor, closeTo(2, .01));
      switch (family) {
        case 'PetEdit':
          await support.pumpFamily(t, 'DT-02', size);
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
      expect(
        MediaQuery.textScalerOf(t.element(find.byType(Scaffold).first)).scale(16),
        greaterThan(16),
        reason: 'Rendered app must inherit the actual native font scale',
      );
      expect(t.takeException(), isNull);
      await capture(t, family, 'top');
      if (family == 'PetEdit' || family == 'ShelterChat') {
        final field = find.byKey(
          Key(
            family == 'PetEdit'
                ? 'pet-form-name-field'
                : 'adoption-chat-composer',
          ),
        );
        await t.ensureVisible(field);
        await t.tap(field);
        await t.showKeyboard(field);
        final deadline = DateTime.now().add(const Duration(seconds: 8));
        while (n.viewInsets.bottom <= 0 && DateTime.now().isBefore(deadline)) {
          await t.pump(const Duration(milliseconds: 100));
        }
        expect(n.viewInsets.bottom, greaterThan(0));
        await t.pumpAndSettle();
        final cta = family == 'PetEdit'
            ? find.descendant(
                of: find.byKey(const Key('pet-form-save-button')),
                matching: find.byType(PawMateButton),
              )
            : find.byKey(const Key('adoption-chat-send'));
        await t.ensureVisible(cta);
        await t.pumpAndSettle();
        expect(cta.hitTestable(), findsOneWidget);
        expect(
          t.getRect(cta).bottom,
          lessThanOrEqualTo(
            size.height - n.viewInsets.bottom / n.devicePixelRatio + 1,
          ),
        );
      } else if (family == 'RescueExpanded' || family == 'RescueSelected') {
        final target = family == 'RescueExpanded'
            ? find.byKey(const Key('rescue-load-more'))
            : find.byKey(ValueKey('rescue-marker-${detail.day119FirstCaseId}'));
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
        expect(
          t.getRect(find.byType(PawMateBottomNav)).bottom,
          closeTo(height, .6),
        );
      } else {
        final scroll = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        );
        if (scroll.evaluate().isNotEmpty) {
          final p = t.state<ScrollableState>(scroll.first).position;
          for (var i = 0; i < 5 && p.extentAfter > .5; i++) {
            p.jumpTo(p.maxScrollExtent);
            await t.pump(const Duration(milliseconds: 300));
          }
          expect(p.extentAfter, lessThanOrEqualTo(.5));
        }
      }
      expect(t.takeException(), isNull);
      await capture(t, family, 'end');
      (binding.reportData!['rows'] as List<Map<String, Object?>>).add({
        'id': 'ANDROID-STRESS-$family',
        'runtime': 'PASS',
        'visual': 'REVIEW_REQUIRED',
        'talkback_proof': false,
      });
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
