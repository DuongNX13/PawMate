import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'day122_android_responsive_test.dart' show restoreNativeMetrics122;
import '../test/visual/phase1_entry_golden_test.dart' as entry;
import 'package:pawmate_mobile/features/onboarding/presentation/onboarding_screen.dart';

// Fresh, single-screen compositor transport; no screenshot conversion and no
// subsequent screen can consume an outstanding capture from this test.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const run = String.fromEnvironment('D122_RUN');
  const bridge = '/data/user/0/com.pawmate.pawmate_mobile/files/day122-r3';
  binding.reportData = {'day':122,'run':run,'rows':<Map<String,Object?>>[]};
  testWidgets('D122 isolated Onboarding host compositor and real IME', (t) async {
    expect(run, 'onboarding-r3');
    var seq = 0;
    Future<void> phase(String value) => t.runAsync(() async {
      final f = File('$bridge/stages.jsonl');
      await f.writeAsString('${jsonEncode({'run':run,'phase':value,'at':DateTime.now().toUtc().toIso8601String()})}\n',mode:FileMode.append,flush:true);
    });
    Future<void> capture(String stage, {double? ctaBottom,bool? actionable}) async {
      expect(find.byType(OnboardingScreen), findsOneWidget);
      final n = ui.PlatformDispatcher.instance.views.single;
      final request = {'run':run,'sequence':++seq,'id':'ANDROID-STRESS-Onboarding','stage':stage,
        'screen':'OnboardingScreen','at':DateTime.now().toUtc().toIso8601String(),
        'physical':[n.physicalSize.width,n.physicalSize.height],'dpr':n.devicePixelRatio,
        'font_scale':ui.PlatformDispatcher.instance.textScaleFactor,
        'native_ime_bottom':n.viewInsets.bottom/n.devicePixelRatio,
        'cta_bottom':ctaBottom,'cta_hit_testable':actionable,
        'visible_text':find.byType(Text).evaluate().map((e)=>(e.widget as Text).data??'').where((s)=>s.isNotEmpty).toList(),
        'fixture_boundaries':'PREFERENCES_AUTH_DOUBLES_NOT_LIVE'};
      await t.runAsync(() async {
        final pending = File('$bridge/pending.json');
        if (await pending.exists()) throw StateError('Outstanding checkpoint');
        await pending.writeAsString(jsonEncode(request),flush:true);
        final ack = File('$bridge/ack-$seq.json');
        final clock = Stopwatch()..start();
        while (!await ack.exists()) {
          if(clock.elapsed > const Duration(seconds:20)) throw StateError('Host ACK deadline');
          await Future<void>.delayed(const Duration(milliseconds:100));
        }
        final value = jsonDecode(await ack.readAsString()) as Map<String,dynamic>;
        expect(value['run'],run); expect(value['sequence'],seq); expect(value['id'],request['id']);
        await pending.delete();
      });
    }
    try {
      await phase('mount-start');
      await entry.pumpDay120Entry(t,const Size(320,568),login:false);
      restoreNativeMetrics122(t);
      await t.pump(const Duration(milliseconds:500));
      final n = ui.PlatformDispatcher.instance.views.single;
      expect(n.physicalSize/n.devicePixelRatio,const Size(320,568));
      expect(ui.PlatformDispatcher.instance.textScaleFactor,closeTo(2,.01));
      expect(MediaQuery.textScalerOf(t.element(find.byType(Scaffold))).scale(16),greaterThan(16));
      await phase('mount-end');
      await capture('top');
      await phase('top-acked');
      final field = find.byKey(const Key('onboarding-pet-name-field'));
      await t.ensureVisible(field); await t.pumpAndSettle();
      await phase('field-visible');
      await t.tap(field); await t.showKeyboard(field);
      final deadline = DateTime.now().add(const Duration(seconds:8));
      while (n.viewInsets.bottom<=0 && DateTime.now().isBefore(deadline)) {
        await t.pump(const Duration(milliseconds:100));
      }
      expect(n.viewInsets.bottom,greaterThan(0));
      await t.pumpAndSettle(); await phase('native-ime-visible');
      final cta=find.byKey(const ValueKey('onboarding-continue-button'));
      await t.ensureVisible(cta); await t.pumpAndSettle(); await phase('cta-visible');
      expect(cta.hitTestable(),findsOneWidget);
      final bottom=t.getRect(cta).bottom;
      expect(bottom,lessThanOrEqualTo(568-n.viewInsets.bottom/n.devicePixelRatio+1));
      expect(t.takeException(),isNull);
      await capture('end',ctaBottom:bottom,actionable:true); await phase('end-acked');
      (binding.reportData!['rows'] as List<Map<String,Object?>>).add({'id':'ANDROID-STRESS-Onboarding','runtime':'PASS','visual':'REVIEW_REQUIRED','talkback_proof':false});
    } finally {
      await phase('unmount-start');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pump(const Duration(milliseconds:500));
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
      await phase('unmount-end');
    }
  }, timeout:const Timeout(Duration(seconds:75)));
}
